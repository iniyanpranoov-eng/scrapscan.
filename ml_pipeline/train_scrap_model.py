#!/usr/bin/env python3
"""
ScrapScan 2.0 - MobileNetV3Small Transfer Learning Pipeline

Trains a custom TensorFlow Lite scrap material classification model
using transfer learning with MobileNetV3Small on separate train/val/test splits,
evaluates on a held-out test set, and exports optimized TFLite models.
"""

import os
import sys
import json
import argparse
from pathlib import Path
import numpy as np

# Optional imports handled gracefully
try:
    import tensorflow as tf
    from tensorflow.keras import layers, models
    from tensorflow.keras.applications import MobileNetV3Small
    from sklearn.metrics import classification_report, confusion_matrix
except ImportError:
    pass

CATEGORIES = [
    "Plastic Bottle / PET",
    "Aluminum Can & Tins",
    "Paper/Cardboard",
    "Iron & Steel",
    "Copper & Wiring",
    "E-Waste & Circuitry",
    "Glass Bottles"
]

IMAGE_SIZE = (224, 224)
BATCH_SIZE = 32
DEFAULT_EPOCHS = 15

def create_directory_structure(dataset_root: Path):
    """Creates the dataset train/val/test directories for all categories."""
    for split in ["train", "val", "test"]:
        for cat in CATEGORIES:
            folder_name = cat.replace(" / ", "_").replace(" & ", "_").replace("/", "_").replace(" ", "_")
            path = dataset_root / split / folder_name
            path.mkdir(parents=True, exist_ok=True)
    print(f"[+] Verified dataset structure at: {dataset_root}")

def build_model(num_classes: int):
    """Constructs MobileNetV3Small transfer learning architecture."""
    base_model = MobileNetV3Small(
        input_shape=(*IMAGE_SIZE, 3),
        include_top=False,
        weights="imagenet",
        pooling="avg"
    )
    base_model.trainable = False  # Freeze base during initial stage

    inputs = tf.keras.Input(shape=(*IMAGE_SIZE, 3))
    x = layers.RandomFlip("horizontal")(inputs)
    x = layers.RandomRotation(0.15)(x)
    x = layers.RandomZoom(0.1)(x)
    x = base_model(x, training=False)
    x = layers.Dropout(0.2)(x)
    outputs = layers.Dense(num_classes, activation="softmax")(x)

    model = models.Model(inputs, outputs, name="ScrapScanMobileNetV3")
    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=1e-3),
        loss="sparse_categorical_crossentropy",
        metrics=["accuracy"]
    )
    return model, base_model

def evaluate_and_save_metrics(model, test_ds, class_names, output_dir: Path):
    """Computes held-out test evaluation metrics and saves to JSON."""
    y_true = []
    y_pred = []

    for images, labels in test_ds:
        preds = model.predict(images, verbose=0)
        y_true.extend(labels.numpy())
        y_pred.extend(np.argmax(preds, axis=1))

    report = classification_report(
        y_true, y_pred, target_names=class_names, output_dict=True, zero_division=0
    )
    matrix = confusion_matrix(y_true, y_pred).tolist()

    metrics = {
        "model_architecture": "MobileNetV3Small",
        "input_resolution": list(IMAGE_SIZE),
        "test_classification_report": report,
        "confusion_matrix": matrix,
        "classes": class_names,
    }

    metrics_path = output_dir / "metrics.json"
    with open(metrics_path, "w", encoding="utf-8") as f:
        json.dump(metrics, f, indent=2)
    print(f"[+] Evaluation metrics saved to: {metrics_path}")
    return metrics

