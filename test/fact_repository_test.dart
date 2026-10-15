import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_first_app/models/fact.dart';
import 'package:my_first_app/repositories/fact_republic_repository.dart';

const _page = '''
<div class="td-item">
  <span class="td-sml-current-item-nr">1</span>
  <span class="td-sml-current-item-title">Generator fact</span>
  <img src="https://factrepublic.com/fact.jpg">
  <span class="td-sml-description"><p>A fact from the selected generator page.</p>
    <div class="metabar">
      <a class="button source" href="https://example.com/source">Source</a>
      <div class="shareboard">
        <a href="https://twitter.com/?url=http%3A%2F%2Ffactrepublic.com%2Ffacts%2F88">Share</a>
      </div>
    </div>
  </span>
</div>
''';

void main() {
  test('requests only the generator page and parses its live HTML', () async {
    var requests = 0;
    final repository = FactRepublicRepository(
      client: MockClient((request) async {
        requests++;
        expect(request.method, 'GET');
        expect(request.url.toString(), factRepublicGeneratorUrl);
        expect(request.headers['accept'], contains('text/html'));
        return http.Response(
          _page,
          200,
          headers: {'content-type': 'text/html; charset=utf-8'},
        );
      }),
    );

    final facts = await repository.fetchFacts();

    expect(requests, 1);
    expect(facts, hasLength(1));
    expect(facts.single.title, 'Generator fact');
    expect(facts.single.pageUrl, 'https://factrepublic.com/facts/88');
    expect(facts.single.sourceUrl, 'https://example.com/source');
    repository.close();
  });

  test('reports HTTP errors and unexpected page structures', () async {
    final unavailable = FactRepublicRepository(
      client: MockClient((request) async => http.Response('Unavailable', 503)),
    );
    await expectLater(
      unavailable.fetchFacts(),
      throwsA(isA<http.ClientException>()),
    );
    unavailable.close();

    final changedMarkup = FactRepublicRepository(
      client: MockClient(
        (request) async => http.Response('<html>Unexpected page</html>', 200),
      ),
    );
    await expectLater(changedMarkup.fetchFacts(), throwsFormatException);
    changedMarkup.close();
  });
}
