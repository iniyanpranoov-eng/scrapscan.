#!/usr/bin/env python3
"""
ScrapScan 2.0 - Ultralytics YOLOv8-nano Training & TFLite Export Pipeline

Trains a custom YOLOv8-nano model on multi-item scrap detection datasets,
evaluates validation mAP metrics, and exports optimized TFLite models
with FP16 and INT8 quantization for mobile hardware acceleration.
"""

import os
import sys
import shutil
import argparse
from pathlib import Path

try:
    from ultralytics import YOLO
except ImportError:
    pass

DEFAULT_EPOCHS = 50
DEFAULT_IMGSZ = 640
DEFAULT_BATCH = 16

CLASSES = [
    "Plastic Bottle / PET",
    "Aluminum Can & Tins",
    "Paper/Cardboard",
    "Iron & Steel",
    "Copper & Wiring",
    "E-Waste & Circuitry",
    "Glass Bottles"
]

def train_and_export(
    data_yaml: str,
    epochs: int = DEFAULT_EPOCHS,
    batch_size: int = DEFAULT_BATCH,
    imgsz: int = DEFAULT_IMGSZ,
    output_dir: str = "assets/models",
):
    print("=" * 60)
    print("ScrapScan 2.0 - YOLOv8-nano Training & Export Pipeline")
    print("=" * 60)

    output_path = Path(output_dir)
    output_path.mkdir(parents=True, exist_ok=True)

    # 1. Load pretrained YOLOv8-nano model
    print("\n[1/4] Loading pretrained YOLOv8n backbone...")
    model = YOLO("yolov8n.pt")

    # 2. Train on custom scrap dataset
    print(f"\n[2/4] Training YOLOv8-nano on {data_yaml} ({epochs} epochs, {imgsz}x{imgsz})...")
    results = model.train(
        data=data_yaml,
        epochs=epochs,
        imgsz=imgsz,
        batch=batch_size,
        patience=15,
        save=True,
        plots=True,
    )

    # 3. Validate model
    print("\n[3/4] Validating detection metrics (mAP@50, mAP@50-95)...")
    metrics = model.val()
    print(f"[✔] Validation mAP@50: {metrics.box.map50:.4f}")
    print(f"[✔] Validation mAP@50-95: {metrics.box.map:.4f}")

    # 4. Export to TFLite format with FP16 and INT8 quantization
    print("\n[4/4] Exporting to TFLite format with FP16/INT8 quantization...")

    # Export FP16 (Half precision for GPU/NPU acceleration)
    exported_fp16 = model.export(
        format="tflite",
        imgsz=imgsz,
        half=True,
        int8=False,
    )
    print(f"[✔] Exported FP16 TFLite model: {exported_fp16}")

    # Export INT8 (Quantized for low-power mobile CPU/NPU)
    try:
        exported_int8 = model.export(
            format="tflite",
            imgsz=imgsz,
            int8=True,
        )
        print(f"[✔] Exported INT8 TFLite model: {exported_int8}")
    except Exception as e:
        print(f"[!] Note: INT8 export skipped ({e})")

    # Copy to destination assets directory
    if exported_fp16 and os.path.exists(exported_fp16):
        dest_fp16 = output_path / "yolov8n_float16.tflite"
        shutil.copy2(exported_fp16, dest_fp16)
        print(f"[+] Deployed model to: {dest_fp16}")

    # Write labels.txt
    labels_path = output_path / "labels.txt"
    with open(labels_path, "w", encoding="utf-8") as f:
        for c in CLASSES:
            f.write(f"{c}\n")
    print(f"[+] Saved class labels to: {labels_path}")

    print("\n[✔] YOLOv8-nano Training & Mobile Deployment Pipeline Complete.")

def main():
    parser = argparse.ArgumentParser(description="Train and Export YOLOv8-nano for ScrapScan 2.0")
    parser.add_argument(
        "--data",
        type=str,
        default="ml_pipeline/scrap_dataset.yaml",
        help="Path to scrap_dataset.yaml",
    )
    parser.add_argument("--epochs", type=int, default=DEFAULT_EPOCHS, help="Number of training epochs")
    parser.add_argument("--batch", type=int, default=DEFAULT_BATCH, help="Batch size")
    parser.add_argument("--imgsz", type=int, default=DEFAULT_IMGSZ, help="Input image resolution")
    parser.add_argument(
        "--output-dir",
        type=str,
        default="assets/models",
        help="Output directory for TFLite models and labels",
    )
    args = parser.parse_args()

    train_and_export(
        data_yaml=args.data,
        epochs=args.epochs,
        batch_size=args.batch,
        imgsz=args.imgsz,
        output_dir=args.output_dir,
    )

if __name__ == "__main__":
    main()
