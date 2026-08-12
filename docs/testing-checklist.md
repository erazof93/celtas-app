# ✅ Celtas Mobile — Checklist de QA

Referencia usada por el agente `@tester`. Cada módulo del `ROADMAP.md` se considera "completo"
solo cuando pasa lo aplicable de este checklist.

---

## General (aplica a todo módulo)

- [ ] `flutter analyze` sin errores ni warnings nuevos
- [ ] `flutter test` pasa
- [ ] Colores usados coinciden con `CeltasColors` (sin `Color(0xFF...)` sueltos en widgets)
- [ ] Tipografía coincide con la confirmada contra `design-reference/`
- [ ] Toda pantalla que llama a la API maneja: loading, error, y vacío explícitos
- [ ] Ningún texto de UI en inglés

---

## Auth

- [ ] `accessToken` nunca se persiste (solo en memoria vía Riverpod)
- [ ] `refreshToken` sí persiste, en `flutter_secure_storage` (no `SharedPreferences`)
- [ ] Login con Google nunca envía `password` en el body
- [ ] Login con Google: `GoogleSignIn.initialize()` se llama UNA sola vez (la SDK documenta "undefined behavior" si se llama más de una vez); cancelación del picker no muestra error; 409 muestra el mensaje real del backend
- [ ] Un 401 dispara el refresh una sola vez, no un loop
- [ ] Si el refresh falla con 401 definitivo, limpia sesión y redirige a Login; errores
      transitorios (red, 5xx) NO limpian la sesión
- [ ] Persistencia de sesión al reabrir la app funciona (recupera accessToken vía refresh)

## Navegación

- [x] Rutas protegidas redirigen a Login sin sesión
- [x] Bottom nav funciona y refleja la pantalla activa
- [x] **Doble-atrás para salir** (`_ShellScaffold`, `lib/core/router/app_router.dart`): `PopScope
      canPop: false` en el `Scaffold` del shell — primer back muestra `SnackBar` "Presiona de
      nuevo para salir" (mismo patrón visual que `cart_screen.dart`/`product_detail_screen.dart`/
      `home_screen.dart`: `bodyMedium` + `CeltasColors.cream`, `backgroundColor:
      CeltasColors.surface`, `SnackBarBehavior.floating`, 2s), segundo back dentro de esa
      ventana llama `SystemNavigator.pop()`. Confirmado por lectura de código (no solo por el
      test) que el `PopScope` solo puede dispararse cuando el shell es la ruta visible: las
      pantallas empujadas (`/cart`, `/checkout`, `/product/:id`, `/orders/:id`, `/addresses`)
      son `GoRoute` top-level sobre el `Navigator` raíz, así que el back del sistema las pop-ea
      directo sin llegar al `PopScope` del shell — cubierto con test explícito. `flutter analyze`
      limpio, 234/234 tests (232 + 2 agregados por `@tester`). Sin bloqueadores.
      Hallazgos documentados (no bugs, comportamiento verificado y razonable):
      - Cambiar de tab entre el primer y el segundo back NO resetea la ventana de 2s (el `State`
        de `_ShellScaffold` persiste entre tabs porque `IndexedStack` no lo recrea) — test de
        regresión agregado para que un cambio futuro sea intencional.
      - Logout con una ventana de confirmación pendiente no arrastra estado a la sesión
        siguiente: el shell se desmonta por completo al redirigir a `/login` (fuera del
        `StatefulShellRoute`), así que `_ShellScaffoldState` se destruye — confirmado con test
        explícito de logout + login de nuevo dentro del mismo árbol de widgets.
      Riesgo de mantenimiento (no bloqueante): este es ya el 4º lugar del proyecto con el mismo
      bloque `ScaffoldMessenger..hideCurrentSnackBar()..showSnackBar(SnackBar(...))` duplicado
      byte a byte (`cart_screen.dart`, `product_detail_screen.dart`, `home_screen.dart`, y ahora
      `app_router.dart`) — candidato a un helper compartido (`showCeltasSnackBar(context, text)`)
      cuando se toque de nuevo cualquiera de estos archivos.

## Home / Menú

