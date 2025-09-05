# app.py  (fixed paths + stable ROI/classifier pipeline)

from flask import Flask, request, jsonify
from flask_cors import CORS
import time, os
from pathlib import Path
import cv2, numpy as np
import torch, torch.nn.functional as F
from torchvision import models, transforms
from PIL import Image
from ultralytics import YOLO

# ---------- 路徑穩定設定 ----------
BASE = Path(__file__).resolve().parent  # = project_root/python_server

def _p(env_name: str, default_rel: Path) -> Path:
    """優先吃環境變數；否則用 BASE / default_rel。"""
    p = os.getenv(env_name, "")
    return Path(p) if p else (BASE / default_rel)

YOLO_WEIGHTS = _p("YOLO_WEIGHTS", Path("models") / "best.pt")
CLS_WEIGHTS  = _p("CLS_WEIGHTS",  Path("models") / "cls_best.pt")
LABELS_TXT   = _p("LABELS_TXT",   Path("assets") / "labels.txt")

print("[PATHS]")
print("  YOLO   :", YOLO_WEIGHTS)
print("  CLS    :", CLS_WEIGHTS)
print("  LABELS :", LABELS_TXT)

# 先檢查檔案是否存在，問題提早爆
assert LABELS_TXT.exists(), f"labels.txt not found at {LABELS_TXT}"
assert YOLO_WEIGHTS.exists(), f"YOLO weights not found at {YOLO_WEIGHTS}"
assert CLS_WEIGHTS.exists(),  f"classifier weights not found at {CLS_WEIGHTS}"

# ---------- Flask ----------
app = Flask(__name__)
CORS(app)  # 開發期先全開，上線再收斂

# ---------- 讀取 labels ----------
with open(LABELS_TXT, "r", encoding="utf-8") as f:
    LABELS = [x.strip() for x in f if x.strip()]
NUM_CLASSES = len(LABELS)

# ---------- 分類模型（支援整模 or state_dict） ----------
def load_classifier(weights_path: Path, num_classes: int):
    obj = torch.load(str(weights_path), map_location="cpu")
    if hasattr(obj, "state_dict"):       # 可能是整個 nn.Module
        model = obj
    elif isinstance(obj, dict):          # 可能是 state_dict
        model = models.resnet18(weights=None)
        model.fc = torch.nn.Linear(model.fc.in_features, num_classes)
        model.load_state_dict(obj)
    else:
        raise RuntimeError("Unsupported weight format for classifier")
    model.eval()
    return model

# ---------- 前處理（與訓練一致） ----------
TFM = transforms.Compose([
    transforms.Resize((224, 224)),
    transforms.ToTensor(),
    transforms.Normalize(mean=[0.485,0.456,0.406],
                         std =[0.229,0.224,0.225]),
])

# ---------- 載模型（只載一次） ----------
yolo_model   = YOLO(str(YOLO_WEIGHTS))             # YOLO 偵測
resnet_model = load_classifier(CLS_WEIGHTS, NUM_CLASSES)

# 暖機（避免第一次卡頓）
with torch.no_grad():
    _ = resnet_model(torch.zeros(1, 3, 224, 224))

# ---------- ROI 選擇邏輯 ----------
def select_roi_bgr(img_bgr, yolo_res, expand=1.2):
    """
    從 YOLO 結果中挑 hand 與 fretboard 交會最大的組合，回傳放大的 ROI。
    找不到就回傳整張。
    """
    H, W = img_bgr.shape[:2]
    names = getattr(yolo_model, "names", {})  # {id:name}
    hand_ids = {i for i, n in names.items() if "hand" in n.lower()}
    fret_ids = {i for i, n in names.items() if "fret" in n.lower() or "neck" in n.lower()}

    boxes = yolo_res[0].boxes
    if boxes is None or len(boxes) == 0:
        return img_bgr, (0,0,W,H)

    xyxy = boxes.xyxy.cpu().numpy().astype(int)
    cls  = boxes.cls.cpu().numpy().astype(int)

    hands = [xyxy[i] for i in range(len(cls)) if cls[i] in hand_ids]
    frets = [xyxy[i] for i in range(len(cls)) if cls[i] in fret_ids]
    if not hands or not frets:
        return img_bgr, (0,0,W,H)

    def inter_area(a, b):
        x1, y1 = max(a[0], b[0]), max(a[1], b[1])
        x2, y2 = min(a[2], b[2]), min(a[3], b[3])
        return max(0, x2-x1) * max(0, y2-y1)

    best = None
    for hb in hands:
        ha = (hb[2]-hb[0])*(hb[3]-hb[1]) + 1e-6
        for fb in frets:
            ia = inter_area(hb, fb)
            ioa = ia / ha
            if best is None or ioa > best[0]:
                best = (ioa, hb, fb)

    if best is None or best[0] < 0.05:
        return img_bgr, (0,0,W,H)

    _, hb, fb = best
    x1, y1 = min(hb[0], fb[0]), min(hb[1], fb[1])
    x2, y2 = max(hb[2], fb[2]), max(hb[3], fb[3])

    # 外擴
    cx, cy = (x1+x2)/2, (y1+y2)/2
    w, h   = (x2-x1)*expand, (y2-y1)*expand
    nx1, ny1 = int(max(0, cx-w/2)), int(max(0, cy-h/2))
    nx2, ny2 = int(min(W, cx+w/2)), int(min(H, cy+h/2))

    roi = img_bgr[ny1:ny2, nx1:nx2]
    if roi.size == 0:
        return img_bgr, (0,0,W,H)
    return roi, (nx1, ny1, nx2-nx1, ny2-ny1)

# ---------- API ----------
@app.post("/predict")
def predict():
    t0 = time.time()

    if "image" not in request.files:
        return jsonify({"error": "missing field 'image'"}), 400

    # 1) 讀圖（BGR）
    file = request.files["image"]
    data = np.frombuffer(file.read(), np.uint8)
    img  = cv2.imdecode(data, cv2.IMREAD_COLOR)
    if img is None:
        return jsonify({"error": "decode_failed"}), 400

    # 2) YOLO 偵測 + 取 ROI
    det_res = yolo_model(img)
    roi_bgr, (rx, ry, rw, rh) = select_roi_bgr(img, det_res, expand=1.2)

    # 3) 分類（BGR→RGB→PIL→TFM）
    roi_rgb = cv2.cvtColor(roi_bgr, cv2.COLOR_BGR2RGB)
    x = TFM(Image.fromarray(roi_rgb)).unsqueeze(0)

    with torch.no_grad():
        logits = resnet_model(x)
        prob = F.softmax(logits, dim=1)[0]
        score, idx = torch.max(prob, dim=0)
        k = min(5, prob.numel())
        topk_p, topk_i = torch.topk(prob, k=k)
        topk = [{"label": LABELS[i.item()], "prob": float(p.item())}
                for p, i in zip(topk_p, topk_i)]

    ms = int((time.time() - t0) * 1000)
    return jsonify({
        "chord": LABELS[idx.item()],
        "score": float(score.item()),
        "topk": topk,
        "roi": {"x": rx, "y": ry, "w": rw, "h": rh},
        "inference_ms": ms
    })

@app.get("/health")
def health():
    return jsonify({"status": "ok", "classes": NUM_CLASSES})

if __name__ == "__main__":
    # 在 python_server 目錄下執行：python app.py
    app.run(host="0.0.0.0", port=5000, debug=True)
