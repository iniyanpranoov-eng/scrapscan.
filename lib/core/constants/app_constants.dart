import 'default_categories.dart';

class AppConstants {
  static const String appName = 'ScrapScan';
  static const String appVersion = '2.0.0';
  static const String tagline = 'Recycle smarter';
  static const String currency = '₹';
  static const double confidenceThreshold = 0.65; // 65% minimum threshold for automated scrap classification

  // Default Categories & Rates (₹ per kg)
  static const List<Map<String, dynamic>> defaultCategories = DefaultCategories.list;
}
