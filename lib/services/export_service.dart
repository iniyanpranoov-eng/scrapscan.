import 'dart:io';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../core/constants/app_constants.dart';
import '../data/models/scan_record.dart';

class ExportService {
  static final ExportService instance = ExportService._init();

  ExportService._init();

  /// Export scan records to CSV and trigger share sheet
  Future<void> exportToCsv(List<ScanRecord> records) async {
    if (records.isEmpty) {
      throw Exception('No records available to export.');
    }

    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');
    final rows = <List<dynamic>>[
      [
        'ID',
        'Timestamp',
        'Category',
        'Weight (kg)',
        'Rate (INR/kg)',
        'Estimated Value (INR)',
        'Confidence (%)',
        'AI Engine',
        'Lot ID',
      ],
    ];

    for (final r in records) {
      rows.add([
        r.id ?? '',
        dateFormat.format(r.timestamp),
        r.category,
        r.weightKg.toStringAsFixed(2),
        r.rateAtScanTime.toStringAsFixed(2),
        r.estimatedValue.toStringAsFixed(2),
        (r.confidence * 100).toStringAsFixed(1),
        r.aiEngine,
        r.lotId ?? 'Single Scan',
      ]);
    }

    final csvString = const ListToCsvConverter().convert(rows);
    final tempDir = await getTemporaryDirectory();
    final filePath =
        '${tempDir.path}/ScrapScan_Report_${DateTime.now().millisecondsSinceEpoch}.csv';
    final file = File(filePath);
    await file.writeAsString(csvString);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/csv')],
      subject: 'ScrapScan History CSV Report',
      text: 'Exported scrap scan records from ScrapScan.',
    );
  }

  /// Export scan records to PDF and trigger share sheet
  Future<void> exportToPdf(List<ScanRecord> records) async {
    if (records.isEmpty) {
      throw Exception('No records available to export.');
    }

    final pdf = pw.Document();
    final dateFormat = DateFormat('MMM dd, yyyy HH:mm');

    final double totalValue =
        records.fold(0.0, (sum, r) => sum + r.estimatedValue);
    final double totalWeight =
        records.fold(0.0, (sum, r) => sum + r.weightKg);

    // Group by category for summary
    final Map<String, double> categoryWeight = {};
    final Map<String, double> categoryValue = {};

    for (final r in records) {
      categoryWeight[r.category] =
          (categoryWeight[r.category] ?? 0.0) + r.weightKg;
      categoryValue[r.category] =
          (categoryValue[r.category] ?? 0.0) + r.estimatedValue;
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      AppConstants.appName,
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.green800,
                      ),
                    ),
                    pw.Text(
                      AppConstants.tagline,
                      style: const pw.TextStyle(
                        fontSize: 12,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Scan History Report',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      'Generated: ${DateFormat('yyyy-MM-dd').format(DateTime.now())}',
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 18),
            pw.Divider(color: PdfColors.green300, thickness: 1.5),
            pw.SizedBox(height: 12),

            // Summary KPI Cards
            pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.green50,
                      borderRadius: pw.BorderRadius.circular(8),
                      border: pw.Border.all(color: PdfColors.green200),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'TOTAL VALUE',
                          style: const pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.grey700,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'INR ${totalValue.toStringAsFixed(2)}',
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.green900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 12),
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.green50,
                      borderRadius: pw.BorderRadius.circular(8),
                      border: pw.Border.all(color: PdfColors.green200),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'TOTAL WEIGHT',
                          style: const pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.grey700,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          '${totalWeight.toStringAsFixed(2)} kg',
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.green900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 12),
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.green50,
                      borderRadius: pw.BorderRadius.circular(8),
                      border: pw.Border.all(color: PdfColors.green200),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'TOTAL SCANS',
                          style: const pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.grey700,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          '${records.length}',
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.green900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 20),

            // Category Breakdown Table
            pw.Text(
              'Category Breakdown',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: ['Category', 'Weight (kg)', 'Estimated Value (INR)'],
              data: categoryWeight.keys.map((cat) {
                return [
                  cat,
                  (categoryWeight[cat] ?? 0).toStringAsFixed(2),
                  'INR ${(categoryValue[cat] ?? 0).toStringAsFixed(2)}',
                ];
              }).toList(),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.green700),
              rowDecoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
                ),
              ),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            ),
            pw.SizedBox(height: 20),

            // Complete Scan Log Table
            pw.Text(
              'Detailed Scan Log',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: [
                'Date',
                'Category',
                'Weight',
                'Rate',
                'Value',
                'Engine',
              ],
              data: records.map((r) {
                return [
                  dateFormat.format(r.timestamp),
                  r.category,
                  '${r.weightKg.toStringAsFixed(2)} kg',
                  'INR ${r.rateAtScanTime.toStringAsFixed(1)}',
                  'INR ${r.estimatedValue.toStringAsFixed(2)}',
                  r.aiEngine.replaceAll('Google ', ''),
                ];
              }).toList(),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
                fontSize: 9,
              ),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.green800),
              cellStyle: const pw.TextStyle(fontSize: 8),
              rowDecoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
                ),
              ),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            ),
          ];
        },
      ),
    );

    final tempDir = await getTemporaryDirectory();
    final filePath =
        '${tempDir.path}/ScrapScan_Report_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File(filePath);
    await file.writeAsBytes(await pdf.save());

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      subject: 'ScrapScan History PDF Report',
      text: 'ScrapScan 2.0 scan history report.',
    );
  }
}
