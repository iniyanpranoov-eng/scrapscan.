import 'package:flutter/material.dart';
import '../../data/database/app_database.dart';
import '../../data/models/scan_record.dart';
import '../../services/export_service.dart';
import '../widgets/scan_history_card.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<ScanRecord> allScans = [];
  List<ScanRecord> filteredScans = [];
  bool isLoading = true;
  String selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => isLoading = true);
    // Ensure any legacy v1.0.0 records are migrated
    await AppDatabase.instance.migrateV1HistoryIfNeeded();

    final scans = await AppDatabase.instance.getAllScans();

    if (!mounted) return;
    setState(() {
      allScans = scans;
      _applyFilter(selectedFilter);
      isLoading = false;
    });
  }

  void _applyFilter(String filter) {
    setState(() {
      selectedFilter = filter;
      if (filter == 'All') {
        filteredScans = List.from(allScans);
      } else {
        filteredScans =
            allScans.where((s) => s.category.contains(filter)).toList();
      }
    });
  }

  Future<void> _deleteScan(int id) async {
    await AppDatabase.instance.deleteScan(id);
    await _loadHistory();
  }

  Future<void> _clearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All History?'),
        content: const Text(
          'This will permanently remove all saved scrap scans from your offline database.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await AppDatabase.instance.clearAllScans();
      await _loadHistory();
    }
  }

  Future<void> _exportCsv() async {
    try {
      await ExportService.instance.exportToCsv(allScans);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _exportPdf() async {
    try {
      await ExportService.instance.exportToPdf(allScans);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
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
          'Scan History',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (allScans.isNotEmpty) ...[
            PopupMenuButton<String>(
              icon: const Icon(Icons.share_outlined),
              tooltip: 'Export Report',
              onSelected: (value) {
                if (value == 'csv') _exportCsv();
                if (value == 'pdf') _exportPdf();
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'csv',
                  child: Row(
                    children: [
                      Icon(Icons.table_chart_outlined, color: Colors.green),
                      SizedBox(width: 10),
                      Text('Export as CSV'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'pdf',
                  child: Row(
                    children: [
                      Icon(Icons.picture_as_pdf_outlined, color: Colors.red),
                      SizedBox(width: 10),
                      Text('Export as PDF Report'),
                    ],
                  ),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: 'Clear History',
              onPressed: _clearAll,
            ),
          ],
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : allScans.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.history_rounded,
                        size: 80,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No scan history yet',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your saved scans and scrap lots will appear here.',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Filter Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          'All',
                          'Plastic',
                          'Aluminum',
                          'Paper',
                          'Iron',
                          'Copper',
                          'E-Waste',
                          'Glass',
                        ].map((filter) {
                          final isSelected = selectedFilter == filter;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(filter),
                              selected: isSelected,
                              onSelected: (_) => _applyFilter(filter),
                              selectedColor: Colors.green.shade100,
                              checkmarkColor: Colors.green.shade800,
                              labelStyle: TextStyle(
                                color: isSelected
                                    ? Colors.green.shade900
                                    : Colors.black87,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    // Total Count & Quick Actions
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 4,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Showing ${filteredScans.length} of ${allScans.length} scans',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          Row(
                            children: [
                              TextButton.icon(
                                onPressed: _exportCsv,
                                icon: const Icon(Icons.file_download_outlined,
                                    size: 16),
                                label: const Text('CSV',
                                    style: TextStyle(fontSize: 12)),
                              ),
                              TextButton.icon(
                                onPressed: _exportPdf,
                                icon: const Icon(Icons.picture_as_pdf_outlined,
                                    size: 16),
                                label: const Text('PDF',
                                    style: TextStyle(fontSize: 12)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Scans List
                    Expanded(
                      child: ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredScans.length,
                        itemBuilder: (context, index) {
                          final record = filteredScans[index];
                          return ScanHistoryCard(
                            record: record,
                            onDelete: () => _deleteScan(record.id!),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}
