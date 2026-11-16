import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_constants.dart';
import '../../data/database/app_database.dart';
import '../../data/models/detected_object.dart';
import '../../data/models/scrap_category.dart';
import '../../data/models/scan_record.dart';
import '../../data/models/scrap_lot_item.dart';
import '../../services/ai_detector_service.dart';
import '../../services/image_storage_service.dart';
import '../../services/scrap_lot_service.dart';
import '../widgets/bounding_box_overlay.dart';
import '../widgets/uncertain_material_dialog.dart';
import 'scrap_lot_screen.dart';

class ScanResultScreen extends StatefulWidget {
  final String imagePath;

  const ScanResultScreen({
    super.key,
    required this.imagePath,
  });

  @override
  State<ScanResultScreen> createState() => _ScanResultScreenState();
}

class _ScanResultScreenState extends State<ScanResultScreen> {
  String persistedImagePath = '';
  bool isAnalyzing = true;
  String detectedMaterial = 'Analyzing...';
  double confidence = 0.0;
  String aiEngine = 'YOLOv8-nano (Hardware Accelerated)';
  bool isUncertain = false;

  List<DetectedObject> detectedObjects = [];
  List<ScrapCategory> availableCategories = [];
  ScrapCategory? selectedCategory;

  final TextEditingController weightController = TextEditingController();
  bool isSaving = false;
  bool isSaved = false;

  @override
  void initState() {
    super.initState();
    persistedImagePath = widget.imagePath;
    _initializeAndDetect();
  }

  Future<void> _initializeAndDetect() async {
    // 1. Copy image permanently
    final permanent = await ImageStorageService.instance
        .saveImagePermanently(widget.imagePath);

    // 2. Load DB categories
    final categories = await AppDatabase.instance.getAllCategories();

    // 3. Multi-object YOLOv8 detection with hardware acceleration & fallback
    final result = await AIDetectorService.instance.detectObjects(
      permanent,
      categories: categories,
    );

    if (!mounted) return;

    // Trigger subtle haptic feedback upon successful scan completion
    try {
      HapticFeedback.mediumImpact();
    } catch (_) {}

    setState(() {
      persistedImagePath = permanent;
      availableCategories = categories;
      aiEngine = result.aiEngine;
      isUncertain = result.isUncertain;
      detectedObjects = List.from(result.objects);

      if (detectedObjects.isNotEmpty) {
        final first = detectedObjects.first;
        detectedMaterial = first.category;
        confidence = first.confidence;
        selectedCategory = _matchCategory(first.category, categories);
        weightController.text = _totalWeight.toStringAsFixed(2);
      } else {
        detectedMaterial = 'Uncertain / Unknown material';
        confidence = result.primaryConfidence;
        selectedCategory = _matchCategory(result.primaryCategory, categories);
      }

      isAnalyzing = false;
    });
  }

  double get _totalWeight =>
      detectedObjects.fold(0.0, (sum, o) => sum + o.weightKg);

  double get _totalValue =>
      detectedObjects.fold(0.0, (sum, o) => sum + o.estimatedValue);

  ScrapCategory? _matchCategory(String name, List<ScrapCategory> list) {
    final lower = name.toLowerCase();
    for (final cat in list) {
      if (cat.name.toLowerCase() == lower) return cat;
      if (lower.contains('plastic') && cat.name.contains('Plastic')) return cat;
      if (lower.contains('aluminum') && cat.name.contains('Aluminum')) return cat;
      if (lower.contains('paper') && cat.name.contains('Paper')) return cat;
      if (lower.contains('cardboard') && cat.name.contains('Cardboard')) return cat;
      if (lower.contains('iron') && cat.name.contains('Iron')) return cat;
      if (lower.contains('copper') && cat.name.contains('Copper')) return cat;
      if (lower.contains('e-waste') && cat.name.contains('E-Waste')) return cat;
      if (lower.contains('glass') && cat.name.contains('Glass')) return cat;
    }
    return list.isNotEmpty ? list.first : null;
  }

  void _onCategoryManuallySelected(ScrapCategory cat) {
    setState(() {
      selectedCategory = cat;
      detectedMaterial = cat.name;
      isUncertain = false;
      isSaved = false;

      if (detectedObjects.isEmpty) {
        final manualObj = DetectedObject(
          id: 'manual_${DateTime.now().millisecondsSinceEpoch}',
          category: cat.name,
          confidence: 1.0,
          boundingBox: const Rect.fromLTWH(0.1, 0.1, 0.8, 0.8),
          weightKg: double.tryParse(weightController.text) ?? 1.0,
          ratePerKg: cat.ratePerKg,
          aiEngine: 'Manual Selection',
        );
        detectedObjects = [manualObj];
      } else {
        detectedObjects = detectedObjects.map((o) {
          return o.copyWith(
            category: cat.name,
            ratePerKg: cat.ratePerKg,
          );
        }).toList();
      }
    });
  }

