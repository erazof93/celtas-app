import 'dart:async';
import 'dart:convert';

import 'package:celtas_mobile/core/startup/app_preparation_controller.dart';
import 'package:celtas_mobile/core/startup/celtas_startup_app.dart';
import 'package:celtas_mobile/features/addresses/data/address_selection_storage.dart';
import 'package:celtas_mobile/features/auth/application/auth_controller.dart';
import 'package:celtas_mobile/features/auth/application/auth_providers.dart';
import 'package:celtas_mobile/features/auth/application/auth_state.dart';
import 'package:celtas_mobile/features/cart/application/cart_provider.dart';
import 'package:celtas_mobile/features/cart/data/cart_storage.dart';
import 'package:celtas_mobile/features/cart/data/models/cart_item.dart';
import 'package:celtas_mobile/features/settings/application/app_version_check.dart';
import 'package:celtas_mobile/features/settings/application/settings_providers.dart';
import 'package:celtas_mobile/shared/widgets/celtas_button.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Auth extends AuthController {
  _Auth(this.onBuild);
  final void Function() onBuild;
  @override
  AuthState build() {
    onBuild();
    return const AuthState.unauthenticated();
  }
}

void main() {
  const item = CartItem(
    menuItemId: 'saved-product',
    name: 'Carrito guardado',
    unitPrice: 15,
    quantity: 2,
  );
  late AppPreparationController controller;
  late SharedPreferences prefs;
  late String snapshot;
  late int configCalls;
  late int prefsCalls;
  late int firebaseCalls;
  late int containers;
  late int authBuilds;
  Future<void>? configPending;
  Future<SharedPreferences>? prefsPending;
  Future<void>? firebasePending;
  Object? preparationError;
  Object? firebaseError;

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    dotenv.loadFromString(envString: 'API_BASE_URL=https://example.invalid');
  });
  setUp(() async {
    snapshot = jsonEncode(const CartState(items: [item]).toJsonForStorage());
    SharedPreferences.setMockInitialValues({
      CartStorage.storageKey: snapshot,
      'selected_address_id': 'saved-address',
    });
    prefs = await SharedPreferences.getInstance();
    configCalls = 0;
    prefsCalls = 0;
    firebaseCalls = 0;
    containers = 0;
    authBuilds = 0;
    configPending = null;
    prefsPending = null;
    firebasePending = null;
    preparationError = null;
    firebaseError = null;
  });

  Future<void> mount(WidgetTester tester) async {
    controller = AppPreparationController(
      loadConfiguration: () async {
        configCalls++;
        if (configPending != null) await configPending;
      },
      loadPreferences: () async {
        prefsCalls++;
        if (preparationError != null) throw preparationError!;
        return prefsPending == null ? prefs : await prefsPending!;
      },
      initializeFirebase: () async {
        firebaseCalls++;
        if (firebaseError != null) throw firebaseError!;
        if (firebasePending != null) await firebasePending;
      },
      createContainer: (loaded) {
        containers++;
        return ProviderContainer(
          overrides: [
            cartStorageProvider.overrideWithValue(CartStorage(loaded)),
            addressSelectionStorageProvider.overrideWithValue(
              AddressSelectionStorage(loaded),
            ),
            authControllerProvider.overrideWith(
              () => _Auth(() => authBuilds++),
            ),
            appVersionCheckProvider.overrideWith(
              (ref) async => AppVersionCheck.noBlock,
            ),
          ],
        );
      },
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(CeltasStartupApp(controller: controller));
    await tester.pump();
  }

  Future<void> timeout(WidgetTester tester) =>
      tester.pump(const Duration(seconds: 20));
  void expectRecoverable() {
    expect(controller.status, AppPreparationStatus.error);
    expect(controller.container, isNull);
    expect(containers, 0);
    expect(authBuilds, 0);
    expect(prefs.getString(CartStorage.storageKey), snapshot);
    expect(find.text('Reintentar'), findsOneWidget);
  }

  testWidgets(
    'configuration never completes: timeout and retry share operation',
    (tester) async {
      configPending = Completer<void>().future;
      await mount(tester);
      await timeout(tester);
      expectRecoverable();
      await tester.tap(find.text('Reintentar'));
      await tester.pump();
      expect(configCalls, 1);
      expect(prefsCalls, 0);
      expect(firebaseCalls, 0);
      await timeout(tester);
      expectRecoverable();
    },
  );

  testWidgets(
    'Firebase failure retries only Firebase and preserves saved cart',
    (tester) async {
      firebaseError = StateError('Firebase failed');
      await mount(tester);
      expectRecoverable();
      firebaseError = null;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(controller.status, AppPreparationStatus.ready);
      expect(configCalls, 1);
      expect(prefsCalls, 1);
      expect(firebaseCalls, 2);
      expect(containers, 1);
      expect(controller.container!.read(cartProvider).items, [item]);
      expect(prefs.getString(CartStorage.storageKey), snapshot);
    },
  );

  testWidgets(
    'Firebase never completes: visible error, no provisional providers, shared native retry',
    (tester) async {
      firebasePending = Completer<void>().future;
      await mount(tester);
      expect(firebaseCalls, 1);
      await timeout(tester);
      expectRecoverable();
      final first = controller.prepare();
      final second = controller.prepare();
      expect(identical(first, second), isTrue);
      await tester.pump();
      expect(
        tester.widget<CeltasButton>(find.byType(CeltasButton)).onPressed,
        isNull,
      );
      await timeout(tester);
      await first;
      expectRecoverable();
      expect(firebaseCalls, 1);
      expect(prefsCalls, 1);
      expect(configCalls, 1);
    },
  );

  testWidgets(
    'SharedPreferences never completes: no Firebase/provider start or cart overwrite',
    (tester) async {
      prefsPending = Completer<SharedPreferences>().future;
      await mount(tester);
      await timeout(tester);
      expectRecoverable();
      expect(firebaseCalls, 0);
      final retry = controller.prepare();
      await tester.pump();
      await timeout(tester);
      await retry;
      expectRecoverable();
      expect(prefsCalls, 1);
    },
  );

  testWidgets(
    'failed preparation retries only failed step and preserves cart snapshot',
    (tester) async {
      preparationError = StateError('preferences unavailable');
      await mount(tester);
      expectRecoverable();
      preparationError = null;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(controller.status, AppPreparationStatus.ready);
      expect(configCalls, 1);
      expect(prefsCalls, 2);
      expect(firebaseCalls, 1);
      expect(containers, 1);
      expect(authBuilds, 1);
      expect(controller.container!.read(cartProvider).items.single, item);
      expect(
        controller.container!.read(addressSelectionStorageProvider).load(),
        'saved-address',
      );
      expect(prefs.getString(CartStorage.storageKey), snapshot);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('late preferences do not start Firebase until a manual retry', (
    tester,
  ) async {
    final pending = Completer<SharedPreferences>();
    prefsPending = pending.future;
    await mount(tester);
    await timeout(tester);
    pending.complete(prefs);
    await tester.pump();
    expectRecoverable();
    expect(firebaseCalls, 0);
    await controller.prepare();
    await tester.pumpAndSettle();
    expect(controller.status, AppPreparationStatus.ready);
    expect(prefsCalls, 1);
    expect(containers, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'late Firebase completion stays recoverable and is reused on retry',
    (tester) async {
      final pending = Completer<void>();
      firebasePending = pending.future;
      await mount(tester);
      await timeout(tester);
      pending.complete();
      await tester.pump();
      expectRecoverable();
      await controller.prepare();
      await tester.pumpAndSettle();
      final container = controller.container;
      await controller.prepare();
      await tester.pumpWidget(CeltasStartupApp(controller: controller));
      await tester.pumpAndSettle();
      expect(controller.container, same(container));
      expect(containers, 1);
      expect(firebaseCalls, 1);
      expect(container!.read(cartProvider).items.single, item);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'budget includes configuration time and retries never duplicate pending configuration',
    (tester) async {
      final pending = Completer<void>();
      configPending = pending.future;
      await mount(tester);
      await tester.pump(const Duration(seconds: 15));
      firebasePending = Completer<void>().future;
      pending.complete();
      await tester.pump();
      await tester.pump(const Duration(seconds: 5));
      expectRecoverable();
      expect(configCalls, 1);
      expect(firebaseCalls, 1);
    },
  );

  testWidgets(
    'rebuild during loading does not create a second attempt or container',
    (tester) async {
      final pending = Completer<void>();
      configPending = pending.future;
      await mount(tester);
      await tester.pumpWidget(
        CeltasStartupApp(key: UniqueKey(), controller: controller),
      );
      await tester.pump();
      expect(configCalls, 1);
      expect(containers, 0);
      pending.complete();
      await tester.pumpAndSettle();
      expect(configCalls, 1);
      expect(containers, 1);
      expect(authBuilds, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
