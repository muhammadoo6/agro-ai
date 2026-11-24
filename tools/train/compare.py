"""Сравнение двух моделей на реальных фото овощей, которых не было в обучении.

Берём папку test из Vegetable Image Dataset (в обучении использовался только train).
Запуск: python compare.py old.tflite old_labels.json new.tflite new_labels.json
"""
import json
import os
import sys
import urllib.request

import numpy as np
import tensorflow as tf

from extra_data import VEG_REPO, _download, _prep, _produce_class

PER_CLASS = int(os.environ.get("PER_CLASS", "200"))


def files():
    req = urllib.request.Request(f"https://huggingface.co/api/datasets/{VEG_REPO}",
                                 headers={"User-Agent": "agro-ai-trainer"})
    with urllib.request.urlopen(req, timeout=120) as r:
        names = [x["rfilename"] for x in json.load(r)["siblings"] if x["rfilename"].endswith(".jpg")]
    out = {}
    for fn in names:
        parts = fn.split("/")
        if len(parts) >= 4 and parts[1] == "test":
            cls = _produce_class(parts[2].replace("_", " "), "veg")
            if cls:
                out.setdefault(cls, []).append(fn)
    return {k: v[:PER_CLASS] for k, v in out.items()}


def load(path_model, path_labels):
    it = tf.lite.Interpreter(model_path=path_model)
    it.allocate_tensors()
    labels = json.load(open(path_labels))["labels"]
    return it, labels


def predict(it, x):
    i, o = it.get_input_details()[0], it.get_output_details()[0]
    it.set_tensor(i["index"], x[None].astype(np.float32))
    it.invoke()
    return it.get_tensor(o["index"])[0]


def main():
    old, new = load(sys.argv[1], sys.argv[2]), load(sys.argv[3], sys.argv[4])
    data = files()
    res = {"old": {}, "new": {}}
    for cls, fns in sorted(data.items()):
        for fn in fns:
            local = os.path.join("cmp_cache", fn.replace("/", "_"))
            _download(f"https://huggingface.co/datasets/{VEG_REPO}/resolve/main/{urllib.request.quote(fn)}", local)
            x = _prep(open(local, "rb").read(), 224)
            for name, (it, labels) in (("old", old), ("new", new)):
                p = predict(it, x)
                ok = labels[int(np.argmax(p))] == cls if cls in labels else False
                r = res[name].setdefault(cls, [0, 0])
                r[0] += int(ok)
                r[1] += 1
    report = {}
    for name in ("old", "new"):
        tot = sum(v[0] for v in res[name].values()), sum(v[1] for v in res[name].values())
        report[name] = {"top1": tot[0] / max(tot[1], 1), "n": tot[1],
                        "per_class": {k: round(v[0] / v[1], 3) for k, v in res[name].items()}}
    print(json.dumps(report, indent=1, ensure_ascii=False))
    json.dump(report, open("compare.json", "w"), indent=1)


if __name__ == "__main__":
    main()