- [x] Banners respetan vigencia (ya calculada por el backend)
- [x] Menú agrupado por categoría, con imágenes cacheadas correctamente
- [x] Error de banners visible con reintento (no tragado en silencio)
- [x] Pull-to-refresh sin excepción async sin manejar
- [x] **Tap sobre banners según `actionType`** (`home_screen.dart`, `home_providers.dart`, sin
      commitear todavía — mejora post-cierre de este módulo). `flutter analyze` limpio, `flutter
      test` 243/243 (verificado por `@tester`, salida cruda). Contrato `actionValue` = id real
      (no slug) de categoría/producto confirmado independientemente contra
      `../celtas-admin/src/features/banners/BannerForm.tsx` (el `<Select>` de categoría/producto
      usa `category.id`/`item.id` como `value`). `category` selecciona
      `selectedCategoryIdProvider` (compartido con `_MenuList`, antes estado local); `menuItem`
      navega a `/product/:id`, mismo flujo que una tarjeta; `external_url` usa `launchUrl` sin
      `canLaunchUrl` como gate, mismo criterio que el `whatsappUrl` del checkout. Los 2 casos
      borde (categoría sin productos / ya no existe, producto descontinuado) están cubiertos
      reutilizando estados vacíos/`_DetailNotFound` ya existentes — confirmado con test.
      **Bug real encontrado, sin corregir todavía**: el título del banner
      (`_BannerCard`, `home_screen.dart:430-441`, `Positioned(left: 16, bottom: 14, child:
      Text(...))`) no tiene `maxLines`/`overflow`/ancho acotado. Con un título largo, el texto
      renderizado se solapa visualmente con el chevron de afordancia
      (`home_screen.dart:446-455`, `Positioned(right: 12, bottom: 10)`) — el chevron se pinta
      encima de las últimas letras del título porque va después en el `Stack`. Confirmado con un
      widget test de sondeo (no incluido en el suite, descartado tras la prueba) que compara
      `tester.getRect` del texto vs. del ícono con un título de 63 caracteres: `TEXT RECT:
      Rect.fromLTRB(42.0, 159.0, 1085.1, 183.0)`, `CHEVRON RECT: Rect.fromLTRB(740.0, 165.0,
      762.0, 187.0)`, `OVERLAPS: true` (viewport de test 800px de ancho — el chevron está dentro
      del área visible, no clippeado). Riesgo real con títulos de banner largos en producción, no
      solo un caso de laboratorio. Sugerencia para la sesión principal: envolver el título en un
      `Positioned` con `right` acotado (dejando espacio para el chevron cuando `tappable`) +
      `maxLines: 1` + `overflow: TextOverflow.ellipsis`.
      **Riesgos/hallazgos no bloqueantes, verificados**:
      - `selectedCategoryIdProvider` es un `StateProvider` global (no `autoDispose`): persiste
        correctamente al navegar a `/cart`/`/product/:id` y volver (comportamiento esperado, el
        `ProviderScope` raíz no se desmonta en esas rutas empujadas). Doble-tap rápido sobre dos
        banners de categoría distintos resuelve determinísticamente al último tocado (Flutter
        procesa los gestos de forma secuencial). Tocar un banner de categoría mientras
        `publicMenuProvider` todavía está en `loading` no causa condición de carrera: el estado
        se fija igual y `_MenuList` lo lee recién cuando el menú llega y se construye.
      - `external_url` con `http://` en vez de `https://`: el `<queries>` del
        `AndroidManifest.xml` solo declara `android:scheme="https"`, pero **no aplica en la
        práctica** — confirmado leyendo el código nativo del plugin
        (`url_launcher_android-6.3.32/.../UrlLauncher.java`, método `launchUrl`): llama
        `activity.startActivity(launchIntent)` directo, sin pasar por `resolveActivity`/
        `queryIntentActivities` (que es lo que sí restringe la visibilidad de paquetes en Android
        11+). El paquete `<queries>` solo condiciona `canLaunchUrl` (no usado acá). `startActivity`
        con un intent implícito no está sujeto a esa restricción de visibilidad, esté o no
        declarado el scheme.
      - Doble-tap rápido sobre el mismo banner `menuItem` puede empujar `/product/:id` dos veces
        al stack (sin debounce) — **no es un bug nuevo de esta mejora**: mismo patrón ya existente
        sin protección en `_ProductCard`/`_CartIconButton` y en todo el proyecto (`grep -rn
        "debounce" lib/` sin resultados). Riesgo sistémico preexistente, no exclusivo de banners;
        no se bloquea esta mejora por eso pero vale la pena una solución transversal a futuro.
      - Comentario desactualizado en el modelo: `banner.dart:13` sigue diciendo `actionValue` =
        "slug/nombre" para `category`, pero el código (y el contrato real verificado) lo trata
        como el id — el comentario del archivo principal (`home_screen.dart:25-29`) sí es preciso,
        pero el de `banner.dart` no se actualizó. Menor, pero puede inducir a error a quien lea
        solo el modelo.
      **Re-auditoría (fix aplicado): LISTO.** Verifiqué el código real de `home_screen.dart`:
      `Positioned(left: 16, right: tappable ? 40 : 16, bottom: 14, child: Text(..., maxLines: 1,
      overflow: TextOverflow.ellipsis, ...))` — exactamente el fix descrito, no parcial.
      `flutter analyze` limpio, `flutter test` 244/244 (suite completa). El test de regresión
      nuevo (`home_screen_test.dart`, grupo "tap sobre banners", primer test) reproduce mi
      metodología original con un título de 59 caracteres y `tester.getRect`; confirmé
      manualmente revirtiendo el fix (quitando `right`/`maxLines`/`overflow` del `Positioned`) que
      el test falla con el mismo patrón: `Expected: <= 740.0, Actual: 1050.9` — mismo tipo de
      solape que documenté en la auditoría anterior — y que vuelve a pasar al restaurar el fix.
      `right: tappable ? 40 : 16`: para `tappable == false` el margen derecho (16) es simétrico
      con el izquierdo (16), consistente y sin layout raro; nótese que el comportamiento
      *previo a la mejora completa* (commit `c0f68f5`, antes de que existiera cualquier versión
      de esta mejora) no tenía `right` en absoluto — un título largo en un banner sin acción
      hacía *wrap* a 2 líneas en vez de truncarse. El fix actual unifica el comportamiento con
      `maxLines: 1` para tappable y no-tappable por igual, lo cual es una mejora deliberada
      razonable (evita que un título largo en un banner sin acción crezca en altura e invada el
      resto del carrusel), no una regresión.
      Comentario desactualizado de `banner.dart:13` (reportado en la auditoría anterior): **corregido** —
      ahora documenta correctamente que `actionValue` es el `id` real, con la explicación de
      banners viejos con valor escrito a mano.
      **Hallazgo nuevo, no bloqueante — riesgo a verificar en dispositivo con títulos reales
      largos**: con `maxLines: 1` + `ellipsis`, medí (`TextPainter` con el estilo real resuelto
      del `RichText` de producción, en un viewport de 360×800 lógicos — Android angosto típico,
      `tester.view.physicalSize = Size(1080, 2400)` @ dpr 3) el ancho intrínseco de los 4 títulos
      reales ya probados en dispositivo vs. el ancho disponible real (`boxWidth` = 252px en ese
      viewport): "PIZZA 2X1" (153.9px, sin riesgo), "2X1 BRASAS" (171.0px, sin riesgo),
      "APROVECHA LA 2X1" (273.6px, **excede el disponible por ~22px → `didExceedMaxLines: true`,
      se truncaría con "…"**), "CARNES SALTADOS" (256.5px, excede por ~4.5px, límite). Medido con
      la fuente de fallback de test (Cinzel vía `google_fonts` no carga en el entorno de test,
      `allowRuntimeFetching = false`) — Cinzel es una serif ornamental típicamente más ancha que
      un fallback sans, así que el riesgo real en dispositivo es igual o mayor, no menor. La
      captura de pantalla que confirmó el fix en el dispositivo real solo usó "PIZZA 2X1" (título
      corto, no representativo de este caso). No es bloqueante porque: (1) el comportamiento
      resultante es degradación controlada (ellipsis), no solape ni corte a mitad de glifo; (2) no
      hay evidencia de que ocurra en el dispositivo físico ya usado para verificar (probablemente
      >360dp de ancho lógico).
      **Riesgo cerrado**: verificado en el dispositivo real (Xiaomi, `adb shell wm density` →
      450dpi, ancho lógico real ≈384dp según `wm size` 1080px físicos — más ancho que el
      viewport de 360dp que asumió la medición con `TextPainter`) con capturas de pantalla
      directas de los 2 títulos señalados como en riesgo: "APROVECHA LA 2X1" y "CARNES SALTADOS"
      se ven completos en ambos casos, sin "…", sin solape con el chevron. La medición con
      `TextPainter`/fuente de fallback fue conservadora (viewport más angosto que el dispositivo
      real de prueba); no bloqueaba el veredicto y ahora además está confirmado con evidencia
      real, no solo con el razonamiento de "no hay evidencia de que ocurra".
      **Hallazgos no bloqueantes de la auditoría anterior, siguen sin ser bloqueantes** (no se
      pidió corregirlos): `http://` vs `https://` en `external_url` (confirmado que no aplica en
      la práctica por cómo `url_launcher_android` invoca `startActivity`), doble-tap en `menuItem`
      (riesgo sistémico preexistente, no exclusivo de banners), `selectedCategoryIdProvider`
      persistente (comportamiento esperado, verificado).
