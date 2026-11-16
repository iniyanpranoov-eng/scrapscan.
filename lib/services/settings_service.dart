import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService extends ChangeNotifier {
  static final SettingsService instance = SettingsService._init();

  SettingsService._init();

  static const String _keyUseYoloEngine = 'use_yolo_engine';
  bool _useYoloEngine = true;
  bool _isInitialized = false;

  bool get useYoloEngine => _useYoloEngine;

  Future<void> init() async {
    if (_isInitialized) return;
    final prefs = await SharedPreferences.getInstance();
    _useYoloEngine = prefs.getBool(_keyUseYoloEngine) ?? true;
    _isInitialized = true;
  }

  Future<bool> getUseYoloEngine() async {
    if (!_isInitialized) {
      await init();
    }
    return _useYoloEngine;
  }

  Future<void> setUseYoloEngine(bool value) async {
    _useYoloEngine = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyUseYoloEngine, value);
    notifyListeners();
  }
}
