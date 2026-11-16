# ScrapScan 2.0 ♻️

> **Recycle smarter.** Identify scrap materials, estimate payout values, calculate multi-item lots, and track recycling impact offline.

ScrapScan 2.0 is a production-grade, offline-first mobile application built with Flutter that empowers recyclers, scrap dealers, and eco-conscious individuals to turn recyclable waste into documented economic value.

---

## 🌟 What's New in ScrapScan 2.0

- **Modular Clean Architecture**: Decoupled domain, data, service, and presentation layers (`lib/core/`, `lib/data/`, `lib/services/`, `lib/ui/`).
- **Offline SQLite Engine (`sqflite`)**:
  - Persistent, editable scrap categories and real-time market rates per kg.
  - Complete scan history with weights, rates at scan time, payout values, confidence scores, and engine provenance.
  - Automatic, zero-data-loss migration of legacy ScrapScan v1.0.0 `SharedPreferences` scan records on first launch.
  - Category price editing, custom category creation, and default rate restoration in Settings.
- **Hardware-Accelerated YOLOv8-nano Multi-Item Object Detection**:
  - Upgraded vision pipeline to Ultralytics YOLOv8-nano (`assets/models/yolov8n_float16.tflite`) with 640x640 resolution input and Non-Maximum Suppression (NMS).
  - Hardware acceleration with mobile GPU (`GpuDelegateV2`) and multi-threaded NPU/CPU (`XNNPackDelegate`).
  - Interactive camera overlay drawing color-coded bounding boxes and category confidence chips over every detected item in the frame.
  - Multi-item aggregation calculating individual scrap weights, item counts, and cumulative payout totals.
  - Graceful multi-tier fallback: YOLOv8-nano -> MobileNetV3 Isolate -> Offline Google ML Kit.
- **Practical Disposal & Recycling Instructions**:
  - Detailed, actionable preparation steps and safety/hazard warnings for all 7 scrap categories.
  - Dedicated "How to Recycle & Dispose" card on scan results highlighting preparation and environmental protection.
- **Permanent Local Image Storage**:
  - Automatically clones camera captures and gallery uploads into the app's persistent documents directory (`/scans/`), preserving evidence and thumbnails even if Android OS purges cache.
- **Multi-Item "Scrap Lot" Cart Mode**:
  - Weigh and aggregate multiple scrap items across different categories in a single session.
  - Live session totals (combined weight in kg and payout value in ₹) before batch-committing with a shared lot ID.
- **Advanced Analytics & Reporting**:
  - Interactive Daily (last 7 days) and Monthly (last 6 months) bar charts powered by `fl_chart`.
  - Toggle between Value (`₹`) and Weight (`kg`) trends, plus material composition progress metrics.
  - One-tap export to formatted **CSV** spreadsheets and branded **PDF** executive reports via `share_plus`.
- **Android Release Hardening**:
  - Hardened ProGuard rules in `android/app/proguard-rules.pro` keeping `org.tensorflow.lite.**` and `com.google.mlkit.**` native components intact in release builds.

---

## 📐 Architecture Overview

```
lib/
├── core/
│   ├── constants/
│   │   └── app_constants.dart          # Baseline rates, confidence threshold (0.55), branding
│   └── theme/
│       └── app_theme.dart              # ScrapScan green palette, gradients, typography
├── data/
│   ├── database/
│   │   └── app_database.dart           # SQLite helper, schema, CRUD, v1 SharedPreferences migration
│   └── models/
│       ├── scrap_category.dart         # Category entity (id, name, ratePerKg, isDefault, icon)
│       ├── scan_record.dart            # History record (category, weight, rate, value, aiEngine, lotId)
│       └── scrap_lot_item.dart         # Session cart item with estimated value calculator
├── services/
│   ├── ai_classifier_service.dart      # Hybrid TFLite (Isolate) + Google ML Kit offline fallback
│   ├── image_storage_service.dart      # Copies images to persistent app documents directory
│   ├── scrap_lot_service.dart          # Multi-item scrap lot state management
│   └── export_service.dart             # CSV and PDF report generators with system share sheet
├── ui/
│   ├── screens/
│   │   ├── home_screen.dart            # Dashboard, dynamic category grid, total savings KPI
│   │   ├── scan_result_screen.dart     # AI analysis, 55% threshold warning, weight input, lot action
│   │   ├── history_screen.dart         # Paginated scan logs, category filter chips, CSV/PDF export
│   │   ├── analytics_screen.dart       # Daily 7D / Monthly 6M bar charts & material distribution
│   │   ├── scrap_lot_screen.dart       # Multi-item cart review, weight adjustments, batch checkout
│   │   └── settings_screen.dart        # Rate editing, custom categories, engine status, rate reset
│   └── widgets/
│       ├── category_card.dart          # Rounded category card with price indicators
│       ├── scan_history_card.dart      # Historical scan entry with permanent thumbnail and engine badge
│       └── uncertain_material_dialog.dart # Bottom sheet for manual category selection
└── main.dart                           # Flutter initialization and application root
```

