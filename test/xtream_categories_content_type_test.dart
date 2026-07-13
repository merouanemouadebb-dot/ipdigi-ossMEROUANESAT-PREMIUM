import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ipdigi/features/sources/data/xtream_api.dart';
import 'package:ipdigi/features/sources/domain/source.dart';

/// A minimal dio adapter that returns a fixed body + content-type.
/// Exactly mimics the quirk of real IPTV panels (sending a JSON body
/// with `text/html`).
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter({required this.body, required this.contentType});
  final String body;
  final String contentType;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      body,
      200,
      headers: {
        Headers.contentTypeHeader: [contentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio _dioWith({required String body, required String contentType}) {
  // Same as production (dio_client.dart): responseType.json. This setting
  // alone is NOT enough - dio only auto-decodes the body when the
  // content-type is a JSON mime-type; that is the crux of the test.
  final dio = Dio(BaseOptions(responseType: ResponseType.json));
  // BackgroundTransformer can use an isolate (compute); in the test, run
  // with the synchronous transformer while keeping the content-type gate
  // exactly the same.
  dio.transformer = SyncTransformer();
  dio.httpClientAdapter = _FakeAdapter(body: body, contentType: contentType);
  return dio;
}

final _src = XtreamSource(
  id: 'src',
  name: 'Panel',
  createdAt: DateTime.fromMillisecondsSinceEpoch(0),
  url: 'http://panel.example',
  username: 'u',
  password: 'p',
);

void main() {
  const categoriesJson =
      '[{"category_id":"1","category_name":"TR | Ulusal"},'
      '{"category_id":"2","category_name":"TR | Haber"}]';

  test('categories parse edilir: gövde JSON ama content-type application/json',
      () async {
    final api = XtreamApi(
      _dioWith(body: categoriesJson, contentType: 'application/json'),
    );
    final cats = await api.liveCategories(_src);
    expect(cats.map((c) => c.name), ['TR | Ulusal', 'TR | Haber']);
  });

  test(
      'REGRESYON: panel JSON gövdeyi text/html ile dönerse de kategoriler gelir',
      () async {
    // Before the fix: dio does not decode, res.data stays a raw String,
    // _list returns an empty list -> categoryName null -> categories never
    // show (content still loads because the stream endpoint returns the
    // correct content-type).
    final api = XtreamApi(
      _dioWith(body: categoriesJson, contentType: 'text/html'),
    );
    final cats = await api.liveCategories(_src);
    expect(cats, hasLength(2),
        reason: 'text/html content-type kategorileri boşa düşürmemeli');
    expect(cats.map((c) => c.id), ['1', '2']);
  });

  test('text/plain content-type da decode edilir', () async {
    final api = XtreamApi(
      _dioWith(body: categoriesJson, contentType: 'text/plain'),
    );
    final cats = await api.vodCategories(_src);
    expect(cats, hasLength(2));
  });

  test('gerçekten geçersiz gövde güvenle boş listeye düşer', () async {
    final api = XtreamApi(
      _dioWith(body: '<html>403 forbidden</html>', contentType: 'text/html'),
    );
    final cats = await api.seriesCategories(_src);
    expect(cats, isEmpty);
  });
}
