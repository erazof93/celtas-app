import 'dart:async';

import 'package:celtas_mobile/core/network/api_client.dart';
import 'package:celtas_mobile/core/network/auth_session_bridge.dart';
import 'package:celtas_mobile/features/auth/data/models/auth_tokens.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

import 'api_client_test.dart' show StubAdapter, jsonResponse, refreshTokensBody;

class _Session implements AuthSessionBridge {
  @override
  String? accessToken = 'old';
  @override
  int revision = 0;
  @override
  bool canRefresh = true;
  int reads = 0;
  int commits = 0;
  int clears = 0;
  final writes = <String>[];
  Future<String?> Function() read = () async => 'saved';
  Completer<void>? persist;
  Object? persistError;
  @override
  Future<String?> readRefreshToken() {
    reads++;
    return read();
  }

  @override
  Future<bool> commitRefreshedTokens(
    AuthTokens tokens, {
    required int expectedRevision,
    bool Function()? isCurrent,
  }) async {
    commits++;
    if (persist != null) await persist!.future;
    if (persistError != null) throw persistError!;
    if (!canRefresh ||
        revision != expectedRevision ||
        !(isCurrent?.call() ?? true)) {
      return false;
    }
    writes.add(tokens.refreshToken);
    accessToken = tokens.accessToken;
    return true;
  }

  @override
  Future<void> clearSession({int? expectedRevision}) async {
    if (expectedRevision != revision) return;
    clears++;
    canRefresh = false;
    accessToken = null;
    revision++;
    ApiClient.instance.sessionActivityChanged(this);
  }
}

