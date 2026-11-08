"""Проверка готовой модели TFLite на полевых фото PlantDoc (test).

python tools/train/eval_field.py [path/to/plant_disease.tflite] [path/to/labels.json]
Метрики: top-1, top-3, точность при указанной культуре; с TTA (фото + зеркало).
"""
import io
import json
import os
import sys

import numpy as np
import tensorflow as tf
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from extra_data import load_plantdoc  # noqa: E402

model_path = sys.argv[1] if len(sys.argv) > 1 else "assets/models/plant_disease.tflite"
labels_path = sys.argv[2] if len(sys.argv) > 2 else "assets/models/labels.json"
meta = json.load(open(labels_path, encoding="utf-8"))
labels = meta["labels"]
size = meta.get("input_size", 224)
idx = {n: i for i, n in enumerate(labels)}

_, _, te_x, te_n = load_plantdoc(size)
pairs = [(x, idx[n]) for x, n in zip(te_x, te_n) if n in idx]
print(f"field test images usable by this model: {len(pairs)} / {len(te_n)}")

interp = tf.lite.Interpreter(model_path=model_path)
interp.allocate_tensors()
inp = interp.get_input_details()[0]
out = interp.get_output_details()[0]


def run(a):
    interp.set_tensor(inp["index"], a[None].astype(np.float32))
    interp.invoke()
    return interp.get_tensor(out["index"])[0]


crop_of = [n.split("___")[0].lower() for n in labels]
top1 = top3 = crop = 0
for jpg, y in pairs:
    a = np.asarray(Image.open(io.BytesIO(jpg)).convert("RGB"), dtype=np.float32)
    p = (run(a) + run(a[:, ::-1, :])) / 2
    top1 += int(np.argmax(p) == y)
    top3 += int(y in np.argsort(-p)[:3])
    mask = np.array([c == crop_of[y] for c in crop_of])
    crop += int(np.argmax(np.where(mask, p, -1)) == y)
n = max(len(pairs), 1)
res = {"n": len(pairs), "top1": top1 / n, "top3": top3 / n, "with_crop_hint": crop / n}
print("FIELD EVAL:", json.dumps(res))
