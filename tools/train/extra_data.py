"""Дополнительные полевые наборы данных: хлопок и пшеница (оба CC BY 4.0).

* Хлопок — SAR-CLD-2024 (Bishshash et al., Data in Brief 2024, doi:10.17632/b3jy2p6k8w.2),
  зеркало на Hugging Face: Project-AgML/cotton_leaf_disease_classification_bangladesh_2 (raw).
* Пшеница — Wheat Leaf Dataset (Getachew Hayit, Mendeley Data, doi:10.17632/wgd66f8n6h.1).

load_extra(img) -> (images: np.ndarray[object] of JPEG bytes, labels: list[str])
Фото хранятся сжатыми (JPEG): у облачной машины всего 8 ГБ памяти.
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


def _jpeg(a):
    buf = io.BytesIO()
    Image.fromarray(a).save(buf, format="JPEG", quality=92)
    return buf.getvalue()


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
            xs.append(_jpeg(_prep(row["image"]["bytes"], img)))
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
                xs.append(_jpeg(_prep(p, img)))
                ys.append(label)
            except Exception as e:  # noqa: BLE001
                print("skip wheat image:", e)
    print("wheat folders:", dirs)
    return xs, ys


# Растительные категории Caltech-101 не берём в класс «не лист».
PLANT_LIKE = ("bonsai", "lotus", "sunflower", "water_lil", "strawberry", "joshua",
              "flower", "leaf", "tree")
OTHER_LABEL = "Other___not_leaf"
OTHER_MAX = int(os.environ.get("OTHER_MAX", "3500"))


CALTECH_URL = ("https://huggingface.co/datasets/HuggingFaceM4/Caltech-101/resolve/main/"
               "caltech-101.zip")


def _extract_all(path, out):
    """Распаковывает zip/tar(.gz) рекурсивно (архив внутри архива)."""
    import tarfile
    import zipfile
    os.makedirs(out, exist_ok=True)
    if zipfile.is_zipfile(path):
        with zipfile.ZipFile(path) as z:
            z.extractall(out)
    elif tarfile.is_tarfile(path):
        with tarfile.open(path) as t:
            t.extractall(out)
    for root, _, files in os.walk(out):
        for fn in files:
            if fn.endswith((".tar.gz", ".tgz", ".tar", ".zip")):
                inner = os.path.join(root, fn)
                dest = inner + "_x"
                if not os.path.isdir(dest):
                    _extract_all(inner, dest)


def load_other(img):
    """Класс «это не лист»: обычные фото предметов, людей, фона (Caltech-101, CC BY 4.0)."""
    arc = _download(CALTECH_URL, os.path.join(CACHE, "caltech-101.zip"))
    out = os.path.join(CACHE, "caltech")
    if not os.path.isdir(out):
        _extract_all(arc, out)
    paths, excluded = [], set()
    for root, _, files in os.walk(out):
        cat = os.path.basename(root).lower()
        if "annotation" in root.lower():
            continue
        if any(k in cat for k in PLANT_LIKE):
            excluded.add(cat)
            continue
        paths += [os.path.join(root, f) for f in files if f.lower().endswith(IMG_EXT)]
    print("caltech images:", len(paths), "excluded:", sorted(excluded))
    rng = np.random.default_rng(7)
    rng.shuffle(paths)
    xs = []
    for pth in paths:
        try:
            a = _prep(pth, img)
        except Exception as e:  # noqa: BLE001
            print("skip caltech image:", e)
            continue
        if rng.random() < 0.3:  # часть — серые/выцветшие, как фото в плохом свете
            g = a.mean(axis=2, keepdims=True).astype(np.uint8)
            a = np.repeat(g, 3, axis=2)
        xs.append(_jpeg(a))
        if len(xs) >= OTHER_MAX:
            break
    return xs, [OTHER_LABEL] * len(xs)


PLANTDOC_URL = "https://codeload.github.com/pratikkayal/PlantDoc-Dataset/zip/refs/heads/master"
# Папка PlantDoc → класс модели (имена PlantVillage как в TFDS). Нет в списке — пропускаем.
PLANTDOC_MAP = {
    "apple scab leaf": "Apple___Apple_scab",
    "apple leaf": "Apple___healthy",
    "apple rust leaf": "Apple___Cedar_apple_rust",
    "bell_pepper leaf spot": "Pepper,_bell___Bacterial_spot",
    "bell_pepper leaf": "Pepper,_bell___healthy",
    "cherry leaf": "Cherry___healthy",
    "corn gray leaf spot": "Corn___Cercospora_leaf_spot Gray_leaf_spot",
    "corn leaf blight": "Corn___Northern_Leaf_Blight",
    "corn rust leaf": "Corn___Common_rust",
    "peach leaf": "Peach___healthy",
    "potato leaf early blight": "Potato___Early_blight",
    "potato leaf late blight": "Potato___Late_blight",
    "strawberry leaf": "Strawberry___healthy",
    "tomato early blight leaf": "Tomato___Early_blight",
    "tomato septoria leaf spot": "Tomato___Septoria_leaf_spot",
    "tomato leaf bacterial spot": "Tomato___Bacterial_spot",
    "tomato leaf late blight": "Tomato___Late_blight",
    "tomato leaf mosaic virus": "Tomato___Tomato_mosaic_virus",
    "tomato leaf yellow virus": "Tomato___Tomato_Yellow_Leaf_Curl_Virus",
    "tomato leaf": "Tomato___healthy",
    "tomato mold leaf": "Tomato___Leaf_Mold",
    "tomato two spotted spider mites leaf": "Tomato___Spider_mites Two-spotted_spider_mite",
    "grape leaf black rot": "Grape___Black_rot",
    "grape leaf": "Grape___healthy",
}


def load_plantdoc(img):
    """Полевые фото PlantDoc (CC BY 4.0, Singh et al. 2020).

    Возвращает (train_x, train_names, test_x, test_names); test — отдельная
    «полевая» проверка, в обучение не попадает.
    """
    import zipfile
    arc = _download(PLANTDOC_URL, os.path.join(CACHE, "plantdoc.zip"))
    out = os.path.join(CACHE, "plantdoc")
    if not os.path.isdir(out):
        with zipfile.ZipFile(arc) as z:
            z.extractall(out)
    res = {"train": ([], []), "test": ([], [])}
    skipped = set()
    for root, _, files in os.walk(out):
        parts = os.path.normpath(root).split(os.sep)
        split = next((s for s in ("train", "test") if s in parts), None)
        if split is None:
            continue
        cls = os.path.basename(root).strip().lower()
        label = PLANTDOC_MAP.get(cls)
        if label is None:
            if files:
                skipped.add(cls)
            continue
        for fn in files:
            if not fn.lower().endswith(IMG_EXT):
                continue
            try:
                res[split][0].append(_jpeg(_prep(os.path.join(root, fn), img)))
                res[split][1].append(label)
            except Exception as e:  # noqa: BLE001
                print("skip plantdoc image:", e)
    print("plantdoc skipped classes:", sorted(skipped))
    for s in ("train", "test"):
        names = res[s][1]
        print(f"plantdoc {s}: {len(names)}", {k: names.count(k) for k in sorted(set(names))})
    return res["train"][0], res["train"][1], res["test"][0], res["test"][1]


# ---------------------------------------------------------------------------
# Урожай (клубни, плоды, овощи): модель называет, ЧТО на фото — «это картофель».
# * Fruit and Vegetable Image Recognition (реальные фото, 36 видов),
#   зеркало HF: Nattakarn/fruit-and-vegetable-image-recognition
# * Fruits-360 (Mureșan & Oltean, 2018), зеркало HF: PedroSampaio/fruits-360 (MIT)
PRODUCE_SOURCES = [
    ("Nattakarn/fruit-and-vegetable-image-recognition", "real"),
    ("PedroSampaio/fruits-360", "f360"),
]
# Класс модели → названия в наборах (без регистра; для Fruits-360 — по началу имени).
PRODUCE_MAP = {
    "potato": {"real": ["potato"], "f360": ["potato red", "potato white"]},
    "tomato": {"real": ["tomato"], "f360": ["tomato"]},
    "cucumber": {"real": ["cucumber"], "f360": ["cucumber"]},
    "onion": {"real": ["onion"], "f360": ["onion"]},
    "carrot": {"real": ["carrot"], "f360": []},
    "cabbage": {"real": ["cabbage"], "f360": []},
    "eggplant": {"real": ["eggplant"], "f360": ["eggplant"]},
    "pepper": {"real": ["bell pepper", "capsicum", "paprika"], "f360": ["pepper"]},
    "watermelon": {"real": ["watermelon"], "f360": ["watermelon"]},
    "melon": {"real": [], "f360": ["melon", "cantaloupe"]},
    "apple": {"real": ["apple"], "f360": ["apple"]},
    "grape": {"real": ["grapes"], "f360": ["grape "]},
    "pomegranate": {"real": ["pomegranate"], "f360": ["pomegranate"]},
    "apricot": {"real": [], "f360": ["apricot"]},
    "peach": {"real": [], "f360": ["peach", "nectarine"]},
    "pear": {"real": ["pear"], "f360": ["pear"]},
    "corn": {"real": ["corn", "sweetcorn"], "f360": ["corn"]},
    "garlic": {"real": ["garlic"], "f360": []},
    "beetroot": {"real": ["beetroot"], "f360": ["beetroot"]},
    "lemon": {"real": ["lemon"], "f360": ["lemon"]},
    "banana": {"real": ["banana"], "f360": ["banana"]},
    "cherry": {"real": [], "f360": ["cherry"]},
    "strawberry": {"real": [], "f360": ["strawberry"]},
    "walnut": {"real": [], "f360": ["walnut"]},
    "radish": {"real": ["raddish"], "f360": []},
    "turnip": {"real": ["turnip"], "f360": []},
}
PRODUCE_PREFIX = "Produce___"
F360_MAX = int(os.environ.get("F360_MAX", "300"))  # студийные кадры похожи — берём часть
REAL_MAX = int(os.environ.get("REAL_MAX", "400"))


def _hf_info(repo):
    import json
    req = urllib.request.Request(f"https://huggingface.co/api/datasets/{repo}",
                                 headers={"User-Agent": "agro-ai-trainer"})
    with urllib.request.urlopen(req, timeout=120) as r:
        j = json.load(r)
    info = j["cardData"]["dataset_info"]
    info = info[0] if isinstance(info, list) else info
    names = None
    for f in info["features"]:
        if f.get("name") == "label":
            names = f["dtype"]["class_label"]["names"]
            if isinstance(names, dict):
                names = [names[k] for k in sorted(names, key=lambda x: int(x))]
    files = [s["rfilename"] for s in j["siblings"] if s["rfilename"].endswith(".parquet")]
    return names, files


def _produce_class(name, kind):
    n = name.lower().strip()
    for cls, m in PRODUCE_MAP.items():
        for key in m[kind]:
            if (n == key) if kind == "real" else (n + " ").startswith(key if key.endswith(" ") else key):
                return PRODUCE_PREFIX + cls
    return None


def load_produce(img):
    import pyarrow.parquet as pq
    rng = np.random.default_rng(11)
    xs, ys = [], []
    for repo, kind in PRODUCE_SOURCES:
        names, files = _hf_info(repo)
        per = {}
        for fn in files:
            local = os.path.join(CACHE, repo.replace("/", "_"), os.path.basename(fn))
            _download(f"https://huggingface.co/datasets/{repo}/resolve/main/{fn}", local)
            pf = pq.ParquetFile(local)
            for batch in pf.iter_batches(batch_size=256, columns=["image", "label"]):
                for row in batch.to_pylist():
                    cls = _produce_class(names[int(row["label"])], kind)
                    if cls is None:
                        continue
                    per.setdefault(cls, []).append(row["image"]["bytes"])
        cap = REAL_MAX if kind == "real" else F360_MAX
        for cls, items in sorted(per.items()):
            idx = rng.permutation(len(items))[:cap]
            for i in idx:
                try:
                    xs.append(_jpeg(_prep(items[i], img)))
                    ys.append(cls)
                except Exception as e:  # noqa: BLE001
                    print("skip produce image:", e)
        per.clear()
        print(f"produce {kind}:", {k: ys.count(k) for k in sorted(set(ys))})
    return xs, ys


def load_extra(img):
    xs, ys = [], []
    for fn in (load_cotton, load_wheat, load_other, load_produce):
        a, b = fn(img)
        print(fn.__name__, len(a), {k: b.count(k) for k in sorted(set(b))})
        xs += a
        ys += b
    arr = np.empty(len(xs), dtype=object)
    arr[:] = xs
    return arr, ys
