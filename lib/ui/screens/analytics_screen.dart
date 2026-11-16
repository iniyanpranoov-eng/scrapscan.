import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_constants.dart';
import '../../data/database/app_database.dart';
import '../../data/models/scan_record.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  bool isLoading = true;
  List<ScanRecord> scans = [];

  // View state
  bool isDaily = true; // true = Daily (7 days), false = Monthly (6 months)
  bool isValueMetric = true; // true = Value (₹), false = Weight (kg)

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    final data = await AppDatabase.instance.getAllScans();
    if (!mounted) return;
    setState(() {
      scans = data;
      isLoading = false;
    });
  }

  // ======================================================
  // DATA AGGREGATION
  // ======================================================

  List<_DataPoint> _getDailyData() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final result = <_DataPoint>[];

    for (int i = 6; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      final nextDate = date.add(const Duration(days: 1));
      final label = DateFormat('E').format(date); // Mon, Tue...

      double val = 0.0;
      for (final s in scans) {
        if (s.timestamp.isAfter(date) && s.timestamp.isBefore(nextDate)) {
          val += isValueMetric ? s.estimatedValue : s.weightKg;
        }
      }
      result.add(_DataPoint(label: label, value: val));
    }
    return result;
  }

  List<_DataPoint> _getMonthlyData() {
    final now = DateTime.now();
    final result = <_DataPoint>[];

    for (int i = 5; i >= 0; i--) {
      final monthDate = DateTime(now.year, now.month - i, 1);
      final nextMonth = DateTime(now.year, now.month - i + 1, 1);
      final label = DateFormat('MMM').format(monthDate); // Jan, Feb...

      double val = 0.0;
      for (final s in scans) {
        if (s.timestamp.isAfter(monthDate) && s.timestamp.isBefore(nextMonth)) {
          val += isValueMetric ? s.estimatedValue : s.weightKg;
        }
      }
      result.add(_DataPoint(label: label, value: val));
    }
    return result;
  }

  Map<String, double> _getCategoryBreakdown() {
    final map = <String, double>{};
    for (final s in scans) {
      final key = s.category;
      final val = isValueMetric ? s.estimatedValue : s.weightKg;
      map[key] = (map[key] ?? 0.0) + val;
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final totalValue = scans.fold(0.0, (sum, s) => sum + s.estimatedValue);
    final totalWeight = scans.fold(0.0, (sum, s) => sum + s.weightKg);
    final avgRate = totalWeight > 0 ? (totalValue / totalWeight) : 0.0;

    final chartData = isDaily ? _getDailyData() : _getMonthlyData();
    final maxVal = chartData.fold(0.0, (max, d) => d.value > max ? d.value : max);
    final maxY = maxVal > 0 ? maxVal * 1.25 : 10.0;

    final categoryMap = _getCategoryBreakdown();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F8F5),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Scrap Analytics',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // KPI Overview Grid
                  Row(
                    children: [
                      Expanded(
                        child: _kpiCard(
                          title: 'Total Earnings',
                          value: '${AppConstants.currency}${totalValue.toStringAsFixed(1)}',
                          icon: Icons.savings_rounded,
                          color: Colors.green.shade700,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _kpiCard(
                          title: 'Total Weight',
                          value: '${totalWeight.toStringAsFixed(1)} kg',
                          icon: Icons.scale_rounded,
                          color: Colors.teal.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _kpiCard(
                          title: 'Avg Scrap Rate',
                          value: '${AppConstants.currency}${avgRate.toStringAsFixed(1)}/kg',
                          icon: Icons.trending_up_rounded,
                          color: Colors.blue.shade700,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _kpiCard(
                          title: 'Total Scans',
                          value: '${scans.length}',
                          icon: Icons.document_scanner_rounded,
                          color: Colors.deepOrange.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Period & Metric Toggle
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Daily / Monthly Segment
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.green.shade100),
                        ),
                        child: Row(
                          children: [
                            _toggleButton(
                              label: 'Daily (7D)',
                              isSelected: isDaily,
                              onTap: () => setState(() => isDaily = true),
                            ),
                            _toggleButton(
                              label: 'Monthly (6M)',
                              isSelected: !isDaily,
                              onTap: () => setState(() => isDaily = false),
                            ),
                          ],
                        ),
                      ),

                      // Value / Weight Toggle
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.green.shade100),
                        ),
                        child: Row(
                          children: [
                            _toggleButton(
                              label: 'Value (${AppConstants.currency})',
                              isSelected: isValueMetric,
                              onTap: () => setState(() => isValueMetric = true),
                            ),
                            _toggleButton(
                              label: 'Weight (kg)',
                              isSelected: !isValueMetric,
                              onTap: () => setState(() => isValueMetric = false),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Chart Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isDaily
                              ? 'Daily ${isValueMetric ? 'Value Trend' : 'Weight Trend'} (Last 7 Days)'
                              : 'Monthly ${isValueMetric ? 'Value Trend' : 'Weight Trend'} (Last 6 Months)',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          isValueMetric
                              ? 'Total payout value per period'
                              : 'Total scrap weight in kilograms',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                        ),
                        const SizedBox(height: 24),

                        // Bar Chart Widget
                        SizedBox(
                          height: 220,
                          child: BarChart(
                            BarChartData(
                              alignment: BarChartAlignment.spaceAround,
                              maxY: maxY,
                              barTouchData: BarTouchData(
                                enabled: true,
                                touchTooltipData: BarTouchTooltipData(
                                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                    final label = chartData[group.x.toInt()].label;
                                    final val = rod.toY;
                                    return BarTooltipItem(
                                      '$label\n${isValueMetric ? AppConstants.currency : ''}${val.toStringAsFixed(1)}${!isValueMetric ? ' kg' : ''}',
                                      const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    );
                                  },
                                ),
                              ),
                              titlesData: FlTitlesData(
                                show: true,
                                topTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                rightTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 38,
                                    getTitlesWidget: (value, meta) {
                                      if (value == 0) return const Text('0', style: TextStyle(fontSize: 10));
                                      if (value == meta.max) return const SizedBox.shrink();
                                      return Text(
                                        value >= 1000
                                            ? '${(value / 1000).toStringAsFixed(1)}k'
                                            : value.toStringAsFixed(0),
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey.shade600,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 28,
                                    getTitlesWidget: (value, meta) {
                                      final index = value.toInt();
                                      if (index >= 0 && index < chartData.length) {
                                        return Padding(
                                          padding: const EdgeInsets.only(top: 8),
                                          child: Text(
                                            chartData[index].label,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                        );
                                      }
                                      return const SizedBox.shrink();
                                    },
                                  ),
                                ),
                              ),
                              gridData: FlGridData(
                                show: true,
                                drawVerticalLine: false,
                                horizontalInterval: maxY > 0 ? (maxY / 4) : 1,
                                getDrawingHorizontalLine: (value) => FlLine(
                                  color: Colors.grey.shade200,
                                  strokeWidth: 1,
                                ),
                              ),
                              borderData: FlBorderData(show: false),
                              barGroups: List.generate(chartData.length, (i) {
                                return BarChartGroupData(
                                  x: i,
                                  barRods: [
                                    BarChartRodData(
                                      toY: chartData[i].value,
                                      color: isValueMetric
                                          ? Colors.green.shade600
                                          : Colors.teal.shade600,
                                      width: 18,
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(6),
                                      ),
                                    ),
                                  ],
                                );
                              }),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Category Breakdown
                  const Text(
                    'Material Composition',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ...categoryMap.entries.map((e) {
                    final total = isValueMetric ? totalValue : totalWeight;
                    final pct = total > 0 ? (e.value / total) * 100 : 0.0;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                e.key,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '${isValueMetric ? AppConstants.currency : ''}${e.value.toStringAsFixed(1)}${!isValueMetric ? ' kg' : ''} (${pct.toStringAsFixed(1)}%)',
                                style: TextStyle(
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: total > 0 ? (e.value / total).clamp(0.0, 1.0) : 0.0,
                            backgroundColor: Colors.green.shade50,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.green.shade600,
                            ),
                            minHeight: 6,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
    );
  }

  Widget _kpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _toggleButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.green.shade700 : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }
}

class _DataPoint {
  final String label;
  final double value;

  _DataPoint({required this.label, required this.value});
}
