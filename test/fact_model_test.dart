import 'package:flutter_test/flutter_test.dart';
import 'package:my_first_app/models/fact.dart';

const _generatorFixture = '''
<html><body>
  <div class="td-item">
    <div class="td-number-and-title"><h2>
      <span class="td-sml-current-item-nr">1</span>
      <span class="td-sml-current-item-title">Jimi Hendrix</span>
    </h2></div>
    <img src="http://i0.wp.com/factrepublic.com/wp-content/uploads/jimi.jpg"/>
    <span class="td-sml-description">
      <p>Jimi Hendrix played guitar in Little Richard's band until he was fired
      for being too flamboyant, out-dressing, and upstaging the singer.</p>
      <div class="metabar">
        <a class="button source" href="https://example.com/source">Source</a>
        <div class="shareboard">
          <a href="https://twitter.com/intent/tweet?url=http%3A%2F%2Ffactrepublic.com%2Ffacts%2F12345">Share</a>
        </div>
      </div>
    </span>
  </div>
  <div class="td-item">
    <span class="td-sml-current-item-nr">2</span>
    <span class="td-sml-current-item-title">A fact with no extras</span>
    <span class="td-sml-description"><p>This fact has no image or citation.</p></span>
  </div>
  <div class="td-item"><span>Theme item without fact content</span></div>
  <div class="td-item">
    <span class="td-sml-current-item-nr">1</span>
    <span class="td-sml-current-item-title">Jimi Hendrix</span>
    <span class="td-sml-description"><p>Duplicate record.</p></span>
    <div class="shareboard">
      <a href="https://twitter.com/intent/tweet?url=http%3A%2F%2Ffactrepublic.com%2Ffacts%2F12345">Share</a>
    </div>
  </div>
</body></html>
''';

void main() {
  test('parses numbered generator facts, images, sources, and fact links', () {
    final facts = Fact.parseGeneratorPage(_generatorFixture);
    final first = facts.first;

    expect(facts, hasLength(2));
    expect(first.number, '1');
    expect(first.title, 'Jimi Hendrix');
    expect(
      first.description,
      contains("played guitar in Little Richard's band"),
    );
    expect(
      first.imageUrl,
      'https://i0.wp.com/factrepublic.com/wp-content/uploads/jimi.jpg',
    );
    expect(first.sourceUrl, 'https://example.com/source');
    expect(first.pageUrl, 'https://factrepublic.com/facts/12345');
  });

  test('keeps facts when optional image and source elements are absent', () {
    final fact = Fact.parseGeneratorPage(_generatorFixture)[1];

    expect(fact.title, 'A fact with no extras');
    expect(fact.description, 'This fact has no image or citation.');
    expect(fact.imageUrl, isNull);
    expect(fact.sourceUrl, isNull);
    expect(fact.pageUrl, factRepublicGeneratorUrl);
  });

  test('rejects an empty or unexpected page instead of inventing facts', () {
    expect(
      () => Fact.parseGeneratorPage('<html><body>Access denied</body></html>'),
      throwsFormatException,
    );
  });
}
