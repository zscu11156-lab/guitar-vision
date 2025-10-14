# app.py  (aligned with mini_yolo_cls_demo: stable ROI + exact preprocessing + votes + canonical names)
from flask import Flask, request, jsonify
from flask_cors import CORS
import time, os
from pathlib import Path
import cv2, numpy as np
import torch, torch.nn as nn
import torch.nn.functional as F
from torchvision import models
from ultralytics import YOLO
from collections import deque
from io import BytesIO
from PIL import Image, ImageOps  # EXIF 方向修正
from audio_chord import classify_pcm16le  # 你的音訊和弦分類

# ---------- 路徑穩定設定 ----------
BASE = Path(__file__).resolve().parent  # = project_root/python_server
def _p(env_name: str, default_rel: Path) -> Path:
    p = os.getenv(env_name, "")
    return Path(p) if p else (BASE / default_rel)

YOLO_WEIGHTS = _p("YOLO_WEIGHTS", Path("models") / "best.pt")
CLS_WEIGHTS  = _p("CLS_WEIGHTS",  Path("models") / "cls_best.pt")
LABELS_TXT   = _p("LABELS_TXT",   Path("assets") / "labels.txt")

print("[PATHS]")
print("  YOLO   :", YOLO_WEIGHTS)
print("  CLS    :", CLS_WEIGHTS)
print("  LABELS :", LABELS_TXT)

assert YOLO_WEIGHTS.exists(), f"YOLO weights not found at {YOLO_WEIGHTS}"
assert CLS_WEIGHTS.exists(),  f"classifier weights not found at {CLS_WEIGHTS}"
assert LABELS_TXT.exists(),   f"labels.txt not found at {LABELS_TXT}"

# ---------- Canonical chord names（固定你這 12 個） ----------
CANON_LABELS = [
    "Am","Am7","B","Bm","C","Cadd9","D","D7_F#","Dsus4","Em","Em7","G"
]
def _norm_key(s: str) -> str:
    s = (s or "").strip()
    s = s.replace("♯", "#").replace(" ", "").replace("_", "/")
    return s.upper()

CANON_BY_NORM = {_norm_key(c): c for c in CANON_LABELS}  # 規範化key → 正名

# ---------- 讀取 labels.txt（容忍每行末尾逗號） ----------
def _load_labels_file(p: Path):
    labels = []
    with open(p, "r", encoding="utf-8") as f:
        for line in f:
            t = line.strip()
            if not t:
                continue
            # 去除行末逗號/空白
            t = t.strip(", \t\r\n")
            if t:
                labels.append(t)
    return labels

LABELS = _load_labels_file(LABELS_TXT)
NUM_CLASSES = len(LABELS)

# ---------- 與 demo 一致的前處理 ----------
IOA_MIN  = 0.20     # 以「手」為分母的覆蓋率門檻
EXPAND   = 1.20     # 交集外擴倍數
MIN_SIDE = 20       # ROI 最小邊（像素）

MEAN = np.array([0.485, 0.456, 0.406], dtype=np.float32)
STD  = np.array([0.229, 0.224, 0.225], dtype=np.float32)

def _resize_short_side(img_rgb, short=256):
    h, w = img_rgb.shape[:2]
    s = short / min(h, w)
    return cv2.resize(img_rgb, (int(round(w*s)), int(round(h*s))), interpolation=cv2.INTER_LINEAR)

def _center_crop(img_rgb, size=224):
    h, w = img_rgb.shape[:2]
    y1 = max(0, (h - size)//2); x1 = max(0, (w - size)//2)
    return img_rgb[y1:y1+size, x1:x1+size]

def preprocess_for_cls_bgr(img_bgr):
    img = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2RGB)
    img = _resize_short_side(img, 256)
    img = _center_crop(img, 224)
    img = img.astype(np.float32) / 255.0
    img = (img - MEAN) / STD
    img = np.transpose(img, (2, 0, 1))  # CHW
    return torch.from_numpy(img).unsqueeze(0)

# ---------- 幫手 ----------
def _area(rc): return max(0, rc[2]-rc[0]) * max(0, rc[3]-rc[1])

def _inter_rect(a, b):
    x1 = max(a[0], b[0]); y1 = max(a[1], b[1])
    x2 = min(a[2], b[2]); y2 = min(a[3], b[3])
    if x2 <= x1 or y2 <= y1: return None
    return (x1, y1, x2, y2)

def _ioa(inter, a):  # inter 對 a 的覆蓋率（以「手」為分母）
    return _area(inter) / max(1, _area(a))

def _expand_rect(rc, ratio, W, H):
    cx = (rc[0]+rc[2])/2; cy = (rc[1]+rc[3])/2
    w = (rc[2]-rc[0]) * ratio; h = (rc[3]-rc[1]) * ratio
    x1 = int(cx - w/2); y1 = int(cy - h/2)
    x2 = int(cx + w/2); y2 = int(cy + h/2)
    x1 = max(0, x1); y1 = max(0, y1)
    x2 = min(W-1, x2); y2 = min(H-1, y2)
    return (x1, y1, x2, y2)

