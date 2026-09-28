import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aegis/ui/widgets/aegis_logo.dart';

void main() {
  group('AegisLogo Widget Tests', () {
    testWidgets('renders AegisLogo with default properties', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: AegisLogo(),
            ),
          ),
        ),
      );

      expect(find.byType(AegisLogo), findsOneWidget);
    });

    testWidgets('renders AegisLogo with custom size and glow', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: AegisLogo(
                size: 64,
                showGlow: true,
                glowColor: Colors.cyanAccent,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(AegisLogo), findsOneWidget);
      final logoWidget = tester.widget<AegisLogo>(find.byType(AegisLogo));
      expect(logoWidget.size, equals(64));
      expect(logoWidget.showGlow, isTrue);
      expect(logoWidget.glowColor, equals(Colors.cyanAccent));
    });

    testWidgets('renders AegisLogo with custom borderRadius', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AegisLogo(
                size: 48,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(AegisLogo), findsOneWidget);
      expect(find.byType(ClipRRect), findsOneWidget);
    });
  });

  group('Platform Launcher Icons Verification', () {
    test('Flutter bundled asset exists', () {
      expect(File('assets/images/aegis_logo.png').existsSync(), isTrue);
    });

    test('Android launcher mipmaps exist across all densities', () {
      final densities = ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi'];
      for (final density in densities) {
        final file = File('android/app/src/main/res/mipmap-$density/ic_launcher.png');
        expect(file.existsSync(), isTrue, reason: 'Missing Android mipmap-$density/ic_launcher.png');
        expect(file.lengthSync(), greaterThan(100));
      }
    });

    test('iOS app icons exist across required resolutions', () {
      final iosFiles = [
        'Icon-App-20x20@1x.png',
        'Icon-App-20x20@2x.png',
        'Icon-App-20x20@3x.png',
        'Icon-App-29x29@1x.png',
        'Icon-App-29x29@2x.png',
        'Icon-App-29x29@3x.png',
        'Icon-App-40x40@1x.png',
        'Icon-App-40x40@2x.png',
        'Icon-App-40x40@3x.png',
        'Icon-App-60x60@2x.png',
        'Icon-App-60x60@3x.png',
        'Icon-App-76x76@1x.png',
        'Icon-App-76x76@2x.png',
        'Icon-App-83.5x83.5@2x.png',
        'Icon-App-1024x1024@1x.png',
      ];
      for (final name in iosFiles) {
        final file = File('ios/Runner/Assets.xcassets/AppIcon.appiconset/$name');
        expect(file.existsSync(), isTrue, reason: 'Missing iOS icon: $name');
        expect(file.lengthSync(), greaterThan(100));
      }
    });

    test('macOS app icons exist', () {
      final macosFiles = [
        'app_icon_16.png',
        'app_icon_32.png',
        'app_icon_64.png',
        'app_icon_128.png',
        'app_icon_256.png',
        'app_icon_512.png',
        'app_icon_1024.png',
      ];
      for (final name in macosFiles) {
        final file = File('macos/Runner/Assets.xcassets/AppIcon.appiconset/$name');
        expect(file.existsSync(), isTrue, reason: 'Missing macOS icon: $name');
        expect(file.lengthSync(), greaterThan(100));
      }
    });

    test('Web icons and favicon exist', () {
      expect(File('web/favicon.png').existsSync(), isTrue);
      expect(File('web/icons/Icon-192.png').existsSync(), isTrue);
      expect(File('web/icons/Icon-512.png').existsSync(), isTrue);
      expect(File('web/icons/Icon-maskable-192.png').existsSync(), isTrue);
      expect(File('web/icons/Icon-maskable-512.png').existsSync(), isTrue);
    });

    test('Windows app_icon.ico exists', () {
      final file = File('windows/runner/resources/app_icon.ico');
      expect(file.existsSync(), isTrue);
      expect(file.lengthSync(), greaterThan(1000));
    });

    test('Linux runner aegis_logo.png exists', () {
      final file = File('linux/runner/aegis_logo.png');
      expect(file.existsSync(), isTrue);
      expect(file.lengthSync(), greaterThan(1000));
    });
  });
}
