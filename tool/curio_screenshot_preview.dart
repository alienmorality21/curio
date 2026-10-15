import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_first_app/main.dart';
import 'package:my_first_app/repositories/fact_republic_repository.dart';
import 'package:my_first_app/storage/fact_storage.dart';

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
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    CurioApp(
      repository: FactRepublicRepository(
        client: MockClient(
          (request) async => http.Response(_previewPage, 200),
        ),
      ),
      storage: FactStorage(),
    ),
  );
}