def _decode_image_bgr_with_exif_and_mirror(jpeg_bytes: bytes, mirror: bool):
    """PIL 做 EXIF 方向；必要時水平鏡像；再回傳 BGR ndarray。"""
    im = Image.open(BytesIO(jpeg_bytes))
    im = ImageOps.exif_transpose(im)
    if mirror:
        im = ImageOps.mirror(im)
    rgb = np.array(im.convert("RGB"))
    return cv2.cvtColor(rgb, cv2.COLOR_RGB2BGR)

def _truthy(s: str) -> bool:
    return s.lower() in ("1", "true", "yes", "y") if s else False

# ---------- 分類模型 ----------
def _build_resnet18(num_classes: int):
    m = models.resnet18(weights=None)
    m.fc = nn.Linear(m.fc.in_features, num_classes)
    return m

def load_classifier(weights_path: Path, num_classes: int, device: str):
    obj = torch.load(str(weights_path), map_location=device)
    if isinstance(obj, dict) and "state_dict" in obj and isinstance(obj["state_dict"], dict):
        state = obj["state_dict"]
        model = _build_resnet18(num_classes).to(device)
        model.load_state_dict(state, strict=True)
    elif isinstance(obj, dict):
        # 純 state_dict
        model = _build_resnet18(num_classes).to(device)
        model.load_state_dict(obj, strict=True)
    else:
        # 直接是整個 nn.Module
        model = obj.to(device)
    model.eval()
    return model

DEVICE = "cuda" if torch.cuda.is_available() else "cpu"

# ---------- 載模型（只載一次） ----------
yolo_model   = YOLO(str(YOLO_WEIGHTS))
resnet_model = load_classifier(CLS_WEIGHTS, NUM_CLASSES, DEVICE)

with torch.no_grad():
    _ = resnet_model(torch.zeros(1, 3, 224, 224, device=DEVICE))  # 暖機

# ---------- Flask ----------
app = Flask(__name__)
CORS(app)

# ---------- ROI（手 ∩ 琴頸，外擴） ----------
def pick_roi_from_results(results_obj):
    r = results_obj[0]  # Ultralytics Results
    H, W = r.orig_shape
    names = r.names  # id->name
    boxes = r.boxes
    if boxes is None or len(boxes) == 0:
        return None

    xyxy = boxes.xyxy.cpu().numpy().astype(int)
    clss = boxes.cls.cpu().numpy().astype(int)

    hands, necks = [], []
    for rc, ci in zip(xyxy, clss):
        name = str(names[int(ci)]).lower()
        if "hand" in name:
            hands.append(tuple(rc))
        if ("fret" in name) or ("neck" in name):
            necks.append(tuple(rc))

    best, best_area = None, -1
    for hb in hands:
        for nb in necks:
            inter = _inter_rect(hb, nb)
            if inter is None:
                continue
            if _ioa(inter, hb) < IOA_MIN:
                continue
            a = _area(inter)
            if a > best_area:
                best_area = a
                best = inter

    if best is None:
        return None
    x1,y1,x2,y2 = _expand_rect(best, EXPAND, W, H)
    return (x1,y1,x2,y2)

# ---------- 視覺多數決 / 連續幀冷卻判分 ----------
VISION_VOTE_K     = 5
VISION_CONF_TH    = 0.30
HOLD_FRAMES       = 3
COOLDOWN_S        = 1.0

_vision_votes = deque(maxlen=VISION_VOTE_K)       # 存 idx
_vision_votes_conf = deque(maxlen=VISION_VOTE_K)  # 存 conf
_last_score_t = 0.0
_hold_idx = None
_hold_cnt = 0

def _vision_vote_update(idx: int, conf: float):
    _vision_votes.append(idx)
    _vision_votes_conf.append(conf)
    if len(_vision_votes) == 0:
        return None, 0.0
    vals = list(_vision_votes)
    maj = max(set(vals), key=vals.count)
    confs = [c for i,c in zip(_vision_votes, _vision_votes_conf) if i == maj]
    maj_conf = float(np.mean(confs)) if confs else 0.0
    return maj, maj_conf

def _maybe_score_event(target_norm: str, maj_idx: int, maj_conf: float):
    global _hold_idx, _hold_cnt, _last_score_t
    now = time.time()
    if maj_idx is None:
        _hold_idx, _hold_cnt = None, 0
        return False

    # 以「正名」比對，但使用規範化key避免 D7_F#/D7/F# 差異
    maj_label = CANON_BY_NORM.get(_norm_key(LABELS[maj_idx]), LABELS[maj_idx])
    if (_norm_key(maj_label) == target_norm) and (maj_conf >= VISION_CONF_TH):
        if _hold_idx == maj_idx:
            _hold_cnt += 1
        else:
            _hold_idx = maj_idx
            _hold_cnt = 1
    else:
        _hold_idx = maj_idx
        _hold_cnt = 0

    if _hold_cnt >= HOLD_FRAMES and (now - _last_score_t) > COOLDOWN_S:
        _last_score_t = now
        _hold_cnt = 0
        return True
    return False

