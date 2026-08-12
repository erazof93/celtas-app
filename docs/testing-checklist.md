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

## Notificaciones

- [x] Token de FCM se registra tras login (`PATCH /users/me/fcm-token`)
- [x] Falla de registro de token no rompe el flujo de login

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
