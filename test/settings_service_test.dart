import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scrap_scan/services/settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SettingsService Engine Preference Tests', () {
    test('Default useYoloEngine is true', () async {
      final service = SettingsService.instance;
      // Re-init with mock values
      SharedPreferences.setMockInitialValues({});
      await service.init();
      final pref = await service.getUseYoloEngine();
      expect(pref, isTrue);
    });

    test('Can toggle useYoloEngine to false and back to true', () async {
      final service = SettingsService.instance;
      await service.setUseYoloEngine(false);
      expect(await service.getUseYoloEngine(), isFalse);

      await service.setUseYoloEngine(true);
      expect(await service.getUseYoloEngine(), isTrue);
    });
  });
}
