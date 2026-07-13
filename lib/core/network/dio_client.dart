import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 15),
      responseType: ResponseType.json,
      // Some IPTV panels reject the default Dart user agent with HTTP 403.
      // Posing as a desktop browser fixes that on every panel we've tested.
      headers: const {
        'User-Agent':
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 '
                '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept':
            'application/json, text/javascript, text/plain, */*;q=0.8',
        // Tell the server we don't want a kept-alive socket - pair this
        // with the client-side idleTimeout=0 below so each request opens
        // a fresh connection, finishes, and the socket is closed.
        'Connection': 'close',
      },
    ),
  );

  // Dart's default HttpClient caps at ~6 concurrent connections per host
  // and keeps idle sockets alive for 15 s. On a fast scroll over a TMDB
  // backed catalog that becomes the bottleneck - dozens of poster lookups
  // queue behind those 6 lanes. Bump the lane count and disable the
  // keep-alive pool so finished sockets are torn down right away (no
  // lingering server-side resource use).
  dio.httpClientAdapter = IOHttpClientAdapter(
    createHttpClient: () {
      final c = HttpClient();
      c.maxConnectionsPerHost = 24;
      c.idleTimeout = Duration.zero;
      return c;
    },
  );

  return dio;
});
