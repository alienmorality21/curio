import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:file/file.dart' as package_file show File;
import 'package:file/local.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../models/fact.dart';

class FactImageCache {
  FactImageCache({http.Client? client, CacheManager? cacheManager})
    : _client = client ?? http.Client(),
      _cacheManager = cacheManager ?? _persistentCacheManager;

  static final CacheManager _persistentCacheManager = CacheManager(
    Config(
      'curio_fact_images',
      stalePeriod: const Duration(days: 3650),
      maxNrOfCacheObjects: 400,
      fileSystem: _PersistentFileSystem('curio_fact_images'),
    ),
  );
  static CacheManager get persistentCacheManager => _persistentCacheManager;

  static const _maximumImageBytes = 8 * 1024 * 1024;
  static const _requestTimeout = Duration(seconds: 20);
  final http.Client _client;
  final CacheManager _cacheManager;
  final Queue<Completer<void>> _waitingDownloads = Queue<Completer<void>>();
  final Map<String, Future<Fact>> _inFlight = {};
  int _activeDownloads = 0;

  Future<List<Fact>> cacheImages(List<Fact> facts) async {
    return Future.wait(facts.map(cacheFactImage));
  }

  Future<Fact> cacheFactImage(Fact fact) async {
    final imageUrl = fact.imageUrl;
    if (imageUrl == null) return fact;

    final key = sha256.convert(utf8.encode(imageUrl)).toString();
    final pending = _inFlight[key];
    if (pending != null) return pending;

    final task = _cacheFactImage(fact, imageUrl, key);
    _inFlight[key] = task;
    try {
      return await task;
    } finally {
      if (identical(_inFlight[key], task)) _inFlight.remove(key);
    }
  }

  Future<Fact> _cacheFactImage(Fact fact, String imageUrl, String key) async {
    await _acquireSlot();
    try {
      final cached = await _cacheManager.getFileFromCache(key);
      if (cached != null && await _isUsable(cached.file)) {
        return fact.copyWith(imageCacheKey: key);
      }
      if (cached != null) await _cacheManager.removeFile(key);
      final uncachedFact = fact.copyWith(clearImageCacheKey: true);

      final uri = Uri.tryParse(imageUrl);
      if (uri == null ||
          (uri.scheme != 'http' && uri.scheme != 'https') ||
          uri.host.isEmpty) {
        return uncachedFact;
      }
      final response = await _client
          .send(
            http.Request('GET', uri)
              ..headers['Accept'] = 'image/avif,image/webp,image/*',
          )
          .timeout(_requestTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw http.ClientException(
          'Image server returned HTTP ${response.statusCode}.',
          uri,
        );
      }
      final contentType = response.headers['content-type'] ?? '';
      if (!contentType.toLowerCase().startsWith('image/')) {
        throw const FormatException(
          'Image response has a non-image content type.',
        );
      }
      final declaredLength = response.contentLength;
      if (declaredLength != null && declaredLength > _maximumImageBytes) {
        throw const FormatException('Image exceeds the 8 MB cache limit.');
      }

      final bytes = BytesBuilder(copy: false);
      var totalBytes = 0;
      await for (final chunk in response.stream.timeout(_requestTimeout)) {
        totalBytes += chunk.length;
        if (totalBytes > _maximumImageBytes) {
          throw const FormatException('Image exceeds the 8 MB cache limit.');
        }
        bytes.add(chunk);
      }
      final data = bytes.takeBytes();
      if (data.isEmpty) {
        throw const FormatException('Image response was empty.');
      }
      await _cacheManager.putFile(
        imageUrl,
        data,
        key: key,
        maxAge: const Duration(days: 3650),
        fileExtension: _extensionFor(contentType),
      );
      final stored = await _cacheManager.getFileFromCache(key);
      if (stored == null || !await _isUsable(stored.file)) {
        throw StateError('Image was downloaded but not persisted to cache.');
      }
      return uncachedFact.copyWith(imageCacheKey: key);
    } on Exception catch (error, stackTrace) {
      debugPrint(
        'Could not cache fact image for ${fact.id}: $error\n$stackTrace',
      );
      return fact.copyWith(clearImageCacheKey: true);
    } finally {
      _releaseSlot();
    }
  }

  Future<bool> _isUsable(File file) async {
    try {
      if (!await file.exists() || await file.length() == 0) return false;
      final codec = await ui.instantiateImageCodec(
        await file.readAsBytes(),
        targetWidth: 1200,
      );
      await codec.getNextFrame();
      codec.dispose();
      return true;
    } on Exception {
      return false;
    }
  }

  String _extensionFor(String contentType) {
    final subtype = contentType.split('/').last.split(';').first.toLowerCase();
    return switch (subtype) {
      'jpeg' || 'pjpeg' => 'jpg',
      'svg+xml' => 'svg',
      'webp' => 'webp',
      'png' => 'png',
      'gif' => 'gif',
      'avif' => 'avif',
      _ => 'img',
    };
  }

  Future<void> _acquireSlot() async {
    if (_activeDownloads < 2) {
      _activeDownloads++;
      return;
    }
    final waiter = Completer<void>();
    _waitingDownloads.add(waiter);
    await waiter.future;
  }

  void _releaseSlot() {
    if (_waitingDownloads.isNotEmpty) {
      _waitingDownloads.removeFirst().complete();
    } else {
      _activeDownloads--;
    }
  }
}

class _PersistentFileSystem implements FileSystem {
  _PersistentFileSystem(String key) : _directory = _createDirectory(key);

  final Future<Directory> _directory;

  static Future<Directory> _createDirectory(String key) async {
    final root = await getApplicationSupportDirectory();
    final directory = Directory(path.join(root.path, key));
    await directory.create(recursive: true);
    return directory;
  }

  @override
  Future<package_file.File> createFile(String name) async {
    final directory = await _directory;
    return const LocalFileSystem().file(path.join(directory.path, name));
  }
}
