import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SelectedContent;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_first_app/app_theme.dart';
import 'package:my_first_app/repositories/fact_republic_repository.dart';
import 'package:my_first_app/screens/discover_screen.dart';
import 'package:my_first_app/screens/settings_screen.dart';
import 'package:my_first_app/models/fact.dart';
import 'package:my_first_app/storage/fact_storage.dart';
import 'package:my_first_app/utils/brave_search.dart';
import 'package:my_first_app/widgets/zoomable_fact_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _generatorPage = '''
<div class="td-item">
  <span class="td-sml-current-item-nr">1</span>
  <span class="td-sml-current-item-title">First swipe fact</span>
  <span class="td-sml-description"><p>The first fact description.</p></span>
  <div class="shareboard"><a href="https://twitter.com/?url=http%3A%2F%2Ffactrepublic.com%2Ffacts%2F1">Share</a></div>
</div>
<div class="td-item">
  <span class="td-sml-current-item-nr">2</span>
  <span class="td-sml-current-item-title">Second swipe fact</span>
  <span class="td-sml-description"><p>The second fact description.</p></span>
  <div class="shareboard"><a href="https://twitter.com/?url=http%3A%2F%2Ffactrepublic.com%2Ffacts%2F2">Share</a></div>
</div>
''';

const _nextGeneratorPage = '''
<div class="td-item">
  <span class="td-sml-current-item-nr">2</span>
  <span class="td-sml-current-item-title">Second swipe fact</span>
  <span class="td-sml-description"><p>The second fact description.</p></span>
  <div class="shareboard"><a href="https://twitter.com/?url=http%3A%2F%2Ffactrepublic.com%2Ffacts%2F2">Share</a></div>
</div>
<div class="td-item">
  <span class="td-sml-current-item-nr">3</span>
  <span class="td-sml-current-item-title">Third swipe fact</span>
  <span class="td-sml-description"><p>The third fact description.</p></span>
  <div class="shareboard"><a href="https://twitter.com/?url=http%3A%2F%2Ffactrepublic.com%2Ffacts%2F3">Share</a></div>
