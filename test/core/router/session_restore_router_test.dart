import 'dart:async';

import 'package:celtas_mobile/app.dart';
import 'package:celtas_mobile/core/router/app_router.dart';
import 'package:celtas_mobile/features/auth/application/auth_providers.dart';
import 'package:celtas_mobile/features/auth/data/auth_repository.dart';
import 'package:celtas_mobile/features/home/application/home_providers.dart';
import 'package:celtas_mobile/features/settings/application/app_version_check.dart';
import 'package:celtas_mobile/features/settings/application/settings_providers.dart';
import 'package:celtas_mobile/features/settings/presentation/widgets/force_update_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mocktail/mocktail.dart';

class _Repository extends Mock implements AuthRepository {}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    dotenv.loadFromString(envString: 'API_BASE_URL=https://example.invalid');
  });
  for (final error in [false, true]) {
    for (final blocked in [false, true]) {
      testWidgets(
        'protected navigation with ${error ? "error" : "unknown"}; blocked=$blocked',
        (tester) async {
          final read = Completer<String?>();
          final repository = _Repository();
          when(repository.readRefreshToken).thenAnswer((_) => read.future);
          var homeRequests = 0;
          final container = ProviderContainer(
            overrides: [
              authRepositoryProvider.overrideWithValue(repository),
              appVersionCheckProvider.overrideWith(
                (ref) async => blocked
                    ? const AppVersionCheck(
                        isUpdateRequired: true,
                        minVersion: '1.0.1+17',
                      )
                    : AppVersionCheck.noBlock,
              ),
              publicMenuProvider.overrideWith((ref) async {
                homeRequests++;
                return [];
              }),
              activeBannersProvider.overrideWith((ref) async {
                homeRequests++;
                return [];
              }),
            ],
          );
          addTearDown(container.dispose);
          final router = container.read(routerProvider);
          addTearDown(router.dispose);
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: const CeltasApp(),
            ),
          );
          await tester.pump();
          if (error) {
            read.completeError(StateError('storage'));
            await tester.pump();
          }
          for (final path in [
            '/home',
            '/orders/p',
            '/checkout',
            '/product/p',
            '/cart',
          ]) {
            router.go(path);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 1));
            // During UpdateRequired the router is unmounted; no route UI runs.
            if (!blocked) {
              expect(router.routeInformationProvider.value.uri.path, '/');
            }
            expect(homeRequests, 0);
            expect(container.read(routerProvider), same(router));
            if (blocked) expect(find.byType(ForceUpdateScreen), findsOneWidget);
          }
          if (blocked) expect(await tester.binding.handlePopRoute(), isTrue);
          if (!error) {
            read.complete(null);
            await tester.pump();
          }
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}