  void _updateOverallWeight(String value) {
    final parsed = double.tryParse(value) ?? 0.0;
    if (detectedObjects.length == 1) {
      setState(() {
        detectedObjects.first.weightKg = parsed;
        isSaved = false;
      });
    } else if (detectedObjects.isNotEmpty) {
      // Scale proportionally across items
      final currentTotal = _totalWeight;
      setState(() {
        if (currentTotal > 0) {
          final factor = parsed / currentTotal;
          for (final obj in detectedObjects) {
            obj.weightKg *= factor;
          }
        } else {
          final each = parsed / detectedObjects.length;
          for (final obj in detectedObjects) {
            obj.weightKg = each;
          }
        }
        isSaved = false;
      });
    }
  }

  void _editSingleObjectWeight(DetectedObject obj) {
    final controller = TextEditingController(text: obj.weightKg.toStringAsFixed(2));
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text('Edit Weight: ${obj.category}'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: const InputDecoration(
            suffixText: 'kg',
            hintText: 'Enter weight for this item',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newWeight = double.tryParse(controller.text);
              if (newWeight != null && newWeight >= 0) {
                setState(() {
                  obj.weightKg = newWeight;
                  weightController.text = _totalWeight.toStringAsFixed(2);
                  isSaved = false;
                });
                Navigator.pop(dialogCtx);
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _removeDetectedObject(DetectedObject obj) {
    setState(() {
      detectedObjects.removeWhere((o) => o.id == obj.id);
      weightController.text = _totalWeight.toStringAsFixed(2);
      isSaved = false;
      if (detectedObjects.isEmpty) {
        isUncertain = true;
        detectedMaterial = 'Uncertain / Unknown material';
      }
    });
  }

  Future<void> _saveScans() async {
    if (isSaving || isSaved) return;

    if (detectedObjects.isEmpty && selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select or verify a scrap category first.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => isSaving = true);

    try {
      final String? batchLotId =
          detectedObjects.length > 1 ? 'MULTI_${DateTime.now().millisecondsSinceEpoch}' : null;

      for (final obj in detectedObjects) {
        final record = ScanRecord(
          category: obj.category,
          confidence: obj.confidence,
          weightKg: obj.weightKg,
          rateAtScanTime: obj.ratePerKg,
          estimatedValue: obj.estimatedValue,
          imagePath: persistedImagePath,
          timestamp: DateTime.now(),
          aiEngine: obj.aiEngine,
          lotId: batchLotId,
        );
        await AppDatabase.instance.insertScan(record);
      }

      if (!mounted) return;
      setState(() {
        isSaving = false;
        isSaved = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            detectedObjects.length > 1
                ? 'Saved ${detectedObjects.length} detected items to SQLite!'
                : 'Scan saved to SQLite History!',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to save scan: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _addToScrapLot() {
    if (detectedObjects.isEmpty && selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a scrap category before adding to lot.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    for (final obj in detectedObjects) {
      final item = ScrapLotItem(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        category: obj.category,
        ratePerKg: obj.ratePerKg,
        weightKg: obj.weightKg,
        confidence: obj.confidence,
        imagePath: persistedImagePath,
        aiEngine: obj.aiEngine,
      );
      ScrapLotService.instance.addItem(item);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Added ${detectedObjects.length} item(s) to Scrap Lot! (Total: ${ScrapLotService.instance.itemCount})',
        ),
        action: SnackBarAction(
          label: 'View Lot',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ScrapLotScreen()),
            );
          },
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    weightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lot = ScrapLotService.instance;
    final isMulti = detectedObjects.length > 1;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F8F5),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          isMulti ? 'Multi-Object Detection' : 'Scan Result',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          AnimatedBuilder(
            animation: lot,
            builder: (context, _) {
              if (lot.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Badge(
                  label: Text('${lot.itemCount}'),
                  backgroundColor: Colors.green.shade700,
                  child: IconButton(
                    icon: const Icon(Icons.shopping_cart_checkout_rounded),
                    tooltip: 'View Scrap Lot',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ScrapLotScreen(),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Preview Image with Interactive Bounding Box Overlay
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: double.infinity,
                height: 280,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(
                      File(persistedImagePath),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.green.shade50,
                        child: const Center(
                          child: Icon(Icons.image_not_supported_outlined, size: 50),
                        ),
                      ),
                    ),
                    if (!isAnalyzing && detectedObjects.isNotEmpty)
                      BoundingBoxOverlay(objects: detectedObjects),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Uncertain Warning Banner (Strict 65% Threshold)
            if (!isAnalyzing && isUncertain)
              Container(
                margin: const EdgeInsets.only(bottom: 18),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.amber.shade300, width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: Colors.amber.shade800, size: 28),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Uncertain / Unknown Material',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'AI confidence was below 65% threshold. Please manually verify and pick the matching scrap category:',
                      style: TextStyle(fontSize: 13, color: Colors.amber.shade900),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber.shade700,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () async {
                          final selected = await UncertainMaterialSheet.show(
                            context,
                            categories: availableCategories,
                            initialSelection: selectedCategory?.name,
                          );
                          if (selected != null) {
                            _onCategoryManuallySelected(selected);
                          }
                        },
                        icon: const Icon(Icons.tune_rounded, size: 20),
                        label: const Text('Verify / Select Category'),
                      ),
                    ),
                  ],
                ),
              ),

            // Multi-Item Counts / Detection Summary Card
            if (!isAnalyzing && isMulti)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 18),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green.shade100),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.view_in_ar_rounded,
                                color: Colors.green.shade700,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '${detectedObjects.length} Scrap Items Detected',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'YOLOv8',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Item Breakdown List with Inline Adjustments
                    ...detectedObjects.map((obj) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FBF9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: Colors.green.shade100,
                              child: Text(
                                obj.category[0],
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade900,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    obj.category,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    '${(obj.confidence * 100).toStringAsFixed(0)}% conf • ${AppConstants.currency}${obj.ratePerKg.toStringAsFixed(0)}/kg',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            InkWell(
                              onTap: () => _editSingleObjectWeight(obj),
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                child: Row(
                                  children: [
                                    Text(
                                      '${obj.weightKg.toStringAsFixed(2)} kg',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.green.shade800,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.edit_outlined, size: 14, color: Colors.grey),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${AppConstants.currency}${obj.estimatedValue.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Colors.green.shade700,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => _removeDetectedObject(obj),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),

            // Single / Primary Material Detection Card
            if (!isMulti)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 55,
                      height: 55,
                      decoration: BoxDecoration(
                        color: isUncertain
                            ? Colors.amber.shade50
                            : Colors.green.shade50,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: isAnalyzing
                          ? const Padding(
                              padding: EdgeInsets.all(15),
                              child: CircularProgressIndicator(strokeWidth: 2.5),
                            )
                          : Icon(
                              selectedCategory?.iconData ??
                                  Icons.recycling_rounded,
                              color: isUncertain
                                  ? Colors.amber.shade800
                                  : Colors.green.shade700,
                              size: 30,
                            ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            detectedMaterial,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isAnalyzing
                                ? 'Analyzing with $aiEngine...'
                                : 'Rate: ${AppConstants.currency}${selectedCategory?.ratePerKg.toStringAsFixed(1) ?? '0.0'}/kg • ${(confidence * 100).toStringAsFixed(1)}% conf',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Engine: $aiEngine',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isAnalyzing)
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: 'Change category',
                        onPressed: () async {
                          final selected = await UncertainMaterialSheet.show(
                            context,
                            categories: availableCategories,
                            initialSelection: selectedCategory?.name,
                          );
                          if (selected != null) {
                            _onCategoryManuallySelected(selected);
                          }
                        },
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 18),

            // Combined Scrap Weight Input
            Text(
              isMulti ? 'Combined Scrap Weight' : 'Scrap Weight',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: weightController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: _updateOverallWeight,
              decoration: InputDecoration(
                hintText: 'Enter total weight',
                suffixText: 'kg',
                prefixIcon: const Icon(Icons.monitor_weight_outlined),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Cumulative Estimated Payout Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.shade600, Colors.green.shade800],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.currency_rupee,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isMulti
                            ? 'Cumulative Payout (${detectedObjects.length} items)'
                            : 'Estimated Payout',
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${AppConstants.currency}${_totalValue.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Dedicated How to Recycle & Dispose Guide Card
            if (!isAnalyzing && selectedCategory != null)
              _buildRecyclingGuideCard(selectedCategory!),

            const SizedBox(height: 24),

            // Actions: Single/Batch Save & Scrap Lot Cart
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: isAnalyzing || isSaving ? null : _saveScans,
                      icon: isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(isSaved ? Icons.check_circle : Icons.save_outlined),
                      label: Text(
                        isSaved
                            ? 'Saved'
                            : isMulti
                                ? 'Save All (${detectedObjects.length})'
                                : 'Save Scan',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: isAnalyzing ? null : _addToScrapLot,
                      icon: const Icon(Icons.add_shopping_cart_rounded),
                      label: Text(isMulti ? 'Add All to Lot' : 'Add to Lot'),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.green.shade700, width: 1.5),
                        foregroundColor: Colors.green.shade800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Rescan Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: TextButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Scan Another Item'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecyclingGuideCard(ScrapCategory category) {
    final hasSteps = category.recyclingSteps.isNotEmpty;
    final hasWarning = category.disposalWarning.isNotEmpty;

    if (!hasSteps && !hasWarning) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.green.shade100, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.eco_rounded,
                  color: Colors.green.shade700,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'How to Recycle & Dispose',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Preparation & safety guide for ${category.name}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (hasSteps) ...[
            const SizedBox(height: 16),
            const Text(
              'Recycling Preparation Steps:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            ...category.recyclingSteps.asMap().entries.map((entry) {
              final stepIndex = entry.key + 1;
              final stepText = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$stepIndex',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        stepText,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade800,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
          if (hasWarning) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.amber.shade400, width: 1.2),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.amber.shade900,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Safety & Hazard Warning',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          category.disposalWarning,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.brown.shade800,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