</div>
''';

void main() {
  setUpAll(sqfliteFfiInit);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  FactStorage testStorage() => FactStorage(
    databaseFactory: databaseFactoryFfiNoIsolate,
    databasePath: () async => inMemoryDatabasePath,
  );

  test('builds a safely encoded Google Search URL', () {
    final uri = googleSearchUri('  Curio & facts? #selection  ');

    expect(uri.scheme, 'https');
    expect(uri.host, 'www.google.com');
    expect(uri.path, '/search');
    expect(uri.queryParameters['q'], 'Curio & facts? #selection');
  });

  testWidgets('search uses selected text or the whole fact when unselected', (
    tester,
  ) async {
    final repository = FactRepublicRepository(
      client: MockClient((request) async => http.Response(_generatorPage, 200)),
    );
    final queries = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: DiscoverScreen(
          repository: repository,
          storage: testStorage(),
          searchLauncher: (query) async => queries.add(query),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final descriptionArea = tester.widget<SelectionArea>(
      find.byType(SelectionArea).last,
    );
    descriptionArea.onSelectionChanged!(
      const SelectedContent(plainText: 'selected text'),
    );
    await tester.pump();
    await tester.tap(find.text('Search with Google'));
    await tester.pumpAndSettle();
    expect(queries, ['selected text']);

    descriptionArea.onSelectionChanged!(null);
    await tester.pump();
    await tester.tap(find.text('Search with Google'));
    await tester.pumpAndSettle();
    expect(queries.last, 'First swipe fact\nThe first fact description.');
  });

  testWidgets('shows one fact per screen and swipes up to the next', (
    tester,
  ) async {
    var requests = 0;
    final repository = FactRepublicRepository(
      client: MockClient((request) async {
        requests++;
        return http.Response(
          requests == 1 ? _generatorPage : _nextGeneratorPage,
          200,
        );
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: DiscoverScreen(repository: repository, storage: testStorage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('First swipe fact'), findsOneWidget);
    expect(find.text('Source'), findsOneWidget);
    expect(find.text('Search with Google'), findsOneWidget);
    expect(find.textContaining('Share'), findsNothing);
    expect(find.text('1 / 2'), findsNothing);
    final descriptionBottom = tester
        .getRect(find.text('The first fact description.'))
        .bottom;
    final sourceTop = tester.getRect(find.text('Source')).top;
    expect(sourceTop - descriptionBottom, lessThan(50));
    expect(find.byType(ZoomableFactImage), findsOneWidget);

    await tester.tap(find.byTooltip('Hide source and search actions'));
    await tester.pumpAndSettle();
    expect(find.text('Source'), findsNothing);
    expect(find.byTooltip('Show source and search actions'), findsOneWidget);
    await tester.tap(find.byTooltip('Show source and search actions'));
    await tester.pumpAndSettle();
    expect(find.text('Source'), findsOneWidget);

    await tester.tap(find.byTooltip('Hide image'));
    await tester.pumpAndSettle();
    expect(find.text('Show image'), findsOneWidget);
    await tester.tap(find.text('Show image'));
    await tester.pumpAndSettle();
    expect(find.byType(ZoomableFactImage), findsOneWidget);

    await tester.drag(find.byType(ZoomableFactImage), const Offset(0, -300));
    await tester.pumpAndSettle();

    expect(find.text('Second swipe fact'), findsOneWidget);
    expect(find.text('2 / 2'), findsNothing);
    expect(requests, 2);

    await tester.drag(find.byType(ZoomableFactImage), const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(find.text('First swipe fact'), findsOneWidget);

    await tester.drag(find.byType(ZoomableFactImage), const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ZoomableFactImage), const Offset(0, -300));
    await tester.pumpAndSettle();

    expect(find.text('Third swipe fact'), findsOneWidget);
    expect(requests, 3);
    expect(find.text('No new facts right now.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('vertical page swipes navigate forward and backward', (
    tester,
  ) async {
    final repository = FactRepublicRepository(
      client: MockClient((request) async => http.Response(_generatorPage, 200)),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: DiscoverScreen(repository: repository, storage: testStorage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(PageView), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(find.text('Second swipe fact'), findsOneWidget);

    await tester.drag(find.byType(PageView), const Offset(0, 400));
    await tester.pumpAndSettle();
    expect(find.text('First swipe fact'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long fact text is not truncated and can scroll in its page', (
    tester,
  ) async {
    final longDescription = List.filled(
      70,
      'This is the full text of a longer fact.',
    ).join(' ');
    final htmlPage =
        '''
<div class="td-item">
  <span class="td-sml-current-item-nr">1</span>
  <span class="td-sml-current-item-title">A longer fact</span>
  <span class="td-sml-description"><p>$longDescription</p></span>
  <div class="shareboard"><a href="https://twitter.com/?url=http%3A%2F%2Ffactrepublic.com%2Ffacts%2F99">Share</a></div>
</div>
<div class="td-item">
  <span class="td-sml-current-item-nr">2</span>
  <span class="td-sml-current-item-title">Next fact</span>
  <span class="td-sml-description"><p>A shorter fact.</p></span>
