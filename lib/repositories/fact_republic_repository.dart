import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/fact.dart';

class FactRepublicRepository {
  FactRepublicRepository({http.Client? client})
    : _client = client ?? http.Client();

  static const _requestTimeout = Duration(seconds: 20);
  final http.Client _client;

  Future<List<Fact>> fetchFacts() async {
    final uri = Uri.parse(factRepublicGeneratorUrl);
    final response = await _client
        .get(
          uri,
          headers: const {
            'Accept': 'text/html,application/xhtml+xml',
            'User-Agent': 'CurioFacts/1.0 (mobile facts reader)',
          },
        )
        .timeout(_requestTimeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        'Fact Republic returned HTTP ${response.statusCode}.',
        uri,
      );
    }

    try {
      final htmlText = _decodeBody(response);
      final facts = Fact.parseGeneratorPage(htmlText);
      debugPrint('Read ${facts.length} facts from the generator page.');
      return facts;
    } on FormatException catch (error, stackTrace) {
      debugPrint('Could not parse the generator page: $error\n$stackTrace');
      rethrow;
    }
  }

  String _decodeBody(http.Response response) {
    final contentType = response.headers['content-type'] ?? '';
    final charsetMatch = RegExp(
      r'charset=([A-Za-z0-9._-]+)',
      caseSensitive: false,
    ).firstMatch(contentType);
    final charset = charsetMatch?.group(1)?.toLowerCase();
    if (charset == 'windows-1252' || charset == 'iso-8859-1') {
      return String.fromCharCodes(response.bodyBytes);
    }
    return response.body;
  }

  void close() => _client.close();
}