- [x] **Fix del ícono de ubicación del header** (`_HomeHeader`, `home_screen.dart:250-263`, path
      SVG a mano — el parser genérico de `svg_path.dart` no cambió). El punto interior del pin es
      `<circle cx="12" cy="10" r="2.5">` en el mockup real (confirmado leyendo
      `design-reference/Celtas App Mockups.dc.html:133`, no de memoria). El path buggy (`M12 10a2.5
      2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5z`) arrancaba en el CENTRO del círculo; el path fijo (`M9.5 10a2.5
      2.5 0 1 0 5 0a2.5 2.5 0 1 0-5 0z`) arranca en (9.5,10), un punto real de la circunferencia.
      Verificado más allá del test existente (que solo compara `getBounds()`): tracé la curva
      completa con `PathMetric.getTangentForOffset` en 11 puntos equiespaciados y confirmé que es
      un círculo genuino centrado en (12,10) r=2.5 (no una forma degenerada que coincidiera por
      casualidad en el bounding box) — evidencia cruda: `Offset(9.5, 10.0)`, `Offset(10.0, 11.5)`,
      `Offset(11.2, 12.4)`, `Offset(12.8, 12.4)`, `Offset(14.0, 11.5)`, `Offset(14.5, 10.0)`,
      `Offset(14.0, 8.5)`, `Offset(12.8, 7.6)`, `Offset(11.2, 7.6)`, `Offset(10.0, 8.5)`,
      `Offset(9.5, 10.0)` — `bounds: Rect.fromLTRB(9.5, 7.5, 14.5, 12.5)`, coincide con el círculo
      real del mockup. Sin bloqueadores.
