"""Обучение модели распознавания болезней растений для Agro AI (офлайн-версия).

Данные: PlantVillage (tensorflow_datasets `plant_village`, ~54k фото, 38 классов),
плюс полевые фото хлопка (SAR-CLD-2024) и пшеницы (Wheat Leaf Dataset) — см. extra_data.py.
Берём культуры, которые выращивают в Таджикистане. Модель: MobileNetV3-Large
(предобучена на ImageNet) + дообучение. Экспорт: TFLite (квантизация весов).

Выход (в OUT_DIR):
  plant_disease.tflite  — модель (вход: 1x224x224x3 float32 RGB 0..255, выход: вероятности)
  labels.json           — список классов в порядке выходов модели
  report.json           — точность по классам на валидации
"""
import json
import os
import time

import numpy as np
import tensorflow as tf
import tensorflow_datasets as tfds

OUT_DIR = os.environ.get("OUT_DIR", "out")
IMG = int(os.environ.get("IMG", "224"))
BATCH = 64
EPOCHS_HEAD = int(os.environ.get("EPOCHS_HEAD", "4"))
EPOCHS_FINE = int(os.environ.get("EPOCHS_FINE", "3"))
SEED = 42
LIMIT = int(os.environ.get("LIMIT", "0"))  # >0 — быстрый пробный прогон
EXTRA = os.environ.get("EXTRA", "1") == "1"  # хлопок и пшеница
# Маленькие полевые классы повторяем до этого числа примеров (аугментации разные).
MIN_PER_CLASS = int(os.environ.get("MIN_PER_CLASS", "600"))
PLANTDOC = os.environ.get("PLANTDOC", "1") == "1"  # полевые фото PlantDoc
PD_REPEAT = int(os.environ.get("PD_REPEAT", "6"))  # во сколько раз повторить полевые фото
FINE_LAYERS = int(os.environ.get("FINE_LAYERS", "100"))  # сколько верхних слоёв дообучать

# Культуры, полезные для Таджикистана.
# Сравниваем по началу названия (в TFDS: "Cherry___...", "Corn___..." и т.п.).
KEEP_CROPS = ("apple", "cherry", "corn", "grape", "peach", "pepper", "potato",
              "strawberry", "tomato")

tfds.disable_progress_bar()  # иначе лог GitHub переполняется
os.makedirs(OUT_DIR, exist_ok=True)
tf.keras.utils.set_random_seed(SEED)
t0 = time.time()

(train_raw, val_raw), info = tfds.load(
    "plant_village",
    split=["train[:85%]", "train[85%:]"],
    as_supervised=True,
    with_info=True,
    shuffle_files=True,
)
all_names = info.features["label"].names
print("all classes:", all_names)
keep = [i for i, n in enumerate(all_names) if n.lower().startswith(KEEP_CROPS)]
labels = [all_names[i] for i in keep]
print(f"classes kept: {len(labels)} / {len(all_names)}")

extra_x = extra_y = None
if EXTRA:
    import sys
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from extra_data import load_extra
    extra_x, extra_names = load_extra(IMG)
    extra_labels = sorted(set(extra_names))
    labels = labels + extra_labels
    idx = {n: i for i, n in enumerate(labels)}
    extra_y = np.array([idx[n] for n in extra_names], dtype=np.int64)
    print(f"extra classes: {extra_labels}; images: {len(extra_y)}")

# Полевые фото: обучающая часть — в обучение, тестовая — отдельная «полевая» проверка.
pd_tr = pd_te = None
if PLANTDOC:
    import sys
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from extra_data import load_plantdoc
    ptx, ptn, pex, pen = load_plantdoc(IMG)
    lidx = {n: i for i, n in enumerate(labels)}

    def _keep(xs, ns):
        pairs = [(x, lidx[n]) for x, n in zip(xs, ns) if n in lidx]
        missing = sorted({n for n in ns if n not in lidx})
        if missing:
            print("plantdoc labels not in model:", missing)
        return [p[0] for p in pairs], np.array([p[1] for p in pairs], dtype=np.int64)

    pd_tr = _keep(ptx, ptn)
    pd_te = _keep(pex, pen)
    print(f"plantdoc used: train {len(pd_tr[1])}, field-test {len(pd_te[1])}")

