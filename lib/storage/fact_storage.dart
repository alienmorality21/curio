import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart' as sqlite;

import '../models/fact.dart';

class FactStorage {
  FactStorage({
    sqlite.DatabaseFactory? databaseFactory,
    Future<String> Function()? databasePath,
  }) : _databaseFactory = databaseFactory ?? sqlite.databaseFactory,
       _databasePath = databasePath ?? _defaultDatabasePath;

  static const _databaseName = 'curio_content.db';
  static const _cachedFactsKey = 'cached_facts';
  static const _bookmarkedFactsKey = 'bookmarked_facts';

  final sqlite.DatabaseFactory _databaseFactory;
  final Future<String> Function() _databasePath;
  Future<sqlite.Database>? _databaseFuture;

  Future<sqlite.Database> get _database => _databaseFuture ??= _openDatabase();

  Future<sqlite.Database> _openDatabase() async {
    final databasePath = await _databasePath();
    final database = await _databaseFactory.openDatabase(
      databasePath,
      options: sqlite.OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE facts (
              id TEXT PRIMARY KEY,
              data TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE feed_facts (
              fact_id TEXT PRIMARY KEY REFERENCES facts(id) ON DELETE CASCADE,
              position INTEGER NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE bookmarks (
              fact_id TEXT PRIMARY KEY REFERENCES facts(id) ON DELETE CASCADE,
              position INTEGER NOT NULL
            )
          ''');
          await db.execute(
            'CREATE INDEX feed_facts_position ON feed_facts(position)',
          );
          await db.execute(
            'CREATE INDEX bookmarks_position ON bookmarks(position)',
          );
        },
      ),
    );
    await _migratePreferences(database);
    return database;
  }

  static Future<String> _defaultDatabasePath() async =>
      path.join(await sqlite.getDatabasesPath(), _databaseName);

  Future<void> _migratePreferences(sqlite.Database database) async {
    final preferences = await SharedPreferences.getInstance();
    final oldFeed = preferences.getString(_cachedFactsKey);
    final oldBookmarks = preferences.getString(_bookmarkedFactsKey);
    if (oldFeed == null && oldBookmarks == null) return;

    try {
      final feed = oldFeed == null ? const <Fact>[] : _decodeFacts(oldFeed);
      final bookmarks = oldBookmarks == null
          ? const <Fact>[]
          : _decodeFacts(oldBookmarks);
      await database.transaction((transaction) async {
        await _appendFeedFacts(transaction, feed);
        await _storeFacts(transaction, bookmarks);
        for (var index = 0; index < bookmarks.length; index++) {
          await transaction.insert('bookmarks', {
            'fact_id': bookmarks[index].id,
            'position': index,
          }, conflictAlgorithm: sqlite.ConflictAlgorithm.replace);
        }
      });
      await preferences.remove(_cachedFactsKey);
      await preferences.remove(_bookmarkedFactsKey);
      debugPrint('Migrated saved Curio facts into the local database.');
    } on Exception catch (error, stackTrace) {
      debugPrint(
        'Could not migrate older Curio facts; the original data was retained: '
        '$error\n$stackTrace',
      );
    }
  }

  Future<List<Fact>> loadCachedFacts() async {
    final database = await _database;
    final rows = await database.rawQuery('''
      SELECT facts.data
      FROM feed_facts
      INNER JOIN facts ON facts.id = feed_facts.fact_id
      ORDER BY feed_facts.position ASC
    ''');
    return _factsFromRows(rows);
  }

  Future<void> saveCachedFacts(List<Fact> facts) async {
    final database = await _database;
    await database.transaction(
      (transaction) => _appendFeedFacts(transaction, facts),
    );
  }

  Future<void> updateCachedFact(Fact fact) async {
    await updateCachedFacts([fact]);
  }

  Future<void> updateCachedFacts(List<Fact> facts) async {
    if (facts.isEmpty) return;
    final database = await _database;
    await database.transaction((transaction) async {
      await _storeFacts(transaction, facts);
    });
  }

  Future<List<Fact>> loadBookmarks() async {
    final database = await _database;
    final rows = await database.rawQuery('''
      SELECT facts.data
      FROM bookmarks
      INNER JOIN facts ON facts.id = bookmarks.fact_id
      ORDER BY bookmarks.position ASC
    ''');
    return _factsFromRows(rows);
  }

  Future<void> saveBookmarks(List<Fact> facts) async {
    final database = await _database;
    await database.transaction((transaction) async {
      await _storeFacts(transaction, facts);
      await transaction.delete('bookmarks');
      for (var index = 0; index < facts.length; index++) {
        await transaction.insert('bookmarks', {
          'fact_id': facts[index].id,
          'position': index,
        }, conflictAlgorithm: sqlite.ConflictAlgorithm.replace);
      }
    });
  }

  Future<void> close() async {
    final databaseFuture = _databaseFuture;
    _databaseFuture = null;
    if (databaseFuture != null) {
      await (await databaseFuture).close();
    }
  }

  Future<void> _appendFeedFacts(
    sqlite.Transaction transaction,
    List<Fact> facts,
  ) async {
    await _storeFacts(transaction, facts);
    final rows = await transaction.rawQuery(
      'SELECT COALESCE(MAX(position), -1) AS max_position FROM feed_facts',
    );
    var position = (rows.single['max_position'] as int) + 1;
    for (final fact in facts) {
      final existing = await transaction.query(
        'feed_facts',
        columns: const ['fact_id'],
        where: 'fact_id = ?',
        whereArgs: [fact.id],
        limit: 1,
      );
      if (existing.isNotEmpty) continue;
      await transaction.insert('feed_facts', {
        'fact_id': fact.id,
        'position': position++,
      });
    }
  }

  Future<void> _storeFacts(
    sqlite.Transaction transaction,
    List<Fact> facts,
  ) async {
    for (final fact in facts) {
      await transaction.insert('facts', {
        'id': fact.id,
        'data': jsonEncode(fact.toJson()),
      }, conflictAlgorithm: sqlite.ConflictAlgorithm.replace);
    }
  }

  List<Fact> _factsFromRows(List<Map<String, Object?>> rows) {
    return rows
        .map((row) {
          final data = row['data'];
          if (data is! String) {
            throw const FormatException('Stored fact data must be text.');
          }
          final decoded = jsonDecode(data);
          if (decoded is! Map<String, dynamic>) {
            throw const FormatException('Stored fact data must be an object.');
          }
          return Fact.fromJson(decoded);
        })
        .toList(growable: false);
  }

  List<Fact> _decodeFacts(String value) {
    final decoded = jsonDecode(value);
    if (decoded is! List) {
      throw const FormatException('Stored facts must be a list.');
    }
    return decoded
        .map((item) {
          if (item is Map<String, dynamic>) return Fact.fromJson(item);
          if (item is String && item.trim().isNotEmpty) {
            return Fact.fromJson({'title': item, 'description': item});
          }
          throw const FormatException('Stored fact entry is invalid.');
        })
        .toList(growable: false);
  }
}