- [x] **Barra flotante de carrito en el Home** (`_CartSummaryBar`, `home_screen.dart:136-227`):
      confirmado por lectura de código que vive dentro del `Stack` del `body` de `HomeScreen`
      (`Positioned(left: 0, right: 0, bottom: 0, child: SafeArea(top: false, child:
      _CartSummaryBar(...)))`), no en el shell — nunca reemplaza el bottom nav (que vive en
      `_ShellScaffold`, fuera del árbol de `HomeScreen`). Usa `CeltasColors.card`/`border`/
      `CeltasRadii.card`/`CeltasRadii.pill` consistentes con el resto de la app, sin
      `Color(0xFF...)` sueltos. Cubierta con test explícito en `app_router_test.dart` (oculta sin
      ítems, aparece con 1 ítem con el texto exacto `"1 item · S/ 15.50"`, navega a `/cart` al
      tocarla). `SafeArea(top: false)` anidado dentro del `SafeArea` ya presente en
      `HomeScreen.body` no duplica el padding inferior — comportamiento estándar de `SafeArea`
      (consume el `MediaQuery.padding` una sola vez y lo resetea a 0 para descendientes),
      confirmado por lectura del widget, no es un bug.
      ⚠️ Riesgo no cubierto: no hay test que verifique la transición inversa (1 ítem → 0 ítems,
      ej. tras vaciar el carrito desde `/cart` y volver) — solo se prueba la aparición 0→1. El
      `if (hasCartItems)` en el build hace que desaparecer sea trivialmente correcto por
      construcción (mismo `cartProvider.select` que la muestra), así que el riesgo es bajo, pero
      no está confirmado con un test explícito.

## Carrito / Checkout

- [x] El total lo calcula el backend, la app nunca lo envía ni lo asume
- [x] Ningún flujo de pago procesado dentro de la app en ningún punto
- [x] `whatsappUrl` se abre correctamente; caso de WhatsApp no instalado manejado con mensaje
      claro, no crash
- [x] Carrito se limpia tras confirmar pedido exitosamente
- [x] Validación de cupón (`/coupons/validate`) no lo marca como usado antes de confirmar

## Perfil / Direcciones

- [ ] DTO de edición de perfil no permite cambiar campos que el backend no acepta
- [ ] CRUD de direcciones con verificación de que pertenecen al usuario (aunque esto lo
      garantiza el backend, confirmar que la UI no intente operar sobre IDs ajenos)

## Pedidos / Cupones

- [x] Badges de estado de pedido visualmente distinguibles entre sí (los 5 estados)
- [x] Historial de pedidos trae la lista completa vía `GET /orders/me` — confirmado que ese
      endpoint NO pagina ni filtra por status para el cliente (solo `GET /orders`, admin-only,
      lo hace); no debe asumirse ni construirse paginación para `/orders/me` ni `/coupons/me`
      (mismo patrón sin paginar)
- [x] El historial refleja un pedido recién creado al volver del checkout (invalidar +
      re-fetchear, no insertar a mano)
- [x] Cupones muestran estado (activo/usado/expirado) correctamente
- [x] Monto mínimo de compra (`minPurchaseAmount`): el subtotal del carrito se envía a
      `POST /coupons/validate` para que el backend rechace cupones que no lo alcanzan con su
      mensaje real; `0` se trata igual que `null` ("sin mínimo", mismo criterio que
      `celtas-admin`)
- [x] Si el subtotal cae por debajo del `minPurchaseAmount` del cupón ya aplicado al decrementar
      cantidades o quitar un ítem, el cupón se retira solo del preview (con aviso explícito por
      `SnackBar` si el carrito sigue con ítems; sin aviso si queda vacío) — el usuario ya NO ve un
      descuento de vista previa que el backend rechazaría al confirmar (`CartNotifier._clearCouponIfInvalid`)
- [x] Ese mismo re-chequeo cubre la ventana de carrera entre "aplicar cupón" (network async) y
      una edición de cantidades concurrente durante la espera: `CartNotifier.applyCoupon` ahora
      re-valida el mínimo contra el subtotal ACTUAL (no el que existía cuando arrancó la
      validación) antes de aceptar el cupón — si ya no alcanza, no lo aplica y devuelve `false`
      para que la UI muestre el mismo mensaje que daría el backend, en vez de un descuento de
      vista previa inválido (hallazgo original del `tester`, cerrado con test de regresión con
      `Completer` simulando la carrera)
- [x] **Vaciar carrito** (`cart_screen.dart`, commits `272a04e` + `a737e50`): ícono en el header
      solo con ítems + diálogo de confirmación (CANCELAR/VACIAR, mismo patrón ya usado en
      `profile_screen._confirmLogout` y `addresses_screen._confirmDelete`) + `clear()` resetea
      ítems y cupón en un solo paso (`state = const CartState()`). `flutter analyze` limpio,
      219/219 tests pasan, incluida la cobertura (carrito vacío sin ícono, apertura del diálogo,
      CANCELAR no toca el carrito, VACIAR limpia ítems y cupón). Re-auditado: el fix en
      `a737e50` cambió `IconButton` → `GestureDetector` + `Icon(delete_outline, size: 18,
      color: CeltasColors.redLight)`, alineado byte a byte con `addresses_screen.dart:441-449`
      (único otro ícono de borrado con confirmación del proyecto). Confirmado con `grep -rn
      "IconButton(" lib`: no queda ningún `IconButton` de Material en `lib/` (los únicos
      matches son widgets propios `_CircleIconButton` / `_CartIconButton`, sin relación). El
      comentario del código ahora referencia correctamente `addresses_screen.dart` como
      precedente, ya no la referencia inexacta a "Home/Mis Cupones". Sin bloqueadores.
