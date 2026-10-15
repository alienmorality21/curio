import 'package:flutter_test/flutter_test.dart';
import 'package:my_first_app/models/fact.dart';
import 'package:my_first_app/storage/fact_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late FactStorage storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = FactStorage(
      databaseFactory: databaseFactoryFfiNoIsolate,
      databasePath: () async => inMemoryDatabasePath,
    );
  });

  tearDown(() => storage.close());

  test(
    'stores complete facts and prevents duplicate feed and bookmark rows',
    () async {
      const fact = Fact(
        id: 'fact-1',
        number: '1',
        title: 'Offline fact',
        description: 'Saved description.',
        pageUrl: 'https://example.com/fact',
        imageUrl: 'https://example.com/image.jpg',
        sourceUrl: 'https://example.com/source',
        category: 'History',
        sourceName: 'Example Source',
        imageCacheKey: 'image-hash',
      );

      await storage.saveCachedFacts([fact, fact]);
      await storage.saveBookmarks([fact, fact]);

      final cached = (await storage.loadCachedFacts()).single;
      final bookmark = (await storage.loadBookmarks()).single;
      expect(cached.description, fact.description);
      expect(cached.imageUrl, fact.imageUrl);
      expect(cached.imageCacheKey, fact.imageCacheKey);
      expect(cached.category, fact.category);
      expect(bookmark.sourceUrl, fact.sourceUrl);
      expect(bookmark.sourceName, fact.sourceName);
    },
  );

  test('migrates old preference records without losing bookmarks', () async {
    SharedPreferences.setMockInitialValues({
      'cached_facts':
          '[{"id":"legacy","title":"Old fact","description":"Kept"}]',
      'bookmarked_facts':
          '[{"id":"legacy","title":"Old fact","description":"Kept"}]',
    });
    storage = FactStorage(
      databaseFactory: databaseFactoryFfiNoIsolate,
      databasePath: () async => inMemoryDatabasePath,
    );

    expect((await storage.loadCachedFacts()).single.title, 'Old fact');
    expect((await storage.loadBookmarks()).single.description, 'Kept');
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.containsKey('bookmarked_facts'), isFalse);
  });

  test('supports saved records without image metadata', () async {
    const fact = Fact(
      id: 'no-image',
      number: '2',
      title: 'Text-only fact',
      description: 'Still safe to open.',
      pageUrl: 'https://example.com/fact',
    );

    await storage.saveBookmarks([fact]);

    final restored = (await storage.loadBookmarks()).single;
    expect(restored.imageUrl, isNull);
    expect(restored.title, fact.title);
  });
}