remap = np.full(len(all_names), -1, dtype=np.int64)
for new, old in enumerate(keep):
    remap[old] = new
remap_t = tf.constant(remap)


def select(ds):
    ds = ds.map(lambda x, y: (x, tf.gather(remap_t, y)), num_parallel_calls=tf.data.AUTOTUNE)
    ds = ds.filter(lambda x, y: y >= 0)
    # Уменьшаем один раз и кешируем в памяти (uint8).
    ds = ds.map(lambda x, y: (tf.image.resize(x, (IMG, IMG), antialias=True), y),
                num_parallel_calls=tf.data.AUTOTUNE)
    ds = ds.map(lambda x, y: (tf.cast(tf.clip_by_value(x, 0, 255), tf.uint8), y))
    # Сжимаем в JPEG: в памяти ~15 КБ на фото вместо 150 КБ (у машины 8 ГБ RAM).
    ds = ds.map(lambda x, y: (tf.io.encode_jpeg(x, quality=92), y),
                num_parallel_calls=tf.data.AUTOTUNE)
    return ds  # кэшируем один раз — после объединения с полевыми данными


if LIMIT:
    train_raw = train_raw.take(LIMIT)
    val_raw = val_raw.take(LIMIT // 4)
train_c = select(train_raw)
val_c = select(val_raw)

if extra_x is not None:
    # Стратифицированное разбиение 85/15 и дополнение маленьких классов повторами.
    rng = np.random.default_rng(SEED)
    tr_idx, va_idx = [], []
    for c in np.unique(extra_y):
        ids = rng.permutation(np.where(extra_y == c)[0])
        if LIMIT:
            ids = ids[:40]
        n_val = max(1, int(round(len(ids) * 0.15)))
        va_idx += ids[:n_val].tolist()
        tr = ids[n_val:]
        if len(tr) < MIN_PER_CLASS and not LIMIT:
            tr = np.concatenate([tr, rng.choice(tr, MIN_PER_CLASS - len(tr), replace=True)])
        tr_idx += tr.tolist()
    tr_idx = rng.permutation(tr_idx)
    ex_tr = tf.data.Dataset.from_tensor_slices(
        (tf.constant(list(extra_x[tr_idx]), dtype=tf.string), extra_y[tr_idx]))
    ex_va = tf.data.Dataset.from_tensor_slices(
        (tf.constant(list(extra_x[va_idx]), dtype=tf.string), extra_y[va_idx]))
    train_c = train_c.concatenate(ex_tr)
    val_c = val_c.concatenate(ex_va)
    del extra_x

if pd_tr is not None and len(pd_tr[1]):
    reps = 1 if LIMIT else PD_REPEAT
    xs = pd_tr[0] * reps
    ys = np.tile(pd_tr[1], reps)
    train_c = train_c.concatenate(
        tf.data.Dataset.from_tensor_slices((tf.constant(xs, dtype=tf.string), ys)))

train_c = train_c.cache()
val_c = val_c.cache()

n_classes = len(labels)
counts = np.zeros(n_classes, dtype=np.int64)
for _, y in train_c.batch(1024):
    counts += np.bincount(y.numpy(), minlength=n_classes)
print("train counts:", dict(zip(labels, counts.tolist())))
print(f"cached in {time.time() - t0:.0f}s")

# Веса классов против дисбаланса.
class_weight = {i: min(5.0, float(counts.sum() / (n_classes * max(c, 1))))
                for i, c in enumerate(counts)}

# Аугментации — чтобы модель меньше зависела от ровного фона лаборатории.
augment = tf.keras.Sequential([
    tf.keras.layers.RandomFlip("horizontal_and_vertical"),
    tf.keras.layers.RandomRotation(0.15),
    tf.keras.layers.RandomZoom((-0.25, 0.1)),
    tf.keras.layers.RandomTranslation(0.1, 0.1),
    tf.keras.layers.RandomBrightness(0.25, value_range=(0, 255)),
    tf.keras.layers.RandomContrast(0.3),
], name="augment")


def to_float(x, y):
    return tf.cast(x, tf.float32), y


def decode(x, y):
    img = tf.io.decode_jpeg(x, channels=3)
    return tf.ensure_shape(img, (IMG, IMG, 3)), y


train_ds = (train_c.shuffle(20000, seed=SEED)
            .map(decode, num_parallel_calls=tf.data.AUTOTUNE)
            .batch(BATCH)
            .map(to_float, num_parallel_calls=tf.data.AUTOTUNE)
            .map(lambda x, y: (augment(x, training=True), y), num_parallel_calls=tf.data.AUTOTUNE)
            .prefetch(tf.data.AUTOTUNE))
val_ds = (val_c.map(decode, num_parallel_calls=tf.data.AUTOTUNE)
          .batch(BATCH).map(to_float).prefetch(tf.data.AUTOTUNE))

base = tf.keras.applications.MobileNetV3Large(
    input_shape=(IMG, IMG, 3), include_top=False, weights="imagenet",
    pooling="avg", include_preprocessing=True,  # вход: RGB 0..255
)
base.trainable = False
inputs = tf.keras.Input((IMG, IMG, 3), name="image")
x = base(inputs, training=False)
x = tf.keras.layers.Dropout(0.3)(x)
outputs = tf.keras.layers.Dense(n_classes, activation="softmax", name="probs")(x)
model = tf.keras.Model(inputs, outputs)

model.compile(optimizer=tf.keras.optimizers.Adam(1e-3),
              loss="sparse_categorical_crossentropy", metrics=["accuracy"])
model.fit(train_ds, validation_data=val_ds, epochs=EPOCHS_HEAD, class_weight=class_weight, verbose=2)
print(f"head done in {time.time() - t0:.0f}s")

# Дообучение верхних слоёв.
base.trainable = True
for layer in base.layers[:-FINE_LAYERS]:
    layer.trainable = False
for layer in base.layers:
    if isinstance(layer, tf.keras.layers.BatchNormalization):
        layer.trainable = False
model.compile(optimizer=tf.keras.optimizers.Adam(1e-5),
              loss="sparse_categorical_crossentropy", metrics=["accuracy"])
TIME_BUDGET = int(os.environ.get("TIME_BUDGET", "19200"))  # GitHub обрывает задачу через 6 ч


class StopBeforeTimeout(tf.keras.callbacks.Callback):
    """Не начинать эпоху, если она не успеет закончиться — модель сохранится вовремя."""

    def on_epoch_begin(self, epoch, logs=None):
        self.t = time.time()

    def on_epoch_end(self, epoch, logs=None):
        took = time.time() - self.t
        if time.time() - t0 + took > TIME_BUDGET:
            print(f"time budget: stop after fine epoch {epoch + 1}")
            self.model.stop_training = True


model.fit(train_ds, validation_data=val_ds, epochs=EPOCHS_FINE, class_weight=class_weight,
          verbose=2, callbacks=[StopBeforeTimeout()])
print(f"fine-tune done in {time.time() - t0:.0f}s")

# Оценка по классам.
y_true, y_pred = [], []
for xb, yb in val_ds:
    p = model.predict_on_batch(xb)
    y_true.extend(yb.numpy().tolist())
    y_pred.extend(np.argmax(p, axis=1).tolist())
y_true, y_pred = np.array(y_true), np.array(y_pred)
acc = float((y_true == y_pred).mean())
per_class = {}
for i, n in enumerate(labels):
    m = y_true == i
    per_class[n] = {"n": int(m.sum()), "acc": float((y_pred[m] == i).mean()) if m.any() else None}
print(f"VAL ACCURACY: {acc:.4f}")

# «Полевая» проверка на PlantDoc test: фото с реальных полей, модель их не видела.
field = None
if pd_te is not None and len(pd_te[1]):
    fx = tf.data.Dataset.from_tensor_slices(
        (tf.constant(pd_te[0], dtype=tf.string), pd_te[1]))
    fds = fx.map(decode).batch(BATCH).map(to_float)
    probs, ys = [], []
    for xb, yb in fds:
        p1 = model.predict_on_batch(xb)
        p2 = model.predict_on_batch(tf.image.flip_left_right(xb))  # как в приложении (TTA)
        probs.append((p1 + p2) / 2)
        ys.extend(yb.numpy().tolist())
    probs = np.concatenate(probs)
    ys = np.array(ys)
    crop_of = [n.split("___")[0].lower() for n in labels]
    top1 = float((probs.argmax(1) == ys).mean())
    top3 = float(np.mean([y in np.argsort(-p)[:3] for p, y in zip(probs, ys)]))
    # Если фермер указал культуру — сравниваем только её классы (так работает приложение).
    crop_ok = []
    for p, y in zip(probs, ys):
        mask = np.array([c == crop_of[y] for c in crop_of])
        crop_ok.append(int(np.argmax(np.where(mask, p, -1)) == y))
    crop_acc = float(np.mean(crop_ok))
    field = {"n": int(len(ys)), "top1": top1, "top3": top3, "with_crop_hint": crop_acc}
    print(f"FIELD (PlantDoc test, TTA): n={len(ys)} top1={top1:.4f} top3={top3:.4f} "
          f"with_crop_hint={crop_acc:.4f}")

# Экспорт TFLite.
saved_dir = os.path.join(OUT_DIR, "_saved")
try:
    model.export(saved_dir)  # Keras 3
    converter = tf.lite.TFLiteConverter.from_saved_model(saved_dir)
except AttributeError:
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
converter.optimizations = [tf.lite.Optimize.DEFAULT]
tfl = converter.convert()
with open(os.path.join(OUT_DIR, "plant_disease.tflite"), "wb") as f:
    f.write(tfl)
with open(os.path.join(OUT_DIR, "labels.json"), "w", encoding="utf-8") as f:
    json.dump({"input_size": IMG, "input_range": [0, 255], "labels": labels}, f, ensure_ascii=False, indent=1)

# Проверка TFLite на части валидации.
interp = tf.lite.Interpreter(model_content=tfl)
interp.allocate_tensors()
inp = interp.get_input_details()[0]
out = interp.get_output_details()[0]
ok = tot = 0
for xb, yb in val_ds.take(10):
    for xi, yi in zip(xb.numpy(), yb.numpy()):
        interp.set_tensor(inp["index"], xi[None].astype(np.float32))
        interp.invoke()
        ok += int(np.argmax(interp.get_tensor(out["index"])[0]) == yi)
        tot += 1
tfl_acc = ok / tot
print(f"TFLITE ACCURACY (sample {tot}): {tfl_acc:.4f}; size {len(tfl) / 1e6:.2f} MB")

with open(os.path.join(OUT_DIR, "report.json"), "w", encoding="utf-8") as f:
    json.dump({"val_accuracy": acc, "tflite_sample_accuracy": tfl_acc, "img": IMG,
               "train_counts": dict(zip(labels, counts.tolist())), "per_class": per_class,
               "field": field,
               "seconds": time.time() - t0}, f, ensure_ascii=False, indent=1)
import shutil
shutil.rmtree(saved_dir, ignore_errors=True)
print(f"total {time.time() - t0:.0f}s")