- [x] **Selector de cupón propio desde el carrito** (`coupon_picker_sheet.dart`, commit
      `b911bb7`): filtra por `UserCoupon.effectiveStatus == active` (no `status` crudo) —
      confirmado contra `CouponsService.findMyCoupons` (`../celtas-backend/src/modules/coupons/
      coupons.service.ts`), que devuelve la entidad TypeORM cruda sin la corrección del cron
      diario. Elegibilidad usa el mismo criterio que el resto de la app
      (`!hasMinPurchase || subtotal >= minPurchaseAmount`, `0`/`null` tratados igual como "sin
      mínimo"); boundary `subtotal == minPurchaseAmount` verificado con test nuevo (elegible, no
      bloqueado). El sheet solo hace `Navigator.pop(coupon.code)` — la validación real sigue
      pasando por `POST /coupons/validate` vía `_applyCoupon()`, sin duplicar esa llamada
      (`verify(...).called(1)` en el test de "elegir un cupón elegible"). Sin `Color(0xFF...)`
      sueltos, usa `CeltasColors`/`CeltasRadii.input`/`CeltasRadii.card` consistentes con el
      resto de tarjetas de cupón y checkout. Se agregaron 2 tests de regresión que el commit no
      cubría: boundary exacto del mínimo, y reapertura del sheet tras cerrarlo sin elegir nada
      (no deja el picker en un estado roto). 227/227 tests, `flutter analyze` limpio. Sin
      bloqueadores.
- [x] **Ajustes visuales post-cierre en el carrito** (`cart_screen.dart`): ícono de papelera
      (vaciar carrito, `ValueKey('cart-clear')`) agrandado de `size: 18` a `size: 24` +
      `Padding(4)` (tap target ~32dp) — sigue siendo `GestureDetector` + `Icon`, no `IconButton`
      (confirmado de nuevo con `grep -rn "IconButton(" lib`: 0 matches reales). "VER MIS
      CUPONES" pasó de `Text` plano a un chip real (`Container` con `CeltasColors.buttonSurface`
      + `border: Border.all(color: CeltasColors.orange)` + `CeltasRadii.pill`) — mismo
      `ValueKey('cart-coupon-picker')`. `CeltasColors.buttonSurface` no es un token nuevo:
      confirmado con `grep -rn "buttonSurface" lib/` que ya lo usa el botón "Aplicar" del cupón en
      la misma pantalla (`cart_screen.dart:601`) — consistente, no inventado para este chip.
      Ambos cambios cubiertos por los tests ya existentes (mismos `ValueKey`, sin necesidad de
      tests nuevos). `flutter analyze` limpio, 258/258 tests. Sin bloqueadores.

## Notificaciones