def export_tflite(model, output_dir: Path, labels: list):
    """Exports float32 and quantized TFLite models with label mapping."""
    output_dir.mkdir(parents=True, exist_ok=True)

    # 1. Float32 TFLite
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    tflite_model = converter.convert()
    float_path = output_dir / "scrap_model.tflite"
    with open(float_path, "wb") as f:
        f.write(tflite_model)
    print(f"[+] Saved Float32 TFLite model to: {float_path} ({len(tflite_model) / 1024:.1f} KB)")

    # 2. Dynamic Range Quantized TFLite (size optimization)
    quant_converter = tf.lite.TFLiteConverter.from_keras_model(model)
    quant_converter.optimizations = [tf.lite.Optimize.DEFAULT]
    quant_model = quant_converter.convert()
    quant_path = output_dir / "scrap_model_quantized.tflite"
    with open(quant_path, "wb") as f:
        f.write(quant_model)
    print(f"[+] Saved Quantized TFLite model to: {quant_path} ({len(quant_model) / 1024:.1f} KB)")

    # 3. Labels text file
    labels_path = output_dir / "labels.txt"
    with open(labels_path, "w", encoding="utf-8") as f:
        for lbl in labels:
            f.write(f"{lbl}\n")
    print(f"[+] Saved labels to: {labels_path}")

def main():
    parser = argparse.ArgumentParser(description="ScrapScan 2.0 ML Pipeline")
    parser.add_argument("--dataset-dir", type=str, default="dataset", help="Root directory for dataset")
    parser.add_argument("--output-dir", type=str, default="assets/models", help="Destination for TFLite weights")
    parser.add_argument("--epochs", type=int, default=DEFAULT_EPOCHS, help="Number of training epochs")
    parser.add_argument("--init-dataset", action="store_true", help="Initialize folder skeleton")
    args = parser.parse_args()

    dataset_root = Path(args.dataset_dir)
    output_dir = Path(args.output_dir)

    if args.init_dataset:
        create_directory_structure(dataset_root)
        print("Dataset directory scaffold initialized.")
        return

    # Check if dataset exists and has images
    train_dir = dataset_root / "train"
    val_dir = dataset_root / "val"
    test_dir = dataset_root / "test"

    if not train_dir.exists() or not list(train_dir.glob("*/*.*")):
        print(f"[!] No training images found in '{train_dir}'. Initializing directory scaffold...")
        create_directory_structure(dataset_root)
        print("\nPlease populate dataset/train/, dataset/val/, and dataset/test/ with images per category, then rerun.")
        return

    # Load datasets
    train_ds = tf.keras.utils.image_dataset_from_directory(
        train_dir, image_size=IMAGE_SIZE, batch_size=BATCH_SIZE
    )
    val_ds = tf.keras.utils.image_dataset_from_directory(
        val_dir, image_size=IMAGE_SIZE, batch_size=BATCH_SIZE
    )
    test_ds = tf.keras.utils.image_dataset_from_directory(
        test_dir, image_size=IMAGE_SIZE, batch_size=BATCH_SIZE, shuffle=False
    )

    class_names = train_ds.class_names
    print(f"[+] Training on classes: {class_names}")

    model, base_model = build_model(len(class_names))

    # Phase 1: Train classification head
    print(f"\n--- Phase 1: Training Classification Head ({args.epochs} epochs) ---")
    model.fit(train_ds, validation_data=val_ds, epochs=args.epochs)

    # Phase 2: Fine-tuning top layers of base model
    print("\n--- Phase 2: Fine-Tuning Top Layers ---")
    base_model.trainable = True
    for layer in base_model.layers[:-20]:
        layer.trainable = False

    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=1e-4),
        loss="sparse_categorical_crossentropy",
        metrics=["accuracy"]
    )
    model.fit(train_ds, validation_data=val_ds, epochs=max(5, args.epochs // 2))

    # Evaluate on held-out test set
    print("\n--- Phase 3: Held-Out Test Evaluation ---")
    evaluate_and_save_metrics(model, test_ds, class_names, Path("ml_pipeline"))

    # Export TFLite
    print("\n--- Phase 4: TFLite Export & Quantization ---")
    export_tflite(model, output_dir, class_names)
    print("\n[✔] ML Pipeline training, test evaluation, and TFLite export complete.")

if __name__ == "__main__":
    main()
