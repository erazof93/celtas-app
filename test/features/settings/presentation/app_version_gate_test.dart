import 'package:celtas_mobile/app.dart';
import 'package:celtas_mobile/core/router/app_router.dart';
import 'package:celtas_mobile/features/settings/application/app_version_check.dart';
import 'package:celtas_mobile/features/settings/application/settings_providers.dart';
import 'package:celtas_mobile/features/settings/presentation/widgets/force_update_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Prueba el cableado real de `_AppVersionGate` en `lib/app.dart`, NO solo la
/// función pura (`app_version_check_test.dart`) ni el provider aislado
/// (`app_version_check_provider_test.dart`, con mocktail sobre el
/// repositorio). Se usa `routerProvider.overrideWithValue` con un `GoRouter`
/// mínimo (en vez del router real de la app) para aislar el mecanismo del
/// gate del resto del árbol de rutas/auth.
///
/// HALLAZGO DE @tester CORREGIDO (ver `docs/testing-checklist.md` para el
/// veredicto original NO LISTO): `_AppVersionGateState.build()` guardaba
/// `context` en la MISMA posición del árbol donde `MaterialApp.router(builder:
/// ...)` monta el `Navigator` de `go_router` como DESCENDIENTE
/// (`widget.child`) — un `BuildContext` solo puede mirar hacia arriba, así
/// que ese `Navigator` NUNCA fue ancestro de `context` en tiempo de
/// ejecución. `showDialog(context: context, ...)` reventaba con
/// `FlutterError: Navigator operation requested with a context that does not
/// include a Navigator` en el momento exacto en que se necesitaba bloquear al
/// usuario — el peor momento posible para un fallo silencioso. Fix: se
/// muestra el diálogo con el `context` de `rootNavigatorKey` (ver
/// `app_router.dart`), que sí apunta al `Navigator` real montado por
/// `child`. El test de abajo (`isUpdateRequired: true`) reemplaza al sondeo
/// descartado que reprodujo el bug original — usa un router con el MISMO
/// `navigatorKey: rootNavigatorKey` que usa el router real de la app (a
/// diferencia de los otros dos tests de este archivo, que no llegan a
/// disparar `showDialog` y por eso no necesitan esa key para ser válidos).
void main() {
  GoRouter fakeRouter({GlobalKey<NavigatorState>? navigatorKey}) => GoRouter(
        navigatorKey: navigatorKey,
        initialLocation: '/x',
        routes: [
          GoRoute(
            path: '/x',
            builder: (_, _) => const Scaffold(body: Text('CONTENIDO REAL')),
          ),
        ],
      );

  testWidgets(
    'isUpdateRequired: false → nunca se muestra el diálogo, la app se usa '
    'con normalidad',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            routerProvider.overrideWithValue(fakeRouter()),
            appVersionCheckProvider.overrideWith(
              (ref) async => AppVersionCheck.noBlock,
            ),
          ],
          child: const CeltasApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ForceUpdateDialog), findsNothing);
      expect(find.text('CONTENIDO REAL'), findsOneWidget);
    },
  );

  testWidgets(
    'red desconectada (appVersionCheckProvider en AsyncError) → fail-open '
    'real de punta a punta, sin diálogo y sin excepción no manejada',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            routerProvider.overrideWithValue(fakeRouter()),
            appVersionCheckProvider.overrideWith(
              (ref) async => throw Exception('sin conexión'),
            ),
          ],
          child: const CeltasApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ForceUpdateDialog), findsNothing);
      expect(find.text('CONTENIDO REAL'), findsOneWidget);
      // Riverpod captura el error del `Future` como `AsyncError`; no debe
      // escapar como una excepción no manejada del árbol de widgets.
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'isUpdateRequired: true → muestra ForceUpdateDialog no descartable sin '
    'lanzar (regresión del bug de Navigator corregido en app_router.dart)',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            routerProvider.overrideWithValue(
              fakeRouter(navigatorKey: rootNavigatorKey),
            ),
            appVersionCheckProvider.overrideWith(
              (ref) async => const AppVersionCheck(
                isUpdateRequired: true,
                minVersion: '1.2.0+30',
              ),
            ),
          ],
          child: const CeltasApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ForceUpdateDialog), findsOneWidget);
      expect(find.text('Versión requerida: 1.2.0'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // No descartable: ni el botón atrás del sistema...
      final handled = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(handled, isTrue);
      expect(find.byType(ForceUpdateDialog), findsOneWidget);

      // ...ni un tap fuera del diálogo (la barrera) lo cierran.
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.byType(ForceUpdateDialog), findsOneWidget);
    },
  );
}
