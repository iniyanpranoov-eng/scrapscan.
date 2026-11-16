import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/scrap_category.dart';

class UncertainMaterialSheet extends StatelessWidget {
  final List<ScrapCategory> categories;
  final String? initialSelection;
  final ValueChanged<ScrapCategory> onCategorySelected;

  const UncertainMaterialSheet({
    super.key,
    required this.categories,
    this.initialSelection,
    required this.onCategorySelected,
  });

  static Future<ScrapCategory?> show(
    BuildContext context, {
    required List<ScrapCategory> categories,
    String? initialSelection,
  }) {
    return showModalBottomSheet<ScrapCategory>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => UncertainMaterialSheet(
        categories: categories,
        initialSelection: initialSelection,
        onCategorySelected: (cat) => Navigator.pop(context, cat),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.amber,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Material Category',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'AI confidence was below 65%. Verify or choose the right scrap type:',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.55,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: categories.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final cat = categories[index];
                  final isSelected = cat.name == initialSelection;

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: Colors.green.shade50,
                      child: Icon(cat.iconData, color: Colors.green.shade700),
                    ),
                    title: Text(
                      cat.name,
                      style: TextStyle(
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? Colors.green.shade800 : Colors.black87,
                      ),
                    ),
                    subtitle: Text(
                      cat.description.isNotEmpty ? cat.description : 'Standard scrap rate',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: Text(
                      '${AppConstants.currency}${cat.ratePerKg.toStringAsFixed(1)}/kg',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.green.shade700,
                      ),
                    ),
                    onTap: () => onCategorySelected(cat),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
