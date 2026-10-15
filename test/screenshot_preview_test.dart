import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_first_app/main.dart';
import 'package:my_first_app/repositories/fact_republic_repository.dart';
import 'package:my_first_app/storage/fact_storage.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _previewPage = '''
<div class="td-item">
  <span class="td-sml-current-item-nr">1</span>
  <span class="td-sml-current-item-title">A year on Venus</span>
  <span class="td-sml-description"><p>Venus completes one orbit around the Sun in less time than it takes to rotate once on its axis.</p></span>
  <div class="metabar"><a class="source" href="https://science.nasa.gov/venus/">Source</a></div>
  <div class="shareboard"><a href="https://twitter.com/?url=https%3A%2F%2Ffactrepublic.com%2Ffacts%2F1">Share</a></div>
</div>
<div class="td-item">
  <span class="td-sml-current-item-nr">2</span>
  <span class="td-sml-current-item-title">An octopus has three hearts</span>
  <span class="td-sml-description"><p>Two hearts pump blood to the gills, while a third pumps it to the rest of the body.</p></span>
  <div class="metabar"><a class="source" href="https://oceanservice.noaa.gov/facts/octopus.html">Source</a></div>
  <div class="shareboard"><a href="https://twitter.com/?url=https%3A%2F%2Ffactrepublic.com%2Ffacts%2F2">Share</a></div>
</div>
''';

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    await _loadFlutterFonts();
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => Directory.systemTemp.path,
        );
  });

  testWidgets('captures the Discover screen preview', (tester) async {
    await _setPhoneViewport(tester);
    await _pumpPreview(tester);

    expect(find.text('A year on Venus'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../screenshots/curio-discover.png'),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('captures the Settings screen preview', (tester) async {
    await _setPhoneViewport(tester);
    await _pumpPreview(tester);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Reading'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../screenshots/curio-settings.png'),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}

Future<void> _loadFlutterFonts() async {
  final flutterBin = File(Platform.resolvedExecutable)
      .parent
      .parent
      .parent
      .parent
      .parent;
  final fontsDirectory = path.join(
    flutterBin.path,
    'cache',
    'artifacts',
    'material_fonts',
  );
  for (final font in {
    'Roboto': 'roboto-regular.ttf',
    'MaterialIcons': 'materialicons-regular.otf',
  }.entries) {
    final bytes = await File(path.join(fontsDirectory, font.value))
        .readAsBytes();
    final loader = FontLoader(font.key)
      ..addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
    await loader.load();
  }
}

Future<void> _setPhoneViewport(WidgetTester tester) async {
  tester.view.physicalSize = const Size(420, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpPreview(WidgetTester tester) async {
  await tester.pumpWidget(
    CurioApp(
      repository: FactRepublicRepository(
        client: MockClient((request) async => http.Response(_previewPage, 200)),
      ),
      storage: FactStorage(
        databaseFactory: databaseFactoryFfiNoIsolate,
        databasePath: () async => inMemoryDatabasePath,
      ),
    ),
  );
  await tester.pumpAndSettle();
}
