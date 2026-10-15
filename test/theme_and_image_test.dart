import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_first_app/app_theme.dart';
import 'package:my_first_app/main.dart';
import 'package:my_first_app/repositories/fact_republic_repository.dart';
import 'package:my_first_app/screens/settings_screen.dart';
import 'package:my_first_app/storage/fact_storage.dart';
import 'package:my_first_app/widgets/fact_image.dart';
import 'package:my_first_app/widgets/zoomable_fact_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  FactStorage testStorage() => FactStorage(
    databaseFactory: databaseFactoryFfiNoIsolate,
    databasePath: () async => inMemoryDatabasePath,
  );

  test(
    'image height adapts to landscape, square, and portrait aspect ratios',
    () {
      final landscape = factImageDisplayHeight(
        width: 320,
        aspectRatio: 1.8,
        maxHeight: 300,
      );
      final square = factImageDisplayHeight(
        width: 320,
        aspectRatio: 1,
        maxHeight: 300,
      );
      final portrait = factImageDisplayHeight(
        width: 320,
        aspectRatio: 0.6,
        maxHeight: 260,
      );

      expect(landscape, closeTo(320 / 1.8, 0.1));
      expect(square, 300);
      expect(portrait, 260);
    },
  );

  test('all theme definitions provide readable contrasting surfaces', () {
    final light = curioTheme(Brightness.light);
    final dark = curioTheme(Brightness.dark);
    final oled = curioTheme(Brightness.dark, oled: true);

    expect(light.useMaterial3, isTrue);
    expect(light.scaffoldBackgroundColor, const Color(0xFFF8F9F6));
    expect(dark.scaffoldBackgroundColor, const Color(0xFF151A18));
    expect(oled.scaffoldBackgroundColor, Colors.black);
    expect(dark.colorScheme.primary, const Color(0xFF86D7BC));
    expect(oled.colorScheme.onSurface, isNot(Colors.black));
    expect(themeModeFor(CurioThemePreference.system), ThemeMode.system);
    expect(themeModeFor(CurioThemePreference.oled), ThemeMode.dark);
  });

  testWidgets(
    'theme selector updates and image placeholder remains available',
    (tester) async {
      CurioThemePreference? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: SettingsScreen(
            themePreference: CurioThemePreference.system,
            onThemeChanged: (preference) async {
              selected = preference;
            },
            bookmarks: const [],
            onRemoveBookmark: (_) {},
          ),
        ),
      );

      await tester.tap(find.text('OLED black'));
      await tester.pumpAndSettle();
      expect(selected, CurioThemePreference.oled);

      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: FactImage(imageUrl: null))),
      );
      expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('reading controls change text size and line spacing', (
    tester,
  ) async {
    var selectedTextScale = 1.0;
    var selectedLineSpacing = 1.4;
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          themePreference: CurioThemePreference.system,
          onThemeChanged: (_) async {},
          bookmarks: const [],
          onRemoveBookmark: (_) {},
          onReadingSettingsChanged: (textScale, lineSpacing) async {
            selectedTextScale = textScale;
            selectedLineSpacing = lineSpacing;
          },
        ),
      ),
    );

    final textSlider = tester.widget<Slider>(find.byType(Slider).at(0));
    textSlider.onChanged!(1.2);
    await tester.pump();
    textSlider.onChangeEnd!(1.2);
    await tester.pumpAndSettle();
    final spacingSlider = tester.widget<Slider>(find.byType(Slider).at(1));
    spacingSlider.onChanged!(1.6);
    await tester.pump();
    spacingSlider.onChangeEnd!(1.6);
    await tester.pumpAndSettle();

    expect(selectedTextScale, greaterThan(1));
    expect(selectedLineSpacing, greaterThan(1.4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('image failures retain a themed placeholder without an error', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FactImage(imageUrl: 'http://127.0.0.1:1/unavailable-image.png'),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));

    expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fact images open a pinch-zoom full-screen viewer', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: ZoomableFactImage(
              imageUrl: 'https://example.com/missing.png',
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(ZoomableFactImage));
    await tester.pumpAndSettle();

    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.text('Image'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('OLED selection is persisted and restored on app restart', (
    tester,
  ) async {
    const page = '''
<div class="td-item">
  <span class="td-sml-current-item-nr">1</span>
  <span class="td-sml-current-item-title">Theme fact</span>
  <span class="td-sml-description"><p>Theme test fact.</p></span>
</div>
''';
    FactRepublicRepository repository() => FactRepublicRepository(
      client: MockClient((request) async => http.Response(page, 200)),
    );

    await tester.pumpWidget(
      CurioApp(repository: repository(), storage: testStorage()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OLED black'));
    await tester.pumpAndSettle();
    final textSlider = tester.widget<Slider>(find.byType(Slider).at(0));
    textSlider.onChanged!(1.2);
    await tester.pump();
    textSlider.onChangeEnd!(1.2);
    await tester.pumpAndSettle();

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('theme_preference'), 'oled');
    expect(preferences.getDouble('fact_text_scale'), 1.2);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      CurioApp(repository: repository(), storage: testStorage()),
    );
    await tester.pumpAndSettle();
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
    expect(app.darkTheme!.scaffoldBackgroundColor, Colors.black);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(tester.widget<Slider>(find.byType(Slider).first).value, 1.2);
    expect(tester.takeException(), isNull);
  });
}
