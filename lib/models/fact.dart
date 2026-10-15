import 'package:html/dom.dart' as html;
import 'package:html/parser.dart' as html_parser;
import 'package:flutter/foundation.dart';

const factRepublicGeneratorUrl =
    'https://factrepublic.com/random-facts-generator/';

class Fact {
  const Fact({
    required this.id,
    required this.number,
    required this.title,
    required this.description,
    required this.pageUrl,
    this.imageUrl,
    this.sourceUrl,
    this.category,
    this.sourceName,
    this.imageCacheKey,
  });

  final String id;
  final String number;
  final String title;
  final String description;
  final String pageUrl;
  final String? imageUrl;
  final String? sourceUrl;
  final String? category;
  final String? sourceName;
  final String? imageCacheKey;

  Map<String, Object?> toJson() => {
    'id': id,
    'number': number,
    'title': title,
    'description': description,
    'pageUrl': pageUrl,
    'imageUrl': imageUrl,
    'sourceUrl': sourceUrl,
    'category': category,
    'sourceName': sourceName,
    'imageCacheKey': imageCacheKey,
  };

  factory Fact.fromJson(Map<String, Object?> json) {
    final rawId = json['id'] ?? json['url'];
    final rawNumber = json['number'];
    final rawTitle = json['title'] ?? json['name'];
    final rawDescription = json['description'] ?? json['fact'];
    final rawPageUrl = json['pageUrl'];
    final imageUrl = json['imageUrl'];
    final sourceUrl = json['sourceUrl'];
    final category = json['category'];
    final sourceName = json['sourceName'];
    final imageCacheKey = json['imageCacheKey'];
    if (rawTitle is! String ||
        rawDescription is! String ||
        rawTitle.trim().isEmpty ||
        rawDescription.trim().isEmpty ||
        (rawId != null && rawId is! String) ||
        (imageUrl != null && imageUrl is! String) ||
        (sourceUrl != null && sourceUrl is! String) ||
        (category != null && category is! String) ||
        (sourceName != null && sourceName is! String) ||
        (imageCacheKey != null && imageCacheKey is! String) ||
        (rawNumber != null && rawNumber is! String) ||
        (rawPageUrl != null && rawPageUrl is! String)) {
      throw const FormatException('Stored fact data is invalid.');
    }
    final migratedId = (rawId as String?)?.trim();
    return Fact(
      id: migratedId != null && migratedId.isNotEmpty
          ? migratedId
          : '${rawTitle.trim()}:${rawDescription.trim()}',
      number: rawNumber as String? ?? '—',
      title: rawTitle,
      description: rawDescription,
      pageUrl: rawPageUrl as String? ?? factRepublicGeneratorUrl,
      imageUrl: imageUrl as String?,
      sourceUrl: sourceUrl as String?,
      category: category as String?,
      sourceName: sourceName as String?,
      imageCacheKey: imageCacheKey as String?,
    );
  }

  Fact copyWith({String? imageCacheKey, bool clearImageCacheKey = false}) =>
      Fact(
        id: id,
        number: number,
        title: title,
        description: description,
        pageUrl: pageUrl,
        imageUrl: imageUrl,
        sourceUrl: sourceUrl,
        category: category,
        sourceName: sourceName,
        imageCacheKey: clearImageCacheKey
            ? null
            : imageCacheKey ?? this.imageCacheKey,
      );

  static List<Fact> parseGeneratorPage(String htmlText) {
    final document = html_parser.parse(htmlText);
    final items = document.querySelectorAll('.td-item');
    final facts = <Fact>[];
    final seen = <String>{};

    for (final item in items) {
      try {
        final fact = _parseItem(item, facts.length + 1);
        if (seen.add(fact.id)) facts.add(fact);
      } on FormatException catch (error) {
        // Generator pages can contain unrelated theme items without fact data.
        debugPrint('Skipped generator-page item ${facts.length + 1}: $error');
      }
    }
    if (facts.isEmpty) {
      throw const FormatException(
        'The generator page did not contain any readable facts.',
      );
    }
    return List.unmodifiable(facts);
  }

  static Fact _parseItem(html.Element item, int fallbackNumber) {
    final titleElement = item.querySelector('.td-sml-current-item-title');
    final title = _text(titleElement?.text);
    final paragraphs = item
        .querySelectorAll('.td-sml-description p')
        .map((element) => _text(element.text))
        .where((text) => text.isNotEmpty)
        .toList(growable: false);
    final description = paragraphs.join('\n\n');

    if (title.isEmpty || description.isEmpty) {
      throw const FormatException('Fact is missing a title or description.');
    }

    final number = _text(item.querySelector('.td-sml-current-item-nr')?.text);
    final image = item.querySelector('img[src]');
    final imageUrl = _httpsUrl(image?.attributes['src']);
    final sourceAnchor = item.querySelector('.metabar a.source[href]');
    final sourceUrl = _sourceUrl(sourceAnchor);
    final sourceName = _text(sourceAnchor?.text);
    final category = _text(
      item.querySelector('.td-sml-current-item-category')?.text,
    );
    final pageUrl = _factPageUrl(item);
    final id =
        pageUrl ??
        '${number.isEmpty ? fallbackNumber : number}:$title:$description';

    return Fact(
      id: id,
      number: number.isEmpty ? '$fallbackNumber' : number,
      title: title,
      description: description,
      pageUrl: pageUrl ?? factRepublicGeneratorUrl,
      imageUrl: imageUrl,
      sourceUrl: sourceUrl,
      category: category.isEmpty ? null : category,
      sourceName: sourceName.isEmpty ? null : sourceName,
    );
  }

  static String? _factPageUrl(html.Element item) {
    for (final anchor in item.querySelectorAll('.shareboard a[href]')) {
      final shareUri = Uri.tryParse(anchor.attributes['href'] ?? '');
      final originalUrl = shareUri?.queryParameters['url'];
      if (originalUrl == null) continue;
      final originalUri = Uri.tryParse(originalUrl);
      if (originalUri == null ||
          originalUri.host.toLowerCase() != 'factrepublic.com' ||
          !originalUri.path.startsWith('/facts/')) {
        continue;
      }
      return originalUri.replace(scheme: 'https').toString();
    }
    return null;
  }

  static String? _sourceUrl(html.Element? anchor) {
    final value = anchor?.attributes['href'];
    if (value == null) return null;
    final uri = Uri.tryParse(value);
    if (uri == null ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.host.isEmpty) {
      return null;
    }
    return uri.toString();
  }

  static String? _httpsUrl(String? value) {
    if (value == null) return null;
    final uri = Uri.tryParse(value);
    if (uri == null ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.host.isEmpty) {
      return null;
    }
    return uri.replace(scheme: 'https').toString();
  }

  static String _text(String? value) =>
      (value ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
}
