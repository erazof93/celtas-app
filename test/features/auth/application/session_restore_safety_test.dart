import 'dart:async';

import 'package:celtas_mobile/core/network/api_client.dart';
import 'package:celtas_mobile/features/addresses/data/address_selection_storage.dart';
import 'package:celtas_mobile/features/auth/application/auth_controller.dart';
import 'package:celtas_mobile/features/auth/application/auth_providers.dart';
import 'package:celtas_mobile/features/auth/application/auth_state.dart';
import 'package:celtas_mobile/features/auth/data/auth_repository.dart';
import 'package:celtas_mobile/features/auth/data/models/auth_tokens.dart';
import 'package:celtas_mobile/features/auth/data/models/user.dart';
import 'package:celtas_mobile/features/notifications/application/notification_providers.dart';
import 'package:celtas_mobile/features/notifications/data/notification_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../core/network/api_client_test.dart'
    show StubAdapter, jsonResponse, refreshTokensBody;

class _Storage extends Mock implements FlutterSecureStorage {}

class _Notifications extends Mock implements NotificationRepository {}

class _AddressStorage extends AddressSelectionStorage {
  @override
  Future<void> clear() async {}
}

AuthTokens tokens(String account) => AuthTokens(
  accessToken: 'access-$account',
  refreshToken: 'refresh-$account',
  user: User(
    id: account,
    email: '$account@example.invalid',
    fullName: account,
    provider: UserProvider.local,
    totalSpent: 0,
    role: UserRole.cliente,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  ),
);

class _Repository extends AuthRepository {
  _Repository(super.dio, super.storage);
  final refreshes = <Completer<AuthTokens>>[];
  final cancellations = <CancelToken>[];
  int googleSignOuts = 0;
  Object? loginError;
  Future<AuthTokens>? loginBlock;
  @override
  Future<AuthTokens> refresh(String refreshToken, {CancelToken? cancelToken}) {
    cancellations.add(cancelToken!);
    final pending = Completer<AuthTokens>();
    refreshes.add(pending);
    return pending.future; // Also exercises transports ignoring cancellation.
  }

  @override
  Future<AuthTokens> login({
    required String email,
    required String password,
  }) async {
    if (loginError != null) throw loginError!;
    if (loginBlock != null) return loginBlock!;
    return tokens(email);
  }

  @override
  Future<void> signOutFromGoogle() async {
    googleSignOuts++;
  }
}