- [x] Token de FCM se registra tras login (`PATCH /users/me/fcm-token`)
- [x] Falla de registro de token no rompe el flujo de login
- [x] **Historial local de notificaciones** (`/notifications`, `NotificationHistoryItem` +
      `NotificationHistoryRepository` + `NotificationHistoryNotifier` +
      `NotificationsScreen`, persistido con `shared_preferences` — justificado, no es dato
      sensible como el `refreshToken`). `flutter analyze` limpio, `flutter test` 258/258
      (verificado de forma independiente, salida cruda abajo). Ruta `/notifications` sí está en
      `_protectedPaths` (`app_router.dart:36`), campana del Home navega ahí
      (`home_screen.dart:294-307`), tap sobre un ítem reusa `NotificationTarget.fromPayload`
      sin duplicar la clasificación (`notifications_screen.dart:94-103`). Modelo
      `fromJson(toJson())` roundtrip correcto (incluido `DateTime` y el `data` crudo). Sin
      `IconButton`/`Color(0xFF...)` sueltos; estados de carga/error/vacío explícitos y
      cubiertos por test para vacío y datos, pero NO para error (ver hallazgo abajo).

      ❌ **Falló — condición de carrera real en `NotificationHistoryNotifier.add()`, el fix
      documentado (`await future` antes de mutar) NO cierra el caso pedido**
      (`notification_providers.dart:33-38`). El `await future` solo protege `add()` vs `build()`
      todavía en curso (el caso que sí prueba `notification_history_provider_test.dart:59-73`).
      Pero **dos llamadas a `add()` concurrentes SÍ pierden un ítem**: `future` es una property
      *getter* (`_element.futureNotifier.value`, ver
      `~/.pub-cache/hosted/pub.dev/riverpod-2.6.1/lib/src/async_notifier/base.dart:86-89`) que
      ambas llamadas leen ANTES de que la primera alcance a mutar `state` — si `add(A)` y
      `add(B)` se disparan sin `await` entre medio (ej. dos pushes casi simultáneos, foreground +
      background, o dos notificaciones seguidas mientras la primera todavía está
      guardando en `shared_preferences`), ambas capturan el mismo `current` (la lista base, sin
      ninguno de los dos ítems nuevos). `add(A)` corre primero y deja `state = [A, ...base]`, pero
      `add(B)` fue programado como microtask ANTES de que A mutara el estado, así que cuando B
      retoma ejecución usa su propio `current` ya capturado (la lista base, sin A) y sobrescribe
      con `state = [B, ...base]` — **A se pierde**. Reproducido con un test ad hoc (no incluido en
      el suite, descartado tras la prueba, mismo criterio que el hallazgo de solape de banners de
      la auditoría anterior): dos `add()` sin `await` entre medio → `state` termina con 1 solo
      ítem, no 2. Salida cruda:
      ```
      STATE: [NotificationHistoryItem(title: Notificación 1, body: Cuerpo 1, receivedAt:
      2026-01-01 00:01:00.000Z, data: {orderId: order-1})]
      Expected: <2>
        Actual: <1>
      ```
      (perdió `itemAt(0)`, quedó solo `itemAt(1)`). Riesgo real en producción: `onMessage`,
      `onMessageOpenedApp` y el mensaje inicial llaman `_saveToHistory` de forma independiente y
      sin coordinación — dos notificaciones (ej. cambio de estado de pedido + cupón nuevo)
      llegando con pocos milisegundos de diferencia disparan `add()` dos veces sin que la primera
      haya terminado de resolver `future`/`save()`. Sugerencia para la sesión principal: serializar
      las mutaciones (ej. encadenar cada `add()` sobre una `Future` interna tipo mutex, o leer
      `state.value`/`state.valueOrNull` directo en vez de `await future` ya que dentro de un
      método síncrono-hasta-el-primer-await el `state` actual ya refleja cualquier mutación previa
      aplicada síncronamente).

      ⚠️ **Riesgos / casos borde no cubiertos**:
      - `_saveToHistory` (`notification_service.dart:120-136`) descarta silenciosamente cualquier
        notificación cuyo `NotificationTarget.fromPayload` sea `NoneNotificationTarget` (`if
        (target is NoneNotificationTarget) return;`) — pero `_showLocalNotification` (línea
        159-178) SÍ la muestra en la bandeja del sistema/banner en foreground sin ese filtro (solo
        exige `message.notification != null`). Esto crea una asimetría: si el backend alguna vez
        manda una notificación genérica sin `orderId`/`couponCode` en `data` (ej. un anuncio o
        promo sin deep link), el usuario la ve aparecer en el teléfono pero después, al abrir la
        campana, no está en el historial — puede razonablemente esperar verla ahí. Con el
        contrato actual del backend (confirmado en el comentario del archivo: solo
        `{orderId,status}` o `{couponCode}`, sin un tercer tipo) esto no ocurre en la práctica hoy,
        así que no es bloqueante, pero es una trampa si el backend agrega notificaciones genéricas
        a futuro sin que alguien recuerde tocar este filtro.
      - `NotificationHistoryNotifier.add()` actualiza `state` con la lista COMPLETA sin recortar a
        `_maxItems` (50) — el recorte solo pasa dentro de `NotificationHistoryRepository.save()`
        (`.take(_maxItems)`) para lo que se persiste en disco. En una sesión larga con muchas
        notificaciones, la lista en memoria (lo que la pantalla `/notifications` renderiza) puede
        crecer sin límite dentro de esa sesión, aunque al reiniciar la app solo se recarguen 50.
        Inconsistencia menor, no crashea (no hay paginación ni límite de renderizado en la
        pantalla tampoco), pero vale la pena capar `add()` igual que `save()`.
      - Sin test para el estado de error de `NotificationsScreen`
        (`_NotificationsError`/`No se pudo cargar tu historial de notificaciones`) — el código lo
        maneja (falla de `shared_preferences`/JSON corrupto en `load()`), pero no hay cobertura
        de regresión, a diferencia del resto de pantallas con estados error/vacío/carga
        explícitamente testeados.
      - No existe `notification_service_test.dart` — `NotificationService` (incluido el nuevo
        `_saveToHistory`) sigue sin tests unitarios/de integración (gap preexistente al módulo 9,
        no introducido por esta mejora, pero la mejora le agregó lógica nueva sin agregar
        cobertura).

      **Veredicto de este ítem: PENDIENTE** — la condición de carrera de `add()` vs `add()` es un
      bug real con evidencia reproducible, no solo un caso de laboratorio (dos pushes casi
      simultáneos son plausibles en producción). No se corrige acá — reportado para la sesión
      principal.

      **Corregido en la sesión principal** (`notification_providers.dart`): `add()` ahora encadena
      cada mutación sobre una `Future` interna (`_mutationQueue`), en vez de solo esperar `future`
      antes de mutar — con esto, un segundo `add()` disparado antes de que el primero termine
      queda en cola y arranca recién cuando el anterior ya mutó `state`, cerrando también el caso
      "`add()` vs `add()` en curso" (no solo "`add()` vs `build()` en curso", que ya cerraba el fix
      anterior). El encadenado sigue avanzando aunque una mutación falle (`.catchError`), para que
      una notificación que no se pudo guardar no trabe las siguientes. Test de regresión agregado
      (`notification_history_provider_test.dart`, "dos add() concurrentes..."): dos `add()` sin
      `await` entre medio → ambos ítems sobreviven en `state` y en lo persistido, reproduciendo
      exactamente el escenario que encontró `@tester` (antes del fix este mismo test fallaba con
      `Expected: <2>, Actual: <1>`, igual que el hallazgo original).

      De los riesgos no bloqueantes reportados arriba, también se cerraron:
      - **Recorte de `add()` a `NotificationHistoryRepository.maxItems`** (renombrado de `_maxItems`
        a público, para no duplicar el número mágico 50 entre el repositorio y el notifier): la
        lista en memoria ya no puede crecer sin límite dentro de una sesión larga. Test de
        regresión agregado (`add() recorta la lista en memoria...`).
      - **Estado de error de `NotificationsScreen` sin cobertura**: test agregado
        (`notifications_screen_test.dart`, "error al cargar el historial → mensaje y REINTENTAR").
      - **Transición 1→0 ítems de `_CartSummaryBar` sin cobertura** (reportado en la misma
        auditoría, sección Home/Menú de este documento): test agregado en `app_router_test.dart`
        ("barra de resumen del carrito en Home: transición 1→0 ítems la oculta de nuevo").

      Quedan documentados, sin corregir (mismo criterio de "no bloqueante" que el resto del
      proyecto — no hay evidencia de que ocurran con el contrato actual del backend):
      - La asimetría de `NoneNotificationTarget` (se muestra en el sistema pero no queda en el
        historial) — solo importaría si el backend agrega un tercer tipo de notificación sin
        `orderId`/`couponCode`, lo cual no existe hoy.
      - Falta de `notification_service_test.dart` — gap preexistente al módulo 9, no introducido
        por esta mejora.

      **Segunda pasada de `@tester`, independiente**: confirmó con salida cruda propia (no la
      mía) `flutter analyze` limpio y `flutter test` 262/262, incluido el archivo aislado de
      notificaciones (`+3: dos add() concurrentes... pasa`, `+4: add() recorta la lista en
      memoria... pasa`). Trazó a mano la semántica síncrona de Dart en `add()`/`_addLocked()` para
      confirmar que el encadenado sobre `_mutationQueue` cierra la carrera de verdad (dos llamadas
      sin `await` entre medio leen/escriben el campo en el mismo tick, sin ventana de carrera
      posible; `.then()` no arranca el callback hasta que el anterior de la cola resuelve
      *enteramente*, incluido el `await save(...)` interno; `.catchError` mantiene la cadena viva
      sin perder el error para el caller original) — no encontró forma de que dos `add()` se sigan
      pisando. Verificó también que los tests de estado de error y transición 1→0 cubren
      genuinamente el código real (textos exactos de `_NotificationsError`, flujo real de agregar
      + `clear()` sobre el mismo árbol). Única limitación reportada: no pudo completar el
      experimento adicional de revertir el fix en una copia y confirmar que el test falla sin él
      (falla de tooling de shell a mitad de sesión, no relacionada con el código) — mitigada por
      la revisión de código detallada. **Veredicto final: LISTO PARA MARCAR COMPLETO.**