void main() {
  late _Session session;
  late StubAdapter adapter;
  late int httpCalls;
  late int hooks;
  Future<ResponseBody> Function()? refresh;
  setUpAll(
    () => dotenv.loadFromString(
      envString: 'API_BASE_URL=https://example.invalid',
    ),
  );
  Future<void> start(WidgetTester tester) async {
    session = _Session();
    httpCalls = 0;
    hooks = 0;
    refresh = null;
    ApiClient.instance.session = session;
    ApiClient.instance.onSessionRefreshed = () => hooks++;
    adapter = StubAdapter((options) async {
      if (options.path == '/auth/refresh') {
        httpCalls++;
        return refresh == null
            ? jsonResponse({'success': true, 'data': refreshTokensBody}, 200)
            : await refresh!();
      }
      return options.extra['_retry'] == true
          ? jsonResponse({'ok': true}, 200)
          : jsonResponse({'message': 'expired'}, 401);
    });
    ApiClient.instance.dio.httpClientAdapter = adapter;
    addTearDown(() {
      ApiClient.instance.session = null;
      ApiClient.instance.onSessionRefreshed = null;
    });
  }

  Future<void> flush(WidgetTester tester) async {
    // Dio schedules zero-duration event tasks between its interceptor stages.
    // Drain those tasks without advancing the refresh deadline.
    for (var event = 0; event < 20; event++) {
      await tester.pump(Duration.zero);
    }
  }

  Future<Object?> request([String path = '/menu']) => ApiClient.instance.dio
      .get(path)
      .then<Object?>((value) => value, onError: (Object error) => error);

  testWidgets(
    'never completing credential read: shared wait, timeout, late read ignored',
    (tester) async {
      await start(tester);
      final read = Completer<String?>();
      session.read = () => read.future;
      final first = request();
      final second = request('/banners');
      await flush(tester);
      expect(session.reads, 1);
      await tester.pump(const Duration(seconds: 20));
      await flush(tester);
      expect(
        (await first as DioException).type,
        DioExceptionType.receiveTimeout,
      );
      expect(
        (await second as DioException).type,
        DioExceptionType.receiveTimeout,
      );
      expect(session.clears, 0);
      expect(httpCalls, 0);
      final retry = request();
      await flush(tester);
      expect(
        session.reads,
        1,
      ); // No second native read while the first is pending.
      read.complete('saved');
      await flush(tester);
      expect(await retry, isA<Response<dynamic>>());
      expect(httpCalls, 1);
      expect(hooks, 1);
    },
  );

  testWidgets(
    'Secure Storage read error resolves all requests without clearing session',
    (tester) async {
      await start(tester);
      final read = Completer<String?>();
      session.read = () => read.future;
      final first = request();
      final second = request('/banners');
      await flush(tester);
      read.completeError(StateError('storage unavailable'));
      await flush(tester);
      expect((await first as DioException).type, DioExceptionType.unknown);
      expect((await second as DioException).response, isNull);
      expect(session.clears, 0);
      expect(session.accessToken, 'old');
      expect(httpCalls, 0);
      session.read = () async => 'saved';
      final retry = request();
      await flush(tester);
      expect(await retry, isA<Response<dynamic>>());
    },
  );

  testWidgets('HTTP timeout cancels transport and ignores late tokens', (
    tester,
  ) async {
    await start(tester);
    final pending = Completer<ResponseBody>();
    refresh = () => pending.future;
    final result = request();
    await flush(tester);
    final sent = adapter.requests.singleWhere((r) => r.path == '/auth/refresh');
    await tester.pump(const Duration(seconds: 20));
    await flush(tester);
    expect(
      (await result as DioException).type,
      DioExceptionType.receiveTimeout,
    );
    expect(sent.cancelToken!.isCancelled, isTrue);
    pending.complete(
      jsonResponse({'success': true, 'data': refreshTokensBody}, 200),
    );
    await flush(tester);
    expect(session.commits, 0);
    expect(session.clears, 0);
    expect(hooks, 0);
  });

  testWidgets('late HTTP 401 after timeout never clears credentials', (
    tester,
  ) async {
    await start(tester);
    final pending = Completer<ResponseBody>();
    refresh = () => pending.future;
    final result = request();
    await flush(tester);
    await tester.pump(const Duration(seconds: 20));
    await flush(tester);
    expect(
      (await result as DioException).type,
      DioExceptionType.receiveTimeout,
    );
    pending.complete(jsonResponse({'message': 'invalid'}, 401));
    await flush(tester);
    expect(session.clears, 0);
    expect(session.accessToken, 'old');
    expect(session.commits, 0);
  });

  testWidgets('one deadline spans read, HTTP and queued persistence', (
    tester,
  ) async {
    await start(tester);
    final read = Completer<String?>();
    session.read = () => read.future;
    final pending = Completer<ResponseBody>();
    refresh = () => pending.future;
    session.persist = Completer<void>();
    final result = request();
    await flush(tester);
    await tester.pump(const Duration(seconds: 8));
    await flush(tester);
    read.complete('saved');
    await flush(tester);
    await tester.pump(const Duration(seconds: 8));
    await flush(tester);
    pending.complete(
      jsonResponse({'success': true, 'data': refreshTokensBody}, 200),
    );
    await flush(tester);
    expect(session.commits, 1);
    await tester.pump(const Duration(seconds: 4));
    await flush(tester);
    expect(
      (await result as DioException).type,
      DioExceptionType.receiveTimeout,
    );
    session.persist!.complete();
    await flush(tester);
    expect(session.writes, isEmpty);
    expect(session.accessToken, 'old');
    expect(session.clears, 0);
    expect(hooks, 0);
  });

  testWidgets('concurrent requests share read, HTTP, commit and hook', (
    tester,
  ) async {
    await start(tester);
    final pending = Completer<ResponseBody>();
    refresh = () => pending.future;
    final results = [request(), request('/banners'), request('/orders')];
    await flush(tester);
    expect(session.reads, 1);
    expect(httpCalls, 1);
    pending.complete(
      jsonResponse({'success': true, 'data': refreshTokensBody}, 200),
    );
    await flush(tester);
    for (final result in results) {
      expect(await result, isA<Response<dynamic>>());
    }
    expect(session.commits, 1);
    expect(session.writes, ['refresh-new']);
    expect(hooks, 1);
  });

  testWidgets(
    'delayed original 401 reuses a token already published by another request',
    (tester) async {
      await start(tester);
      final delayed = Completer<ResponseBody>();
      adapter = StubAdapter((options) async {
        if (options.path == '/auth/refresh') {
          httpCalls++;
          return jsonResponse({
            'success': true,
            'data': refreshTokensBody,
          }, 200);
        }
        if (options.extra['_retry'] == true) {
          return jsonResponse({'ok': true}, 200);
        }
        return options.path == '/slow'
            ? delayed.future
            : jsonResponse({'message': 'expired'}, 401);
      });
      ApiClient.instance.dio.httpClientAdapter = adapter;
      final slow = request('/slow');
      final fast = request();
      await flush(tester);
      expect(await fast, isA<Response<dynamic>>());
      expect(session.accessToken, 'access-new');
      delayed.complete(jsonResponse({'message': 'expired'}, 401));
      await flush(tester);
      expect(await slow, isA<Response<dynamic>>());
      expect(httpCalls, 1);
      expect(session.reads, 1);
      expect(session.commits, 1);
      expect(hooks, 1);
    },
  );

  testWidgets(
    'logout cancels waiting refresh immediately; late 401 does not clear again',
    (tester) async {
      await start(tester);
      final pending = Completer<ResponseBody>();
      refresh = () => pending.future;
      final result = request();
      await flush(tester);
      await session.clearSession(expectedRevision: session.revision);
      await flush(tester);
      expect((await result as DioException).type, DioExceptionType.cancel);
      pending.complete(jsonResponse({'message': 'invalid'}, 401));
      await flush(tester);
      expect(session.clears, 1);
      expect(session.commits, 0);
      expect(session.writes, isEmpty);
    },
  );

  testWidgets('new account refresh proceeds while old read is pending', (
    tester,
  ) async {
    await start(tester);
    final read = Completer<String?>();
    session.read = () => read.future;
    final old = request();
    await flush(tester);
    session.revision++;
    session.accessToken = 'new-account';
    ApiClient.instance.sessionActivityChanged(session);
    session.read = () async => 'new-saved';
    final current = request();
    await flush(tester);
    expect((await old as DioException).type, DioExceptionType.cancel);
    expect(await current, isA<Response<dynamic>>());
    read.complete('obsolete');
    await flush(tester);
    expect(httpCalls, 1);
    expect(session.commits, 1);
    // Dio reuses RequestOptions for replay; the adapter records it twice.
    expect(
      adapter.requests
          .where((r) => r.path == '/menu' && r.extra['_retry'] == true)
          .toSet(),
      hasLength(1),
    );
  });

  testWidgets(
    'storage persistence failure with 401 evidence is not HTTP invalidation',
    (tester) async {
      await start(tester);
      final options = RequestOptions(path: 'storage');
      session.persistError = DioException(
        requestOptions: options,
        response: Response<dynamic>(requestOptions: options, statusCode: 401),
      );
      final pendingResult = request();
      await flush(tester);
      final result = await pendingResult;
      expect((result as DioException).type, DioExceptionType.unknown);
      expect(result.response, isNull);
      expect(session.clears, 0);
      expect(session.writes, isEmpty);
    },
  );
}
