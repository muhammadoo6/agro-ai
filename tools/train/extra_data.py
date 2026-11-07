"""Дополнительные полевые наборы данных: хлопок и пшеница (оба CC BY 4.0).

* Хлопок — SAR-CLD-2024 (Bishshash et al., Data in Brief 2024, doi:10.17632/b3jy2p6k8w.2),
  зеркало на Hugging Face: Project-AgML/cotton_leaf_disease_classification_bangladesh_2 (raw).
* Пшеница — Wheat Leaf Dataset (Getachew Hayit, Mendeley Data, doi:10.17632/wgd66f8n6h.1).

load_extra(img) -> (images uint8 [N, img, img, 3], labels: list[str])
"""
import io
import os
import subprocess
import urllib.request

import numpy as np
from PIL import Image, ImageOps

CACHE = os.environ.get("EXTRA_CACHE", "extra_cache")

COTTON_URL = ("https://huggingface.co/datasets/Project-AgML/"
              "cotton_leaf_disease_classification_bangladesh_2/resolve/main/raw/"
              "train-00000-of-00001.parquet")
COTTON_LABELS = {
    "Bacterial Blight": "Cotton___Bacterial_blight",
    "Curl Virus": "Cotton___Leaf_curl_virus",
    "Healthy Leaf": "Cotton___healthy",
    "Herbicide Growth Damage": "Cotton___Herbicide_damage",
    "Leaf Hopper Jassids": "Cotton___Jassids",
    "Leaf Redding": "Cotton___Leaf_reddening",
    "Leaf Variegation": "Cotton___Leaf_variegation",
}

WHEAT_URL = ("https://data.mendeley.com/public-files/datasets/wgd66f8n6h/files/"
             "4ec9266d-d7c1-4fd5-85c9-e5624c09a847/file_downloaded")
# Ключевые слова в путях архива → класс.
WHEAT_KEYS = [
    ("septoria", "Wheat___Septoria"),
    ("stripe", "Wheat___Stripe_rust"),
    ("yellow", "Wheat___Stripe_rust"),
    ("rust", "Wheat___Stripe_rust"),
    ("healthy", "Wheat___healthy"),
    ("health", "Wheat___healthy"),
]
IMG_EXT = (".jpg", ".jpeg", ".png", ".bmp", ".webp")


def _download(url, path):
    if os.path.exists(path) and os.path.getsize(path) > 0:
        return path
    os.makedirs(os.path.dirname(path), exist_ok=True)
    print("download", url)
    req = urllib.request.Request(url, headers={"User-Agent": "agro-ai-trainer"})
    with urllib.request.urlopen(req, timeout=600) as r, open(path + ".part", "wb") as f:
        while True:
            chunk = r.read(1 << 20)
            if not chunk:
                break
            f.write(chunk)
    os.replace(path + ".part", path)
    print("saved", path, os.path.getsize(path))
    return path


def _prep(data, img):
    im = Image.open(io.BytesIO(data) if isinstance(data, (bytes, bytearray)) else data)
    im = ImageOps.exif_transpose(im).convert("RGB")
    im = ImageOps.fit(im, (img, img), Image.BILINEAR)  # квадрат по центру
    return np.asarray(im, dtype=np.uint8)


def load_cotton(img):
    import pyarrow.parquet as pq
    path = _download(COTTON_URL, os.path.join(CACHE, "cotton_raw.parquet"))
    table = pq.read_table(path)
    # Порядок классов — как в карточке набора (class_label 0..6).
    order = ["Bacterial Blight", "Curl Virus", "Healthy Leaf", "Herbicide Growth Damage",
             "Leaf Hopper Jassids", "Leaf Redding", "Leaf Variegation"]
    xs, ys = [], []
    for row in table.to_pylist():
        try:
            xs.append(_prep(row["image"]["bytes"], img))
            ys.append(COTTON_LABELS[order[int(row["label"])]])
        except Exception as e:  # noqa: BLE001
            print("skip cotton image:", e)
    return xs, ys


def load_wheat(img):
    arc = _download(WHEAT_URL, os.path.join(CACHE, "wheat_leaf.rar"))
    out = os.path.join(CACHE, "wheat")
    if not os.path.isdir(out):
        subprocess.run(["7z", "x", "-y", f"-o{out}", arc], check=True,
                       stdout=subprocess.DEVNULL)
    xs, ys, dirs = [], [], {}
    for root, _, files in os.walk(out):
        for fn in files:
            if not fn.lower().endswith(IMG_EXT):
                continue
            p = os.path.join(root, fn)
            rel = os.path.relpath(p, out).lower()
            label = next((lab for k, lab in WHEAT_KEYS if k in rel), None)
            dirs.setdefault(os.path.dirname(os.path.relpath(p, out)), label)
            if label is None:
                continue
            try:
                xs.append(_prep(p, img))
                ys.append(label)
            except Exception as e:  # noqa: BLE001
                print("skip wheat image:", e)
    print("wheat folders:", dirs)
    return xs, ys


def load_extra(img):
    xs, ys = [], []
    for fn in (load_cotton, load_wheat):
        a, b = fn(img)
        print(fn.__name__, len(a), {k: b.count(k) for k in sorted(set(b))})
        xs += a
        ys += b
    return np.stack(xs), ys