- [x] **Auditoría independiente — 6 mejoras/fixes sin commitear (Home, Producto/Carrito,
      Notificaciones): fix de raíz de `svg_path.dart` (S/s, T/t), corazón de favoritos quitado
      del detalle, `SafeArea` en `product_detail_screen.dart`, `maxItems` 50→30, badge de no
      leídas + `markAllRead()`, margen del `SnackBar` "Agregado"**. `flutter analyze` limpio
      (verificado de forma independiente, salida cruda: `No issues found!`). `flutter test`
      272/272 antes de agregar cobertura propia, 276/276 después (verificado con salida cruda,
      no solo confiando en el reporte de la sesión principal).

      ✅ **Pasó**:
      - **`svg_path.dart` — `smoothCubicTo`/`smoothQuadTo`**: revisado línea por línea. `c1`/`cx`
        se calculan en coordenadas YA absolutas (reflejo del último punto de control, o el punto
        actual si no hay uno previo); si el comando es relativo, `c2`/`nx`/`ny` (o `nx`/`ny` en el
        caso de `T`/`t`) se convierten a mano a absolutos ANTES de delegar en
        `cubicTo`/`quadTo`, y esa delegación siempre usa `relative: false` — confirma que ya no
        se duplica el offset (el bug real: delegar el `relative` original de vuelta a
        `cubicTo`/`quadTo`, que le volvía a sumar `x,y` a un `c1` que ya los tenía).
      - **Barrido propio de todo `lib/` buscando comandos `s`/`t`** (no confié en el barrido de
        la sesión principal): confirmado con `grep` que los únicos paths reales de la app que
        usan `S`/`s` son el pin y la campana de `home_screen.dart`, la campana de
        `profile_screen.dart`, el ícono de WhatsApp de `checkout_screen.dart`, y el ícono
        "Perfil" del bottom nav (`celtas_bottom_nav.dart`) — exactamente los 4 sitios que reporta
        la sesión principal, ninguno más, ninguno menos. Ningún path real de la app usa `T`/`t`
        (solo se ejercita en tests sintéticos). Calculé `getBounds()` de los 5 paths reales
        afectados con la función real del proyecto (no una reimplementación mía) — los 5 caen
        dentro de un viewBox 24×24 razonable: pin `Rect.fromLTRB(5.0, 3.0, 19.0, 22.0)`, punto del
        pin `Rect.fromLTRB(9.5, 7.5, 14.5, 12.5)`, campana (Home) `Rect.fromLTRB(3.0, 2.0, 21.0,
        22.0)`, campana (Perfil) `Rect.fromLTRB(3.0, 2.0, 21.0, 17.0)`, WhatsApp
        `Rect.fromLTRB(1.8, 1.9, 22.5, 22.3)`, Perfil (bottom nav) `Rect.fromLTRB(4.0, 4.0, 20.0,
        21.0)`.
      - **Corazón de favoritos**: confirmado que `product_detail_screen.dart` ya no tiene
        `_liked` ni un segundo `_CircleIconButton` — solo queda el de volver.
      - **`SafeArea`**: auditoría propia (no la de la sesión principal) de TODOS los `Scaffold(` de
        `lib/` — confirmado que `product_detail_screen.dart` es el único screen que le faltaba
        (`body: SafeArea(top: false, ...)`, mismo criterio que `celtas_bottom_nav.dart`); el resto
        ya lo tenía, incluido `splash_screen.dart` (que envuelve el `SafeArea` dentro de un
        `Stack`, no como hijo directo de `body`, pero cumple la misma función).
      - **`maxItems` 30**: confirmado en `notification_history_repository.dart` y su test.
      - **Campo `read` sobre JSON viejo sin esa key**: confirmado en el `.g.dart` generado
        (`read: json['read'] as bool? ?? false`) — no explota, cae en `false`. Sin test previo
        para este caso exacto; agregado por mí (ver abajo).
      - **Cola de mutaciones `add()`/`markAllRead()`**: revisado a mano — ambos métodos encolan
        sobre el mismo `_mutationQueue` de forma síncrona (antes de cualquier `await`), así que el
        orden de ejecución es estrictamente FIFO según el orden de llamada, y cada mutación
        (incluido su `await save(...)` interno) termina por completo antes de que arranque la
        siguiente. No hay ventana de carrera real entre `add()` y `markAllRead()`: en el peor caso
        el resultado depende del orden de llamada (esperado), pero ninguna notificación se pierde
        ni queda en un estado inconsistente. Sin test previo que ejercitara este caso
        específicamente (los existentes solo cubren `add()` vs `add()`); agregado por mí.
      - Badge de la campana: mismo patrón visual que el badge del carrito (`CeltasColors.orange`/
        `CeltasColors.black`, mismas constraints/padding) — sin colores sueltos.
      - Margen del `SnackBar` "Agregado" (`EdgeInsets.fromLTRB(16, 0, 16, 88)`) confirmado en
        ambos sitios (`home_screen.dart` y `product_detail_screen.dart`), mismo valor de 88 ya
        usado para el padding inferior del `ListView`/`_CartSummaryBar`.

      ⚠️ **Cobertura que faltaba, agregada por mí** (regla 4: lógica crítica sin test propio):
      - `test/features/notifications/data/models/notification_history_item_test.dart`: nuevo
        caso que llama `fromJson()` sobre un `Map` SIN la key `read` (no `null`, ausente del
        todo — la forma real de un JSON persistido antes de este cambio) y confirma `item.read ==
        false`.
      - `test/features/notifications/application/notification_history_provider_test.dart`: dos
        casos nuevos — (1) `add()` y `markAllRead()` disparados sin `await` entre medio, con
        `markAllRead()` encolado antes que el `add()` de una notificación nueva, confirmando que
        ninguna se pierde y que el resultado final respeta el orden FIFO de la cola (la nueva
        queda sin leer porque llegó DESPUÉS del marcado); (2) `markAllRead()` llamado dos veces
        seguidas cuando ya todo está leído no reescribe `state` (mismo `List` en memoria,
        `identical()`), confirmando el `return` temprano de `_markAllReadLocked` para evitar un
        `save()` de más en cada apertura de la pantalla sin novedades.
      - `test/core/router/app_router_test.dart`: caso de punta a punta con navegación REAL de
        `go_router` (no un fake aislado) — historial persistido de antes con 2 no leídas, login,
        badge visible con "2", tap en la campana, `pop()` con el botón real de volver
        (`notifications-back`), y confirmación de que el badge ya no aparece al volver al Home.
        Este caso no estaba cubierto: los tests existentes probaban el badge y el
        `markAllRead()`-al-entrar por separado, con providers fake, pero no la cadena completa a
        través del router real.

      ⚠️ **Riesgos no cubiertos, no bloqueantes**:
      - Sigue sin existir `notification_service_test.dart` (gap preexistente, documentado en
        auditorías anteriores, no introducido por esta ronda).
      - La fidelidad de diseño del badge de la campana (color/tamaño) se verificó por
        comparación de código contra `_CartIconButton` (ya auditado en una ronda anterior), no
        contra `design-reference/` directamente — no hay mockup de este badge en
        `design-reference/` porque `NotificationsScreen` es una pantalla nueva sin precedente ahí
        (documentado también en auditorías anteriores).

      **Veredicto: LISTO PARA MARCAR COMPLETO.** Ningún bug real encontrado en esta ronda — las 6
      mejoras se verificaron contra el código real (no contra la descripción de la sesión
      principal) y quedaron con cobertura de test adicional donde faltaba.

---

## Reporte de auditoría (formato esperado del @tester)

```
## Auditoría: <nombre del módulo>

✅ Pasó:
- ...

❌ Falló:
- [archivo/widget] — descripción exacta del problema

⚠️ Riesgos / casos borde no cubiertos:
- ...

Veredicto: LISTO PARA MARCAR COMPLETO / PENDIENTE
```