</div>
''';
    final repository = FactRepublicRepository(
      client: MockClient((request) async => http.Response(htmlPage, 200)),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: DiscoverScreen(repository: repository, storage: testStorage()),
      ),
    );
    await tester.pumpAndSettle();

    final description = tester.widget<Text>(find.text(longDescription));
    expect(description.maxLines, isNull);
    expect(description.overflow, isNull);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(find.text('Scroll text · swipe image to navigate'), findsOneWidget);
    expect(tester.getRect(find.text('Source')).top, greaterThan(0));
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('refresh control fetches the generator page again', (
    tester,
  ) async {
    var requests = 0;
    final repository = FactRepublicRepository(
      client: MockClient((request) async {
        requests++;
        return http.Response(_generatorPage, 200);
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: DiscoverScreen(repository: repository, storage: testStorage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(requests, 1);

    await tester.tap(find.byTooltip('Refresh facts from Fact Republic'));
    await tester.pumpAndSettle();

    expect(requests, 2);
    expect(find.byType(PageView), findsOneWidget);
  });

  testWidgets('saved facts are persisted locally for offline reading', (
    tester,
  ) async {
    final storage = testStorage();
    final repository = FactRepublicRepository(
      client: MockClient((request) async => http.Response(_generatorPage, 200)),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: DiscoverScreen(repository: repository, storage: storage),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Save fact for offline reading'));
    await tester.pumpAndSettle();

    final bookmarks = await storage.loadBookmarks();
    expect(bookmarks.single.title, 'First swipe fact');
    expect(find.text('Saved offline.'), findsOneWidget);
  });

  testWidgets('keeps saved content visible when refresh loses connectivity', (
    tester,
  ) async {
    var requests = 0;
    final repository = FactRepublicRepository(
      client: MockClient((request) async {
        requests++;
        if (requests == 1) return http.Response(_generatorPage, 200);
        throw http.ClientException('offline');
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: DiscoverScreen(repository: repository, storage: testStorage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Refresh facts from Fact Republic'));
    await tester.pumpAndSettle();

    expect(find.text('First swipe fact'), findsOneWidget);
    expect(find.textContaining('Showing saved facts.'), findsOneWidget);
  });

  testWidgets('restores cached facts before an offline request fails', (
    tester,
  ) async {
    const cachedFact = Fact(
      id: 'offline-1',
      number: '1',
      title: 'Previously loaded fact',
      description: 'This fact is available without a connection.',
      pageUrl: 'https://example.com/fact',
    );
    SharedPreferences.setMockInitialValues({
      'cached_facts': jsonEncode([cachedFact.toJson()]),
    });
    final repository = FactRepublicRepository(
      client: MockClient((request) async {
        throw http.ClientException('offline');
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DiscoverScreen(repository: repository, storage: testStorage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Previously loaded fact'), findsOneWidget);
    expect(find.textContaining('Showing saved facts.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long fact and actions fit a narrow phone with larger text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 680);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final longDescription = List.filled(
      60,
      'Full fact text remains readable when the phone has a narrow display.',
    ).join(' ');
    final page =
        '''
<div class="td-item">
  <span class="td-sml-current-item-nr">1</span>
  <span class="td-sml-current-item-title">A responsive fact</span>
  <span class="td-sml-description"><p>$longDescription</p></span>
</div>
''';
    final repository = FactRepublicRepository(
      client: MockClient((request) async => http.Response(page, 200)),
    );

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.4)),
          child: child!,
        ),
        home: DiscoverScreen(repository: repository, storage: testStorage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Source'), findsOneWidget);
    expect(find.text('Search with Google'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('saved fact opens its full image and complete detail screen', (
    tester,
  ) async {
    const description =
        'The full saved fact description remains available offline, including '
        'all of its supporting details and source information.';
    const fact = Fact(
      id: 'saved-detail',
      number: '7',
      title: 'A saved fact with an image',
      description: description,
      pageUrl: 'https://example.com/fact',
      imageUrl: 'https://example.com/fact-image.png',
      sourceUrl: 'https://example.com/source',
      sourceName: 'Example source',
      category: 'Culture',
      imageCacheKey: 'saved-image-key',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          themePreference: CurioThemePreference.system,
          onThemeChanged: (_) async {},
          bookmarks: const [fact],
          onRemoveBookmark: (_) {},
        ),
      ),
    );

    await tester.scrollUntilVisible(
      find.text(fact.title),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text(fact.title));
    await tester.pumpAndSettle();

    expect(find.text('Saved fact'), findsOneWidget);
    expect(find.text(description), findsOneWidget);
    expect(find.text('Source: Example source'), findsOneWidget);
    expect(find.text('Search with Google'), findsOneWidget);
    expect(find.byType(SelectionArea), findsNWidgets(2));
    expect(find.textContaining('Share'), findsNothing);
    expect(find.byType(ZoomableFactImage), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byTooltip('Hide source and search actions'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byTooltip('Hide source and search actions'));
    await tester.pumpAndSettle();
    expect(find.text('Source'), findsNothing);
    await tester.tap(find.byTooltip('Show source and search actions'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byTooltip('Hide image'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byTooltip('Hide image'));
    await tester.pumpAndSettle();
    expect(find.text('Show image'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
