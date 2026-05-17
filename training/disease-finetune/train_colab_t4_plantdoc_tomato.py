"""Colab/T4 transfer-learning script for the Disease Scout tomato classifier.

This script expects the PlantDoc folder layout:

    PlantDoc-Dataset-master/
      train/<class name>/*.jpg
      test/<class name>/*.jpg

It trains a small MobileNetV2 classifier on tomato PlantDoc classes and saves
the model plus metrics. Run this on Google Colab with a T4 GPU for the actual
fine-tune; use smoke-plantdoc-finetune.ps1 locally only to verify data paths.
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dataset-root", default="/content/PlantDoc-Dataset-master")
    parser.add_argument("--output-dir", default="/content/disease_scout_finetune")
    parser.add_argument("--image-size", type=int, default=224)
    parser.add_argument("--batch-size", type=int, default=16)
    parser.add_argument("--head-epochs", type=int, default=3)
    parser.add_argument("--finetune-epochs", type=int, default=2)
    parser.add_argument("--min-train-images", type=int, default=20)
    parser.add_argument("--export-tflite", action="store_true")
    return parser.parse_args()


def discover_classes(dataset_root: Path, min_train_images: int) -> list[str]:
    excluded = {"Tomato two spotted spider mites leaf"}
    train_root = dataset_root / "train"
    test_root = dataset_root / "test"
    classes: list[str] = []
    for class_dir in sorted(train_root.iterdir()):
        if not class_dir.is_dir():
            continue
        if not class_dir.name.startswith("Tomato"):
            continue
        if class_dir.name in excluded:
            continue
        train_count = count_images(class_dir)
        test_count = count_images(test_root / class_dir.name)
        if train_count >= min_train_images and test_count > 0:
            classes.append(class_dir.name)
    if len(classes) < 2:
        raise RuntimeError(f"Need at least two tomato classes, found {len(classes)}")
    return classes


def count_images(path: Path) -> int:
    if not path.exists():
        return 0
    suffixes = {".jpg", ".jpeg", ".png", ".webp"}
    return sum(1 for item in path.rglob("*") if item.is_file() and item.suffix.lower() in suffixes)


def prepare_workdir(dataset_root: Path, output_dir: Path, classes: list[str]) -> Path:
    workdir = output_dir / "plantdoc_tomato_work"
    if workdir.exists():
        shutil.rmtree(workdir)
    for split in ("train", "test"):
        for class_name in classes:
            src = dataset_root / split / class_name
            dst = workdir / split / class_name
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copytree(src, dst)
    return workdir


def main() -> None:
    args = parse_args()
    os.environ.setdefault("TF_CPP_MIN_LOG_LEVEL", "2")

    import tensorflow as tf

    dataset_root = Path(args.dataset_root)
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    classes = discover_classes(dataset_root, args.min_train_images)
    workdir = prepare_workdir(dataset_root, output_dir, classes)

    image_size = (args.image_size, args.image_size)
    train_ds = tf.keras.utils.image_dataset_from_directory(
        workdir / "train",
        validation_split=0.2,
        subset="training",
        seed=1337,
        image_size=image_size,
        batch_size=args.batch_size,
    )
    val_ds = tf.keras.utils.image_dataset_from_directory(
        workdir / "train",
        validation_split=0.2,
        subset="validation",
        seed=1337,
        image_size=image_size,
        batch_size=args.batch_size,
    )
    test_ds = tf.keras.utils.image_dataset_from_directory(
        workdir / "test",
        image_size=image_size,
        batch_size=args.batch_size,
        shuffle=False,
    )

    class_names = train_ds.class_names
    label_map = {str(index): name for index, name in enumerate(class_names)}
    (output_dir / "label_map.json").write_text(json.dumps(label_map, indent=2), encoding="utf-8")

    autotune = tf.data.AUTOTUNE
    train_ds = train_ds.prefetch(autotune)
    val_ds = val_ds.prefetch(autotune)
    test_ds = test_ds.prefetch(autotune)

    inputs = tf.keras.Input(shape=(args.image_size, args.image_size, 3))
    x = tf.keras.layers.RandomFlip("horizontal")(inputs)
    x = tf.keras.layers.RandomRotation(0.08)(x)
    x = tf.keras.layers.RandomZoom(0.12)(x)
    x = tf.keras.applications.mobilenet_v2.preprocess_input(x)

    base = tf.keras.applications.MobileNetV2(
        include_top=False,
        weights="imagenet",
        input_shape=(args.image_size, args.image_size, 3),
    )
    base.trainable = False
    x = base(x, training=False)
    x = tf.keras.layers.GlobalAveragePooling2D()(x)
    x = tf.keras.layers.Dropout(0.25)(x)
    outputs = tf.keras.layers.Dense(len(class_names), activation="softmax")(x)
    model = tf.keras.Model(inputs, outputs)

    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=1e-3),
        loss="sparse_categorical_crossentropy",
        metrics=["accuracy"],
    )
    head_history = model.fit(train_ds, validation_data=val_ds, epochs=args.head_epochs)

    base.trainable = True
    for layer in base.layers[:-30]:
        layer.trainable = False
    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=1e-5),
        loss="sparse_categorical_crossentropy",
        metrics=["accuracy"],
    )
    ft_history = model.fit(train_ds, validation_data=val_ds, epochs=args.finetune_epochs)
    test_loss, test_accuracy = model.evaluate(test_ds, verbose=0)

    model_path = output_dir / "disease_scout_tomato_mobilenetv2.keras"
    model.save(model_path)

    metrics = {
        "classes": class_names,
        "head_epochs": args.head_epochs,
        "finetune_epochs": args.finetune_epochs,
        "test_loss": float(test_loss),
        "test_accuracy": float(test_accuracy),
        "head_history": head_history.history,
        "finetune_history": ft_history.history,
        "model_path": str(model_path),
    }
    (output_dir / "metrics.json").write_text(json.dumps(metrics, indent=2), encoding="utf-8")

    if args.export_tflite:
        converter = tf.lite.TFLiteConverter.from_keras_model(model)
        tflite_model = converter.convert()
        (output_dir / "disease_scout_tomato_mobilenetv2.tflite").write_bytes(tflite_model)

    print(json.dumps(metrics, indent=2))


if __name__ == "__main__":
    main()
