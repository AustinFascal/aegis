import 'package:flutter_test/flutter_test.dart';
import 'package:aegis/core/constants/app_version.dart';

void main() {
  group('AppVersion Tests', () {
    test('AppVersion defaults gracefully when uninitialized', () {
      expect(AppVersion.formatted, startsWith('v'));
      expect(AppVersion.rawVersion, isNotEmpty);
      expect(AppVersion.rawVersion.startsWith('v'), isFalse);
    });

    test('AppVersion handles fallback initialization in test environment', () async {
      await AppVersion.init();
      expect(AppVersion.formatted, isNotEmpty);
      expect(AppVersion.formatted.startsWith('v'), isTrue);
      expect(AppVersion.buildNumber, isNotEmpty);
    });
  });
}