void main() {
  late ProviderContainer container;
  late _Repository repository;
  late _Notifications notifications;
  late String? stored;
  late List<String?> writes;
  late int reads;
  late int deletes;
  Future<String?>? readBlock;
  Future<void>? writeBlock;
  Future<void>? deleteBlock;
  Object? readError;
  Object? writeError;

  setUpAll(
    () => dotenv.loadFromString(
      envString: 'API_BASE_URL=https://example.invalid',
    ),
  );
  setUp(() {
    stored = 'saved';
    writes = [];
    reads = 0;
    deletes = 0;
    readBlock = null;
    writeBlock = null;
    readError = null;
    deleteBlock = null;
    writeError = null;
  });

  Future<void> pump(WidgetTester tester) =>
      tester.pump(const Duration(milliseconds: 1));
  Future<void> start(WidgetTester tester) async {
    final storage = _Storage();
    when(() => storage.read(key: any(named: 'key'))).thenAnswer((_) async {
      reads++;
      if (readError != null) throw readError!;
      return readBlock == null ? stored : await readBlock!;
    });
    when(
      () => storage.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((invocation) async {
      final value = invocation.namedArguments[#value] as String?;
      writes.add(value);
      if (writeError != null) throw writeError!;
      final pending = writeBlock;
      if (pending != null) await pending;
      stored = value;
    });
    when(() => storage.delete(key: any(named: 'key'))).thenAnswer((_) async {
      deletes++;
      final pending = deleteBlock;
      if (pending != null) await pending;
      stored = null;
    });
    repository = _Repository(Dio(), storage);
    notifications = _Notifications();
    when(notifications.clearFcmToken).thenAnswer((_) async {});
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(repository),
        notificationRepositoryProvider.overrideWithValue(notifications),
        addressSelectionStorageProvider.overrideWithValue(_AddressStorage()),
      ],
    );
    addTearDown(container.dispose);
    container.listen(authControllerProvider, (_, _) {});
    await pump(tester);
  }

  AuthController controller() =>
      container.read(authControllerProvider.notifier);
  AuthState state() => container.read(authControllerProvider);
  Future<void> flushHttp(WidgetTester tester) async {
    for (var event = 0; event < 20; event++) {
      await tester.pump(Duration.zero);
    }
  }

  DioException httpError(int status) {
    final request = RequestOptions(path: '/auth/refresh');
    return DioException(
      requestOptions: request,
      type: DioExceptionType.badResponse,
      response: Response<dynamic>(requestOptions: request, statusCode: status),
    );
  }

  testWidgets('restore publishes only after persistence, and clears deadline', (
    tester,
  ) async {
    await start(tester);
    final write = Completer<void>();
    writeBlock = write.future;
    repository.refreshes.single.complete(tokens('a'));
    await pump(tester);
    expect(state().status, AuthStatus.unknown);
    expect(stored, 'saved');
    write.complete();
    await pump(tester);
    expect(state().user?.id, 'a');
    expect(stored, 'refresh-a');
    await tester.pump(const Duration(seconds: 20));
    expect(state().status, AuthStatus.authenticated);
  });

  testWidgets('dispose cancels storage wait deadline and ignores late read', (
    tester,
  ) async {
    final read = Completer<String?>();
    readBlock = read.future;
    await start(tester);
    final restore = controller().bootstrap();
    container.dispose();
    await restore;
    expect(ApiClient.instance.session, isNull);
    read.complete('late');
    await pump(tester);
    expect(repository.refreshes, isEmpty);
    expect(writes, isEmpty);
    expect(deletes, 0);
    expect(stored, 'saved');
    // No clock advance: Flutter's timer invariant verifies cancellation.
  });

  testWidgets('dispose cancels HTTP and ignores late refresh success', (
    tester,
  ) async {
    await start(tester);
    final published = <AuthState>[];
    container.listen(authControllerProvider, (_, next) => published.add(next));
    final restore = controller().bootstrap();
    container.dispose();
    await restore;
    expect(repository.cancellations.single.isCancelled, isTrue);
    repository.refreshes.single.complete(tokens('late'));
    await pump(tester);
    expect(published, isEmpty);
    expect(writes, isEmpty);
    expect(deletes, 0);
    expect(stored, 'saved');
    expect(ApiClient.instance.session, isNull);
  });

  testWidgets('dispose ignores late 401 without deleting credentials', (
    tester,
  ) async {
    await start(tester);
    container.dispose();
    repository.refreshes.single.completeError(httpError(401));
    await pump(tester);
    expect(repository.cancellations.single.isCancelled, isTrue);
    expect(deletes, 0);
    expect(stored, 'saved');
  });

  testWidgets(
    'invalidating auth cancels old attempt without overwriting new session',
    (tester) async {
      await start(tester);
      final old = controller();
      final oldRevision = old.revision;
      container.invalidate(authControllerProvider);
      await pump(tester);
      expect(controller(), same(old));
      expect(controller().revision, greaterThan(oldRevision));
      expect(repository.cancellations.first.isCancelled, isTrue);
      expect(repository.refreshes, hasLength(2));
      repository.refreshes.last.complete(tokens('current'));
      await pump(tester);
      repository.refreshes.first.complete(tokens('obsolete'));
      await pump(tester);
      expect(state().user?.id, 'current');
      expect(stored, 'refresh-current');
      expect(writes, ['refresh-current']);
      expect(deletes, 0);
      expect(ApiClient.instance.session, same(controller()));
    },
  );

  testWidgets(
    'dispose before rebuilt bootstrap microtask starts no new operations',
    (tester) async {
      await start(tester);
      container.invalidate(authControllerProvider);
      controller(); // Rebuild schedules bootstrap, but has not run it yet.
      container.dispose();
      repository.refreshes.single.complete(tokens('obsolete'));
      await pump(tester);
      expect(reads, 1);
      expect(repository.refreshes, hasLength(1));
      expect(repository.cancellations.single.isCancelled, isTrue);
      expect(writes, isEmpty);
      expect(deletes, 0);
      expect(ApiClient.instance.session, isNull);
    },
  );

  testWidgets(
    'invalidating during login discards its result and restarts restoration',
    (tester) async {
      await start(tester);
      final pendingLogin = Completer<AuthTokens>();
      repository.loginBlock = pendingLogin.future;
      final login = controller().login(email: 'old-account', password: 'test');
      container.invalidate(authControllerProvider);
      await pump(tester);
      expect(repository.refreshes, hasLength(2));
      repository.refreshes.last.complete(tokens('restored'));
      await pump(tester);
      pendingLogin.complete(tokens('obsolete-login'));
      repository.refreshes.first.complete(tokens('obsolete-refresh'));
      await pump(tester);
      await login;
      expect(state().user?.id, 'restored');
      expect(writes, ['refresh-restored']);
      expect(stored, 'refresh-restored');
      expect(deletes, 0);
    },
  );

  testWidgets(
    'never completing storage times out; late read cannot start HTTP',
    (tester) async {
      final read = Completer<String?>();
      readBlock = read.future;
      await start(tester);
      await tester.pump(const Duration(seconds: 20));
      expect(state().status, AuthStatus.error);
      expect(deletes, 0);
      readBlock = null;
      final retry = controller().bootstrap();
      await pump(tester);
      read.complete('obsolete');
      await pump(tester);
      expect(reads, 2);
      expect(repository.refreshes, hasLength(1));
      repository.refreshes.single.complete(tokens('b'));
      await pump(tester);
      await retry;
      expect(state().user?.id, 'b');
    },
  );

  testWidgets(
    'HTTP never completes; timeout cancels and ignores late response',
    (tester) async {
      await start(tester);
      await tester.pump(const Duration(seconds: 20));
      expect(state().status, AuthStatus.error);
      expect(repository.cancellations.single.isCancelled, isTrue);
      repository.refreshes.single.complete(tokens('late'));
      await pump(tester);
      expect(writes, isEmpty);
      expect(stored, 'saved');
      expect(deletes, 0);
      expect(state().status, AuthStatus.error);
    },
  );

  testWidgets(
    'never completing write keeps retries bounded without overlapping storage',
    (tester) async {
      await start(tester);
      writeBlock = Completer<void>().future;
      repository.refreshes.single.complete(tokens('a'));
      await pump(tester);
      await tester.pump(const Duration(seconds: 20));
      expect(state().status, AuthStatus.error);
      final retry = controller().bootstrap();
      await pump(tester);
      await tester.pump(const Duration(seconds: 20));
      await retry;
      expect(state().status, AuthStatus.error);
      expect(writes, ['refresh-a']);
      expect(reads, 1);
      expect(stored, 'saved');
      expect(deletes, 0);
    },
  );

  testWidgets(
    'global budget spans read, HTTP and write; late write cannot authenticate',
    (tester) async {
      final read = Completer<String?>();
      readBlock = read.future;
      await start(tester);
      await tester.pump(const Duration(seconds: 15));
      read.complete('saved');
      await pump(tester);
      await tester.pump(const Duration(seconds: 4));
      final write = Completer<void>();
      writeBlock = write.future;
      repository.refreshes.single.complete(tokens('a'));
      await pump(tester);
      await tester.pump(const Duration(seconds: 1));
      expect(state().status, AuthStatus.error);
      expect(deletes, 0);
      write.complete();
      await pump(tester);
      expect(state().status, AuthStatus.error);
      expect(stored, 'refresh-a');
    },
  );

  for (final error in [
    DioException(
      requestOptions: RequestOptions(path: '/auth/refresh'),
      type: DioExceptionType.connectionError,
    ),
    DioException(
      requestOptions: RequestOptions(path: '/auth/refresh'),
      type: DioExceptionType.receiveTimeout,
    ),
  ]) {
    testWidgets(
      'recoverable ${error.type} preserves credentials and retry succeeds',
      (tester) async {
        await start(tester);
        repository.refreshes.single.completeError(error);
        await pump(tester);
        expect(state().status, AuthStatus.error);
        expect(stored, 'saved');
        expect(deletes, 0);
        final retry = controller().bootstrap();
        await pump(tester);
        repository.refreshes.last.complete(tokens('recovered'));
        await pump(tester);
        await retry;
        expect(state().user?.id, 'recovered');
      },
    );
  }

  testWidgets('5xx preserves credentials', (tester) async {
    await start(tester);
    repository.refreshes.single.completeError(httpError(503));
    await pump(tester);
    expect(state().status, AuthStatus.error);
    expect(state().errorMessage, contains('temporalmente'));
    expect(stored, 'saved');
    expect(deletes, 0);
  });
  testWidgets('confirmed 401 deletes credentials', (tester) async {
    await start(tester);
    repository.refreshes.single.completeError(httpError(401));
    await pump(tester);
    expect(state().status, AuthStatus.unauthenticated);
    expect(stored, isNull);
    expect(deletes, 1);
  });

  for (final failsRead in [true, false]) {
    testWidgets(
      '${failsRead ? "read" : "write"} storage error is recoverable',
      (tester) async {
        if (failsRead) readError = StateError('storage');
        await start(tester);
        if (!failsRead) {
          writeError = StateError('storage');
          repository.refreshes.single.complete(tokens('a'));
          await pump(tester);
        }
        expect(state().status, AuthStatus.error);
        expect(state().errorMessage, contains('leer o guardar'));
        expect(stored, 'saved');
        expect(deletes, 0);
      },
    );
  }

  testWidgets('concurrent calls share future and HTTP request', (tester) async {
    await start(tester);
    final first = controller().bootstrap();
    final second = controller().bootstrap();
    expect(identical(first, second), isTrue);
    await pump(tester);
    expect(reads, 1);
    expect(repository.refreshes, hasLength(1));
    repository.refreshes.single.complete(tokens('a'));
    await pump(tester);
    await Future.wait([first, second]);
    expect(writes, ['refresh-a']);
  });

  for (final late401 in [false, true]) {
    testWidgets(
      'late ${late401 ? "401" : "refresh"} cannot replace/delete newer login',
      (tester) async {
        await start(tester);
        await controller().login(email: 'b', password: 'test');
        if (late401) {
          repository.refreshes.single.completeError(httpError(401));
        } else {
          repository.refreshes.single.complete(tokens('a'));
        }
        await pump(tester);
        expect(state().user?.id, 'b');
        expect(stored, 'refresh-b');
        expect(writes, ['refresh-b']);
        expect(deletes, 0);
      },
    );
  }

  testWidgets('late response cannot restore after logout', (tester) async {
    await start(tester);
    await controller().logout();
    repository.refreshes.single.complete(tokens('a'));
    await pump(tester);
    expect(state().status, AuthStatus.unauthenticated);
    expect(stored, isNull);
    expect(writes, isEmpty);
  });

  testWidgets(
    'old in-flight write finishes before newer login persists and publishes',
    (tester) async {
      await start(tester);
      final write = Completer<void>();
      writeBlock = write.future;
      repository.refreshes.single.complete(tokens('a'));
      await pump(tester);
      writeBlock = null;
      final login = controller().login(email: 'b', password: 'test');
      await pump(tester);
      expect(writes, ['refresh-a']);
      expect(state().status, isNot(AuthStatus.authenticated));
      write.complete();
      await pump(tester);
      await login;
      expect(writes, ['refresh-a', 'refresh-b']);
      expect(stored, 'refresh-b');
      expect(state().user?.id, 'b');
    },
  );

  testWidgets(
    'logout deletion follows pending write and prevents resurrection',
    (tester) async {
      await start(tester);
      final write = Completer<void>();
      writeBlock = write.future;
      repository.refreshes.single.complete(tokens('a'));
      await pump(tester);
      final logout = controller().logout();
      await pump(tester);
      expect(deletes, 0);
      expect(state().status, AuthStatus.unauthenticated);
      write.complete();
      await pump(tester);
      await logout;
      expect(stored, isNull);
      expect(deletes, 1);
      expect(state().status, AuthStatus.unauthenticated);
    },
  );

  testWidgets('obsolete queued writes are skipped before reaching storage', (
    tester,
  ) async {
    await start(tester);
    final write = Completer<void>();
    writeBlock = write.future;
    repository.refreshes.single.complete(tokens('a'));
    await pump(tester);
    writeBlock = null;
    final loginB = controller().login(email: 'b', password: 'test');
    await pump(tester);
    final loginC = controller().login(email: 'c', password: 'test');
    await pump(tester);
    write.complete();
    await pump(tester);
    await Future.wait([loginB, loginC]);
    expect(writes, ['refresh-a', 'refresh-c']);
    expect(stored, 'refresh-c');
    expect(state().user?.id, 'c');
  });

  testWidgets(
    'logout refresh for FCM cleanup is followed by credential deletion',
    (tester) async {
      await start(tester);
      repository.refreshes.single.complete(tokens('a'));
      await pump(tester);
      when(notifications.clearFcmToken).thenAnswer((_) async {
        final session = controller();
        expect(session.canRefresh, isTrue);
        final rotated = AuthTokens(
          user: tokens('a').user,
          accessToken: 'rotated-access',
          refreshToken: 'rotated-refresh',
        );
        expect(
          await session.commitRefreshedTokens(
            rotated,
            expectedRevision: session.revision,
          ),
          isTrue,
        );
      });
      await controller().logout();
      expect(writes, ['refresh-a', 'rotated-refresh']);
      expect(stored, isNull);
      expect(state().status, AuthStatus.unauthenticated);
      expect(repository.googleSignOuts, 1);
    },
  );

  testWidgets('silent-refresh 401 during logout does not skip local cleanup', (
    tester,
  ) async {
    await start(tester);
    repository.refreshes.single.complete(tokens('a'));
    await pump(tester);
    when(notifications.clearFcmToken).thenAnswer((_) async {
      final session = controller();
      await session.clearSession(expectedRevision: session.revision);
    });
    await controller().logout();
    expect(stored, isNull);
    expect(state().status, AuthStatus.unauthenticated);
    expect(repository.googleSignOuts, 1);
  });

  testWidgets('pending 401 deletion cannot overtake a newer login', (
    tester,
  ) async {
    await start(tester);
    final deletion = Completer<void>();
    deleteBlock = deletion.future;
    repository.refreshes.single.completeError(httpError(401));
    await pump(tester);
    expect(state().status, AuthStatus.unauthenticated);
    final login = controller().login(email: 'b', password: 'test');
    await pump(tester);
    expect(writes, isEmpty);
    deletion.complete();
    await pump(tester);
    await login;
    expect(stored, 'refresh-b');
    expect(state().user?.id, 'b');
  });

  testWidgets('queued logout deletion precedes credentials of the next login', (
    tester,
  ) async {
    await start(tester);
    final write = Completer<void>();
    writeBlock = write.future;
    repository.refreshes.single.complete(tokens('a'));
    await pump(tester);
    final logout = controller().logout();
    await pump(tester);
    writeBlock = null;
    final login = controller().login(email: 'b', password: 'test');
    await pump(tester);
    write.complete();
    await pump(tester);
    await Future.wait([logout, login]);
    expect(deletes, 1);
    expect(stored, 'refresh-b');
    expect(state().user?.id, 'b');
  });

  testWidgets('failed newer login must not suppress queued logout deletion', (
    tester,
  ) async {
    await start(tester);
    final write = Completer<void>();
    writeBlock = write.future;
    repository.refreshes.single.complete(tokens('a'));
    await pump(tester);
    final logout = controller().logout();
    await pump(tester);
    repository.loginError = StateError('login failed');
    await expectLater(
      controller().login(email: 'b', password: 'test'),
      throwsStateError,
    );
    write.complete();
    await pump(tester);
    await logout;
    expect(stored, isNull);
    expect(deletes, 1);
    expect(state().status, AuthStatus.unauthenticated);
  });

  testWidgets('write failure does not poison later credential mutations', (
    tester,
  ) async {
    await start(tester);
    writeError = StateError('storage');
    repository.refreshes.single.complete(tokens('a'));
    await pump(tester);
    expect(state().status, AuthStatus.error);
    writeError = null;
    final retry = controller().bootstrap();
    await pump(tester);
    repository.refreshes.last.complete(tokens('b'));
    await pump(tester);
    await retry;
    expect(stored, 'refresh-b');
    expect(state().user?.id, 'b');
  });

  testWidgets('old silent refresh revision cannot commit/delete after login', (
    tester,
  ) async {
    await start(tester);
    repository.refreshes.single.complete(tokens('a'));
    await pump(tester);
    final oldRevision = controller().revision;
    await controller().login(email: 'b', password: 'test');
    expect(
      await controller().commitRefreshedTokens(
        tokens('a-late'),
        expectedRevision: oldRevision,
      ),
      isFalse,
    );
    await controller().clearSession(expectedRevision: oldRevision);
    expect(state().user?.id, 'b');
    expect(stored, 'refresh-b');
    expect(writes, ['refresh-a', 'refresh-b']);
    expect(deletes, 0);
  });

  for (final expires in [false, true]) {
    testWidgets(
      'real credential queue skips silent write after ${expires ? 'timeout' : 'logout'}',
      (tester) async {
        await start(tester);
        repository.refreshes.single.complete(tokens('a'));
        await pump(tester);
        final http = Completer<ResponseBody>();
        var refreshCalls = 0;
        ApiClient.instance.dio.httpClientAdapter = StubAdapter((options) async {
          if (options.path == '/auth/refresh') {
            refreshCalls++;
            return http.future;
          }
          return jsonResponse({'message': 'expired'}, 401);
        });
        final result = ApiClient.instance.dio
            .get('/protected')
            .then<Object?>((value) => value, onError: (Object error) => error);
        await flushHttp(tester);
        expect(refreshCalls, 1);
        final nativeWrite = Completer<void>();
        writeBlock = nativeWrite.future;
        final earlierWrite = repository.saveRefreshToken('queued-first');
        await pump(tester);
        http.complete(
          jsonResponse({'success': true, 'data': refreshTokensBody}, 200),
        );
        await flushHttp(tester);
        expect(writes, ['refresh-a', 'queued-first']);
        if (expires) {
          await tester.pump(const Duration(seconds: 20));
          await flushHttp(tester);
          expect(
            (await result as DioException).type,
            DioExceptionType.receiveTimeout,
          );
          expect(state().user?.id, 'a');
          expect(deletes, 0);
        }
        final logout = controller().logout();
        await pump(tester);
        await flushHttp(tester);
        if (!expires) {
          expect((await result as DioException).type, DioExceptionType.cancel);
        }
        writeBlock = null;
        nativeWrite.complete();
        await earlierWrite;
        await logout;
        await flushHttp(tester);
        expect(writes, ['refresh-a', 'queued-first']);
        expect(deletes, 1);
        expect(stored, isNull);
        expect(state().status, AuthStatus.unauthenticated);
      },
    );
  }
}