---

## 🤖 Hybrid AI Pipeline & Model Status

### Honest Model Status
| Component | Status | Behavior |
|---|---|---|
| **Custom TFLite (MobileNetV3)** | Pipeline ready (`ml_pipeline/`) | When `assets/models/scrap_model.tflite` is present, executes 224x224 inference inside background `Isolate.run`. |
| **Google ML Kit (Offline)** | **Active & Bundled** | Zero-network offline fallback that maps generic vision labels into the 7 core scrap categories. |
| **Confidence Safeguard** | **Active (55% threshold)** | Any inference scoring below 0.55 or unidentifiable triggers an explicit warning banner requiring user verification. |

### Baseline Scrap Categories & Standard Rates
1. **Plastic Bottle / PET**: ₹20.0 / kg (PET bottles, HDPE containers)
2. **Aluminum Can & Tins**: ₹35.0 / kg (Beverage cans, tin containers, foil scrap)
3. **Paper/Cardboard**: ₹10.0 / kg (Corrugated cartons, newspapers, books)
4. **Iron & Steel**: ₹28.0 / kg (Scrap iron, rebar, steel frames)
5. **Copper & Wiring**: ₹450.0 / kg (Stripped copper, electric cables)
6. **E-Waste & Circuitry**: ₹120.0 / kg (PCBs, motherboards, old electronic devices)
7. **Glass Bottles**: ₹4.0 / kg (Beverage glass bottles, glass jars)

*All rates and categories are completely editable and expandable in Settings.*

---

## 🧠 Python ML Training Pipeline (`ml_pipeline/`)

To train custom MobileNetV3Small weights on your own dataset:

### 1. Requirements
```bash
pip install tensorflow scikit-learn numpy
```

### 2. Prepare Dataset
Organize scrap images into class folders across `train/`, `val/`, and `test/`:
```bash
python ml_pipeline/train_scrap_model.py --init-dataset
```
Directory structure:
```
dataset/
├── train/
│   ├── Plastic_Bottle_PET/
│   ├── Aluminum_Can_Tins/
│   └── ...
├── val/
└── test/
```

### 3. Run Transfer Learning & Quantization
```bash
python ml_pipeline/train_scrap_model.py --epochs 15 --dataset-dir dataset --output-dir assets/models
```
The script will:
- Train MobileNetV3Small classification head, followed by top-layer fine-tuning.
- Evaluate on the held-out `test/` set and output `ml_pipeline/metrics.json` (classification report + confusion matrix).
- Export Float32 (`scrap_model.tflite`) and dynamic-range int8 quantized (`scrap_model_quantized.tflite`) weights.

### 4. Train Ultralytics YOLOv8-nano Multi-Item Detector
```bash
pip install ultralytics
python ml_pipeline/train_yolov8.py --data ml_pipeline/scrap_dataset.yaml --epochs 50 --output-dir assets/models
```
The script will:
- Train YOLOv8-nano on custom annotated bounding boxes in `dataset/images/` and `dataset/labels/`.
- Validate detection mAP@50 and mAP@50-95.
- Export FP16 (`yolov8n_float16.tflite`) and INT8 quantized models directly into `assets/models/`.

---

## 🛡️ Android Release Hardening

ProGuard rules in `android/app/proguard-rules.pro` protect native ML Kit and TFLite binaries:
```proguard
# TensorFlow Lite
-keep class org.tensorflow.lite.** { *; }
-keepclassmembers class org.tensorflow.lite.** { *; }
-dontwarn org.tensorflow.lite.**

# Google ML Kit
-keep class com.google.mlkit.** { *; }
-keepclassmembers class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_** { *; }
-dontwarn com.google.mlkit.**
-dontwarn com.google.android.gms.internal.mlkit_**
```

### Build Release APK
```bash
flutter build apk --release --target-platform android-arm64
```

---

## 🧪 Verification & Testing

Run all unit, integration, and widget tests:
```bash
flutter test
```
Run static analysis:
```bash
flutter analyze
```

---

## 📄 License
ScrapScan 2.0 is developed for educational and commercial scrap recycling workflows.
Tagline: *Recycle smarter.*
