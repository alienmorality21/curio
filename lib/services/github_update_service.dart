import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

final _latestReleaseUri = Uri.https(
  'api.github.com',
  '/repos/alienmorality21/curio/releases/latest',
);
const _maximumApkSize = 200 * 1024 * 1024;
const _apkMimeType = 'application/vnd.android.package-archive';

class GithubUpdate {
  const GithubUpdate({
    required this.version,
    required this.downloadUrl,
    required this.sha256,
    required this.size,
  });

  final String version;
  final Uri downloadUrl;
  final String sha256;
  final int size;
}

class GithubUpdateService {
  GithubUpdateService({
    http.Client? client,
    Future<String> Function()? currentVersion,
    Future<Directory> Function()? temporaryDirectory,
    Future<OpenResult> Function(String path)? openApk,
  }) : _client = client ?? _sharedClient,
       _currentVersion = currentVersion ?? _installedVersion,
       _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory,
       _openApk = openApk ?? _openWithAndroidInstaller;

  static final http.Client _sharedClient = http.Client();

  final http.Client _client;
  final Future<String> Function() _currentVersion;
  final Future<Directory> Function() _temporaryDirectory;
  final Future<OpenResult> Function(String path) _openApk;

  Future<GithubUpdate?> checkForUpdate() async {
    final installedVersion = await _currentVersion();
    final response = await _client
        .get(
          _latestReleaseUri,
          headers: const {'Accept': 'application/vnd.github+json'},
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException(
        'GitHub returned HTTP ${response.statusCode} while checking releases.',
        uri: _latestReleaseUri,
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('GitHub returned an invalid release record.');
    }
    if (decoded['draft'] == true || decoded['prerelease'] == true) {
      throw const FormatException('GitHub returned a non-stable release.');
    }

    final tagName = decoded['tag_name'];
    if (tagName is! String || !_isValidReleaseVersion(tagName)) {
      throw const FormatException(
        'GitHub returned an invalid release version.',
      );
    }
    final comparison = _compareVersions(tagName, installedVersion);
    if (comparison <= 0) return null;

    final assets = decoded['assets'];
    if (assets is! List) {
      throw const FormatException('The GitHub release has no APK assets.');
    }
    final asset = assets.whereType<Map<String, dynamic>>().firstWhere(
      (candidate) => candidate['name'] == 'app-release.apk',
      orElse: () => throw const FormatException(
        'The latest GitHub release does not contain app-release.apk.',
      ),
    );

    final downloadUrl = asset['browser_download_url'];
    final digest = asset['digest'];
    final size = asset['size'];
    if (downloadUrl is! String ||
        digest is! String ||
        size is! int ||
        size <= 0 ||
        size > _maximumApkSize) {
      throw const FormatException('The GitHub APK metadata is invalid.');
    }

    final uri = Uri.tryParse(downloadUrl);
    final expectedSegments = [
      'alienmorality21',
      'curio',
      'releases',
      'download',
      tagName,
      'app-release.apk',
    ];
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'github.com' ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        !listEquals(uri.pathSegments, expectedSegments)) {
      throw const FormatException('GitHub returned an untrusted APK URL.');
    }

    final digestMatch = RegExp(
      r'^sha256:([0-9a-f]{64})$',
      caseSensitive: false,
    ).firstMatch(digest);
    if (digestMatch == null) {
      throw const FormatException(
        'GitHub did not provide a valid APK SHA-256.',
      );
    }

    return GithubUpdate(
      version: tagName,
      downloadUrl: uri,
      sha256: digestMatch.group(1)!.toLowerCase(),
      size: size,
    );
  }

  Future<String> downloadApk(
    GithubUpdate update, {
    required void Function(int receivedBytes, int totalBytes) onProgress,
  }) async {
    if (!_isValidReleaseVersion(update.version) ||
        update.size <= 0 ||
        update.size > _maximumApkSize ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(update.sha256) ||
        update.downloadUrl.scheme != 'https' ||
        update.downloadUrl.host != 'github.com' ||
        !listEquals(update.downloadUrl.pathSegments, [
          'alienmorality21',
          'curio',
          'releases',
          'download',
          update.version,
          'app-release.apk',
        ])) {
      throw const FormatException('The GitHub APK metadata is invalid.');
    }
    final request = http.Request('GET', update.downloadUrl)
      ..headers['Accept'] = 'application/octet-stream';
    final response = await _client
        .send(request)
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException(
        'GitHub returned HTTP ${response.statusCode} while downloading the APK.',
        uri: update.downloadUrl,
      );
    }
    if (response.contentLength != null &&
        response.contentLength != update.size) {
      throw const FormatException('The APK size does not match its release.');
    }

    final directory = await _temporaryDirectory();
    final file = File(
      '${directory.path}${Platform.pathSeparator}curio-update-${update.version}.apk',
    );
    final output = file.openWrite();
    final digestOutput = _DigestSink();
    final digestInput = sha256.startChunkedConversion(digestOutput);
    var receivedBytes = 0;
    try {
      await for (final chunk in response.stream.timeout(
        const Duration(minutes: 3),
      )) {
        receivedBytes += chunk.length;
        if (receivedBytes > update.size || receivedBytes > _maximumApkSize) {
          throw const FormatException(
            'The downloaded APK is larger than expected.',
          );
        }
        digestInput.add(chunk);
        output.add(chunk);
        onProgress(receivedBytes, update.size);
      }
      await output.flush();
      await output.close();
      digestInput.close();

      if (receivedBytes != update.size) {
        throw const FormatException('The downloaded APK is incomplete.');
      }
      final downloadedDigest = digestOutput.value!.toString();
      if (downloadedDigest != update.sha256) {
        throw const FormatException('The APK SHA-256 verification failed.');
      }

      return file.path;
    } on Object {
      await output.close();
      if (await file.exists()) await file.delete();
      rethrow;
    }
  }

  Future<void> openApkInstaller(String path) async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      throw UnsupportedError('APK installation is available only on Android.');
    }
    final result = await _openApk(path);
    if (result.type != ResultType.done) {
      throw Exception(
        'Android could not open the APK installer: ${result.message}',
      );
    }
  }

  static Future<String> _installedVersion() async =>
      (await PackageInfo.fromPlatform()).version;

  static Future<OpenResult> _openWithAndroidInstaller(String path) =>
      OpenFilex.open(path, type: _apkMimeType);

  static bool _isValidReleaseVersion(String version) =>
      RegExp(r'^v?\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$').hasMatch(version);

  static int _compareVersions(String first, String second) {
    final firstMatch = RegExp(r'^v?(\d+)\.(\d+)\.(\d+)').firstMatch(first);
    final secondMatch = RegExp(r'^v?(\d+)\.(\d+)\.(\d+)').firstMatch(second);
    if (firstMatch == null || secondMatch == null) {
      throw const FormatException('The app or release version is invalid.');
    }
    for (var index = 1; index <= 3; index++) {
      final difference =
          int.parse(firstMatch.group(index)!) -
          int.parse(secondMatch.group(index)!);
      if (difference != 0) return difference.sign;
    }
    return 0;
  }
}

class _DigestSink implements Sink<Digest> {
  Digest? value;

  @override
  void add(Digest digest) => value = digest;

  @override
  void close() {}
}
