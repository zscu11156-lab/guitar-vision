from flask import Flask, request, jsonify
import torch
import cv2
import numpy as np
from ultralytics import YOLO

app = Flask(__name__)

# === 模型初始化 (只載一次) ===
yolo_model = YOLO("best.pt")   # YOLO 偵測手 & 琴頸
resnet_model = torch.load("cls_best.pt", map_location="cpu")
resnet_model.eval()

@app.route("/predict", methods=["POST"])
def predict():
    # 1. 讀取圖片
    file = request.files['image']
    img = cv2.imdecode(np.frombuffer(file.read(), np.uint8), cv2.IMREAD_COLOR)

    # 2. YOLO 偵測手 + 琴頸 (取得 ROI)
    results = yolo_model(img)
    # TODO: 根據 YOLO bbox 擷取 ROI 區域
    roi = img  # 假設這裡先用整張圖

    # 3. ResNet 做和弦分類
    roi_tensor = torch.tensor(roi).permute(2,0,1).unsqueeze(0).float() / 255.0
    with torch.no_grad():
        pred = resnet_model(roi_tensor)
    chord_id = pred.argmax(dim=1).item()

    # 4. 回傳 JSON
    return jsonify({"chord": f"Chord_{chord_id}"})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)