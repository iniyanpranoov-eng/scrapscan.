import 'package:flutter/foundation.dart';
import '../data/database/app_database.dart';
import '../data/models/scrap_lot_item.dart';

class ScrapLotService extends ChangeNotifier {
  static final ScrapLotService instance = ScrapLotService._init();

  ScrapLotService._init();

  final List<ScrapLotItem> _items = [];

  List<ScrapLotItem> get items => List.unmodifiable(_items);

  int get itemCount => _items.length;
  bool get isEmpty => _items.isEmpty;

  double get totalWeight =>
      _items.fold(0.0, (sum, item) => sum + item.weightKg);

  double get totalValue =>
      _items.fold(0.0, (sum, item) => sum + item.estimatedValue);

  void addItem(ScrapLotItem item) {
    _items.add(item);
    notifyListeners();
  }

  void removeItem(String id) {
    _items.removeWhere((item) => item.id == id);
    notifyListeners();
  }

  void updateItemWeight(String id, double weight) {
    final index = _items.indexWhere((item) => item.id == id);
    if (index != -1) {
      _items[index].weightKg = weight;
      notifyListeners();
    }
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }

  /// Commits all lot items into SQLite database under a shared lot session ID
  Future<List<int>> commitLot(AppDatabase database) async {
    if (_items.isEmpty) return [];

    final lotId = 'LOT_${DateTime.now().millisecondsSinceEpoch}';
    final records = _items.map((item) => item.toScanRecord(lotId: lotId)).toList();

    final ids = await database.insertLotScans(records);
    clear();
    return ids;
  }
}
