import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../data/database/app_database.dart';
import '../../data/models/scrap_category.dart';
import '../../services/ai_classifier_service.dart';
import '../../services/ai_detector_service.dart';
import '../../services/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  List<ScrapCategory> categories = [];
  bool isLoading = true;
  bool isCustomTfliteAvailable = false;
  bool isYoloAvailable = false;
  bool useYoloEngine = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => isLoading = true);
    final cats = await AppDatabase.instance.getAllCategories();
    final tfliteOk = await AIClassifierService.instance.isCustomModelAvailable();
    final yoloOk = await AIDetectorService.instance.isYOLOModelAvailable();
    final yoloPref = await SettingsService.instance.getUseYoloEngine();

    if (!mounted) return;
    setState(() {
      categories = cats;
      isCustomTfliteAvailable = tfliteOk;
      isYoloAvailable = yoloOk;
      useYoloEngine = yoloPref;
      isLoading = false;
    });
  }

  void _editCategoryRate(ScrapCategory category) {
    final controller = TextEditingController(text: category.ratePerKg.toString());

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text('Edit Price: ${category.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Set scrap payout rate per kilogram:',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: InputDecoration(
                prefixText: '${AppConstants.currency} ',
                suffixText: '/ kg',
                hintText: 'Enter price',
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
            ),
            onPressed: () async {
              final newRate = double.tryParse(controller.text);
              if (newRate != null && newRate > 0) {
                await AppDatabase.instance.updateCategoryRate(category.id!, newRate);
                if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                _loadSettings();
              }
            },
            child: const Text('Save Rate'),
          ),
        ],
      ),
    );
  }

  void _addCustomCategoryDialog() {
    final nameController = TextEditingController();
    final rateController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Add Custom Scrap Category'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Category Name',
                  hintText: 'e.g., Brass & Bronze',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: rateController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Rate per kg',
                  prefixText: '${AppConstants.currency} ',
                  suffixText: '/ kg',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  hintText: 'e.g., Plumbing fixtures, valves',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
            ),
            onPressed: () async {
              final name = nameController.text.trim();
              final rate = double.tryParse(rateController.text.trim()) ?? 0.0;
              final desc = descController.text.trim();

              if (name.isNotEmpty && rate > 0) {
                final newCat = ScrapCategory(
                  name: name,
                  ratePerKg: rate,
                  isDefault: false,
                  iconName: 'recycling_rounded',
                  description: desc,
                );
                await AppDatabase.instance.insertCategory(newCat);
                if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                _loadSettings();
              }
            },
            child: const Text('Add Category'),
          ),
        ],
      ),
    );
  }

  Future<void> _resetDefaultRates() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Default Scrap Rates?'),
        content: const Text(
          'This will reset all default categories back to their baseline rates per kg.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset Rates'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await AppDatabase.instance.resetDefaultRates();
      await _loadSettings();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Default scrap rates have been restored.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8F5),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                // About App Card
                Card(
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.green.shade50,
                      child: const Icon(
                        Icons.recycling_rounded,
                        color: Colors.green,
                      ),
                    ),
                    title: const Text(
                      '${AppConstants.appName} 2.0',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text(
                      '${AppConstants.tagline} • Turn scrap into real value.',
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // AI Engine Status Card
                Card(
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: Colors.blue.shade50,
                              child: Icon(Icons.psychology_rounded,
                                  color: Colors.blue.shade700),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'AI & Detection Engine',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            useYoloEngine ? 'Custom YOLOv8 Model' : 'Google ML Kit Offline',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          subtitle: Text(
                            useYoloEngine
                                ? 'Hardware-accelerated multi-item object detector active'
                                : 'Offline single-item image classification fallback active',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                          value: useYoloEngine,
                          activeColor: Colors.green.shade700,
                          onChanged: (val) async {
                            await SettingsService.instance.setUseYoloEngine(val);
                            setState(() => useYoloEngine = val);
                          },
                        ),
                        const Divider(height: 16),
                        _engineStatusRow(
                          title: 'Custom YOLOv8-nano (Object Detection)',
                          subtitle: useYoloEngine
                              ? (isYoloAvailable
                                  ? 'Active Custom Model (yolov8n_float16.tflite bundled)'
                                  : 'Model not bundled (see ml_pipeline/)')
                              : 'Disabled by user preference',
                          isActive: useYoloEngine && isYoloAvailable,
                        ),
                        const Divider(height: 16),
                        _engineStatusRow(
                          title: 'Custom TFLite (MobileNetV3)',
                          subtitle: useYoloEngine && isCustomTfliteAvailable
                              ? 'Active Custom Model (scrap_model.tflite bundled)'
                              : 'Model not bundled (see ml_pipeline/)',
                          isActive: useYoloEngine && isCustomTfliteAvailable,
                        ),
                        const Divider(height: 16),
                        _engineStatusRow(
                          title: 'Google ML Kit (Offline Fallback)',
                          subtitle: !useYoloEngine
                              ? 'Active primary offline classifier (user selected)'
                              : (isYoloAvailable || isCustomTfliteAvailable
                                  ? 'Standby secondary offline fallback'
                                  : 'Active primary offline classifier'),
                          isActive: !useYoloEngine || (!isYoloAvailable && !isCustomTfliteAvailable),
                        ),
                        const Divider(height: 16),
                        _engineStatusRow(
                          title: 'Confidence Threshold',
                          subtitle: '65% minimum for automated classification',
                          isActive: true,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Scrap Prices Management Card
                Card(
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: Colors.green.shade50,
                                  child: const Icon(
                                    Icons.currency_rupee,
                                    color: Colors.green,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Scrap Prices per kg',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            TextButton.icon(
                              onPressed: _addCustomCategoryDialog,
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Add'),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      ...categories.map((cat) {
                        return ListTile(
                          leading: Icon(cat.iconData, color: Colors.green),
                          title: Text(cat.name),
                          subtitle: cat.description.isNotEmpty
                              ? Text(cat.description, style: const TextStyle(fontSize: 11))
                              : null,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${AppConstants.currency}${cat.ratePerKg.toStringAsFixed(1)} / kg',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                tooltip: 'Edit rate',
                                onPressed: () => _editCategoryRate(cat),
                              ),
                              if (!cat.isDefault)
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      size: 18, color: Colors.red),
                                  tooltip: 'Delete custom category',
                                  onPressed: () async {
                                    await AppDatabase.instance
                                        .deleteCategory(cat.id!);
                                    _loadSettings();
                                  },
                                ),
                            ],
                          ),
                        );
                      }),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _resetDefaultRates,
                              icon: const Icon(Icons.restore_rounded, size: 18),
                              label: const Text('Reset Default Rates'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Version Info
                Card(
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const ListTile(
                    leading: CircleAvatar(
                      child: Icon(Icons.apps_rounded),
                    ),
                    title: Text(
                      'App Version',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('ScrapScan v2.0.0 (Modular SQLite Edition)'),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _engineStatusRow({
    required String title,
    required String subtitle,
    required bool isActive,
  }) {
    return Row(
      children: [
        Icon(
          isActive ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
          color: isActive ? Colors.green.shade700 : Colors.grey,
          size: 20,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
