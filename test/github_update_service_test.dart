import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_first_app/services/github_update_service.dart';

void main() {
  test('finds a newer stable APK release on the official repository', () async {
    final apk = [1, 2, 3, 4];
    final digest = sha256.convert(apk).toString();
    final client = MockClient((request) async {
      expect(request.url.host, 'api.github.com');
      return http.Response(jsonEncode(_release(apk, digest)), HttpStatus.ok);
    });

    final service = GithubUpdateService(
      client: client,
      currentVersion: () async => '1.0.0',
    );
    final update = await service.checkForUpdate();

    expect(update, isNotNull);
    expect(update!.version, 'v1.1.0');
    expect(update.sha256, digest);
    expect(update.size, apk.length);
    expect(
      update.downloadUrl.toString(),
      'https://github.com/alienmorality21/curio/releases/download/'
      'v1.1.0/app-release.apk',
    );
  });

  test('does not offer the installed release again', () async {
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode(
          _release([1, 2, 3, 4], sha256.convert([1, 2, 3, 4]).toString()),
        ),
        HttpStatus.ok,
      ),
    );
    final service = GithubUpdateService(
      client: client,
      currentVersion: () async => '1.1.0',
    );

    expect(await service.checkForUpdate(), isNull);
  });

  test(
    'rejects APK download URLs outside the official GitHub release',
    () async {
      final release = _release(
        [1, 2, 3, 4],
        sha256.convert([1, 2, 3, 4]).toString(),
      )..['assets'][0]['browser_download_url'] = 'https://example.com/app.apk';
      final client = MockClient(
        (_) async => http.Response(jsonEncode(release), HttpStatus.ok),
      );
      final service = GithubUpdateService(
        client: client,
        currentVersion: () async => '1.0.0',
      );

      expect(service.checkForUpdate(), throwsFormatException);
    },
  );

  test(
    'downloads to temporary storage and verifies the SHA-256 digest',
    () async {
      final apk = [0, 1, 2, 3, 4, 5];
      final digest = sha256.convert(apk).toString();
      final temporaryDirectory = await Directory.systemTemp.createTemp(
        'curio-update-test-',
      );
      addTearDown(() => temporaryDirectory.delete(recursive: true));
      final client = MockClient((request) async {
        if (request.method == 'GET' && request.url.host == 'api.github.com') {
          return http.Response(
            jsonEncode(_release(apk, digest)),
            HttpStatus.ok,
          );
        }
        return http.Response.bytes(
          apk,
          HttpStatus.ok,
          headers: const {'content-type': 'application/octet-stream'},
        );
      });
      final service = GithubUpdateService(
        client: client,
        currentVersion: () async => '1.0.0',
        temporaryDirectory: () async => temporaryDirectory,
      );
      final update = (await service.checkForUpdate())!;
      final progress = <(int, int)>[];

      final path = await service.downloadApk(
        update,
        onProgress: (received, total) => progress.add((received, total)),
      );

      expect(await File(path).readAsBytes(), apk);
      expect(progress.last, (apk.length, apk.length));
    },
  );

  test('deletes a download when its SHA-256 digest does not match', () async {
    final apk = [1, 2, 3, 4];
    final temporaryDirectory = await Directory.systemTemp.createTemp(
      'curio-update-invalid-test-',
    );
    addTearDown(() => temporaryDirectory.delete(recursive: true));
    final client = MockClient(
      (_) async => http.Response.bytes(apk, HttpStatus.ok),
    );
    final service = GithubUpdateService(
      client: client,
      temporaryDirectory: () async => temporaryDirectory,
    );

    await expectLater(
      service.downloadApk(
        GithubUpdate(
          version: 'v1.1.0',
          downloadUrl: Uri.https(
            'github.com',
            '/alienmorality21/curio/releases/download/v1.1.0/app-release.apk',
          ),
          sha256: List.filled(64, '0').join(),
          size: apk.length,
        ),
        onProgress: (_, _) {},
      ),
      throwsFormatException,
    );
    expect(await temporaryDirectory.list().isEmpty, isTrue);
  });
}

Map<String, dynamic> _release(List<int> apk, String digest) => {
  'tag_name': 'v1.1.0',
  'draft': false,
  'prerelease': false,
  'assets': [
    {
      'name': 'app-release.apk',
      'browser_download_url':
          'https://github.com/alienmorality21/curio/releases/download/'
          'v1.1.0/app-release.apk',
      'digest': 'sha256:$digest',
      'size': apk.length,
    },
  ],
};