# ---------- 影像 API ----------
@app.post("/predict")
def predict():
    t0 = time.time()
    if "image" not in request.files:
        return jsonify({"error": "missing field 'image'"}), 400

    mirror = _truthy(request.form.get("mirror", ""))  # 前鏡頭請帶 1

    # 讀圖（PIL EXIF + 可選鏡像 → BGR）
    raw = request.files["image"].read()
    try:
        img = _decode_image_bgr_with_exif_and_mirror(raw, mirror=mirror)
    except Exception:
        data = np.frombuffer(raw, np.uint8)
        img  = cv2.imdecode(data, cv2.IMREAD_COLOR)
    if img is None:
        return jsonify({"error": "decode_failed"}), 400

    target = (request.form.get("target") or "").strip()
    target_norm = _norm_key(target) if target else ""

    # YOLO 偵測 + ROI
    r = yolo_model(img, verbose=False)
    roi_rect = pick_roi_from_results(r)
    roi_state = "ok"
    if roi_rect is None:
        H, W = img.shape[:2]
        roi_rect = (0, 0, W-1, H-1)
        roi_state = "fallback_full"

    x1,y1,x2,y2 = roi_rect
    crop = img[y1:y2, x1:x2]
    if min(crop.shape[:2]) < MIN_SIDE:
        ms = int((time.time() - t0) * 1000)
        return jsonify({
            "error": "roi_too_small",
            "roi": {"x": int(x1), "y": int(y1), "w": int(x2-x1), "h": int(y2-y1)},
            "roi_state": "too_small",
            "inference_ms": ms
        }), 200

    # 分類（與 demo 同步的前處理）
    x = preprocess_for_cls_bgr(crop).to(DEVICE)
    with torch.no_grad():
        logits = resnet_model(x)
        prob = F.softmax(logits, dim=1)[0].detach().cpu().numpy()
    idx = int(prob.argmax())
    conf = float(prob[idx])

    # 單幀結果 → 正名
    raw_label   = LABELS[idx]
    canon_label = CANON_BY_NORM.get(_norm_key(raw_label), raw_label)

    # 視覺多數決
    maj_idx, maj_conf = _vision_vote_update(idx, conf)
    maj_label = (CANON_BY_NORM.get(_norm_key(LABELS[maj_idx]), LABELS[maj_idx])
                 if maj_idx is not None else None)

    # top-k 也用正名
    k = min(5, len(prob))
    topk_idx = np.argsort(prob)[::-1][:k]
    topk = [{"label": CANON_BY_NORM.get(_norm_key(LABELS[i]), LABELS[i]),
             "prob": float(prob[i])} for i in topk_idx]

    # 正確旗標
    is_correct = (_norm_key(canon_label) == target_norm) if target else None
    is_correct_maj = (_norm_key(maj_label) == target_norm) if (target and maj_label) else None

    # (可選) 連續幀冷卻判分
    score_event = False
    if target:
        score_event = _maybe_score_event(target_norm, maj_idx, maj_conf)

    ms = int((time.time() - t0) * 1000)
    return jsonify({
        # 舊鍵（相容）
        "chord": canon_label,
        "score": conf,

        # 新鍵（清楚）
        "label": canon_label,
        "confidence": conf,

        # 多數決
        "maj_label": maj_label,
        "maj_confidence": maj_conf,

        # 正確旗標
        "is_correct": is_correct,
        "is_correct_maj": is_correct_maj,
        "score_event": score_event,

        "topk": topk,
        "roi": {"x": int(x1), "y": int(y1), "w": int(x2-x1), "h": int(y2-y1)},
        "roi_state": roi_state,  # ok / fallback_full / too_small
        "inference_ms": ms
    })

# ---------- 音訊挑戰 API ----------
AUDIO_SR_DEFAULT = 44100
AUDIO_HOP        = 1024
AUDIO_CONF_TH    = 0.30
ENERGY_THRESH    = 0.02
VOTE_WINDOW      = 5

_last_votes = deque(maxlen=VOTE_WINDOW)

@app.post("/audio_chunk")
def audio_chunk():
    pcm = request.get_data(cache=False, as_text=False)
    if not pcm or len(pcm) < 1000:
        return jsonify({"error": "empty_or_too_short"}), 400
    try:
        sr = int(request.args.get("sr", AUDIO_SR_DEFAULT))
    except Exception:
        sr = AUDIO_SR_DEFAULT

    chord, conf, energy = classify_pcm16le(pcm, sr=sr, hop=AUDIO_HOP)
    vote_item = chord if (conf >= AUDIO_CONF_TH and energy >= ENERGY_THRESH) else "NC"
    _last_votes.append(vote_item)
    vote = max(set(_last_votes), key=list(_last_votes).count) if _last_votes else vote_item

    return jsonify({
        "chord": chord,
        "conf":  float(conf),
        "energy": float(energy),
        "vote": vote
    })

# ---------- 健康檢查 ----------
@app.get("/health")
def health():
    return jsonify({
        "status": "ok",
        "device": DEVICE,
        "classes": NUM_CLASSES,
        "canon_labels": CANON_LABELS
    })

@app.get("/ping")
def ping():
    return "pong"

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)
