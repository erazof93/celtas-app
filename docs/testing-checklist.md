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
      Riesgo de mantenimiento — **RESUELTO**, ver sección "Refactor: `showCeltasSnackBar`
      compartido" más abajo (bajo Producto + Carrito): el bloque duplicado en este archivo y en
      `cart_screen.dart`/`product_detail_screen.dart`/`home_screen.dart` se consolidó en
      `lib/shared/widgets/celtas_snackbar.dart`.

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

### Cartel de "local cerrado" en el Home, event-driven vía `nextChangeAt` (reemplaza un intento previo con `Timer.periodic`, nunca comiteado) — ✅ COMPLETO

Última pieza de la feature cross-repo "horario de atención" (backend y `celtas-admin` ya
cerrados en sus propios repos, con el bloqueo real del checkout — 409 de `POST /orders` — y su
aviso preventivo ya auditados en la sección "Bloqueo por local cerrado en el checkout" de más
abajo, sin cambios ahí salvo extraer el widget visual a uno compartido). Contrato nuevo
verificado contra el código fuente real del backend, no asumido: `backend-celtas/src/modules/
settings/settings.controller.ts` (`businessHours()`) y `settings.service.ts`
(`getNextChangeAt()`) — `GET /settings/business-hours` ahora también devuelve `nextChangeAt`
(ISO 8601 UTC o `null`), el instante exacto en que `open` va a cambiar, calculado a partir del
horario programado en hora de Lima; `null` cuando el cierre manual está activo (impredecible) o
el horario configurado nunca abre (los 7 días `closed`). Confirmado en vivo contra el backend de
producción (`curl https://backend-celtas.onrender.com/settings/business-hours`, local realmente
cerrado en el momento de la verificación): `nextChangeAt` presente con el local cerrado.

Mecanismo **event-driven, no polling** (decisión de arquitectura explícita para reducir carga
sobre Render free con muchos usuarios concurrentes) en `home_screen.dart`
(`_HomeScreenState`, `HomeScreen` pasó de `ConsumerWidget` a `ConsumerStatefulWidget` con
`WidgetsBindingObserver`): `ref.listenManual(businessHoursProvider, ..., fireImmediately: true)`
programa un único `Timer` (nunca periódico) contra `nextChangeAt` + un margen de deriva de reloj
de 5s; al disparar, solo hace `ref.invalidate(businessHoursProvider)` — el propio `listenManual`
reprograma con el `nextChangeAt` nuevo que llegue, autoperpetuándose. `nextChangeAt: null` → no
se programa nada. `AppLifecycleState.resumed` cancela cualquier timer pendiente y reconsulta de
inmediato. `businessHoursProvider` (`FutureProvider`, sin `.autoDispose`) no se tocó — ya era
observable por igual desde `home_screen.dart` que desde `checkout_screen.dart` sin ajustes. El
cartel (`BusinessClosedNotice`, extraído de `_ClosedNotice` del checkout a
`shared/widgets/business_closed_notice.dart`, mismo bloque visual sin cambio, reutilizado por
ambas pantallas) es puramente informativo — NO deshabilita nada, el cliente sigue pudiendo
navegar y agregar productos al carrito con el local cerrado.

**Bug real encontrado y corregido durante el desarrollo de esta misma sesión** (no se omite ni
se suaviza): la primera versión de `_onBusinessHoursChanged` decidía si reprogramar el timer con
`next.valueOrNull` (o incluso `next is AsyncData<BusinessHours>` a secas). Riverpod 2.x, mientras
un `invalidate()` está en vuelo, entrega `AsyncData(isLoading: true, value: <valor ANTERIOR>)` —
sigue siendo `AsyncData` (no un `AsyncLoading` aparte, para no parpadear la UI), pero con datos
VIEJOS. Reaccionar a eso reprogramaba un timer contra un `nextChangeAt` YA VENCIDO, que disparaba
casi de inmediato y generaba un `invalidate()` fantasma mientras el fetch real todavía estaba en
vuelo — una carrera real entre el timer viejo y el refetch de `resumed`. El chequeo correcto,
verificado con un test que reproduce la carrera exacta, es
`if (next is! AsyncData<BusinessHours> || next.isLoading) return;` en
`lib/features/home/presentation/home_screen.dart` — exige un valor `AsyncData` genuinamente
asentado, nunca en medio de un refresco.

`flutter analyze` (salida cruda propia): `No issues found!`. `flutter test` (suite completa,
salida cruda propia): `359: All tests passed!`.

✅ Pasó:
- **Diff real revisado completo** (`git diff`), no solo el resumen del encargo — coincide con lo
  descrito: `home_screen.dart` (`ConsumerWidget` → `ConsumerStatefulWidget`), `business_hours.dart`
  + regenerados `.freezed.dart`/`.g.dart` (`nextChangeAt` parseado a `DateTime` real vía
  `DateTime.parse`, no queda `String` suelto — confirmado en el `.g.dart` generado), extracción
  transparente de `_ClosedNotice` → `BusinessClosedNotice` (mismo `key:
  ValueKey('checkout-closed-notice')` preservado en el checkout, contenido visual idéntico
  carácter por carácter en el diff).
- **Las 3 mutaciones del encargo, repetidas de forma independiente** (no solo confiando en las ya
  hechas por la sesión principal), cada una revertida y confirmada con `git diff` idéntico al
  original después:
  1. `rawDelay + _clockDriftMargin` → `rawDelay - _clockDriftMargin` (fires-not-early): falla
     exactamente el test `'el timer se dispara en el instante de nextChangeAt ..., no antes'`
     (`Expected: <1> Actual: <2>`), con el efecto cascada esperado sobre el test de la carrera.
  2. Se quitó el `if (nextChangeAt == null) return;` (con un fallback de 1h para no crashear):
     falla exactamente el test `'nextChangeAt: null ... → NO programa ningún timer'`
     (`Expected: <1> Actual: <2>`), y en cascada 5 tests más que dependían de que no hubiera timer
     previo activo.
  3. Se quitó `|| next.isLoading` del chequeo: falla exactamente el test de la carrera
     (`'resumed cancela el timer viejo de inmediato (síncrono) ...'`, `Expected: <2> Actual: <3>`
     — el refetch fantasma que describe el bug real encontrado durante el desarrollo), reproduce
     el bug documentado arriba de forma consistente.
- **`ref.listenManual` sin `.close()` en `dispose()` verificado que NO es un leak**: confirmado
  leyendo `flutter_riverpod-2.6.1/lib/src/consumer.dart` (doc del método + implementación en
  `ConsumerStatefulElement.unmount()`) que la suscripción se cierra automáticamente cuando el
  widget se desmonta — no hacía falta guardar/cerrar la suscripción a mano.
- **Barrido propio (no solo confiar en el de la sesión principal) de `test/` buscando otros
  lugares que monten el `HomeScreen` real sin stubear `businessHoursProvider`**: `grep -rn
  "HomeScreen"` en todo `test/` solo encuentra referencias en `home_screen_test.dart` (su propio
  archivo) y `app_router_test.dart` (que ya stubea `businessHoursProvider` en su `overrides()`
  compartido). `cart_screen_test.dart` y `product_detail_screen_test.dart` registran la ruta
  `/home` pero con un `Scaffold(body: Text('HOME'))` falso, no el `HomeScreen` real — confirmado
  leyendo el código de sus routers de prueba, no solo el resumen del encargo.
- **Contrato de `nextChangeAt` verificado contra el código fuente real del backend**
  (`backend-celtas/src/modules/settings/settings.controller.ts`/`settings.service.ts`, no contra
  el resumen del encargo): `getNextChangeAt()` siempre calcula el próximo instante hacia adelante
  desde `reference = new Date()` (el reloj del propio servidor al momento del request) — nunca
  devuelve un instante ya vencido *según su propio reloj*. La única forma de que el cliente reciba
  un `nextChangeAt` ya vencido es la latencia de red / cold-start de Render (documentado hasta
  30-50s), que es exactamente el caso que `rawDelay.isNegative ? Duration.zero : ...` maneja
  correctamente (dispara casi de inmediato en vez de con un delay negativo inválido).
- **Diseño del margen de 5s y el caso borde de `nextChangeAt` muy vencido al arrancar la app**:
  evaluado explícitamente — no es un bug. `Duration.zero` dispara el refetch casi de inmediato, lo
  cual es el comportamiento correcto (el estado real cambió hace rato, hay que reflejarlo ya). El
  refetch resultante siempre calcula un `nextChangeAt` genuinamente futuro desde el reloj del
  servidor en ESE momento (nunca repite el mismo instante ya vencido), así que no hay riesgo de
  loop ajustado de refetch continuo bajo operación normal.

❌ Falló:
- Ninguno funcional.

⚠️ Riesgos / hallazgos menores no bloqueantes:
- **No verificado en vivo con el Home realmente abierto** en dispositivo/emulador ni contra
  `celtas-admin` con credenciales de admin (ni en esta auditoría ni en el desarrollo original) —
  solo se verificó en vivo el contrato de `GET /settings/business-hours` contra producción (con
  el local realmente cerrado, `nextChangeAt` presente) y todo lo demás vía widget tests +
  lectura de código fuente real (mobile + backend). Queda pendiente confirmar visualmente en un
  dispositivo real que el cartel se ve/actualiza como se espera y que el timer sobrevive
  correctamente el ciclo real de background/foreground de Android (no solo el simulado por
  `tester.binding.handleAppLifecycleStateChanged` en los widget tests).
- **Riesgo teórico, no observado, de refetch ajustado si el backend devolviera repetidamente un
  `nextChangeAt` ya vencido por un margen mayor al esperado** (ej. si el reloj del servidor
  estuviera mal configurado, o Render tarda mucho más de los 30-50s documentados en despertar):
  no habría loop infinito porque cada refetch recalcula un `nextChangeAt` genuinamente nuevo
  desde el reloj del servidor en ese momento (confirmado leyendo `getNextChangeAt()`), pero no
  hay ningún backoff explícito del lado mobile si esto llegara a fallar — bajo riesgo dado cómo
  está implementado el backend, sin evidencia de que ocurra, no bloqueante.

**Veredicto: LISTO.**

## Carrito / Checkout

- [x] El total lo calcula el backend, la app nunca lo envía ni lo asume
- [x] Ningún flujo de pago procesado dentro de la app en ningún punto
- [x] `whatsappUrl` se abre correctamente; caso de WhatsApp no instalado manejado con mensaje
      claro, no crash
- [x] Carrito se limpia tras confirmar pedido exitosamente
- [x] Validación de cupón (`/coupons/validate`) no lo marca como usado antes de confirmar

### Persistencia del carrito en caché local (`SharedPreferences`) — auditoría @tester

Fix de un defecto reportado: los ítems del carrito se perdían al cerrar y reabrir la app.
Archivos: `lib/features/cart/data/cart_storage.dart` (NUEVO), `cart_item.dart`
(`toStorageJson`/`fromStorageJson` manuales), `cart_provider.dart`
(`CartState.toJsonForStorage` + `_saveCartToStorage()` fire-and-forget en cada mutación +
rehidratación síncrona en `build()`), `lib/main.dart` (pre-carga `SharedPreferences` + override
del `cartStorageProvider`).

Checklist específico:

- [ ] `flutter analyze` limpio — **verificado por @tester**: `No issues found! (ran in 4.7s)`
- [ ] `flutter test test/features/cart/` verde — **verificado**: `95: All tests passed!`
- [ ] `flutter test` (suite completa) verde — **verificado**: `+521 ~1: All tests passed!`
      (el `~1` skip es preexistente, no relacionado)
- [ ] Contrato de API: N/A — el JSON de `cart_v1` es 100% local, nunca se envía al backend
      (el `POST /orders` sigue mandando solo `menuItemId`+`quantity`+`sauceIds`). No hay
      contrato externo contra el cual hacer cross-check. `selectedSauces` reusa el
      `SauceOption.toJson`/`fromJson` ya generado (`{id,name}`), que sí está atado al contrato
      de `GET /menu` y no cambió.
- [ ] Fidelidad de diseño: N/A — feature sin UI propia.
- [ ] `accessToken`/dato sensible NO va acá — **OK**: el carrito no es dato sensible; usa
      `SharedPreferences`, nunca `flutter_secure_storage` (mismo criterio que
      `SeenRewardsStorage`/`NotificationHistoryRepository`).
- [ ] Caché ilegible no rompe el arranque — **OK**: `load()` tiene try/catch total; JSON
      corrupto / shape inesperado / entrada malformada → `[]`. Cubierto con test (`'JSON
      corrupto en la caché → carrito vacío, sin crash'`).
- [ ] Escritura best-effort no propaga errores a la UI — **OK**: `save()`/`clear()` tragan
      excepciones; el notifier llama `unawaited(...)`.
- [ ] Modo degradado (sin override en `main.dart`) no crashea — **OK**: default
      `CartStorage()` sin `prefs` → `load()` devuelve `[]`, `save()` resuelve `getInstance()`
      perezosamente. Cubierto con test.
- [ ] Rewards NO se persisten — **OK**: `toJsonForStorage` excluye `rewardRedemptionId != null`.
      Cubierto con test.
- [ ] Cupón / `couponRemovedNotice` NO se persisten — **OK**. Cubierto con test.
- [ ] `clear()` del notifier vacía la caché — **OK** (escribe `{'items': []}`, no `remove`).
      Cubierto con test.

**Huecos de cobertura encontrados (tests que faltan, no bugs):**

1. Round-trip de `image != null` — todos los tests de persistencia usan ítems sin `image`.
   El path `if (image != null) 'image': image` + `json['image'] as String?` está sin ejercitar.
2. Round-trip de `explicitlyNoSauces: true` — se persiste (`if (explicitlyNoSauces)`) y se lee
   (`as bool? ?? false`), pero ningún test de persistencia lo verifica de punta a punta.
3. Round-trip de varias salsas a la vez — solo se prueba `[mayo]` (una). No se prueba
   `[mayo, mostaza]` ni el orden tras rehidratar.
4. Comentario con emoji / caracteres no-ASCII — `jsonEncode`/`jsonDecode` lo manejan, pero no
   hay test. Riesgo bajo.
5. "Última escritura gana" bajo mutaciones rápidas consecutivas — implícitamente cubierto (el
   test de rehidratación hace 2 `addItem` seguidos y un solo `pumpEventQueue`), pero no hay un
   test explícito que fuerce el interleaving de dos `save()` `unawaited`.

**Riesgos / hallazgos no bloqueantes:**

- `CartStorage.clear()` es **código muerto**: nadie lo llama. `CartNotifier.clear()` (usado en
  `cart_screen.dart:76` y `checkout_screen.dart:155`) llama `_saveCartToStorage()`, que escribe
  `{'items': []}` vía `save()`, no `_storage.clear()` (que haría `remove` de la key). El efecto
  observable es el mismo, pero el método `clear()` de `CartStorage` nunca se ejecuta en la app
  real ni en los tests. Candidato a eliminar o a cablear.
- La rehidratación fire-and-forget + `unawaited` implica que si el SO mata el proceso en el
  instante entre `addItem` y que `prefs.setString` termine de bajar a disco, ese ítem se pierde.
  Es inherente al diseño best-effort y aceptado explícitamente en el encargo; el defecto que se
  arregla (cierre normal → reapertura) sí da tiempo al flush. **Debe cubrirlo la prueba manual
  en dispositivo** (ver abajo).
- El cableado real de `main.dart` (`cartStorageProvider.overrideWithValue(CartStorage(prefs))`)
  no está cubierto por ningún test — `main.dart` no se testea. Solo verificado por lectura.
  Lo cubre la prueba manual en dispositivo.
- `storageKey = 'cart_v1'` está versionado (bien). No hay migración activa: un cambio de shape
  a futuro obliga a `cart_v2` y deja la key `cart_v1` huérfana (fuga menor de storage, nunca se
  limpia). Dentro de `v1` la compat es razonable: campos que falten → defaults, campos extra →
  ignorados. Sin acción requerida ahora, solo a tener presente.
- Una sola entrada malformada dentro de un `items` por lo demás válido descarta **todo** el
  carrito (el try/catch envuelve la comprensión entera). Es el comportamiento documentado
  ("forma inesperada → []"), aceptable, pero vale saberlo.

**Prueba manual en dispositivo real — PENDIENTE (no ejecutada por @tester):**

- Agregar ítems → cerrar la app (swipe away) → reabrir → los ítems normales persisten con su
  cantidad, salsas y comentario.
- Agregar un reward (canje de estrellas) → cerrar → reabrir → el reward desapareció, los ítems
  normales siguen.
- Aplicar un cupón → cerrar → reabrir → el cupón NO vuelve.
- Confirmar un pedido → reabrir → carrito vacío.
- (Opcional, borde) matar el proceso inmediatamente tras agregar un ítem → reabrir → verificar
  si el ítem sobrevivió (best-effort, puede perderse).

**Veredicto @tester: LISTO con salvedades.** Lo crítico pasa: `analyze` limpio, suite verde,
rewards/cupón excluidos con test, JSON corrupto y modo degradado cubiertos, no hay dato
sensible en `SharedPreferences`, sin contrato de API ni diseño que validar. Lo pendiente es
cobertura de tests secundaria (5 huecos listados, ninguno es un bug) + la prueba manual en
dispositivo, que el encargo asignó explícitamente al usuario. No se marca nada del `ROADMAP.md`.

### Salsas/cremas (selector en el detalle + carrito + payload) — ✅ COMPLETO

Escrito originalmente en una sesión sin acceso al toolchain de Flutter (ver `ROADMAP.md`, sección
4). Los primeros 3 ítems y los de fusión/línea de carrito se confirmaron corriendo el toolchain de
verdad (ver auditorías puntuales de esta sección + la de tri-state más abajo). Los 2 ítems que
faltaban — verificación en dispositivo/emulador real de "agregar → vuelve a Home" y del texto de
WhatsApp — quedaron cerrados con un test de integración nuevo (`integration_test/sauces_flow_test.dart`)
corrido en emulador Y en dispositivo físico real; ver "Auditoría puntual: verificación E2E en
dispositivo real" al final de esta sección.

- [x] `flutter pub get` + `dart run build_runner build --delete-conflicting-outputs` no genera
      diffs distintos a los `*.freezed.dart`/`*.g.dart` ya escritos (`sauce_option.*`,
      `public_menu_item.*`, `cart_item.freezed.dart`) — confirmado de nuevo en la auditoría de
      tri-state más abajo: `build_runner` corrido de verdad, salida cruda `Built with
      build_runner/aot in 8s; wrote 0 outputs.` (sin drift)
- [x] `flutter analyze` limpio (confirmado repetidamente en varias auditorías puntuales de esta
      sección, la más reciente con salida cruda propia: `No issues found!`)
- [x] `flutter test` verde, incluyendo los archivos tocados/nuevos: `product_detail_screen_test.dart`,
      `cart_provider_test.dart`, `cart_screen_test.dart`, `order_repository_test.dart` — 329/329
      confirmado con salida cruda propia en la auditoría de tri-state
- [x] Producto sin salsas configuradas (ej. arroz chaufa) no muestra la sección en el detalle —
      confirmado por lectura de código (`if (item.sauces.isNotEmpty) ... _SauceSelector` en
      `product_detail_screen.dart`) y por el test `'producto sin catálogo de salsas: el botón
      sigue habilitado sin elección (validación no aplica)'`
- [ ] ~~Producto con salsas: selección múltiple funciona, es opcional (se puede agregar sin elegir
      ninguna)~~ **DESACTUALIZADO por decisión de negocio explícita (ver auditoría de tri-state
      abajo)**: desde el tri-state real, un producto CON catálogo de salsas ya NO es opcional —
      exige una elección real (al menos una salsa, o el chip "Sin salsas") antes de habilitar
      "AGREGAR AL CARRITO"/"GUARDAR CAMBIOS". La selección múltiple entre salsas reales sigue
      funcionando igual (eso sí sigue siendo cierto), pero "se puede agregar sin elegir ninguna" ya
      no es correcto tal como está escrito — corregir la redacción de este ítem si se retoma esta
      sección, o quitarlo a favor del checklist de tri-state de abajo.
- [x] "Agregar al carrito" vuelve a Home automáticamente (verificado en dispositivo/emulador real,
      no solo en el widget test — la transición de `go_router` sobre `/product/:id` empujado sí
      cae en Home). `integration_test/sauces_flow_test.dart`: tras "AGREGAR AL CARRITO" el detalle
      (`detail-add`) ya no está montado y `home-cart-icon` sí — probado con salsa real y con "Sin
      salsas" explícito, en emulador (`emulator-5554`, Android 17) y en dispositivo físico
      (`24117RN76L`, Xiaomi, Android 15). Ver auditoría E2E al final de la sección.
- [x] Mismo producto con distinta combinación de salsas → filas separadas en el carrito, cada una
      con su propio stepper de cantidad; misma combinación → se fusiona (suma cantidad) —
      confirmado con tests reales de `cart_provider_test.dart`/`product_detail_screen_test.dart`
      (fusión y no-fusión), incluida la variante con `explicitlyNoSauces` (ver auditoría de
      tri-state abajo)
- [x] Carrito muestra "cremas: ..." debajo del nombre y arriba del precio, solo cuando hay
      selección — confirmado; ver también la variante tri-state ("Sin salsas") en la auditoría de
      abajo
- [ ] ~~`POST /orders` manda `sauceIds` por ítem solo cuando corresponde (nunca lista vacía)~~
      **DESACTUALIZADO por el tri-state real (ver auditoría abajo)**: desde el tri-state, el
      payload SÍ manda `sauceIds: []` explícito a propósito cuando el cliente tocó "Sin salsas" —
      "nunca lista vacía" ya no es la regla real. Regla vigente: se omite la llave SOLO cuando el
      producto no ofrece catálogo de salsas o el cliente nunca llegó a elegir; se manda `[]`
      explícito cuando el cliente eligió "Sin salsas" a propósito; se mandan los ids cuando hay
      salsas elegidas. Verificado con test + mutación real (ver abajo).
- [x] Mensaje de WhatsApp final incluye las salsas concatenadas, incluido el caso "Sin salsas"
      literal del tri-state (esto lo arma el backend — `OrdersService.buildWhatsappUrl` en
      `backend-celtas`). Verificado end-to-end en dispositivo físico real (`24117RN76L`, Android 15)
      con `integration_test/sauces_flow_test.dart`: pedido creado recorriendo el checkout de la app
      (`cart-continue` → `checkout-confirm`), y el `text` del `whatsappUrl` de ese pedido (el mismo
      string que `_openWhatsapp` le pasa a `launchUrl` sin mutar) trae
      `• 1x Celtas Burgues Clasica (Salsas: mayonesa)` y
      `• 1x Celtas Burgues Clasica (Salsas: Sin salsas)`. Ver auditoría E2E al final de la sección.

#### Auditoría puntual: fix de la carrera SnackBar/`pop()` en `_addToCart()`

Alcance de esta auditoría: SOLO el fix descrito abajo (commit sin commitear todavía sobre
`product_detail_screen.dart` + `product_detail_screen_test.dart`), no el resto de la sección
"Salsas/cremas" de arriba (sigue pendiente, sin correr). No se marca ningún checkbox de la
sección anterior por esta auditoría.

`flutter analyze`: `No issues found!` (confirmado con salida cruda propia). `flutter test`
(suite completa): `301: All tests passed!` (confirmado con salida cruda propia).

Diff auditado (`git diff`, verificado byte a byte contra lo reportado por la sesión principal):
en `_addToCart()`, el `context.pop()` final pasó de ejecutarse inmediato a diferirse con
`WidgetsBinding.instance.addPostFrameCallback((_) { if (!mounted) return; context.pop(); });`;
en el test se agregó `await tester.pumpAndSettle();` tras el `pump()` que sigue al tap en
`detail-add` en los 2 tests señalados. El diff también trae 3 cambios no mencionados en el
encargo (`goRouter.push(...)` → `unawaited(goRouter.push(...))` en el helper `pumpDetail` y en
2 tests) — confirmado que son necesarios y no decorativos: revertí solo esos 3 sitios
(`git stash` del archivo de test) y `flutter analyze` reporta 3 issues reales de
`unawaited_futures` en esas líneas exactas; no es un cambio de comportamiento, solo silencia un
lint ya activo (`analysis_options.yaml:38`) que aparentemente no se había corrido antes sobre
este archivo.

**Verificación de causa raíz, no solo confianza en el diagnóstico reportado** — reconstruí la
matriz de combinaciones reales (prod × test) copiando versiones intermedias a un scratchpad y
restaurando con `git diff`/comparación byte a byte al terminar, sin dejar el repo en un estado
intermedio:
- `pop()` inmediato + test con un solo `pump()` (estado real de HEAD antes de este fix): **falla
  igual que lo descrito** — reproduje el error exacto, evidencia cruda:
  `Expected: exactly one matching candidate / Actual: Found 2 widgets with text "Agregado:
  Berserker Burger ×3"` en el primer test, y `Bad state: Too many elements` en el segundo
  (`tester.widget<SnackBar>(find.byType(SnackBar))` con 2 candidatos). Confirma que el bug
  reportado es real, no una descripción inventada.
- `pop()` diferido (el fix real, confirmado por diff que coincide con el commit) + test con un
  solo `pump()` (sin el `pumpAndSettle()` agregado): el SnackBar YA NO se duplica (el test de
  margen, que solo depende del `SnackBar`, pasa con un solo `pump()`) — confirma que diferir el
  `pop()` sí resuelve la causa raíz real de la duplicación, no es un cambio cosmético. El otro
  test sí sigue fallando con un solo `pump()`, pero por un motivo DISTINTO y esperado: el
  `context.pop()` deferido con `addPostFrameCallback` necesita un frame adicional para que el
  `Navigator` refleje la ruta removida (`Found 1 widget with key [detail-add]`, no el error de
  duplicado) — exactamente la razón por la que el `pumpAndSettle()` agregado en ese test es
  necesario y no redundante.
- Con ambos cambios juntos (estado final real): los 2 tests pasan limpio, confirmado arriba.

Conclusión: el diagnóstico y el fix de la sesión principal son correctos — diferir el `pop()`
elimina la ventana en la que el `ScaffoldMessenger` pinta dos veces el mismo `SnackBar` durante
la transición de `hideCurrentSnackBar()`+`showSnackBar()` superpuesta con la remoción de ruta;
el `pumpAndSettle()` agregado en los tests es una consecuencia necesaria de ese mismo cambio
(el `pop()` deferido tarda un frame más en reflejarse), no un parche que enmascare el problema
por su cuenta.

✅ Pasó:
- `mounted` se chequea antes de usar `context` dentro del callback diferido — evita un
  `use_build_context_synchronously`/crash si el usuario navega fuera de la pantalla (ej. back
  del sistema) en la ventana de un frame entre el tap y que corra el callback. `flutter analyze`
  no reporta el lint `use_build_context_synchronously` en este archivo, consistente con el guard.
- No hay doble-pop ni fuga observable: el callback se registra una sola vez por tap (no hay
  acumulación de callbacks si el usuario no puede volver a tocar "AGREGAR" durante la ventana de
  un frame — `CeltasButton` no se deshabilita durante ese frame, pero un segundo tap real
  requeriría que el usuario interactúe más rápido que un frame de render, no es un escenario
  practicable).
- Las aserciones de los 2 tests modificados no se debilitaron: mismo `expect` sobre el estado del
  `cartProvider`, mismo texto del `SnackBar`, mismo `margin` esperado, mismo
  `find.byKey(detail-add), findsNothing` — el único cambio es CUÁNDO se evalúan (después de
  `pumpAndSettle()` en vez de justo después de `pump()`), no QUÉ se evalúa.

⚠️ Riesgos / casos borde no cubiertos, no bloqueantes:
- No hay test de regresión explícito para el caso "back del sistema mientras el `postFrameCallback`
  está pendiente" (el guard `if (!mounted) return;` lo cubre por código, pero no hay un test que
  fuerce esa ventana de carrera de un frame — difícil de reproducir de forma determinística en
  `flutter_test` sin acoplarse a detalles de implementación de `pump()`).
- Sigue pendiente, fuera del alcance de esta auditoría puntual, el resto de la sección
  "Salsas/cremas" de arriba (todos los `[ ]` sin marcar) — en particular la verificación en
  dispositivo/emulador real del flujo "Agregar → vuelve a Home" (el widget test ya confirma la
  mecánica, pero el propio checklist pide una verificación aparte en dispositivo real porque la
  transición de `go_router` puede comportarse distinto).

**Veredicto de este fix puntual: LISTO.** No se marca ningún checkbox de la sección
"Salsas/cremas" de arriba — esta auditoría cubrió únicamente la carrera SnackBar/`pop()`, no el
resto del módulo.

#### Auditoría puntual: 2 hallazgos de la prueba en dispositivo real del dueño del negocio (el "+" del Home debe respetar el selector, editar salsas de un ítem ya en el carrito)

Alcance de esta auditoría: SOLO estos dos ajustes (sin commitear todavía), no el resto de la
sección "Salsas/cremas" de arriba (sigue pendiente, sin correr formalmente). No se marca ningún
checkbox de esa sección por esta auditoría. Documentado explícitamente por pedido del encargo:
**ambos hallazgos vinieron de la prueba del dueño del negocio en dispositivo real, no de una
revisión de código** — es la app en producción (backend real) la que expuso el "+" rápido
agregando sin dejar elegir salsas, y la falta de forma de corregir una selección de salsas ya en
el carrito sin borrar la fila y repetir el flujo desde cero.

`flutter analyze`: `No issues found!` (salida cruda propia). `flutter test` (suite completa):
`316: All tests passed!` (salida cruda propia).

✅ Pasó:
- **Hallazgo 1 (botón "+" del Home)**: confirmado por lectura de código
  (`home_screen.dart:818-848`) que el `onTap` de `_AddButton` ahora bifurca en
  `item.sauces.isNotEmpty` — si las ofrece, `context.push('/product/${item.id}')` (mismo
  `push` que ya usa el tap sobre la tarjeta) y `return` temprano, sin llamar a `addItem`; si no
  las ofrece, seguido igual que antes (`addItem` + `SnackBar`). Verificado que no es un cambio
  cosmético: reverté el `lib/features/home/presentation/home_screen.dart` completo con `git
  stash push -- <archivo>` y corrí `flutter test test/features/home/presentation/
  home_screen_test.dart` — el test nuevo (`'botón "+" en un producto CON salsas → navega al
  detalle...'`) es el ÚNICO que falla (`Expected: exactly one matching candidate / Actual: Found
  0 widgets with text "DETAIL i-5"`), el resto de la suite del archivo (26 tests) sigue pasando
  igual — confirma que el test ejercita el código real del fix, no un falso positivo, y que el
  cambio no rompió nada del comportamiento previo (SnackBar de margen, carrusel de banners,
  etc.). Restauré con `git stash pop` acto seguido.
- **Hallazgo 2 (editar salsas desde el carrito)**: `CartNotifier.updateLine` (nuevo,
  `cart_provider.dart`) revisado línea por línea — `lineKey` es un getter calculado sobre
  `CartItem` (no cacheado, confirmado en `cart_item.dart:44-49`), así que `updated.lineKey` tras
  el `copyWith` con las salsas nuevas siempre refleja la combinación real, sin arrastrar el
  `lineKey` viejo. Casos borde verificados con evidencia, no solo lectura:
  - **Fusión real, no solo nominal**: reproduje el escenario completo pedido en el encargo (2
    filas del mismo producto con distinta combinación, se edita una para que coincida con la
    otra) con una mutación deliberada del código (cambié
    `items[i].copyWith(quantity: items[i].quantity + quantity)` a
    `items[i].copyWith(quantity: quantity)` — quitando la suma) y corrí
    `cart_provider_test.dart` + `product_detail_screen_test.dart`: los 2 tests de fusión (uno en
    cada archivo) fallan exactamente con esa mutación (`Expected: <4> / Actual: <3>`), confirmando
    que sí ejercitan la suma real y no un valor que coincidiría igual sin ella. Revertido con
    `git checkout -- lib/features/cart/application/cart_provider.dart` acto seguido y
    reconfirmado con `git diff` (idéntico byte a byte al estado previo a la mutación) + `flutter
    analyze`/`flutter test` limpios de nuevo (316/316).
  - **Editar sin cambios (fila comparada consigo misma)**: `mergeIndex == oldIndex` en ese caso
    (la única fila que coincide con la combinación nueva es la misma que se está editando), así
    que cae en la rama `else` (reemplazo simple, no fusión) — no hay riesgo de que la fila se
    "fusione consigo misma" duplicando su propia cantidad. Cubierto con test explícito
    (`'editar sin cambiar nada...'`).
  - **`oldLineKey` inexistente / `quantity <= 0`**: ambos son no-op (`return` temprano),
    cubiertos con test. `quantity <= 0` es inalcanzable desde la UI real (el stepper de
    `product_detail_screen.dart:307` tiene piso en 1), documentado como guardia defensiva
    consistente con el resto del archivo (mismo criterio que `addItem`).
  - Ruta de navegación (`app_router.dart`): `state.extra as CartItem?` en `/product/:id`
    confirmado — `cart_screen.dart` pasa el `CartItem` completo por `extra` (sin serializar,
    correcto: no hay necesidad de codificarlo a query string, y `go_router` soporta objetos
    arbitrarios por `extra` en navegación in-memory).
  - **El `pop()` en modo edición**: confirmado que es literalmente el mismo código que el modo
    normal (mismo `WidgetsBinding.instance.addPostFrameCallback` + `context.pop()`), sin rama
    nueva — razonable porque, a diferencia de Home, no existe ningún camino real en la app hoy
    que llegue a `/product/:id` con `editingItem != null` que no sea `push` desde
    `cart_screen.dart` (`grep -rn "editingItem:" lib/` solo dentro de `app_router.dart`, y
    `grep -rn "extra: item" lib/` solo dentro de `_CartItemRow` de `cart_screen.dart`) — no hay
    forma hoy de que el pop caiga en un lugar distinto de `/cart`.
- **`_offersSauces` no le pega a la red en el helper `pumpCart` de `cart_screen_test.dart`**:
  confirmado que el override por defecto (`publicMenuProvider.overrideWith((ref) async =>
  menu)`, `menu: const []` por defecto) sí resuelve el problema para toda la suite existente —
  pero además, el tercer test del grupo nuevo ("ítem con salsas ya seleccionadas...") demuestra
  con evidencia que ni siquiera hace falta el override en ese caso puntual: monta el árbol con un
  `ProviderContainer` que NO overridea `publicMenuProvider` en absoluto y el ícono igual aparece
  — porque `_offersSauces` hace `if (item.selectedSauces.isNotEmpty) return true;` ANTES de
  tocar `ref.watch(publicMenuProvider)`, así que el provider ni se llega a leer cuando la fila ya
  trae salsas seleccionadas (snapshot del propio `CartItem`, sin depender de una segunda
  consulta al menú). Confirma que el guard de orden de evaluación es real, no solo un detalle de
  implementación incidental.
- **El ícono de lápiz no aparece para productos sin salsas**: confirmado por lectura y por el
  test dedicado (`'producto que NO ofrece salsas...'`, con el menú vacío por defecto de
  `pumpCart`) — sin `item.selectedSauces` Y sin coincidencia en `publicMenuProvider`, `_offersSauces`
  devuelve `false` y el `if (offersSauces)` de `cart_screen.dart:339` ni construye el
  `GestureDetector`. No hay "nada que editar" ahí, tal como pide el encargo.
- **`_CartItemRow` sigue mostrando "cremas: ..." debajo del nombre y arriba del precio**: el
  nuevo `Row` (nombre + ícono opcional) reemplazó solo el `Text` suelto que había antes, sin
  tocar el bloque `if (item.selectedSauces.isNotEmpty) ...` que sigue exactamente donde estaba
  (`cart_screen.dart:360-375`) — confirmado por lectura completa del widget, no solo el diff.
- **Fidelidad visual**: `Icons.edit_outlined` sin `Color(0xFF...)` suelto (`CeltasColors.textMuted`,
  mismo token que ya usa el resto de la app para texto secundario) — consistente con el
  precedente ya establecido en el mismo archivo de usar `Icons.*` de Material para íconos
  interactivos sin equivalente en `design-reference/` (`Icons.delete_outline` para vaciar
  carrito, mismo criterio que la auditoría anterior de esta sección ya validó). No hay mockup de
  este ícono en `design-reference/` (es un estado interactivo nuevo, el mockup estático no lo
  representa) — mismo criterio ya aceptado en auditorías previas de este documento para el aviso
  de dirección faltante del checkout.

❌ Falló:
- Ninguno.

⚠️ Riesgos / casos borde no cubiertos, no bloqueantes:
- **Tap target del ícono de lápiz notablemente más chico que el precedente ya establecido en el
  mismo archivo**: `cart_screen.dart:349-356` — `Icon(Icons.edit_outlined, size: 16)` envuelto en
  `Padding(padding: EdgeInsets.only(left: 8))`, sin padding arriba/abajo/derecha. El área
  tocable real es ~16×16 (el padding izquierdo agranda el ancho del `GestureDetector` pero no el
  alto). Esto es notablemente más chico que el ícono de vaciar carrito del MISMO archivo
  (`cart_screen.dart:193-200`, `size: 24` + `Padding(all: 4)` ≈ 32×32), que una auditoría anterior
  de esta misma sección corrigió explícitamente por ser "chico y difícil de acertar". No es un
  bug funcional (el flujo se probó y funciona en dispositivo real según el encargo) y no bloquea
  el veredicto, pero es una inconsistencia real de usabilidad dentro del mismo archivo que vale
  la pena revisar si se toca de nuevo esta pantalla — sugerencia: `Padding(all: 8)` en vez de
  `EdgeInsets.only(left: 8)`, dejando el ícono visualmente en el mismo lugar pero con un área
  tocable ~32×32 consistente con el ícono de papelera.
  **Aplicado tras esta auditoría**: `Padding(only(left: 8))` → `Padding(all(6))`, área tocable
  ahora ~28×28 (ícono 16 + padding 6 por lado). `flutter analyze`/`flutter test` verificados de
  nuevo, limpios.
- **Sin test de regresión para la carrera "el menú público cambia mientras `_CartItemRow` ya está
  en pantalla"** (ej. `publicMenuProvider` pasa de ya no ofrecer salsas para ese producto — poco
  realista en la práctica, el menú no suele cambiar mid-sesión, y el propio encargo advierte que
  el catálogo real de salsas estuvo cambiando en vivo durante la prueba del dueño del negocio) —
  `_offersSauces` usa `ref.watch`, así que el ícono reaccionaría solo (aparecer/desaparecer) ante
  ese cambio, pero no hay un test explícito que lo confirme. Riesgo bajo: no hay reporte de que
  esto haya causado un problema real en la sesión de prueba en dispositivo.
- Sigue pendiente, fuera del alcance de esta auditoría puntual, el resto de la sección
  "Salsas/cremas" de arriba (todos los `[ ]` sin marcar).
- `test/features/checkout/data/order_repository_test.dart` aparece modificado en `git status`
  pero sin diff real contra `HEAD` (`git diff` vacío) — no forma parte de este encargo, no se
  auditó.

**Veredicto de este fix puntual: LISTO.** Ambos hallazgos del dueño del negocio quedan resueltos
con evidencia verificada de forma independiente (no solo por lectura del diff): mutación
deliberada + reversión confirmada byte a byte para el caso de fusión, y `git stash`/reversión
confirmada para el botón "+" del Home. Único hallazgo nuevo (no bloqueante): tap target chico del
ícono de lápiz, inconsistente con el precedente ya corregido en el mismo archivo para el ícono de
papelera.

#### Auditoría puntual: tri-state real de salsas (no aplica / sin salsas explícito / con salsas)

Alcance de esta auditoría: SOLO la mejora de tri-state descrita en el encargo (`CartItem
.explicitlyNoSauces` + propagación en `cart_provider.dart` + chip "Sin salsas" mutuamente
excluyente en `product_detail_screen.dart` + línea "Sin salsas" en `cart_screen.dart` +
`sauceIds: []` explícito en `order_repository.dart`), no el resto de la sección "Salsas/cremas" de
arriba. Contrato del backend verificado independientemente por lectura directa de
`../backend-celtas/src/modules/orders/orders.service.ts` (`resolveSelectedSauces`, líneas
355-379) y `dto/create-order.dto.ts` (`sauceIds?: string[]`, `@IsOptional()` + `@IsArray()` +
`@IsUUID('4', {each:true})`) — coincide exactamente con lo descrito en el encargo: `undefined` →
`null` ("no aplica"), `[]` explícito → `[]` ("sin salsas" real, mostrado literal), con ids →
nombres validados y snapshot.

`flutter analyze`: `No issues found!` (salida cruda propia). `flutter test` (suite completa):
`329: All tests passed!` (salida cruda propia, no solo confianza en el reporte de la sesión
principal). `dart run build_runner build --delete-conflicting-outputs` corrido de verdad: `Built
with build_runner/aot in 8s; wrote 0 outputs.` — confirma que `cart_item.freezed.dart` ya
commiteado es byte-idéntico al que generaría el toolchain real, sin drift a mano.

✅ Pasó:
- **`CartItem.explicitlyNoSauces`** (`cart_item.dart`): campo `@Default(false) bool`, confirmado
  presente en el `.freezed.dart` real (no solo en el modelo fuente) — `copyWith`, `==`,
  `hashCode`, `toString()` y el constructor de `_CartItem` lo incluyen correctamente.
- **`CartNotifier.addItem`/`updateLine`** (`cart_provider.dart`): ambos reciben
  `explicitlyNoSauces` y lo propagan a la fila nueva; en fusión (mismo `lineKey`), lo combinan con
  `OR` (`items[i].explicitlyNoSauces || explicitlyNoSauces`) contra la fila objetivo. Verificado
  que en la práctica el `OR` es una red de seguridad, no una necesidad activa: `lineKey` se calcula
  solo a partir de `selectedSauces` (ignora `explicitlyNoSauces`), pero un producto CON catálogo
  de salsas nunca puede llegar a `selectedSauces: [] && explicitlyNoSauces: false` desde la UI real
  (el botón de agregar/guardar queda deshabilitado hasta que haya una elección real — ver abajo),
  así que las dos filas que comparten `lineKey` con `selectedSauces` vacío SIEMPRE tienen
  `explicitlyNoSauces: true` de origen; el `OR` no cambia el resultado en ningún camino alcanzable
  hoy, pero tampoco es incorrecto tenerlo.
- **Exclusión mutua real en `product_detail_screen.dart`** (`_toggleSauce`/`_toggleNoSauces`):
  verificada con MUTACIÓN REAL, no solo lectura — revertí ambos métodos a una versión sin la
  exclusión (`_toggleSauce` ya no pone `_explicitlyNoSauces = false`; `_toggleNoSauces` ya no
  limpia `_selectedSauceIds`) y corrí `product_detail_screen_test.dart`: exactamente 2 tests
  fallan (`'"Sin salsas" y los chips de salsas reales son mutuamente excluyentes en ambos
  sentidos'` y `'Mayonesa → "Sin salsas" limpia la selección real...'`), ambos con el mismo patrón
  de evidencia cruda (`Expected: exactly one matching candidate / Actual: Found 2 widgets with
  icon...`, dos chips marcados a la vez) — confirma que el fix ejercita código real, no un test que
  pasaría igual sin él. Reverti la mutación y confirmé `git diff` idéntico byte a byte al estado
  previo + `flutter analyze`/`flutter test` limpios de nuevo (329/329).
- **Botón deshabilitado hasta elección real** (`_hasRequiredSauceChoice`): confirmado que
  `onPressed: null` es una deshabilitación REAL, no solo visual — `CeltasButton` calcula `enabled =
  onPressed != null && !loading` y usa `onTap: enabled ? onPressed : null` (mismo patrón ya
  auditado en `checkout_screen.dart`/`cart_screen.dart` para otros botones deshabilitados). Test
  `'sin elegir ninguna opción, tocar el botón deshabilitado no agrega nada al carrito'` usa
  `warnIfMissed: false` correctamente (el tap no puede "acertar" un `GestureDetector` con `onTap:
  null`) y confirma `cartProvider` sigue vacío tras el tap.
- **`order_repository.dart` — condición nueva verificada con MUTACIÓN REAL**: revertí `else if
  (item.explicitlyNoSauces) 'sauceIds': const <String>[]` a la condición vieja (solo `if
  (item.selectedSauces.isNotEmpty) 'sauceIds': [...]`, sin el `else if`) y corrí
  `order_repository_test.dart`: falla exactamente el test nuevo (`'ítem con explicitlyNoSauces=true
  y selectedSauces vacío → manda "sauceIds": [] explícito (no ausente)'`, `Expected: true / Actual:
  <false>` sobre `item.containsKey('sauceIds')`), los otros 5 tests del archivo siguen pasando —
  confirma que el test ejercita la rama nueva real. Reverti la mutación, confirmé `git diff`
  idéntico byte a byte y `flutter analyze`/`flutter test` limpios de nuevo.
- **Prioridad correcta si ambos campos coincidieran (estado contradictorio hipotético)**: la
  condición es `if (selectedSauces.isNotEmpty) ... else if (explicitlyNoSauces) ...` — si por algún
  bug futuro ambos campos quedaran `true`/no-vacíos a la vez, gana `selectedSauces` (manda los ids
  reales, ignora la bandera "sin salsas"), que es el comportamiento más seguro de los dos. Hoy este
  caso no es alcanzable desde la UI real (mutua exclusión ya verificada arriba), documentado como
  riesgo teórico no bloqueante más abajo.
- **Botón "+" rápido del Home** (`home_screen.dart:828-836`): confirmado por lectura que sigue sin
  tocar — para productos CON catálogo de salsas ya navega al detalle en vez de agregar directo
  (fix de una auditoría anterior, sin relación con este cambio); para productos SIN catálogo llama
  `addItem(item)` sin pasar `explicitlyNoSauces` (default `false`), consistente con el caso "no
  aplica" del backend (la llave se omite). No hay forma hoy de que este botón dispare
  `explicitlyNoSauces: true` — correcto, ese chip solo existe en el detalle.
- **`lineKey` no se ve afectado por el campo nuevo**: confirmado por lectura de `cart_item.dart` —
  el getter sigue calculándose solo a partir de `selectedSauces`, sin incluir
  `explicitlyNoSauces`; la fusión de filas del carrito sigue funcionando exactamente igual que
  antes de este cambio (mismos tests de fusión/no-fusión ya existentes siguen en verde).
- **Modo edición preserva el campo al guardar sin tocar nada**: confirmado por lectura de código
  (`_explicitlyNoSauces` se inicializa desde `editingItem?.explicitlyNoSauces ?? false` en
  `initState`, y `_addToCart` pasa ese mismo valor a `updateLine` sin transformarlo) — si el
  usuario abre el modo edición de una fila con "Sin salsas" ya marcado y toca "GUARDAR CAMBIOS" sin
  interactuar con los chips, el valor viaja intacto. Hay cobertura PARCIAL de esto: el test
  `'fila editada con explicitlyNoSauces=true precarga el chip "Sin salsas"...'` confirma el estado
  de la UI ANTES de tocar el botón (chip marcado, botón habilitado), pero ningún test tapea
  realmente "GUARDAR CAMBIOS" sin cambios y verifica el `CartItem` resultante en `cartProvider` —
  ver hueco de cobertura abajo (no bloqueante, la lógica se verificó por lectura directa del
  camino de datos, que es lineal y sin ramas condicionales que puedan perder el valor).
- **`checkout_screen.dart`**: `_confirmOrder` pasa `items: cart.items` (la lista completa de
  `CartItem`, sin transformar) a `createOrder` — `explicitlyNoSauces` viaja intacto de punta a
  punta desde el carrito hasta el payload de `POST /orders`, confirmado por lectura directa (no
  hay ningún mapeo intermedio que pudiera perder el campo).
- **Cobertura general**: 3 grupos de tests nuevos/ampliados revisados línea por línea, no solo
  ejecutados — `order_repository_test.dart` (contrato completo de `sauceIds` con los 3 casos + caso
  multi-ítem con selección independiente por ítem), `cart_provider_test.dart` (`addItem`/
  `updateLine` con `explicitlyNoSauces`, incluida la fusión que preserva el campo vía `OR`),
  `cart_screen_test.dart` ("Sin salsas" visible tri-state), `product_detail_screen_test.dart`
  (exclusión mutua en ambos sentidos + precarga en modo edición).
- Sin `Color(0xFF...)` sueltos ni desviación de fidelidad visual: el chip "Sin salsas" reutiliza
  `_SauceChip` (mismo widget que los chips de salsas reales, ya auditado en una ronda anterior),
  sin estilos nuevos.

❌ Falló:
- Ninguno.

⚠️ Riesgos / casos borde no cubiertos, no bloqueantes:
- **Hueco de cobertura real**: no hay un test que tapee "GUARDAR CAMBIOS" en modo edición sobre una
  fila con `explicitlyNoSauces: true` sin tocar ningún chip, y verifique que el `CartItem`
  resultante en `cartProvider` sigue con `explicitlyNoSauces: true` (solo se verifica el estado
  previo de la UI, no el resultado post-guardado para este caso puntual — sí existe ese patrón
  completo para el caso de salsas reales, `'GUARDAR CAMBIOS actualiza la fila correcta...'`).
  Verificado por lectura de código que el camino de datos es lineal (sin condicionales que puedan
  perder el valor), así que el riesgo real de que esto falle en producción es bajo, pero no está
  confirmado con un test de regresión explícito.
- **Estado contradictorio teórico sin invariante a nivel de tipo**: `CartItem` no impide en tiempo
  de compilación que `selectedSauces` no vacío y `explicitlyNoSauces: true` coexistan — hoy la UI
  garantiza mutua exclusión (verificado con mutación real arriba) y `order_repository.dart` tiene
  una prioridad segura si igual coexistieran, pero no hay una aserción explícita en el modelo ni un
  test que documente qué pasa si algún código futuro (fuera de `product_detail_screen.dart`)
  construye un `CartItem` con ambos campos "activos" a la vez. Riesgo bajo, no bloqueante.
- **No verificado en dispositivo/emulador real** en esta sesión (sin dispositivo conectado): que
  "Sin salsas" aparezca correctamente en el mensaje de WhatsApp real generado por el backend, ni el
  flujo visual completo Home → detalle con "Sin salsas" → carrito → checkout → WhatsApp. La
  lógica del lado del backend para este caso ya fue verificada en su propia sesión (según el
  encargo), y el payload que la app manda está confirmado con test + mutación real, pero la cadena
  end-to-end visual no se ejercitó en esta auditoría.
- Sigue pendiente, fuera del alcance de esta auditoría puntual, el resto de la sección
  "Salsas/cremas" de arriba que depende de dispositivo real (verificación visual de "vuelve a
  Home", texto de WhatsApp).

**Veredicto de este fix puntual: LISTO.** Los dos puntos de mutación activa pedidos explícitamente
en el encargo (exclusión mutua de chips en `product_detail_screen.dart`, condición nueva de
`order_repository.dart`) se verificaron con reversión real del código y confirmación de que el
test correspondiente falla — no es una confianza ciega en el diff. Contrato de `sauceIds`
verificado por lectura directa del backend real (`resolveSelectedSauces` + DTO), no por el
resumen del encargo. `flutter analyze`/`flutter test`/`build_runner` corridos de verdad con salida
cruda propia. Único hueco de cobertura real (no bloqueante): falta un test de regresión explícito
para "guardar cambios sin tocar nada preserva `explicitlyNoSauces` en modo edición" — la lógica se
verificó por lectura de código, camino lineal sin ramas de riesgo. No se marca el checkbox de
`ROADMAP.md` de la mejora completa de "selección de salsas/cremas" (sigue teniendo verificación de
dispositivo real pendiente, fuera del alcance de este encargo puntual) — solo se actualizaron los
ítems específicos de esta sección de arriba que ya quedaron confirmados por el toolchain real.

#### Auditoría puntual: hero a 270px + `CeltasButton.enabled` separado de `onPressed`

Alcance: 2 ajustes de UX pedidos tras feedback real de uso en dispositivo (capturas del dueño del
negocio) sobre `product_detail_screen.dart` y `celtas_button.dart` — no el resto de la sección de
arriba. Archivos tocados: `lib/shared/widgets/celtas_button.dart`,
`lib/features/menu/presentation/product_detail_screen.dart`,
`test/shared/widgets/celtas_button_test.dart`,
`test/features/menu/presentation/product_detail_screen_test.dart`.

`flutter analyze`: `No issues found!` (salida cruda propia). `flutter test` (suite completa):
`334: All tests passed!` (salida cruda propia — 333 previos + 1 test nuevo agregado por
`@tester`, ver abajo). Confirmado por `grep -rn "CeltasButton("  lib/` que hay 13 usos del widget
en `lib/`, ninguno pasa `enabled` explícitamente — el nuevo default `enabled: true` no cambia el
comportamiento de ninguno.

**Cambio 1 — `CeltasButton.enabled`:** ahora `looksEnabled = enabled && onPressed != null &&
!loading` controla SOLO el color/texto (naranja/negro vs. gris/`textSubtle`); `canTap = onPressed
!= null && !loading` controla SOLO `InkWell.onTap`, sin depender de `enabled`. Verificado con
MUTACIÓN REAL: revertí `onTap: canTap ? onPressed : null` a `onTap: looksEnabled ? onPressed :
null` (el comportamiento viejo, donde `enabled: false` también bloqueaba el toque) y corrí
`celtas_button_test.dart` — falla exactamente el test nuevo (`'enabled: false con onPressed no
nulo: se ve gris (textSubtle + border) pero el toque SÍ dispara el callback'`), evidencia cruda:
`Expected: true / Actual: <false>` sobre `tapped` tras el `tester.tap`. Los otros 2 tests del
grupo nuevo (`enabled: true` sin regresión, `onPressed: null` sigue sin recibir el toque) no se
ven afectados por esta mutación puntual. Reverti la mutación y confirmé `git diff` idéntico byte
a byte al estado previo.

**Cambio 2 — botón de agregar/guardar en `product_detail_screen.dart`:** ahora usa `enabled:
_hasRequiredSauceChoice` + un `onPressed` real (nunca `null`) que muestra un `SnackBar` con el
mismo texto que `_SauceChoiceNotice` cuando falta elegir salsas, en vez de llamar `_addToCart`.
Verificado con MUTACIÓN REAL: revertí a `onPressed: _hasRequiredSauceChoice ? _addToCart : null`
(el patrón viejo, sin el `enabled` separado) y corrí `product_detail_screen_test.dart` — falla
exactamente el test objetivo (`'sin elegir ninguna opción, tocar el botón (visualmente gris)
muestra el SnackBar de aviso...'`), evidencia cruda: `Expected: exactly one matching candidate /
Actual: Found 0 widgets with text "Elegí tus salsas..." descending from widgets with type
"SnackBar"`. Como efecto colateral esperado (el revert también vuelve a poner `onPressed: null`
cuando falta elegir), también falla `'producto con salsas: el botón de agregar arranca
visualmente deshabilitado... pero sigue recibiendo el toque (onPressed no nulo)'`
(`Expected: false / Actual: <true>` sobre `button.onPressed == null`) — consistente, no un
hallazgo nuevo. El texto del `SnackBar` es el MISMO que usa `_SauceChoiceNotice`, y el test
existente (`'sin elegir ninguna opción...'`) ya buscaba el texto específicamente dentro de
`find.byType(SnackBar)` para no depender de cuál de los 2 matches en pantalla (aviso inline +
SnackBar) resuelve el finder — confirmado correcto, no un falso positivo. Reverti la mutación y
confirmé `git diff` idéntico byte a byte al estado previo.

**Cambio 3 — hero de 400px a 270px:** agregué un test nuevo (`'hero de 270px deja el selector de
salsas y su aviso de elección pendiente dentro del viewport visible SIN deslizar...'`) que arma
el árbol con el mismo viewport que ya usa `pumpDetail` (390×844 lógicos) sobre `productId: 'i-3'`
(el único producto con salsas del fixture) y compara `tester.getBottomRight(...).dy` del
`_SauceChoiceNotice` contra el alto lógico del viewport, sin scrollear. Con el hero real (270px)
pasa: `noticeBottom≈621.4` (dato de referencia, ver el delta de 130px con la mutación abajo).
**Verifiqué con MUTACIÓN REAL, tal como pide el protocolo del proyecto, y encontré un resultado
distinto al esperado**: revertí el hero a 400px y corrí el test — **NO falló**. Evidencia cruda
(con un `print` temporal, removido antes de dejar el test final):
`PROBE noticeBottom=751.4 logicalHeight=844.0`. Es decir, con el fixture de prueba actual (`i-3`,
`price: 12`, **sin `description`**) el aviso ya cabía completo dentro del viewport de 390×844
lógicos incluso con el hero de 400px, con ~93px de margen de sobra — el test que agregué NO
distingue entre el estado "con bug" (400px) y el estado "arreglado" (270px) bajo este fixture
puntual, así que no es una guarda de regresión fuerte para el problema real reportado en
dispositivo. Posibles explicaciones, no confirmadas: el producto real que motivó el reporte del
dueño del negocio probablemente SÍ tiene `description` (la mayoría de productos del menú real la
tienen; el fixture i-3 de este archivo de test es el único con salsas y deliberadamente no tiene
descripción), lo que agregaría ~56px más de altura (2 líneas × 14px × 1.5 line-height + 14px de
spacing) y probablemente sí haría fallar el test con 400px; también es posible que el entorno de
`flutter_test` no simule el `viewPadding` del sistema (status bar/nav bar) que sí consume espacio
real en un dispositivo físico, aunque analicé el layout (`SafeArea(top: false)` envuelve toda la
`Column`, así que un inset real del sistema desplazaría el borde inferior del `Container` de la
barra "AGREGAR AL CARRITO", no la posición del aviso dentro del `SingleChildScrollView`, que se
calcula igual sin importar el tamaño del `Viewport` visible). Dejé el test en el suite porque sí
verifica correctamente el estado ACTUAL (con el fix), pero no lo cuento como una mutación
"confirmada" en el sentido estricto del protocolo — lo documento como hallazgo, no lo oculto.
Reverti la mutación (`height: 270`) y confirmé `git diff` idéntico byte a byte al estado previo.

`flutter devices` mostró un dispositivo Android real conectado (`24117RN76L`, Android 15,
API 35) — intenté evaluar una verificación visual real, pero `/product/:id` está detrás de
`_isProtectedPath` en `app_router.dart` (requiere sesión autenticada contra el backend real de
producción) y esta auditoría no contaba con credenciales de prueba. Decidí no crear una cuenta
nueva en el backend de producción solo para esta verificación visual puntual — documentado como
no verificado en dispositivo real, igual que auditorías anteriores de este mismo archivo cuando
no había dispositivo disponible en absoluto.

✅ Pasó:
- `flutter analyze`/`flutter test` limpios (334/334, salida cruda propia).
- `CeltasButton.enabled` verificado con mutación real: el toque sigue disparando `onPressed`
  incluso con `enabled: false`, mientras el estilo sigue gris — comportamiento exactamente como
  lo describe el doc-comment del campo.
- Default `enabled: true` no rompe ningún uso existente del widget (13 usos en `lib/`, ninguno
  pasa el parámetro).
- Botón de `product_detail_screen.dart` verificado con mutación real: el `SnackBar` de aviso
  aparece al tocar sin elección y `cartProvider` sigue vacío; el texto coincide con
  `_SauceChoiceNotice`.
- Botón de volver (`detail-back`, `Positioned(top: 44, ...)`, ícono 38px) sigue dentro de los
  270px del hero (44+38=82 < 270) — confirmado por lectura de código, no hay solape aritmético
  posible.
- 5ª ocurrencia del bloque `ScaffoldMessenger..hideCurrentSnackBar()..showSnackBar(...)` duplicado
  byte a byte, ahora 2 dentro del mismo `product_detail_screen.dart` (además de
  `cart_screen.dart`/`home_screen.dart`/`app_router.dart`) — **RESUELTO**, ver sección "Refactor:
  `showCeltasSnackBar` compartido" más abajo.

❌ Falló:
- Ninguno de los tests del suite. La mutación del hero (Cambio 3) no reprodujo el "estado con
  bug" bajo el fixture de prueba actual — ver detalle arriba, no es un fallo de test, es una
  limitación de cobertura documentada.

⚠️ Riesgos / casos borde no cubiertos, no bloqueantes:
- **Test de bounds del hero no es una guarda de regresión fuerte** (ver Cambio 3 arriba): no
  falla si alguien revierte el hero a 400px, porque el único fixture con salsas del archivo
  (`i-3`) no tiene `description`. Si se retoma este archivo, valdría la pena agregar un segundo
  producto con salsas Y descripción al fixture compartido (o uno dedicado a este test) para que
  el test discrimine de verdad entre 270px y 400px.
- **No verificado en dispositivo/emulador real**: el layout completo con la nueva altura del
  hero (gradiente, texto superpuesto, que "nada luzca roto") y el comportamiento táctil real del
  botón gris con feedback — había un dispositivo conectado, pero alcanzar la pantalla requiere
  login real y esta auditoría no tenía credenciales de prueba disponibles.
- El resto de riesgos ya documentados en la auditoría de tri-state de arriba (mensaje de
  WhatsApp con "Sin salsas", flujo visual completo Home→detalle→carrito→checkout→WhatsApp) siguen
  igual de pendientes, sin relación con este cambio puntual.

**Veredicto de este fix puntual: LISTO.** Los 2 puntos de mutación pedidos explícitamente en el
encargo (`CeltasButton.enabled` vs. `onPressed`, y el botón de `product_detail_screen.dart`) se
verificaron con reversión real del código y confirmación de que el test correspondiente falla. El
3er punto de mutación (hero 400px→270px) se verificó también con reversión real, pero el
resultado fue que el test NO detecta la regresión bajo el fixture actual — reportado como
hallazgo honesto, no como éxito. Esto no bloquea el veredicto porque: (1) el ajuste en sí (270px
< 400px, mismo contenido) es una mejora de margen matemáticamente inequívoca, sin necesidad de un
test para confirmarla; (2) el test agregado sí verifica correctamente que el estado ACTUAL (con
el fix) deja el aviso visible sin scroll bajo un viewport realista; (3) no se pidió corregir el
fixture de prueba como parte de este encargo. No se marca ningún checkbox nuevo de la sección
"Salsas/cremas" de arriba por esta auditoría puntual (sigue igual de incompleta, sin relación con
estos 2 ajustes) — se documentó la entrada correspondiente en `ROADMAP.md`.

#### Auditoría puntual: verificación E2E en dispositivo real (los 2 ítems que faltaban)

Alcance: cerrar los 2 checkboxes `[ ]` que quedaban de la sección "Salsas/cremas" — "agregar al
carrito vuelve a Home" y "el texto de WhatsApp trae las salsas concatenadas / 'Sin salsas'
literal" — que sólo podían confirmarse en dispositivo/emulador real y ninguna sesión anterior
tuvo uno conectado para esto.

Se agregó `integration_test/sauces_flow_test.dart` (espejo del patrón de `cart_flow_test.dart`;
usa el usuario de prueba persistente `mobile_it@celtas.pe` contra el backend real). Flujo:
login real → busca en `GET /menu` el primer producto con `sauces` no vacío ("Celtas Burgues
Clasica", salsa "mayonesa") → abre el detalle, elige la salsa, "AGREGAR AL CARRITO" → assert
`detail-add` desmontado + `home-cart-icon` presente (volvió a Home) → repite con el chip "Sin
salsas" → abre el carrito, assert `cremas: mayonesa` y `Sin salsas` → `cart-continue` →
`checkout-confirm` (+ modal de teléfono si aparece) → espera el pedido en `GET /orders/me` →
decodifica el `text` del `whatsappUrl` y assert de que contiene
`Celtas Burgues Clasica (Salsas: mayonesa)` y `Celtas Burgues Clasica (Salsas: Sin salsas)`.
El test **exige** (`expect(orderPath, 'ui')`) que el pedido se haya creado recorriendo el
checkout de la app; tiene un `_createOrderDirect` de respaldo que valida el formato del mensaje
igual, pero si se usa el test falla ruidoso (para que una regresión del checkout no se esconda
tras un verde) — hallazgo de `@tester` en la auditoría, corregido.

Formato del sufijo de salsas verificado por lectura directa de
`../backend-celtas/src/modules/orders/orders.service.ts` (`buildWhatsappUrl`, ~líneas 694-698):
`selectedSauces === null` → sin sufijo; `[]` → ` (Salsas: Sin salsas)`; con nombres →
` (Salsas: n1, n2)`. Payload de la app en `lib/features/checkout/data/order_repository.dart:95-100`:
`selectedSauces.isNotEmpty` → `sauceIds: [ids]`; `else if explicitlyNoSauces` → `sauceIds: []`
explícito; si no, se omite la llave. `_openWhatsapp` (`checkout_screen.dart:270-279`) pasa la URL
a `launchUrl` sin mutarla, así que el `text` del `whatsappUrl` del pedido es exactamente lo que
se abre.

Corridas reales (salida cruda propia, reproducidas también por `@tester`):
- `flutter analyze` → `No issues found!` (con `integration_test/` incluido).
- `flutter test` (suite unit) → `513: All tests passed!`.
- `flutter test integration_test/sauces_flow_test.dart -d emulator-5554` (Android 17 / API 37) →
  verde. La primera corrida cruzó el borde de cierre del local (23:59 hora Lima → 409 "Local
  cerrado", manejado bien por la app); ya dentro de horario, el pedido se creó por el flujo de UI.
- `flutter test integration_test/sauces_flow_test.dart -d 24117RN76L` (Xiaomi físico, Android 15 /
  API 35) → `All tests passed!`, `[camino=ui]`, pedido `bd7fc143-4edf-4d35-93be-42811ae6cd17`
  creado recorriendo el checkout; `text` del `whatsappUrl` con las 2 líneas
  `• 1x Celtas Burgues Clasica (Salsas: mayonesa)` y `• 1x ... (Salsas: Sin salsas)`.

Análisis de falso positivo:
- **"Vuelve a Home"**: si `_addToCart()` no hiciera el `addPostFrameCallback` → `context.pop()`
  (`product_detail_screen.dart:221-224`), `ProductDetailScreen` seguiría montado y `detail-add`
  seguiría presente → `findsNothing` falla. La mutación equivalente ya está documentada arriba
  (sección "fix de la carrera SnackBar/`pop()`": `pop()` inmediato → `Found 1 widget with key
  [detail-add]`). Sólido en ambos dispositivos, 100% flujo de UI.
- **Texto de WhatsApp**: si la app omitiera la llave en vez de mandar `sauceIds: []` para la
  línea "Sin salsas", el backend produciría la línea sin sufijo → falla el `contains('(Salsas:
  Sin salsas)')`. Si el backend perdiera el sufijo, fallan ambos asserts. En la corrida del
  dispositivo físico es un check end-to-end real a través de `OrderRepository.createOrder`.

Pedidos de prueba reales creados en producción durante esta verificación + la auditoría de
`@tester` (cuenta `mobile_it@celtas.pe`, dirección de prueba en San Juan de Miraflores):
`f39feced`, `00f27c37`, `8dff6420`, `00477980`, `44f4e4cc`, `bd7fc143` — borrables desde el panel
admin.

Hallazgo no bloqueante (de `@tester`, ya aplicado): el respaldo `_createOrderDirect` podía
enmascarar un fallo del checkout por UI en el emulador preview Android 17 (`launchUrl` se colgaba
~66s). Corregido: el test ahora trackea el camino y falla si no fue el de UI.

**Veredicto de `@tester`: LISTO.** Los 2 checkboxes de arriba quedan marcados; el checkbox del
`ROADMAP.md` ("selección de salsas/cremas en el detalle de producto", Módulo 4) pasa a `[x]`.

### Refactor: `showCeltasSnackBar` compartido (limpieza de deuda técnica)

Consolida el bloque `ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(...)`,
duplicado repetidas veces en `lib/` (ver riesgos de mantenimiento ya flaggeados arriba, en
Navegación y en esta misma sección), en un helper nuevo:
`lib/shared/widgets/celtas_snackbar.dart` → `showCeltasSnackBar(context, message,
{backgroundColor, duration, margin})`.

**6 sitios migrados** (no 5 — ver hallazgo de `@tester` abajo):

| # | Archivo | Mensaje | margin explícito |
|---|---|---|---|
| 1 | `home_screen.dart` (`_BannerCard._openExternalUrl`) | "No se pudo abrir el enlace del banner." | no |
| 2 | `home_screen.dart` (`_AddButton.onTap`, "+" rápido) | "Agregado: ${item.name}" | sí, 88 (`_CartSummaryBar`) |
| 3 | `product_detail_screen.dart` (`_addToCart`) | "Agregado: X ×N" / "Cambios guardados: X" | sí, 88 |
| 4 | `product_detail_screen.dart` (botón agregar, elección pendiente) | 'Elegí tus salsas o toca "Sin salsas"...' | no |
| 5 | `cart_screen.dart` (`ref.listen` de `couponRemovedNotice`) | mensaje variable del cupón quitado | no |
| 6 | `app_router.dart` (`_handleBackPress`) | "Presiona de nuevo para salir" | no (pasa `duration: _confirmWindow` explícito, ligado a la constante de la ventana de doble-back) |

El sitio 4 (aviso de salsas) **no es una relocalización pura**: es una 4ª ocurrencia del patrón
agregada en la mejora inmediatamente anterior de este mismo módulo ("tri-state de salsas" /
`CeltasButton.enabled`, ver más arriba) — ya estaba presente en el árbol de trabajo (sin commitear
todavía) cuando arrancó este refactor, y por eso cuenta como uno de los sitios "preexistentes" a
consolidar, aunque no exista en el `HEAD` de git al momento de auditar. Se aclara para que una
comparación contra `git show HEAD:...` no se lea como que este refactor introdujo comportamiento
nuevo — no lo hizo, solo relocalizó código ya presente en el working tree.

`margin` default `null` (no un `EdgeInsets` fijo): solo 2 de los 6 sitios (los de "Agregado al
carrito") necesitan el margen de 88px por `_CartSummaryBar`/`CeltasBottomNav`; el resto dependía
del cálculo default de `SnackBar`, que se pierde si el helper impone un margen no nulo por
default.

**Auditoría por `@tester` (dos pasadas):**

*Primera pasada* — encontró 4 problemas reales, todos corregidos antes de este veredicto:
1. **Bug real en el test nuevo**: `celtas_snackbar_test.dart` armaba su propio `wrap()` con
   `backgroundColor: backgroundColor ?? CeltasColors.surface` / `duration: duration ?? const
   Duration(seconds: 2)` — el caso "usa el estilo por default" terminaba pasando esos valores
   explícitos al helper, así que el test era tautológico para `backgroundColor`/`duration` (nunca
   ejercitaba el default real de la función). Confirmado con mutación: cambiar el default de
   `duration` a `Duration(seconds: 9)` y el de `margin` a `EdgeInsets.zero` en
   `celtas_snackbar.dart` **no hizo fallar ningún test**. Corregido separando `wrapDefault()`
   (llama a `showCeltasSnackBar(context, message)` sin argumentos opcionales) de `wrapCustom()`
   (para el caso de overrides) — re-verificado con la misma mutación
   (`backgroundColor: CeltasColors.gold`, `duration: Duration(seconds: 9)`, `margin:
   EdgeInsets.zero`): ahora falla exactamente el test "usa el estilo por default"
   (`Expected: Color(...0.09,0.07,0.06...) Actual: Color(...1.0,0.72,0.0...)`), revertido después
   y confirmado que vuelve a pasar.
2. **6º sitio no migrado**: `home_screen.dart` (`_AddButton.onTap`, "+" rápido) tiene el mismo
   bloque duplicado pero como dos sentencias (`hideCurrentSnackBar()` y `showSnackBar()` por
   separado, sin la cascada `..`), por eso el `grep "\.\.hideCurrentSnackBar()"` usado para ubicar
   los sitios no lo encontró. Migrado a `showCeltasSnackBar` (ver sitio 2 de la tabla).
3. Aclarar que el sitio 4 no es extracción pura — ver párrafo de arriba.
4. `cart_screen_test.dart` no confirmaba explícitamente que el mensaje de `couponRemovedNotice`
   vivía dentro de un `SnackBar` (solo `find.text(...)`, sin `find.byType(SnackBar)`) — reforzado
   con `find.descendant(of: find.byType(SnackBar), matching: find.text(...))`, mismo patrón que
   ya usa `product_detail_screen_test.dart` para el aviso de salsas.

✅ Confirmado por `@tester` en la primera pasada (sin cambios necesarios):
- Paridad de comportamiento visible en los 5 sitios originales (mensaje, `backgroundColor`,
  `duration`, `margin`, `behavior`, estilo de texto) — comparado call site por call site contra
  el `HEAD` anterior al refactor.
- `flutter analyze` (`No issues found!`) y `flutter test` (338/338) limpios.
- Tests preexistentes de los 5 sitios (`cart_screen_test.dart`, `home_screen_test.dart`,
  `app_router_test.dart`) sin diff — pasan intactos, sin haberse debilitado ninguna aserción.

*Segunda pasada (verificación independiente de los 4 puntos corregidos arriba)* — **LISTO**, los
4 se confirmaron reales y suficientes:
1. Repetida la mutación original (`backgroundColor: CeltasColors.gold`, `duration:
   Duration(seconds: 9)`, `margin: EdgeInsets.zero` en `celtas_snackbar.dart`) de forma
   independiente: ahora sí falla `usa el estilo por default...` (antes de la corrección no fallaba
   ningún test). Revertido y confirmado con `diff` contra una copia del archivo tomada antes de
   mutar que `celtas_snackbar.dart` quedó byte a byte igual al original (no hay diff de git para
   comparar porque el archivo es nuevo/untracked). El test vuelve a pasar tras revertir.
2. Confirmado leyendo `home_screen.dart` (`_AddButton.onTap`, líneas ~817-834): usa
   `showCeltasSnackBar(context, 'Agregado: ${item.name}', margin: const
   EdgeInsets.fromLTRB(16, 0, 16, 88))` — mismo margen de 88 que ya usaba antes. El test
   `'el SnackBar de "Agregado" desde el "+" rápido tiene margen para no quedar tapado por la barra
   flotante del carrito'` (`home_screen_test.dart`) sigue intacto y verifica exactamente ese
   margen.
3. La nota sobre el sitio 4 (aviso de salsas) es una aclaración honesta, no un intento de esconder
   el hallazgo: explica con precisión por qué no aparece en `git show HEAD:...` sin minimizar que
   sigue siendo uno de los 6 sitios reales consolidados.
4. Confirmado en `cart_screen_test.dart` (línea ~451): el assert ahora usa `find.descendant(of:
   find.byType(SnackBar), matching: find.text(...))` en vez de `find.text(...)` suelto.

`flutter analyze` (`No issues found!`) y `flutter test` (338/338) limpios tras revertir la
mutación.

- [ ] DTO de edición de perfil no permite cambiar campos que el backend no acepta
- [ ] CRUD de direcciones con verificación de que pertenecen al usuario (aunque esto lo
      garantiza el backend, confirmar que la UI no intente operar sobre IDs ajenos)

### Direcciones con Geoapify (autocompletado + GPS + mapa con pin arrastrable) — ⚠️ LISTO CON OBSERVACIONES

Rama `feature/direcciones-geoapify`, no comiteada todavía al momento de esta auditoría. Archivos
nuevos: `address_location_picker.dart`, `address_map_picker.dart`, `geoapify_repository.dart`,
`location_repository.dart`, `geoapify_providers.dart`, `current_location_controller.dart`,
`location_permission_action.dart`, `location_resolution_failure.dart`,
`geoapify_suggestion.dart`; `Address`/`address_repository.dart`/`address_providers.dart`/
`addresses_screen.dart` ajustados para `latitude`/`longitude`.

`flutter analyze`: `No issues found! (ran in 26.6s)` (salida cruda propia). `flutter test` (suite
completa): `440: Some tests failed.` — la única falla es
`test/features/coupons/presentation/coupons_screen_test.dart: cupón con minPurchaseAmount > 0 →
muestra "Pedido mínimo: S/X.XX"...`, **no relacionada con esta feature** (no toca `coupons/` en
absoluto — confirmado con `git diff --stat` sin cambios en ese módulo). Causa raíz confirmada por
lectura del propio test: usa `expiresAt: DateTime(2026, 8, 20)` hardcodeado — la fecha real del
sistema hoy es exactamente 2026-08-20, y el cálculo de "activo vs. expirado" compara contra
`DateTime.now()` (que ya incluye la hora del día, no solo la fecha), así que un cupón que vence
"hoy a medianoche" ya cuenta como vencido en cualquier momento posterior a las 00:00 de hoy — un
test con fecha fija que coincide con la fecha real de ejecución ("date bomb"), no un bug de esta
feature. Aislado y reproducido corriendo solo ese archivo (`flutter test
test/features/coupons/presentation/coupons_screen_test.dart`): mismo resultado. Reportado para
que se corrija en la sesión principal (ej. calcular `expiresAt` relativo a `DateTime.now()` en
vez de una fecha absoluta), no corregido acá.
`dart run build_runner build --delete-conflicting-outputs`: `Built with build_runner/aot in 11s;
wrote 0 outputs` — `address.freezed.dart`/`address.g.dart` ya comiteados (sin comitear todavía)
son byte-idénticos a lo que generaría el toolchain real, sin drift a mano.

✅ Pasó:
- **Contrato de API verificado contra el código fuente real del backend**, no asumido:
  `backend-celtas/src/modules/users/entities/address.entity.ts` (rama también
  `feature/direcciones-geoapify` en ese repo) — `latitude`/`longitude` son
  `@Column({ type: 'double precision', nullable: true })`, `number | null`; `create-address.dto.ts`/
  `update-address.dto.ts` los declaran `@IsOptional() @IsNumber() @IsLatitude()/@IsLongitude()`.
  Coincide exactamente con el modelo Dart (`double? latitude`/`longitude`, ambos opcionales) y con
  el `.g.dart` generado (`(json['latitude'] as num?)?.toDouble()`).
- **Los 3 bugs de parseo de datos (distrito de grano fino, POI en vez de calle, POI sin calle
  real repitiéndose en `street`) SÍ tienen test que ejercita el caso real, no solo el happy path**
  — confirmado leyendo `test/features/addresses/data/models/geoapify_suggestion_test.dart`: el
  grupo `bestDistrict` prueba explícitamente `city: 'San Juan de Miraflores', district: 'El
  Arenal'` → espera `'San Juan de Miraflores'` (si se revirtiera la prioridad a `district` primero,
  este test fallaría con `'El Arenal'`); el grupo `bestFullAddress` prueba tanto el caso POI-antes-
  que-calle (`formatted` con "Institución Educativa..." vs. `street`+`housenumber` reales) como el
  caso borde `street == name` (Parque Cáceres) cayendo a `formatted` — ambos con fixtures que
  reproducen los valores reales mencionados en el encargo (no inventados), y con
  aserciones que exigen el string exacto post-fix (no solo `isNotEmpty` o similar, que pasaría
  igual sin el fix).
- **429 (rate limit compartido) a nivel repositorio nunca lanza y nunca bloquea**: confirmado con
  test explícito en `geoapify_repository_test.dart` (`'429 (rate limit compartido) → NUNCA lanza,
  devuelve [] silenciosamente'`) y por lectura de los 3 métodos (`autocomplete`/`geocode`/
  `reverseGeocode`), los 3 con el mismo patrón `try/on DioException catch (_) { return
  const []/null; }`. Por lectura de `addresses_screen.dart`/`checkout_screen.dart`: el submit del
  formulario nunca depende de que `latitude`/`longitude` estén resueltos — manda lo que haya en
  `_formLatitude`/`_formLongitude` (posiblemente `null`) sin bloquear ni validar su presencia.
- **Patrón de permiso de ubicación idéntico al ya construido para notificaciones**: comparado
  `LocationPermissionAction`/`locationPermissionActionFor` contra
  `NotificationPermissionAction`/`actionForAuthorizationStatus` — misma forma (enum +
  función pura sin estado), mismo criterio (`deniedForever`/rechazo permanente → abre
  Configuración del sistema directo, JAMÁS vuelve a llamar `requestPermission()`). Cubierto con 6
  tests en `current_location_controller_test.dart` que verifican con `verify()`/`verifyNever()`
  cada rama (concedido, denegado→acepta, denegado→rechaza de nuevo sin reintentar,
  `deniedForever`→Configuración sin llamar `requestPermission()`, GPS de sistema apagado sin
  llamar `getCurrentPosition()`, excepción nativa clasificada como `unknown`) — no solo el
  happy path.
- **Contrato de API real, no aproximado**: `AddressRepository` manda `latitude`/`longitude` con
  la sintaxis null-aware de mapa (`'latitude': ?latitude`) tanto en `create` como en `update`, así
  que un valor `null` omite la llave del body en vez de mandar `"latitude": null` explícito —
  consistente con que el DTO del backend los trata como `@IsOptional()` (ausente ≠ error), sin
  necesidad de mandar `null` a propósito.
- **Fidelidad de diseño**: la pantalla "09 · DIRECCIONES GUARDADAS" de
  `design-reference/Celtas App Mockups.dc.html` no incluye ningún GPS/mapa/autocompletado (es UI
  enteramente nueva de esta feature, sin equivalente en el mockup original de 12 pantallas) — los
  colores usados en los widgets nuevos (`CeltasColors.orange` = `#E8590C`, `CeltasColors.
  textSubtle` = `#6B6357`) coinciden con los valores reales ya usados en el resto de la pantalla
  de direcciones del mockup (confirmado línea por línea contra el HTML/CSS real, no de memoria).
  Sin `Color(0xFF...)` sueltos en ninguno de los 2 widgets nuevos.
- **Estados de UI de la pantalla contenedora** (`AddressesScreen`): loading (`SlowBackendNotice`),
  error con mensaje real + REINTENTAR, y vacío (`_EmptyAddresses`) todos explícitos — confirmado
  por lectura de código, coincide con el patrón ya usado en el resto de la app.
- **Permisos nativos declarados en ambas plataformas**: `AndroidManifest.xml`
  (`ACCESS_FINE_LOCATION`/`ACCESS_COARSE_LOCATION`) e `Info.plist`
  (`NSLocationWhenInUseUsageDescription` con texto específico mencionando el botón "Usar mi
  ubicación actual") — ninguno pide ubicación en segundo plano (`always`/`ACCESS_BACKGROUND_
  LOCATION`), consistente con el uso real (solo al tocar el botón).
- **`AddressFormCard`/`checkout_screen.dart`**: la integración de `latitude`/`longitude` en
  ambos callers (pantalla de direcciones y checkout) sigue el mismo patrón — se resetean a `null`
  tras un alta exitosa, y el widget compartido (`CeltasTextField`, con `onChanged`/`suffixIcon`/
  `focusNode` nuevos, todos opcionales) no rompe ningún uso existente.

❌ Falló:
- Ninguno funcional propio de esta feature. (La única falla de `flutter test` es de
  `coupons_screen_test.dart`, no relacionada — ver arriba.)

⚠️ Riesgos / observaciones — **no bloqueantes para esta auditoría, pero pendientes de cerrar
antes de dar el módulo por completo verificado**:
- **Los bugs #1 (dropdown de sugerencias detrás del mapa/botón GPS, z-order) y #2 (debounce del
  drag del pin) NO tienen ningún test automatizado que los cubra** — confirmado con `grep -rn`
  sobre todo `test/` buscando `AddressLocationPicker`/`AddressMapPicker`/`_SuggestionsList`/
  `onPositionChanged`/cualquier referencia a "suggestion": no existe ningún widget test que monte
  `AddressLocationPicker` o `AddressMapPicker` directamente, y `addresses_screen_test.dart` (el
  único test que monta el formulario completo) nunca overridea `geoapifyRepositoryProvider` ni
  configura `GEOAPIFY_API_KEY` en su `.env` de prueba — con `hasApiKey == false`, el dropdown de
  sugerencias nunca llega a aparecer en ese suite (el único comentario que lo menciona,
  línea 184, es solo sobre un `pump()` extra por el layout más alto, no sobre su contenido). Esto
  significa que si alguien revirtiera el fix del `Stack` externo (bug #1) o el debounce del mapa
  (bug #2) mañana, **ningún test lo detectaría** — a diferencia de los bugs #3/#4/#5, que sí están
  genuinamente cubiertos con fixtures reales y aserciones exactas. Recomendación para la sesión
  principal: al menos un widget test que (a) overridee `geoapifyRepositoryProvider` con un stub
  que resuelva sugerencias, escriba texto, dispare el debounce con `tester.pump(_debounceDuration)`
  y confirme con `tester.getRect`/orden de pintado que el `_SuggestionsList` queda por encima del
  mapa/botón; y (b) simule varios `onPositionChanged(hasGesture: true)` seguidos dentro de la
  ventana de debounce y confirme que `reverseGeocode` se llama una sola vez (`verify(...).called(1)`
  en vez de una vez por evento).
- **`.env.example` incluye una API key de Geoapify que parece real** (`GEOAPIFY_API_KEY=
  99317e665beb4d499fac674d1a92e91b`, formato hex de 32 caracteres, exactamente el formato que
  emite Geoapify) — confirmado con `git diff HEAD -- .env.example` que es un cambio nuevo, sin
  comitear todavía, en un archivo que el propio `.gitignore` marca explícitamente para
  versionarse (`!.env.example`, a diferencia de `.env`/`.env.*`). Si esta key es la real usada en
  desarrollo (no una de prueba/demo desechable), comitearla expondría una credencial compartida
  por rate limit a cualquiera con acceso al repo. **No es un bug de código, pero es un hallazgo de
  seguridad real que vale la pena confirmar antes de comitear** — reemplazar por un placeholder
  (`GEOAPIFY_API_KEY=tu_api_key_aqui`) si la key es genuina, o rotarla en
  https://myprojects.geoapify.com/ si ya se comiteó por error en algún punto.
- No hay test de integración end-to-end contra el backend local (`192.168.18.13:3000`) corrido en
  esta auditoría — el checklist funcional a mano (backend con la IP local, sugerencias reales,
  botón GPS, drag+reverse geocoding, guardado persistente con `latitude`/`longitude`) se tomó como
  ya reportado por el usuario y no se re-ejecutó en vivo; esta auditoría se limitó a análisis
  estático + tests automatizados + lectura de código/contrato, no a una re-verificación manual en
  dispositivo real.
- Precedente de otras secciones de este documento (ej. banners, salsas/cremas) de mutar código a
  propósito y confirmar que el test correspondiente falla, no se aplicó a los widgets nuevos de
  esta sección por falta de tests que mutar en primer lugar (ver el punto de arriba) — sí se aplicó
  al verificar que `build_runner` no genera drift.

**Veredicto: LISTO CON OBSERVACIONES.** Ningún hallazgo es un bug funcional nuevo — el código de
los 5 fixes reportados es correcto por lectura y, donde hay test, el test genuinamente ejercita el
bug (confirmado, no solo nominal). Antes de comitear, dos cosas concretas:
1. Confirmar si la API key en `.env.example` es real y, si lo es, reemplazarla por un placeholder
   (o rotarla si ya llegó a comitearse antes).
2. Agregar cobertura automatizada para los bugs #1 (z-order del dropdown) y #2 (debounce del
   drag), hoy sin ningún test de regresión — el resto del módulo (parseo de datos, permisos,
   contrato de API, manejo de 429, estados de UI) sí queda cerrado con evidencia real.
La falla de `coupons_screen_test.dart` (date bomb, no relacionada) debe reportarse aparte a la
sesión principal — no bloquea este módulo pero sí impide decir "440/440" sin matices.

### Bloqueo por local cerrado en el checkout (409 de `POST /orders` + aviso preventivo `GET /settings/business-hours`) — ✅ COMPLETO

Feature cross-repo (backend y `celtas-admin` ya auditados con veredicto LISTO en sus propios
repos); esta sección cubre solo la pieza de mobile. Contrato verificado contra
`backend-celtas/src/modules/orders/orders.service.ts` (`create`: el check
`SettingsService.isOpenNow()` ocurre ANTES de tocar la base, así que un 409 nunca deja nada a
medias) y `backend-celtas/src/modules/settings/settings.controller.ts`/`settings.service.ts`
(`GET /settings/business-hours` → `{ open, message, schedule, manualClosed }`, `message: string
| null`, `null` solo cuando `open: true`).

`git diff` confirmado real (no solo el resumen del encargo): `lib/core/network/api_client.dart`
y `lib/features/checkout/data/order_repository.dart` **sin diff** (`ApiException.statusCode` ya
existía, extraído de `error.response?.statusCode` en `apiExceptionFromDio`, y
`order_repository.dart` ya envolvía su único `catch` con esa función — no hizo falta tocar
ninguno de los dos). Cambios reales: `checkout_screen.dart` (`_showClosedDialog`,
`_ClosedNotice`, rama `if (e.statusCode == 409)` en `_confirmOrder`) + feature nueva
`lib/features/settings/` (`BusinessHours` freezed, `SettingsRepository`,
`businessHoursProvider`).

`flutter analyze`: `No issues found!` (salida cruda propia). `flutter test` (suite completa):
`349: All tests passed!` (salida cruda propia; 348 previos + 1 nuevo agregado por esta
auditoría, ver hallazgo de riesgo cubierto más abajo).

✅ Pasó:
- **Mutación real, verificada de forma independiente**: `if (e.statusCode == 409)` →
  `if (false && e.statusCode == 409)` en `checkout_screen.dart` hace fallar exactamente el test
  del diálogo (`Expected: exactly one matching candidate / Actual: Found 0 widgets with key
  [checkout-closed-dialog]`), el resto de la suite sigue intacta; reverté y confirmé `git diff`
  vacío + el test vuelve a pasar.
- **409 vs. resto de errores de `POST /orders` sin regresión**: el test `'producto no disponible
  → mensaje real del backend, no navega'` sigue usando `ApiException(..., statusCode: 400)` y
  pasa sin cambios — confirma que el 400 (producto no disponible, y por el mismo mecanismo
  cualquier otro código que no sea 409, ej. cupón inválido) sigue mostrándose inline vía
  `_orderError`, sin colisionar con el diálogo nuevo.
- **Carrito intacto tras el 409**: `container.read(cartProvider).items` se verifica `isNotEmpty`
  tanto justo después del diálogo como después de cerrarlo con "ENTENDIDO"; no navega a Home
  (`find.text('HOME')` → `findsNothing`) en ningún momento del flujo — coherente con que el 409
  ocurre ANTES de tocar la base en el backend, así que no hay pedido creado que limpiar.
- **Contrato de `ApiException`/`apiExceptionFromDio` verificado línea por línea**: extrae
  `data['message']` del body de error (`{success: false, message, statusCode}`, confirmado contra
  `HttpExceptionFilter` real del backend) y preserva `error.response?.statusCode` — el mock de
  409 en `order_repository_test.dart` ejercita exactamente ese camino.
- **`BusinessHours.message` nullable es real, no defensivo**: confirmado en
  `settings.service.ts` (`evaluateSchedule`/`isOpenNow`) que `message: null` ocurre únicamente en
  la rama `open: true`; el modelo Dart (`String? message`) refleja eso con precisión.
- **Fidelidad de patrón del aviso preventivo**: `_ClosedNotice` es un espejo estructural exacto
  de `_MissingAddressNotice` ya auditado (mismo padding, `CeltasRadii.input`, ancho de borde 1.2,
  tamaño de ícono 18, `fontWeight.w700`/`fontSize: 12.5`, `withValues(alpha: 0.12)`), solo cambia
  el token de color (`redLight` en vez de `gold`) — y `redLight` es el mismo tono ya usado en
  todo el resto de la app para estados negativos (`OrderStatusBadge` de `cancelado`,
  `CouponStatus.expired`), consistente con el criterio de "no es algo que el cliente pueda
  corregir llenando el formulario" documentado en el propio comentario del widget.
- **Aviso preventivo no bloquea el flujo real**: verificado por lectura de código que
  `businessHoursAsync` solo se consulta con `.valueOrNull?.open == false` para decidir si se
  muestra el banner — nunca se usa para deshabilitar `onPressed` del botón de confirmar. El 409
  real de `POST /orders` sigue siendo la única fuente de verdad del bloqueo, correcto dado que el
  local puede cerrar recién mientras el checkout ya está abierto.
- **Riesgo señalado en el encargo, cubierto con test nuevo agregado por esta auditoría**: qué
  pasa si `businessHoursProvider` está en loading o falla al entrar al checkout — confirmado por
  lectura que la pantalla solo lee `.valueOrNull` (nunca `.value`/`.requireValue`, que sí
  lanzarían en estado de error), así que loading y error se comportan igual: sin aviso, sin
  crash, sin filtrar ningún mensaje de error a la UI del checkout. Se agregó el test `'GET
  /settings/business-hours falla (ej. backend dormido) → sin aviso, sin crash, checkout sigue
  usable'` en `checkout_screen_test.dart` (mock que lanza `ApiException`), confirmado en verde
  junto con el resto de la suite (349/349).

❌ Falló:
- Ninguno funcional.

⚠️ Riesgos / hallazgos menores no bloqueantes (los 2 primeros, corregidos tras esta auditoría):
- ~~Inconsistencia de color en `_showClosedDialog`~~ — **corregido**: `backgroundColor` pasó de
  `CeltasColors.surface` a `CeltasColors.card`, igual que los otros 3 `AlertDialog` de la app
  (`profile_screen.dart`, `cart_screen.dart`, `addresses_screen.dart`). `flutter analyze`/
  `flutter test` (349/349) vueltos a correr después del cambio, limpios.
- ~~Shape del mock de 409 no calcado del contrato real~~ — **corregido**: el mock en
  `order_repository_test.dart` pasó de `{'message', 'statusCode', 'error': 'Conflict'}` a
  `{'success': false, 'message', 'statusCode'}`, igual al body real de `HttpExceptionFilter`.
- No se pudo verificar el 409 real end-to-end contra el backend de producción en esta auditoría
  (mismo límite ya declarado en el encargo: no hay credenciales de admin para activar el cierre
  manual desde `celtas-admin` en esta sesión) — la cobertura de esta pieza depende enteramente de
  mocks bien alineados al contrato leído del código fuente real, no de una prueba en vivo del
  código de error 409 específico.
- No hay verificación en dispositivo/emulador Android real de esta feature (mismo patrón de deuda
  pendiente que otras secciones de este documento) — solo widget tests.

**Veredicto: LISTO.** Los 2 hallazgos menores señalados por `@tester` (inconsistencia de color,
shape de mock no 100% calcado) se corrigieron de inmediato tras la auditoría — quedan solo los 2
riesgos de verificación en vivo (backend real con 409, dispositivo Android), ya documentados como
no bloqueantes en el encargo original.

### Comentario/nota libre opcional por ítem del carrito (`comment`) — ✅ COMPLETO

Feature espejo de `OrderItem.comment`, ya soportado en producción por el backend y por
`celtas-admin`. Contrato verificado por lectura directa (no por el resumen del encargo):
`backend-celtas/src/modules/orders/dto/create-order.dto.ts`
(`CreateOrderItemDto.comment?: string`, `@IsOptional()`, `@IsString()`, `@MaxLength(140)`) y
`backend-celtas/src/modules/orders/orders.service.ts` (`resolveComment`, línea ~398: trimea y
devuelve `null` si queda vacío; `buildWhatsappUrl`, línea ~426: agrega ` — Nota: {comment}` al
mensaje solo cuando `comment !== null`). `celtas-admin/src/types/api.d.ts` línea 1179 confirma el
mismo `comment?: string` en el DTO generado. Coincide exactamente con lo implementado en mobile.

- [x] `flutter analyze` limpio (`No issues found!`, corrido de forma independiente)
- [x] `flutter test` 399/399 (corrido de forma independiente, no solo confiado del reporte)
- [x] `CartItem.comment` (`String?`, default `null`) participa en `lineKey` solo cuando no es
      `null` — sin salsas ni comentario la key sigue siendo `menuItemId` puro (idéntica a antes);
      con salsas y sin comentario sigue siendo `menuItemId::idsOrdenados` (idéntica a antes); el
      segmento de comentario solo se agrega cuando hay uno. Confirmado por lectura de
      `cart_item.dart` y con **mutación real**: reemplazar el `if (comment != null) parts.add(...)`
      condicional por un `parts.add(comment ?? '')` incondicional (el bug real que el encargo
      reportó haber cometido y corregido) rompió 7+ tests preexistentes de salsas
      (`cart_provider_test.dart`, `product_detail_screen_test.dart`) con el error exacto esperado
      (`'i-3::s-1'` vs `'i-3::s-1::'`, doble separador). Revertido con `git checkout --` y
      reconstruido a mano comparando contra el contenido ya leído en esta misma auditoría (ver
      nota de incidente abajo) — confirmado `flutter analyze`/`flutter test` (399/399) verdes tras
      la reconstrucción.
- [x] Fusión de filas: mismo producto + misma combinación de salsas + mismo comentario → se
      fusiona (suma cantidad); si el comentario difiere, queda en fila aparte — `addItem`/
      `updateLine` (`cart_provider.dart`) no necesitan un `OR` especial para `comment` en la
      fusión (a diferencia de `explicitlyNoSauces`) porque, al participar en `lineKey`, dos filas
      que se fusionan por definición ya tienen el mismo comentario.
- [x] Trim + `null` si queda vacío, tanto del lado del cliente (`_addToCart` en
      `product_detail_screen.dart`) como espejado del criterio real del backend
      (`resolveComment`) — dos líneas de defensa, no una dependencia ciega del backend.
- [x] `order_repository.dart`: `comment` se manda en el payload de `POST /orders` SOLO si
      `item.comment != null && item.comment!.trim().isNotEmpty` — mismo criterio que `sauceIds`/
      `addressSnapshot`/`couponCode`, nunca una llave irrelevante. Confirmado con los 4 casos de
      `order_repository_test.dart`: ausente, presente+trimeado, solo-espacios→omitido,
      independiente por ítem (un ítem con nota y otro sin nota en el mismo pedido).
- [x] Fidelidad visual de "NOTA PARA TU PEDIDO": sin mockup de referencia para esta sección (no
      existe en `design-reference/`, es una sección nueva igual que "SALSAS Y CREMAS" lo fue en su
      momento) — juzgado contra el lenguaje visual ya establecido en la misma pantalla, no contra
      un CSS inexistente. Confirmado por lectura: mismo patrón exacto que el label de
      "SALSAS Y CREMAS" (`labelSmall`, `fontSize: 13`, `fontWeight: w700`, `letterSpacing: 0.5`,
      `color: CeltasColors.textLabel`) + subtítulo (`bodySmall`, `fontSize: 12`,
      `CeltasColors.textMuted`) — no una aproximación visual distinta.
- [x] `cart_screen.dart`: línea `'nota: ${item.comment}'` solo cuando `comment` no es nulo/vacío,
      mismo estilo (`bodySmall`, `fontSize: 11.5`, `italic`, `textMuted`) que la línea de salsas,
      debajo de ella si ambas aplican — confirmado por los 3 casos nuevos de `cart_screen_test.dart`
      (con salsas+nota, sin salsas+nota, sin nota→no muestra la línea).

**Incidente durante esta auditoría (autoinfligido, corregido en el momento):** al hacer la prueba
de mutación de arriba, se usó `git checkout -- lib/features/cart/data/models/cart_item.dart` para
revertir — pero como esta feature completa nunca se había comiteado (confirmado con `git log`/
`git status`: todo el cambio vivía como working tree sin commit), ese comando no deshizo solo la
mutación: devolvió el archivo entero al último commit (`485ea1e`), es decir, **borró también la
implementación real del campo `comment`** (no solo el bug de la mutación). Detectado de inmediato
por el aviso del propio harness de que el archivo había cambiado en disco de forma no solicitada;
reconstruido a mano línea por línea contra el contenido exacto ya leído momentos antes en esta
misma sesión de auditoría (no desde memoria aproximada). Re-verificado con `flutter analyze`
(`No issues found!`) y `flutter test` (399/399) después de la reconstrucción — mismo resultado que
antes del incidente, sin pérdida real. Documentado acá en vez de omitido porque, aunque no afectó
el resultado final, es el tipo de error que si no se detecta a tiempo destruye trabajo ajeno sin
dejar rastro en git (nada comiteado, nada en el stash). Lección para próximas auditorías de este
proyecto: no usar `git checkout --` como mecanismo de revertir mutaciones de prueba sobre archivos
que puedan tener cambios sin commitear — preferir guardar el contenido original (ya leído) y
restaurarlo con `Edit`, o confirmar primero con `git status`/`git diff` que el archivo está
comiteado antes de un `checkout` destructivo.

⚠️ Hallazgo no bloqueante (señalado en el encargo, confirmado real, no corregido por decisión
explícita de alcance): el ícono de lápiz de `cart_screen.dart`
(`_CartItemRow._offersSauces`) decide su visibilidad solo por si el producto ofrece catálogo de
salsas. Un producto SIN salsas pero CON un comentario ya agregado no muestra el ícono de editar —
no hay forma de editar solo la nota desde el carrito sin volver a pasar por "agregar de nuevo"
(que crea una fila nueva en vez de reemplazar, dado que ya no hay `oldLineKey` accesible desde esa
ruta). No se pidió cambiar este criterio en este encargo; queda como mejora de UX a evaluar, no
como bug de esta feature.

**Veredicto: LISTO.** Contrato de backend confirmado por lectura directa (no por el resumen del
encargo), diseño consistente con el lenguaje visual ya establecido en la pantalla, `flutter
analyze` y `flutter test` (399/399) verdes de forma independiente, el fix de `lineKey` reportado
como corregido se confirmó real (no cosmético) con mutación, y los 5 casos de negocio del encargo
(fusión/no-fusión por comentario, trim+null, comment nunca se manda si no aplica, diseño
consistente, estados ya cubiertos por la sección de salsas) verificados. Sin regresiones: los 330+
tests preexistentes de salsas siguen pasando sin haberse debilitado.

## Pedidos / Cupones

- [x] Badges de estado de pedido visualmente distinguibles entre sí (los 5 estados)
- [x] Historial de pedidos trae la lista completa vía `GET /orders/me` — confirmado que ese
      endpoint NO pagina ni filtra por status para el cliente (solo `GET /orders`, admin-only,
      lo hace); no debe asumirse ni construirse paginación para `/orders/me` ni `/coupons/me`
      (mismo patrón sin paginar)
- [x] El historial refleja un pedido recién creado al volver del checkout (invalidar +
      re-fetchear, no insertar a mano)
- [x] Cupones muestran estado (activo/usado/expirado) correctamente
- [x] "Mis cupones" ordena la lista LOCALMENTE por `effectiveStatus` (no `status` crudo):
      activos → usados → expirados al final, sin importar el orden en que responde el backend
      (`_sortedByEffectiveStatus` en `coupons_screen.dart`, concatenación de tres `where()` en
      vez de `list.sort()` con comparador, porque `List.sort` no garantiza estabilidad). Los
      usados/expirados NUNCA se ocultan ni se recortan — sin límite de cantidad ni paginación en
      esta pantalla (`GET /coupons/me` ya se llamaba sin paginar desde el cierre original del
      módulo; confirmado que este ajuste no le agregó `page`/`limit`). Cubierto con test de
      widget (`coupons_screen_test.dart`, "orden local...") que alimenta el mock en orden
      "raro" (expirado, activo, usado) y verifica el orden visual leyendo los `Text` que
      contienen "Código:" en orden de aparición en el árbol — técnica confiable acá porque son
      3 `Text` simples dentro de un `ListView.separated` de un solo nivel, sin reordenamiento
      de render (`Stack`/`Positioned`) que pudiera desacoplar orden de build de orden visual.
      `CouponStatus` es un enum cerrado de 3 valores (`active`/`used`/`expired`), así que los
      tres `where()` particionan la lista completa sin riesgo de un caso fuera de rango que se
      pierda. Dos huecos de cobertura señalados por `@tester` en la auditoría original, cerrados
      después con tests dedicados: (1) orden relativo estable DENTRO de cada categoría con 2+
      cupones por grupo (activo/usado/expirado en pares, backend responde "B antes que A" en
      cada categoría; el test confirma que se pinta B→A tal cual llegó, no reordenado por código
      ni por ningún otro criterio) — usa una superficie de test más alta
      (`tester.view.physicalSize`, mismo patrón que `orders_screen_test.dart`) porque
      `ListView.separated` es perezoso y las 6 tarjetas no caben en el viewport default; (2) el
      orden se recalcula correctamente tras pull-to-refresh cuando el backend devuelve datos
      nuevos y en otro orden que la carga inicial (un solo cupón usado → los 3 estados
      desordenados), confirmando que el reordenamiento no queda pegado al primer fetch. 279/279
      tests, `flutter analyze` limpio. Auditado por `@tester`: veredicto LISTO
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
- [x] **Aviso explícito de dirección faltante en checkout + botón realmente deshabilitado**
      (`checkout_screen.dart`, sin commitear todavía): `_MissingAddressNotice` (mismo patrón
      card+ícono+texto que `SlowBackendNotice`, tono `CeltasColors.gold` de advertencia) se
      muestra de forma reactiva junto al botón mientras `_selectedAddressId == null`; `onPressed`
      del `CeltasButton` queda `null` en ese caso (mismo criterio que carrito vacío/`_confirming`,
      confirmado leyendo `celtas_button.dart`: `enabled = onPressed != null && !loading`, fondo
      pasa de `CeltasColors.orange` a `CeltasColors.border`). Se quitó el `if (addressId == null)
      {...}` muerto de `_confirmOrder` (inalcanzable con el botón deshabilitado) — confirmado por
      lectura completa del diff, sin referencias rotas. `_orderError` se sigue usando solo para
      errores reales de API/WhatsApp (`ListView` del cuerpo), sin colisionar con el nuevo aviso
      (`Column` de la barra inferior fija) — son widgets distintos en zonas distintas del layout.
      `flutter analyze`: `No issues found!`. `flutter test`: 284/284 (283 existentes + 1 nuevo).
      **Hallazgo cerrado en el momento**: no existía cobertura para el flujo completo (dirección
      vacía → aviso visible + botón deshabilitado → dirección agregada → aviso desaparece + botón
      habilitado) — los tests existentes cubrían "sin direcciones → muestra el formulario" y
      "agregar dirección → queda seleccionada" por separado, pero ninguno verificaba el estado del
      aviso/`onPressed` explícitamente. Se agregó un test nuevo en `checkout_screen_test.dart`
      ("aviso de dirección faltante...") y se confirmó que es un test de regresión real: revertido
      temporalmente el fix vía `git stash push -- lib/features/checkout/presentation/
      checkout_screen.dart` (reversible, restaurado con `git stash pop` acto seguido), el test
      falla con `Expected: exactly one matching candidate / Actual: Found 0 widgets with key
      [checkout-missing-address-notice]` — confirma que ejercita el código real, no un falso
      positivo. Sin precedente exacto en `design-reference/` para este aviso (es un estado
      dinámico/interactivo que el mockup estático no representa), pero usa únicamente tokens ya
      aprobados (`CeltasColors.gold`, `CeltasRadii.input`, sin `Color(0xFF...)` sueltos) y respeta
      la semántica de color ya establecida en la app (gold = advertencia/atención, no error —
      igual criterio que el ícono de reloj de `SlowBackendNotice`; `redLight` sigue reservado para
      errores reales de `_orderError`/`_AddressError`).

      ⚠️ **Pendiente de validar en dispositivo real**: no hay un dispositivo Android conectado en
      esta sesión (`flutter devices` solo lista Windows/Chrome/Edge) — no se pudo confirmar
      visualmente en pantalla física el contraste del aviso gold sobre el fondo, ni el estado
      gris real del botón deshabilitado, ni que el layout de la barra inferior (aviso + botón +
      `SafeArea`) no se corte en un dispositivo angosto real. Esto NO se probó y no se reporta
      como probado.

      **Veredicto: LISTO CON OBSERVACIONES** — todo lo verificable desde análisis estático, tests
      y lectura de código pasa; queda pendiente la verificación visual en dispositivo real antes
      de considerar el cambio 100% cerrado.

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

### Aviso proactivo por push de cambio de horario de atención (`{ businessHoursChanged: 'true' }`) — última pieza de la feature cross-repo "horario de atención" — ✅ COMPLETO

Extiende el patrón ya existente de `NotificationTarget` (sealed class, clasificación de `data`
por llave presente, sin campo `type` explícito) con un cuarto caso,
`BusinessHoursNotificationTarget`, para el aviso que el backend manda cuando el admin
activa/desactiva el cierre manual desde `celtas-admin`. Payload sin más contenido que la llave
`businessHoursChanged` — nunca la fuente del estado real, siempre hay que reconsultar
`GET /settings/business-hours` (`businessHoursProvider`).

✅ **Verificado de forma independiente**:
- `git diff` real de los 3 archivos tocados
  (`notification_target.dart`, `notification_service.dart`, `notifications_screen.dart`)
  coincide exactamente con lo reportado por la sesión principal, incluido el 4to switch en
  `notifications_screen.dart` (`_NotificationCard._handleTap` + el cálculo de `tappable`) que no
  estaba en el encargo original y se agregó por el error de exhaustividad del compilador — no es
  un desvío sin justificar, es la consecuencia correcta de que el `sealed class` obliga a cubrir
  el caso nuevo en cualquier `switch` existente.
- `grep` de `OrderNotificationTarget|CouponNotificationTarget|NoneNotificationTarget|BusinessHoursNotificationTarget`
  en todo `lib/` confirma que no queda ningún otro `switch`/pattern-match sobre
  `NotificationTarget` sin actualizar — los únicos 4 puntos de consumo
  (`fromPayload`, `_invalidateFor`, `_navigateFor`, `fallbackTitle` de `_saveToHistory` en
  `notification_service.dart`, y `_handleTap`/`tappable` en `notifications_screen.dart`) cubren el
  caso nuevo de forma exhaustiva.
- **Mutación 1** (comentar el `if (data.containsKey('businessHoursChanged'))` en `fromPayload`):
  repetida de forma independiente — el test `{ businessHoursChanged: "true" } →
  BusinessHoursNotificationTarget` falló exactamente como se esperaba (`Actual:
  NoneNotificationTarget`). Reverted, `git diff` idéntico al original después.
- **Mutación 2** (quitar `&& target is! BusinessHoursNotificationTarget` del cálculo de
  `tappable` en `notifications_screen.dart`): repetida de forma independiente — el test de
  `onTap: null` falló exactamente como se esperaba (`Expected: null, Actual: <Closure...>`).
  Reverted, `git diff` idéntico al original después.
- `flutter analyze`: `No issues found!` (salida cruda propia, no la de la sesión principal).
- `flutter test` completo: **361/361** (salida cruda propia).
- **`_invalidateFor`'s nuevo case confirmado correcto contra el código real**, no dado por
  sentado: `businessHoursProvider` (`settings_providers.dart`) es un `FutureProvider` global, sin
  `.autoDispose`; `main.dart` crea un único `ProviderContainer` a mano y lo pasa tanto a
  `NotificationService.instance.init(container)` como a la raíz del árbol de widgets vía
  `UncontrolledProviderScope(container: container, ...)` — es literalmente el mismo container y
  la misma instancia de provider que `HomeScreen`/`CheckoutScreen` leen con `ref.watch`/
  `ref.listenManual`. `_container.invalidate(businessHoursProvider)` desde `NotificationService`
  (que corre fuera del árbol de widgets) sí dispara la reprogramación del timer del Home tal como
  se afirma — no hay dos containers ni dos instancias de provider en juego.
- **Decisión de excluir `BusinessHoursNotificationTarget` de `tappable`**: evaluada como
  coherente, no como un desvío raro — sigue el mismo criterio ya usado para
  `NoneNotificationTarget` (si no hay pantalla a la que navegar, la tarjeta no debería
  comportarse como tocable, para no dejar un toque sin ningún efecto visible/ripple sin acción).
  No había instrucción explícita del encargo sobre esto; la alternativa (dejarla tappable con un
  feedback distinto, ej. forzar un refetch manual con un SnackBar) también sería válida mas no
  fue pedida — no es necesaria para que el cartel del Home se actualice, que ya ocurre solo por
  `_invalidateFor` sin depender de que el cliente toque nada.

❌ **Nada falló** en esta ronda.

⚠️ **Riesgos / casos borde no cubiertos, no bloqueantes**:
- Sigue sin existir `notification_service_test.dart` — `_invalidateFor`/`_navigateFor` (incluido
  el case nuevo de `BusinessHoursNotificationTarget`) no tienen cobertura automatizada, mismo gap
  preexistente ya documentado en auditorías anteriores del módulo 9, no introducido por esta
  ronda. No se pudo mutar ese método por la misma razón: no hay ningún test que lo ejercite.
- **No se pudo probar en vivo** con un dispositivo/emulador Android o iOS conectado activando el
  cierre manual real desde `celtas-admin`: `flutter devices` en esta sesión solo detecta Windows
  desktop y navegadores web (Chrome/Edge), ninguno de los dos recibe push de FCM de forma
  representativa del comportamiento real en Android, y no había credenciales de admin
  disponibles para disparar el toggle real desde el panel. Mismo límite ya declarado en
  auditorías anteriores de esta misma feature (el bloqueo 409 y el cartel event-driven del Home
  tampoco se probaron en vivo). Riesgo real no cerrado: el comportamiento exacto de
  `flutter_local_notifications`/FCM en foreground/background/terminated para este payload
  específico solo está verificado por lectura de código (mismo camino ya usado por
  `orderId`/`couponCode`, que sí se probó en vivo en el módulo 9 original), no por observación
  directa.
- Hallazgo de higiene de repo, no de código: al momento de esta auditoría, el working tree tenía
  sin commitear no solo los 3 archivos de esta ronda sino también el cartel event-driven del Home
  y la extracción de `business_closed_notice.dart` (trabajo de una sesión anterior, ya auditado
  LISTO según el encargo) — confirmado que el único commit real de la feature de horario
  (`bc7c3ad`) solo incluye el bloqueo 409 + aviso preventivo del checkout, no el cartel del Home.
  No es un problema de esta ronda ni bloquea su veredicto, pero vale la pena que la sesión
  principal comitee ese trabajo pendiente para que quede un historial de commits consistente con
  lo que `ROADMAP.md` marca como completo.

**Veredicto: LISTO PARA MARCAR COMPLETO.** Con esto se cierra la feature cross-repo "horario de
atención" — backend, `celtas-admin`, bloqueo real (409), aviso preventivo del checkout, cartel
event-driven del Home, y ahora el aviso proactivo por push. Ningún bug real encontrado en esta
ronda específica.

---

### Gestión del permiso de notificaciones en Perfil (`_NotificationPermissionRow`) — ✅ LISTO

Escrito originalmente en un sandbox sin SDK de Flutter/`pub.dev` bloqueado — nunca había pasado
por `flutter analyze`/`flutter test` reales hasta esta auditoría. Verificado con herramientas
propias (no repetido de lo que reportó la sesión que escribió el código).

`flutter pub get`: `permission_handler` resuelve en `11.4.0` (satisface `^11.3.1`), sin
conflictos — confirmado en `pubspec.lock` (`git diff` propio). `flutter analyze` (salida cruda
propia, tras revertir todas las mutaciones de esta auditoría): `No issues found!`. `flutter test`
(suite completa, salida cruda propia): `377: All tests passed!`.

✅ Pasó:
- **`actionForAuthorizationStatus` cubre los 4 casos de forma exhaustiva** (`switch` sin
  `default` sobre un `enum` — el compilador exige agregar cualquier caso nuevo, no hay forma de
  que un 5to valor de `AuthorizationStatus` pase desapercibido): `notDetermined` →
  `requestPermission`, `denied` → `openSystemSettings`, `authorized`/`provisional` → `none`.
  Cubierto 1:1 por los 4 tests de `notification_permission_action_test.dart`.
- **Mutación real** (`denied` → `requestPermission` en vez de `openSystemSettings`, revertida
  después, `git diff` limpio confirmado): falla exactamente en las 3 capas que deberían
  detectarlo — `notification_permission_action_test.dart` (lógica pura),
  `notification_permission_provider_test.dart` (`handleTap()`), y `profile_screen_test.dart`
  (grupo "Renglón de notificaciones", tap real) — confirma que las 3 capas de test ejercitan
  código real, no un mock que pasaría igual sin él.
- **`WidgetsBindingObserver` en `ProfileScreen`**: `addObserver(this)` en `initState`,
  `removeObserver(this)` en `dispose` — sin doble-registro (una sola llamada a cada uno, mismo
  patrón ya usado y auditado en `HomeScreen`/`businessHoursProvider`), sin fuga (el observer se
  remueve antes de `super.dispose()`).
- **`handleTap()` nunca asume el resultado de `requestPermission()`**: siempre llama a
  `refresh()` al final, que vuelve a preguntar `getStatus()` real — confirmado por lectura y por
  el test dedicado (mock de `getStatus()` con contador, `notDetermined` en la 1ra llamada,
  `authorized` desde la 2da).
- **Fidelidad**: el ícono de campana reutiliza el path SVG exacto ya usado en
  `home_screen.dart` (`home-notifications-bell`), no uno nuevo inventado. Colores por token
  (`CeltasColors.orange`/`cream`/`textMuted`/`redLight`/`divider`), sin `Color(0xFF...)` sueltos.
  El renglón replica el mismo padding/border/tamaño de ícono/tipografía que `_MenuRow` (patrón ya
  auditado en este archivo), con el chevron reemplazado deliberadamente por el texto de
  estado/spinner — no hay contraparte en `design-reference/` para este renglón (es una pantalla
  ya existente con un elemento nuevo, mismo criterio ya aceptado en auditorías previas de este
  documento para elementos interactivos sin mockup, ej. el ícono de lápiz de editar salsas).
- **Estados explícitos**: carga → `CircularProgressIndicator` de 14px en vez del texto, sin texto
  "Activadas"/"Desactivadas" a medias; error (`getStatus()` falla) → texto "No se pudo verificar"
  en `redLight`, tap reintenta vía `refresh()` en vez de `handleTap()` (no dispara
  `requestPermission()`/`openSystemSettings()` por error de red). Vacío no aplica (no hay lista).
- **`permission_handler` se usa exclusivamente por `openAppSettings()`** — confirmado por
  lectura de `notification_permission_repository.dart` (`getStatus()`/`requestPermission()` van
  enteramente por `FirebaseMessaging`) y del código nativo real de
  `permission_handler_android-12.1.0` (`AppSettingsManager.java`): usa
  `Settings.ACTION_APPLICATION_DETAILS_SETTINGS`, un intent estándar hacia la app de Configuración
  del sistema — no requiere `<queries>` en `AndroidManifest.xml` ni entradas en `Info.plist`.
  `POST_NOTIFICATIONS` ya estaba declarado en `AndroidManifest.xml` de un módulo anterior,
  confirmado presente.
- Ningún texto de UI en inglés ("Activadas", "Desactivadas", "No se pudo verificar",
  "Notificaciones").

❌ Falló:
- Ninguno bloqueante.

⚠️ Riesgos / hallazgos no bloqueantes:
- **Gap real de aislamiento en el test de `AppLifecycleState.resumed`**: confirmado con mutación
  — cambiar el guard de `didChangeAppLifecycleState` de `state == AppLifecycleState.resumed` a
  `state == AppLifecycleState.paused` **no hace fallar el test** (`377: All tests passed!` con la
  mutación puesta), porque el test dispara `handleAppLifecycleStateChanged(paused)` seguido de
  `handleAppLifecycleStateChanged(resumed)` en la misma prueba (necesario para forzar una
  transición real desde el estado inicial del harness) — con el guard mutado a `paused`, el
  refresh se dispara en la transición "equivocada" pero el resultado observable final
  (`calls == 2`, texto "Activadas") es idéntico. Una mutación a un estado que el test nunca envía
  (`AppLifecycleState.detached`) sí lo hace fallar correctamente (`Expected: <2>, Actual: <1>`),
  así que el test no está completamente ciego, pero no aísla específicamente "solo `resumed`, no
  `paused`". El código de producción real usa `resumed` (confirmado por lectura directa, correcto
  — es el evento correcto para "la app volvió a primer plano"), así que no hay bug, solo un test
  que podría ser más estricto. Sugerencia no bloqueante: separar el `tester.binding
  .handleAppLifecycleStateChanged(AppLifecycleState.paused)` en un `setUp`/paso previo neutro sin
  cambiar el mock, y verificar `calls == 1` (sin refresh) justo después de `paused` y antes de
  `resumed`, para que una regresión a "refresca en `paused`" quede realmente cubierta.
- **Sin test para el estado visual "provisional"** (`_NotificationPermissionRow` muestra
  "Activadas" igual que `authorized`, mismo branch del `switch` expression) — riesgo bajo, la
  lógica pura sí lo cubre (`actionForAuthorizationStatus`) y el mapeo visual es el mismo branch
  que `authorized`, que sí tiene test.
- **Sin test para el estado de error visual** de `_NotificationPermissionRow` (`getStatus()`
  lanzando, texto "No se pudo verificar" + tap disparando `refresh()` en vez de `handleTap()`) —
  el código lo maneja explícitamente (confirmado por lectura), pero no hay cobertura de
  regresión, a diferencia de los 3 estados visuales sí testeados (`authorized`/`denied` +
  comportamientos de tap). Mismo patrón de gap ya documentado en este archivo para
  `NotificationsScreen` (estado de error sin test) antes de que se corrigiera en una auditoría
  posterior — vale la pena el mismo tratamiento acá.
- No hay `ios/Podfile` en este repo todavía — preexistente, no introducido por este cambio, fuera
  de alcance de esta auditoría (no se intentó build de iOS).
- No verificado en dispositivo/emulador real (sin dispositivo conectado en esta sesión): que el
  diálogo nativo de Android efectivamente aparezca al tocar "Desactivadas" en `notDetermined`,
  que `openAppSettings()` abra la pantalla correcta de la app en un Android real, y que el
  refresh al volver de background se sienta natural (no hay razón para dudar de la mecánica, ya
  cubierta por widget test, pero es la misma limitación ya declarada para el resto del módulo de
  horario/notificaciones en auditorías previas de este documento).

**Veredicto: LISTO.** `flutter analyze` limpio y `flutter test` 377/377 confirmados con salida
cruda propia; lógica de decisión exhaustiva y verificada con mutación real en 3 capas;
`WidgetsBindingObserver` correctamente implementado sin fuga ni doble-registro; estados de
carga/error explícitos; sin colores sueltos ni texto en inglés. Ningún hallazgo bloqueante — los
2 riesgos de cobertura de test (aislamiento del test de `resumed`, estado de error/`provisional`
sin test dedicado) son mejoras de robustez de test, no bugs de producción, y no impiden marcar
este ítem completo en `ROADMAP.md`.

---

## Branding / Íconos y Splash nativos (assets nativos, no es un módulo funcional del roadmap)

No existe una sección de "General" aplicable en la forma estándar (loading/error/vacío no
aplica: no es una pantalla que llama a la API), así que este bloque documenta únicamente lo
verificable de config de `flutter_launcher_icons`/`flutter_native_splash` + assets fuente en
`assets/branding/`.

- [x] `pubspec.yaml`: `android_12.image` apunta a `logo_sin_banner_android12_splash.png` (el
      archivo con relleno), `image:` base y `adaptive_icon_foreground` apuntan a
      `logo_sin_banner_transparente.png` (el original, sin relleno) — confirmado por lectura
      directa del YAML, no por el nombre de archivo.
- [x] El relleno de `logo_sin_banner_android12_splash.png` es real, no solo nominal: bbox del
      canal alfa vía Pillow da contenido centrado en 48.0% del ancho del canvas 6233×6233
      (márgenes izq/der 1620px/1621px, arriba/abajo 2080px/2080px — simétrico real, no un recorte
      accidental). El archivo base (`logo_sin_banner_transparente.png`) tiene bbox de alfa
      ocupando el 100% de su canvas 2992×2073 (sin relleno), confirmando que es el original y no
      una copia rellenada por error. Confirmado también visualmente (composición sobre fondo gris
      para ver el canal alfa).
- [x] **Simulación independiente del recorte de zona segura de Android 12+** (sin dispositivo a
      mano en este momento): un crop centrado del 55%/61%/66% del canvas (rango de "zona segura"
      citado para adaptive icons) sobre el archivo base SIN relleno recorta el bbox del contenido
      en los 3 casos (`CLIPPED=True`); el mismo crop sobre el archivo CON relleno no lo recorta en
      ninguno (`CLIPPED=False`). Consistente con el bug real reportado (solo se veía "ELTA") y con
      la corrección aplicada.
- [x] `remove_alpha_ios: true` con `image_path_ios` apuntando a un JPG: confirmado redundante pero
      inofensivo — el JPG (`logo_completo.jpg`) no tiene canal alfa (`file` confirma "components
      3", sin transparencia), y los íconos iOS generados en
      `ios/Runner/Assets.xcassets/AppIcon.appiconset/` salen en modo `RGB` sin alfa. No genera
      ningún problema real, solo es una bandera sin efecto práctico en este caso.
- [x] `assets/branding/` NO está en `flutter.assets` — correcto: ningún archivo de `lib/` lo
      referencia (`grep -rn "assets/branding\|logo_completo\|logo_sin_banner\|logo_con_banner"
      lib/` sin resultados), y `flutter_launcher_icons`/`flutter_native_splash` leen la ruta
      directo del `pubspec.yaml` en tiempo de generación, no del bundle. Si en el futuro alguna
      pantalla (ej. "Acerca de") necesitara mostrar el logo dentro de la app, ESE archivo puntual
      tendría que agregarse a `flutter.assets` en ese momento — no aplica hoy.
- [x] `flutter analyze`: `No issues found!`. `flutter test`: 279/279 passed (confirmado de nuevo
      de forma independiente, no solo tomado de la palabra de la sesión principal).

  ❌ **Hallazgo nuevo, no reportado por la sesión principal — ícono de notificaciones FCM stale**:
  `android/app/src/main/AndroidManifest.xml` tiene `com.google.firebase.messaging.default_notification_icon`
  apuntando a `@mipmap/ic_launcher` (línea ~50), que sigue siendo el ícono default de Flutter (el
  ala azul), NO el logo de Celtas — confirmado abriendo
  `android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png` (ala azul de Flutter sobre negro) vs.
  `android/app/src/main/res/mipmap-xxxhdpi/launcher_icon.png` (logo de Celtas real, el que sí usa
  `android:icon="@mipmap/launcher_icon"` en el mismo manifest para el ícono del launcher). Este
  `ic_launcher.png` es un remanente del scaffold original de `flutter create`, no tocado por
  `flutter_launcher_icons` porque ese paquete escribe a `launcher_icon.png`/`launcher_icon.xml`
  (nombre configurado en `android: "launcher_icon"`), no al nombre por default `ic_launcher`.
  Preexistía antes de este cambio de branding (no es un bug introducido ahora), pero sigue sin
  corregirse: las notificaciones push (módulo 9, ya en producción) muestran el ícono default de
  Flutter en la barra de estado/bandeja, no el logo de Celtas. Nota técnica para quien lo corrija:
  Android fuerza el ícono pequeño de notificación (API 21+) a una silueta blanca/transparente —
  simplemente apuntar `default_notification_icon` a `launcher_icon.png` (que es a color, opaco)
  probablemente se vería como un blob blanco sólido en la barra de estado, no el logo reconocible;
  hace falta un drawable dedicado (silueta monocromática con fondo transparente), no reusar el
  ícono del launcher tal cual.

  ⚠️ **Riesgo documentado, no bloqueante — hipótesis del launcher (Pixel/Samsung) sin refutar
  directamente en dispositivo, pero sí explicada con evidencia de código**: la pregunta de por qué
  el ícono adaptativo del launcher (`adaptive_icon_foreground`, mismo archivo SIN relleno que tuvo
  el bug del splash) no mostró el mismo recorte en el Xiaomi de prueba. Encontrado en
  `android/app/src/main/res/mipmap-anydpi-v26/launcher_icon.xml`:
  `<foreground><inset android:drawable="@drawable/ic_launcher_foreground" android:inset="16%"/></foreground>`
  — `flutter_launcher_icons` inserta automáticamente un `<inset>` del 16% por lado en el XML del
  adaptive icon (esto no está en ningún archivo de imagen, es una transformación del sistema en
  tiempo de render). Confirmado que el PNG generado (`ic_launcher_foreground.png`, ej. 432×432 en
  xxxhdpi) sigue sin relleno propio (bbox de alfa 100% del canvas, igual que el splash sin
  arreglar) — el margen de seguridad viene ÍNTEGRAMENTE del `inset` del 16% en el XML, no del
  archivo. Esto refuta parcialmente la hipótesis de "fit vs. fill por launcher" del reporte
  original: el mecanismo real y verificable es que `flutter_launcher_icons` compensa
  automáticamente por diseño (16% de inset por lado ≈ deja visible el ~68% central, cercano al
  ~66.6% de "ícono visual" que Google recomienda dentro del canvas de 108dp), mientras que
  `flutter_native_splash` NO aplica ningún inset automático al `android_12.image` (confirmado:
  `android:windowSplashScreenAnimatedIcon="@drawable/android12splash"` sin ningún wrapper de
  inset en `styles.xml`) — por eso ahí sí hacía falta el relleno manual. Sigue siendo cierto que
  68% de contenido visible es más ancho que el 61.1% de "zona segura" garantizada oficialmente
  (66dp/108dp) citada para máscaras circulares agresivas — en teoría un launcher con máscara
  circular muy ajustada (algunos Samsung One UI, algunos lanzadores de terceros) podría aún cortar
  las puntas más extremas de las hachas o los bordes de "C"/"S" por un margen pequeño (~7 puntos
  porcentuales), a diferencia del caso del splash donde el margen que faltaba era mucho mayor
  (100% vs. ~55-66%). No hay forma de confirmar esto sin un dispositivo con ese tipo de máscara a
  mano — documentado como riesgo menor a validar si aparece feedback de usuarios con recorte del
  ícono del launcher en dispositivos no probados (Pixel/stock, Samsung One UI).

  ⚠️ **Riesgo de higiene, no bloqueante**: quedan 5 archivos `mipmap-*/ic_launcher.png` (ícono
  default de Flutter, ala azul, ~4KB c/u) sin usar por el ícono del launcher en sí (el manifest
  usa `launcher_icon`, no `ic_launcher`, para `android:icon`) — pero SÍ referenciados por el
  ícono de notificación FCM stale de arriba. No afecta el tamaño del APK de forma significativa
  (20KB total), pero es ruido en el repo que podría confundir a alguien que busque "dónde está el
  ícono real" — vale la pena limpiarlos junto con el fix del ícono de notificación, no antes (si
  se borran ahora sin arreglar el `default_notification_icon`, el manifest quedaría apuntando a
  un recurso inexistente y el build fallaría).

  **Veredicto: LISTO PARA MARCAR COMPLETO en lo específico auditado por la sesión principal**
  (splash Android 12+, ícono legacy/adaptive, `remove_alpha_ios`, `flutter.assets`) — el bug de
  recorte del splash está corregido y verificado de forma independiente (simulación de crop +
  inspección del archivo, no solo confianza en el reporte). **PENDIENTE, fuera del alcance de lo
  reportado por la sesión principal**: el ícono de notificaciones FCM (`ic_launcher` default de
  Flutter) no se actualizó al branding de Celtas — requiere un drawable de silueta monocromática
  dedicado, no simplemente apuntar al ícono del launcher a color. No hay checkbox de ROADMAP.md
  específico para "branding/íconos" (módulo 10 ya está con todos sus ítems marcados salvo la
  decisión de distribución Play Store vs. APK); no se agrega uno nuevo aquí porque no es parte de
  lo que la sesión principal pidió auditar como alcance — queda a criterio de la sesión principal
  decidir si amplía el módulo 10 con este hallazgo.

- [x] **Ronda nueva: fix del splash nativo recortado en Android 12+ (reemplazo de asset) + SVG
      real de marca reemplazando `CeltasFlame`**. `flutter analyze`: `No issues found!`.
      `flutter test`: 279/279 antes de esta auditoría, 281/281 después (2 tests de regresión
      agregados por mí, ver abajo) — confirmado con salida cruda propia.

      ✅ **Pasó**:
      - **Nombres de archivo cambiaron respecto a la ronda anterior de branding** (la de más
        arriba en esta misma sección, que documentaba `logo_sin_banner_transparente.png` /
        `logo_sin_banner_android12_splash.png` / `logo_completo.jpg`): el `pubspec.yaml` actual
        usa un set de nombres distinto (`logomarcaios.png`, `logobackground.png`,
        `logomarcalienzotransparente.png`, `logo1024splash.png`,
        `logo1024splash_android12.png`) — confirmado que NINGÚN archivo con los nombres viejos
        existe ya en el repo (`find ... -iname "*logo_sin_banner*" -o -iname "*logo_completo*"`
        sin resultados) y que `pubspec.lock`/`flutter pub get` no reportan drift. No es un bug de
        esta ronda — es una renombrada de los assets fuente que ocurrió en algún punto entre
        ambas rondas de trabajo, pero **el texto de la ronda anterior en este mismo archivo y en
        `ROADMAP.md:668-683` sigue describiendo los nombres viejos** (ver hallazgo de
        documentación abajo).
      - **`android_12.image` apunta al archivo con relleno real, no al mismo que la imagen
        clásica**: confirmado por lectura directa del YAML
        (`flutter_native_splash.android_12.image: "assets/branding/logo1024splash_android12.png"`,
        distinto de `image: "assets/branding/logo1024splash.png"`, el bug original que motivó
        este fix). Verifiqué el relleno de forma independiente con Pillow (no confié en el
        comentario del YAML): bbox del canal alfa de `logo1024splash_android12.png` da contenido
        centrado en 47.9% del ancho del canvas 1024×1024 (`bbox=(266, 342, 757, 681)`) — relleno
        real, simétrico, no nominal. El archivo base
        `logo1024splash.png` (1024×709, sin `android_12.` — splash pre-Android 12) SÍ tiene canal
        alfa (formato `P` con `transparency` en la paleta, no `RGBA` directo, pero
        `.convert('RGBA')` confirma el canal) y ese canal ocupa el 100% del canvas (`bbox=(0, 0,
        1024, 709)`), sin relleno — consistente con "llega borde a borde" que describe el
        comentario del `pubspec.yaml`, y coherente con que el splash pre-Android 12 no sufre el
        recorte de zona segura (usa `android:gravity="center"`, no la API de adaptive icon).
      - **Recursos nativos regenerados desde el archivo correcto, no un artefacto viejo**:
        `android/app/src/main/res/drawable-*/android12splash.png` (todas las densidades,
        incluidas las variantes `night-*`) tienen timestamp ~22 segundos DESPUÉS del timestamp de
        `assets/branding/logo1024splash_android12.png` (`12:49:01` el asset fuente,
        `12:49:23`-`12:49:24` los generados) — confirma que `flutter_native_splash:create` corrió
        DESPUÉS de la versión final del asset, no que quedó un artefacto de una corrida anterior
        con el archivo viejo. `styles.xml`/`launch_background.xml` (`values/`, `values-night/`,
        `drawable/`, `drawable-v21/`) tienen el patrón estándar generado por el paquete
        (`layer-list` con `background`/`splash` en capas), sin ediciones manuales visibles.
      - **`CeltasFlame` fue eliminado sin dejar referencias rotas**: `grep -rn "CeltasFlame"
        lib/ test/` no encuentra ningún uso real (el único resultado en `test/` es un comentario
        en `svg_path_test.dart` que menciona el archivo ya eliminado como contexto histórico, no
        una referencia de código). `lib/shared/widgets/celtas_flame.dart` está borrado
        (`git status` lo confirma como `D`). Los 2 únicos sitios que lo usaban
        (`splash_screen.dart`, `login_screen.dart`) ahora usan
        `SvgPicture.asset('assets/branding/iconos.svg', ...)` — confirmado leyendo el código real
        de ambos archivos, no la descripción de la sesión principal: Splash usa `width: 88,
        height: 88, colorFilter: ColorFilter.mode(CeltasColors.gold, BlendMode.srcIn)`, Login usa
        `width: 24, height: 24, colorFilter: ColorFilter.mode(CeltasColors.orange,
        BlendMode.srcIn)`.
      - **Fidelidad de color contra `design-reference/`**: confirmado en
        `design-reference/Celtas App Mockups.dc.html` que la pantalla 01 (Splash, línea 39) usa
        el ícono con `stroke="#FFB800"` a 88×88, y la pantalla 02 (Login, línea 64) usa
        `stroke="#E8590C"` a 24×24 — coincide exactamente con `CeltasColors.gold` (`#FFB800`) y
        `CeltasColors.orange` (`#E8590C`) usados en el código real, mismos tamaños. El mockup usa
        un ícono de trazo (`fill="none" stroke="..."`, un path simple de "hachas cruzadas"); el
        SVG real (`assets/branding/iconos.svg`) es un logo con relleno sólido
        (`fill="#000000" stroke="none"`, un solo color de relleno en los 15 `<path>` del único
        `<g>`) — un solo color fuente es justamente lo que necesita `ColorFilter.mode(color,
        BlendMode.srcIn)` para recolorear sin perder detalle (si tuviera múltiples colores
        fuente, `srcIn` los aplanaría todos al mismo color, lo cual sería un problema; acá no
        aplica). El SVG real es la versión de marca completa/oficial reemplazando la aproximación
        dibujada a mano de `CeltasFlame` — es un reemplazo deliberado (icono real vs. aproximación
        placeholder), no una regresión de fidelidad.
      - **`svg_path.dart` (parser SVG casero) NO fue tocado ni sus consumidores afectados**:
        confirmado con `grep -rln "SvgStrokeIcon" lib/` (8 archivos: `addresses_screen.dart`,
        `cart_screen.dart`, `profile_screen.dart`, `product_detail_screen.dart`,
        `home_screen.dart`, `order_detail_screen.dart`, `celtas_bottom_nav.dart`,
        `svg_stroke_icon.dart`) y `grep -rn "svg_path.dart" lib/` (3 imports:
        `checkout_screen.dart`, `svg_stroke_icon.dart`, `google_logo.dart`) — ninguno de estos 3
        archivos aparece en `git status` como modificado, así que no hay riesgo de que este
        cambio los haya afectado de forma colateral. `svg_path_test.dart` SÍ está modificado, pero
        solo el comentario de la constante `flamePath` (ahora dice "usado antes en
        `celtas_flame.dart` (ya eliminado...)" en vez de referenciar el archivo como si siguiera
        existiendo) — la lógica del test (parsear el mismo path de las "hachas cruzadas" como
        caso de regresión de la gramática del parser) no cambió, confirmado con `flutter test`
        pasando igual.
      - **`pubspec.yaml` coherente**: `flutter_svg: ^2.3.0` en `dependencies` (correcto, se usa
        en runtime, no solo en build time como `flutter_launcher_icons`/`flutter_native_splash`
        que sí van en `dev_dependencies`). `assets/branding/iconos.svg` agregado a
        `flutter.assets` — correcto y necesario a diferencia de los demás archivos de
        `assets/branding/` (que los generadores leen directo del path del YAML en tiempo de
        build, no del bundle); `iconos.svg` sí se decodifica en tiempo de ejecución dentro de la
        app, así que si no estuviera en `flutter.assets` fallaría en runtime, no en build.
        `flutter pub get` corre limpio sin reportar drift entre `pubspec.yaml` y `pubspec.lock`.

      ⚠️ **Cobertura que faltaba, agregada por mí** (regla 4: lógica crítica sin test propio —
      en este caso, "el asset de marca carga sin error" no es lógica de negocio, pero sí es un
      caso real de regresión silenciosa: un typo en la ruta o un asset faltante no habría hecho
      fallar los tests existentes de `splash_screen_test.dart`/`login_screen_test.dart`, que
      nunca interactúan con el ícono):
      - `test/features/auth/presentation/brand_icon_test.dart` (nuevo). **Primer intento
        descartado por falso positivo, documentado en el propio archivo**: escribí primero un
        test que pumpeaba `SplashScreen`/`LoginScreen`, hacía `pumpAndSettle()` y verificaba
        `tester.takeException()` nulo + `find.byType(ErrorWidget)` vacío — asumiendo que eso
        detectaría un asset roto. Antes de confiar en el test, lo puse a prueba de verdad
        (regla del proyecto: no reportar evidencia sin haberla verificado): cambié
        temporalmente la ruta en una copia de `splash_screen.dart` a
        `assets/branding/no-existe.svg` y corrí el test — **pasó igual, con evidencia cruda**
        (`All tests passed!`, sin ninguna línea de error impresa). Investigué la causa leyendo
        el código fuente de `vector_graphics` 1.2.3
        (`~/.pub-cache/.../lib/src/vector_graphics.dart:518-524`): cuando `SvgPicture.asset`
        falla al cargar y NO se le pasa un `errorBuilder` (nuestro caso, ninguno de los 2 usos
        en producción lo pasa), el widget degrada en silencio a un `SizedBox` vacío del mismo
        tamaño — sin lanzar excepción, sin `FlutterError.reportError`, sin `ErrorWidget`. Por
        eso mi primer test era una prueba inútil: pasaba igual con el asset roto o sano. Revertí
        el cambio temporal en `splash_screen.dart` (confirmado con `git diff` que quedó
        idéntico al estado original de esta sesión) y reescribí el test con un enfoque que sí
        funciona: llamar directamente a `SvgAssetLoader(path).loadBytes(null)` (el mismo
        `BytesLoader` que `SvgPicture.asset` resuelve internamente) y esperar el resultado en
        vez de inferirlo del árbol de widgets. Verificado con evidencia cruda de ambos lados:
        `SvgAssetLoader('assets/branding/iconos.svg').loadBytes(null)` no lanza y devuelve bytes
        (`GOOD bytes: 19710`); `SvgAssetLoader('assets/branding/no-existe.svg').loadBytes(null)`
        sí lanza (`BAD CAUGHT: Unable to load asset: "assets/branding/no-existe.svg". The asset
        does not exist or has empty data.`) — el test de regresión que quedó en el archivo
        (`'regresión: una ruta rota SÍ lanza...'`) fija ese comportamiento. El archivo final
        conserva las aserciones de `width`/`height`/`colorFilter` sobre el `SvgPicture` (útiles
        para fidelidad de diseño: 88/88/gold en Splash, 24/24/orange en Login — confirmado
        contra `design-reference/Celtas App Mockups.dc.html` líneas 39 y 64), pero con un
        comentario explícito de que esas aserciones NO prueban que el archivo cargó, solo que el
        widget está configurado con los valores esperados. `flutter test` de este archivo:
        4/4. **Limitación documentada, no cerrada**: el `AssetBundle` de `flutter_test` lee los
        archivos directo del disco por su ruta relativa al paquete, sin validar contra la lista
        `flutter.assets` del `pubspec.yaml` (confirmado: el mismo `rootBundle.load` de una ruta
        inexistente falla por archivo faltante, no por declaración faltante) — así que ninguno
        de estos tests habría detectado que `iconos.svg` no estuviera en `flutter.assets` si el
        archivo físico igual existiera en `assets/branding/`. Esa parte específica (declaración
        en `pubspec.yaml`) solo queda confirmada por lectura directa del YAML (ya hecha arriba),
        no por test automatizado.

      ⚠️ **Hallazgo de documentación (no bloqueante para este cambio en sí, pero real) — la
      sección "Branding / Íconos y Splash nativos" de este mismo archivo y `ROADMAP.md:663-737`
      describen una versión ANTERIOR de los nombres de archivo de `assets/branding/`
      (`logo_sin_banner_transparente.png`, `logo_sin_banner_android12_splash.png`,
      `logo_completo.jpg`, `logo_con_banner_transparente.png`) que **ya no existen en el repo** —
      el `pubspec.yaml` actual usa un set de nombres completamente distinto (ver arriba). Más
      relevante: `ROADMAP.md:663-666` dice textualmente que este ítem "reemplaza la aproximación
      'CeltasFlame' usada hasta ahora **solo en el Splash hecho a mano en Flutter, que sigue
      existiendo tal cual**" — eso ya no es cierto: `CeltasFlame` fue eliminado por completo en
      esta ronda (confirmado arriba) y reemplazado por el SVG real en Splash Y Login. No corrijo
      ese texto yo mismo (no es un archivo de test ni `docs/testing-checklist.md`, y mi rol no
      incluye reescribir la prosa de `ROADMAP.md`, solo marcar checkboxes) — queda señalado acá
      para que la sesión principal actualice `ROADMAP.md:663-737` con los nombres de archivo
      reales y quite la afirmación de que `CeltasFlame` sigue existiendo.
      - **Ícono de notificaciones FCM** (`ic_stat_celtas`, mencionado como pendiente/corregido en
        la ronda anterior de esta sección): confirmado que sigue vigente y consistente en esta
        ronda — `AndroidManifest.xml` (`default_notification_icon` →
        `@drawable/ic_stat_celtas`) y `notification_service.dart`
        (`AndroidInitializationSettings('@drawable/ic_stat_celtas')`) siguen apuntando al mismo
        recurso, sin relación con el cambio de `CeltasFlame`/SVG de esta ronda (son módulos
        independientes: FCM vs. widgets de Auth). No se tocó ni necesitaba tocarse.

      ⚠️ **Riesgos / casos borde no cubiertos, no bloqueantes**:
      - El `viewBox` real de `iconos.svg` es `0 0 1024 709` (relación de aspecto ~1.44:1, más
        ancho que alto) — al pintarse en una caja cuadrada de 88×88 o 24×24 con
        `SvgPicture.asset` (que usa `BoxFit.contain` por default), el resultado real no ocupa el
        cuadrado completo: se ajusta por el ancho y queda con margen vertical (aprox. 88×61 para
        el caso del Splash). El mockup, en cambio, usa un ícono cuyo `viewBox` es cuadrado (`0 0
        24 24`). Esto es una diferencia real entre el ícono de trazo aproximado del mockup y el
        SVG de marca real (que probablemente incluye más contexto del isotipo, no solo el
        símbolo). No es necesariamente un defecto — el contexto de esta sesión indica verificación
        visual ya hecha en dispositivo real ("ícono dorado en Splash", "ícono naranja en Login")
        que no reportó problemas — pero no repetí esa verificación visual yo mismo (no tengo
        acceso al dispositivo en este momento), así que documento el riesgo geométrico en vez de
        confirmarlo o descartarlo con evidencia propia. Sugerencia si se quiere cerrar del todo:
        una captura de pantalla explícita comparando la proporción del ícono renderizado contra
        el hueco cuadrado que ocupaba `CeltasFlame` antes.
      - Ningún test nuevo ni existente verifica el contenido visual/geométrico del `iconos.svg`
        en sí (p. ej. que sus `getBounds()` correspondan a una forma reconocible) — a diferencia
        de la cobertura que sí existe para los paths de `svg_path.dart` (pin, campana, etc.). No
        aplica el mismo nivel de escrutinio porque `iconos.svg` lo parsea `flutter_svg`/
        `vector_graphics` (librería de terceros ya probada), no el parser casero del proyecto —
        pero significa que un SVG mal formado en el futuro (ej. un `<path>` corrupto en un
        reemplazo de logo) solo se detectaría por inspección visual, no por test.

      **Veredicto: LISTO PARA MARCAR COMPLETO** en lo específico de esta ronda (fix del splash
      Android 12+ vía reemplazo de asset, reemplazo de `CeltasFlame` por el SVG real de marca).
      Sin bloqueadores encontrados — los hallazgos son de documentación desactualizada (no de
      código) y riesgos menores ya cubiertos por verificación visual previa en dispositivo real
      reportada por la sesión principal.

### Costo de delivery por distancia — preview en checkout + coordenadas obligatorias — ⚠️ LISTO CON OBSERVACIONES

**Tercera ronda (fix de UX sobre `_PhoneRequiredDialog`, hallazgo en dispositivo físico, todavía
sin commitear)**: bug real encontrado probando en dispositivo real, no en los widget tests — el
diálogo de teléfono obligatorio tenía un solo paso: tocar "CONFIRMAR" validaba el formato Y
guardaba el teléfono (`PATCH /users/me`) Y dejaba seguir con la creación del pedido, todo en el
mismo toque, sin ninguna oportunidad de corregir un typo con formato válido pero dígitos
equivocados antes de que el pedido ya se hubiera disparado.

Fix verificado por lectura completa de `_PhoneRequiredDialogState` en `checkout_screen.dart`: el
diálogo ahora tiene 2 pasos internos (`_reviewing`), mismo `AlertDialog`/mismo key
`checkout-phone-required-dialog`, contenido condicional. Paso 1 (`_reviewPhone`, botón
`checkout-phone-confirm`) SOLO valida `_peruvianPhoneRegExp` y pasa a `_reviewing = true` — no
toca `_saving` ni llama a `updateProfile` en ningún branch (confirmado leyendo el método completo,
su único efecto en caso válido es `setState(() { _reviewing = true; _error = null; })`). Paso 2
(`_confirmAndSave`, botón `checkout-phone-confirm-final`) es el único call site de
`ref.read(profileProvider.notifier).updateProfile(phone: value)` en todo el archivo (confirmado
con `grep -n "updateProfile" checkout_screen.dart` → una sola ocurrencia real, dentro de
`_confirmAndSave`) — recién ahí, con éxito, hace `Navigator.of(context).pop(true)`. "EDITAR"
(`_editPhone`, botón `checkout-phone-edit`) solo hace `setState(() { _reviewing = false; _error =
null; })`, sin tocar `_phoneController` — el texto tipeado se conserva, confirmado también por el
test dedicado que lee `field.controller!.text` tras volver del paso de revisión y encuentra el
mismo valor. El número mostrado en la pregunta de confirmación
(`_formatted(_phoneController.text.trim())`, en `_buildReviewContent`) y el que realmente se
guarda (`_phoneController.text.trim()`, en `_confirmAndSave`) leen exactamente el mismo `.text`
del mismo controller en el mismo momento — `_formatted` solo inserta espacios sobre una copia
local, no muta ni trunca el valor real; no hay ninguna transformación intermedia que pueda hacer
que lo mostrado difiera de lo guardado.

`flutter analyze`: `No issues found! (ran in 3.7s)` (salida cruda propia). `flutter test` (suite
completa): `+458: All tests passed!` (salida cruda propia) — coincide exactamente con el conteo
esperado (458/458, +1 neto sobre el 457/457 de la ronda anterior).

`git diff --stat` de esta ronda confirma que el resto del archivo no tiene ningún diff inesperado:
solo aparecen, además del diálogo de teléfono, los cambios ya auditados en rondas previas
(`estimateDeliveryFee`/fila "Envío", coordenadas obligatorias en `_submitNewAddress`) — sin tocar
`register_screen.dart` (`git diff` vacío, confirmado de nuevo con salida cruda propia).

Tests tocados en `checkout_screen_test.dart`, grupo "gate de teléfono obligatorio al confirmar":
los 2 tests que antes tocaban `checkout-phone-confirm` esperando guardado inmediato ("teléfono
válido..." y "falla el guardado...") ahora pasan primero por el paso de revisión
(`checkout-phone-confirm`) y recién tocan `checkout-phone-confirm-final` para disparar el guardado
— confirmado leyendo ambos tests completos, incluido el `verifyNever(() =>
profileRepo.updateProfile(...))` intermedio en el primero, que confirma que el primer toque de
"CONFIRMAR" (paso 1) todavía no guardó nada antes de pasar al paso 2. El test nuevo dedicado al
paso de revisión (`'paso de revisión: número válido → ...'`) cubre las 3 afirmaciones pedidas en
un solo flujo: número formateado visible (`'¿Confirmas que tu número es 987 654 321?'`), EDITAR
conserva el valor tipeado (verificado leyendo `TextFormField.controller!.text` directamente, no
solo que el campo esté visible), y "SÍ, CONFIRMAR" es lo único que dispara `updateProfile`
(`verifyNever` antes de tocarlo, en dos puntos distintos del flujo — tras llegar a la revisión y
tras volver de EDITAR y volver a llegar — y `verify(...).called(1)` después de tocarlo). Los
matchers de `updateProfile` (`fullName`/`phone`, 2 named args) y `createOrder`
(`items`/`addressId`/`couponCode`, 3 named args) usados en `verify`/`verifyNever` de este grupo
completo son los mismos ya validados empíricamente en la ronda anterior (ver la nota extensa más
abajo sobre el mecanismo real de `noSuchMethod`/mocktail) — sin necesidad de repetir esa prueba
acá, el keyset coincide exactamente con la firma real de ambos métodos.

⚠️ Observación nueva de esta ronda (no bloqueante): el hallazgo del bug en esta ronda vino de
probar en dispositivo físico, no de los widget tests — es un recordatorio de que el flujo
"validar → mutar" en un solo toque es un patrón de riesgo real en esta app (ya se vio antes con
otras confirmaciones), y vale la pena que la sesión principal revise si hay algún otro modal en el
proyecto con el mismo patrón de un solo paso para una mutación irreversible o costosa de deshacer,
antes de considerar cerrado el barrido de este patrón.

**Veredicto de esta ronda: LISTO.** El fix resuelve el bug real reportado (typo sin oportunidad de
corregir antes de crear el pedido) sin introducir ningún efecto secundario en el resto del archivo,
`analyze`/`test` limpios con el conteo esperado, y los tests nuevos/tocados verifican el
comportamiento con matchers estrictos y `verifyNever` en los puntos intermedios correctos, no solo
al final del flujo. Se mantienen las mismas observaciones no bloqueantes ya documentadas en la
ronda anterior (sin test e2e contra el backend real, sin ítem propio en `ROADMAP.md`, el modal no
re-lee `authControllerProvider` tras guardar) — ninguna nueva salvo la de arriba.

---

**Segunda ronda (re-auditoría de corrección, sobre la misma auditoría de abajo, todavía sin
commitear)**: la sesión principal corrigió los 2 `verifyNever` con matcher incompleto señalados
la vez pasada (`checkout_screen_test.dart`/`addresses_screen_test.dart`, ahora con los 6 named
args reales de `createAddress`: `alias`, `fullAddress`, `reference`, `district`, `latitude`,
`longitude`), y revirtió por completo la pieza "teléfono obligatorio en el registro" que esta
misma auditoría había dado por buena — correspondía a un diseño descartado por el dueño del
producto. En su lugar movió ese gate al checkout: `checkout_screen.dart::_confirmOrder` lee
`authControllerProvider.user?.phone` antes de crear el pedido y, si falta, bloquea con
`_PhoneRequiredDialog` (`checkout-phone-required-dialog`), que valida formato peruano
(`_peruvianPhoneRegExp = RegExp(r'^9\d{8}$')`) y guarda con
`profileProvider.notifier.updateProfile(phone: ...)` antes de dejar continuar.

`git diff -- lib/features/auth/presentation/register_screen.dart`: **vacío** (confirmado con
salida cruda propia, sin ningún residuo del validator revertido) y
`test/features/auth/presentation/register_screen_test.dart` **ya no existe** (confirmado con
`ls` del directorio) — la reversión es completa, no parcial.

`flutter analyze`: `No issues found! (ran in 3.7s)` (salida cruda propia). `flutter test` (suite
completa): `+457: All tests passed!` (salida cruda propia) — coincide con el conteo esperado
(457/457, neto +5 sobre el 452/452 de la ronda anterior: −2 por eliminar
`register_screen_test.dart`, +7 por el grupo nuevo "gate de teléfono obligatorio al confirmar" en
`checkout_screen_test.dart`).

Lectura completa de `_confirmOrder`/`_PhoneRequiredDialog` en `checkout_screen.dart` y de los 7
tests nuevos: el gate bloquea la creación del pedido en los 3 casos donde debe (sin teléfono →
modal sin crear pedido; formato inválido → error inline sin llamar a `updateProfile` ni a
`createOrder`; cancelar → `return` limpio, sin pedido, sigue en checkout) y deja pasar
correctamente en los 2 casos donde debe (teléfono ya existía → nunca aparece el modal; teléfono
válido guardado con éxito → cierra el modal y sigue con la creación normal del pedido, verificado
con `addressId` real, no un `any()` genérico). La validación de formato ocurre estrictamente antes
de la mutación: `_submit()` retorna temprano en el `if (!_peruvianPhoneRegExp.hasMatch(value))`
sin tocar `_saving`/`updateProfile` — confirmado por lectura y por el test de formato inválido, que
verifica `verifyNever(() => profileRepo.updateProfile(...))`. Aplica igual para `local` y `google`
(ninguna rama en el código distingue por `provider`, solo mira `phone`), confirmado por el test
dedicado con `UserProvider.google`. El regex (`^9\d{8}$`: 9 dígitos, empieza en 9) es razonable
para el formato peruano de celular.

**Re-verificación de los `verifyNever` corregidos, con hallazgo técnico no bloqueante**: se
revisaron los 2 matchers de 6 named args y también los 3 `verifyNever`/`verify` nuevos del gate de
teléfono (`createOrder` con 3 named args, `updateProfile` con 2). Los 2 de `createOrder`
(`items`/`addressId`/`couponCode`) y el de `updateProfile` (`fullName`/`phone`) coinciden
exactamente con el único call site real de cada método en este flujo (`_confirmOrder` /
`ProfileNotifier.updateProfile`, que siempre pasan ese mismo set de keys) — sin problema. Para los
2 de `createAddress`, se hizo una prueba empírica directa (script descartable en
`test/`, corrido y borrado en esta sesión, sin dejar residuo) para confirmar el mecanismo real de
mocktail, y el resultado contradice parcialmente la explicación técnica que esta misma auditoría
había escrito la ronda pasada: **el forwarder que Dart genera para clases que satisfacen una
interfaz solo vía `noSuchMethod` (el mecanismo de `Mock` de mocktail) siempre incluye TODOS los
named params del método real en el `Invocation`, rellenando con el valor por defecto cualquiera
que se omita en el call site** — no es cierto que "ninguna invocación real calificaría jamás como
coincidente" por tener menos keys explícitas; los keysets de `Invocation.namedArguments` siempre
son el set completo de parámetros del método, sin importar cuántos se escriban literalmente en el
call site. Confirmado con un `noSuchMethod` crudo sin mocktail de por medio
(`invocation.namedArguments.keys` siempre trae los 4 params de un método de prueba de 4 params,
aunque el call site solo escriba 2), y luego replicado con `MockAddressRepository` real: el
matcher original de 3 keys (`alias`/`fullAddress`/`district`, sin `reference`/`latitude`/
`longitude`) SÍ matcheaba la llamada real cuando esos 3 quedan en `null` (que es exactamente el
escenario que ese test protege — el guard roto sin tocar el mapa), porque el forwarder de la
propia expresión `verify()` también rellena esos 3 con su default (`null`), y `null == null`
coincide. Dicho de otro modo: **el `verifyNever` original de la ronda pasada no era una red de
seguridad vacía como se documentó entonces** — si el guard se hubiera roto en el escenario exacto
que ese test ejercita, sí lo habría detectado. El matcher de 6 keys con `any()` explícito para
`reference`/`latitude`/`longitude` sigue siendo una mejora real y válida, no innecesaria: a
diferencia del original, matchea sin importar el VALOR de esos 3 campos (no solo cuando son
`null`), así que también detectaría una variante del bug donde el guard roto dejara pasar un
valor residual no-nulo (ej. coordenadas de una selección anterior sin limpiar) — un caso que el
matcher original, por construcción, no habría cubierto. Conclusión: la corrección aplicada es
correcta y es una mejora de robustez, aunque el motivo original documentado para pedirla (keyset
que "nunca podría coincidir") era técnicamente impreciso — se deja esta nota para que no se repita
esa explicación en futuras auditorías de este mismo patrón mocktail.

Sin commitear todavía al momento de esta re-auditoría (`git status`/`git diff` muestran el estado
real completo, sin nada movido a `ROADMAP.md`). El resto de esta sección (auditoría original, sin
re-verificar a fondo salvo lo ya reconfirmado arriba) queda documentado abajo tal cual se escribió
entonces, con el conteo de tests y el hallazgo de `verifyNever` ya superados por lo anterior.

---

Backend y `celtas-admin` ya cerrados en sus propios repos — esta ronda es exclusivamente mobile.
Archivos tocados: `lib/features/checkout/data/order_repository.dart` (método nuevo
`estimateDeliveryFee`), `lib/features/checkout/application/checkout_providers.dart`
(`deliveryFeeEstimateProvider`), `lib/features/checkout/presentation/checkout_screen.dart` (fila
"Envío" + total mostrado), `lib/features/addresses/presentation/addresses_screen.dart` y
`lib/features/checkout/presentation/checkout_screen.dart` (chequeo manual de coordenadas antes de
guardar), `lib/features/addresses/presentation/widgets/address_form_card.dart`/
`address_location_picker.dart` (doc actualizada, ya no dicen "opcional"),
`.claude/skills/geoapify-direcciones/SKILL.md` actualizada. Tests nuevos/tocados:
`order_repository_test.dart` (+2), `checkout_screen_test.dart` (+5, +7 más en la ronda de
corrección de arriba), `addresses_screen_test.dart` (+1).

`flutter analyze` (auditoría original): `No issues found! (ran in 3.4s)` (salida cruda propia).
`flutter test` (auditoría original): `+452: All tests passed!` — superado por el `+457` de la
ronda de corrección de arriba.

✅ Pasó:
- **Contrato de `POST /orders/estimate-delivery-fee` verificado contra el código fuente real del
  backend** (`backend-celtas/src/modules/orders/orders.controller.ts` +
  `orders.service.ts::estimateDeliveryFee`/`computeDelivery` + `estimate-delivery-fee.dto.ts`):
  body `{ addressId: string }` (UUID), response
  `{ deliveryFee: number, isFarOrder: boolean, distanceMeters: number | null }`. La capa Dart
  (`OrderRepository.estimateDeliveryFee`) manda exactamente `{ addressId }` y solo lee
  `data['deliveryFee']` — coincide con el contrato real, no uno asumido.
- **`isFarOrder`/`distanceMeters` nunca se exponen al cliente**: `grep -rn
  "isFarOrder|distanceMeters"` sobre todo `lib/` y `test/` solo encuentra menciones en
  comentarios (documentando por qué se ignoran a propósito) y en el fixture del test que confirma
  que se ignoran — ningún lugar del código los parsea, guarda ni muestra.
- **Orden `whenData` → watch del provider de delivery fee**: confirmado por lectura de
  `checkout_screen.dart` build() — el callback de `addressesAsync.whenData(...)` que auto-
  selecciona la dirección principal muta `_selectedAddressId` de forma síncrona dentro del mismo
  `build()`, y la línea `final selectedAddressId = _selectedAddressId;` que alimenta el watch de
  `deliveryFeeEstimateProvider` está efectivamente después de ese bloque. No hay regresión de
  timing: en la primera pasada de build con direcciones recién cargadas, el watch ya lee el
  `_selectedAddressId` actualizado, no el `null` inicial.
- **La fila "Envío" nunca aparece sin una dirección seleccionada real**: `deliveryFee` se computa
  como `selectedAddressId == null ? null : ref.watch(...)`, corto-circuitando antes de siquiera
  crear el provider — confirmado también por el test `'sin dirección seleccionada → no llama al
  estimate ni muestra la fila'`, con `verifyNever(() => orderRepo.estimateDeliveryFee(any()))`
  (matcher completo y válido: el método real tiene un solo parámetro posicional, sin named args
  adicionales que puedan producir un falso negativo — a diferencia de otros `verifyNever` de este
  mismo diff, ver más abajo).
- **`cart.total` nunca se toca**: el backend real (`POST /orders`) lo sigue calculando; el preview
  solo suma `cart.total + (deliveryFee ?? 0)` en una variable local (`displayTotal`) para mostrar,
  confirmado por lectura y por el test `'con dirección seleccionada → ... nunca toca cart.total'`
  (`expect(container.read(cartProvider).total, 15.5)` tras verificar que el total mostrado sí
  incluye el envío).
- **Best-effort real, sin bloquear ni filtrar errores feos**: `deliveryFeeEstimateProvider` atrapa
  cualquier excepción y devuelve `null` — confirmado con el test que hace `thenThrow(const
  ApiException(...))` y verifica que ni la fila "Envío" ni el mensaje de error aparecen, y que el
  botón de confirmar sigue habilitado (mismo patrón ya usado por `businessHoursProvider`).
- **Coordenadas obligatorias bloquean el submit en los dos formularios** (`checkout_screen.dart`
  `_submitNewAddress`, `addresses_screen.dart` `_submitForm`), con el mismo texto de error exacto
  ("Toca el mapa para marcar la ubicación de tu dirección", tuteo) y el mismo patrón (chequeo
  manual después de `Form.validate()`, porque `latitude`/`longitude` no viven en un
  `TextFormField`). Confirmado tanto por lectura como por 2 tests nuevos (uno por pantalla) que
  llenan el formulario completo sin tocar el mapa y confirman el mensaje de error.
- **Sin excepción para direcciones viejas al editar**: `_openEditForm` en `addresses_screen.dart`
  precarga `_formLatitude`/`_formLongitude` directo desde `address.latitude`/`address.longitude`
  (`null` si la dirección es anterior a esta feature) — el mismo chequeo de `_submitForm` aplica
  igual al editar, sin ninguna rama especial. Confirmado con el test `'editar dirección
  existente'`, que usa la fixture `home` sin coordenadas y verifica que también exige tocar el
  mapa antes de poder guardar el cambio.
- **Las 3 fuentes de coordenadas (autocompletado, GPS, drag del pin) alimentan el mismo
  callback**: los 3 call sites de `widget.onLocationChanged(point)` en
  `address_location_picker.dart` desembocan en el mismo setter (`_onFormLocationChanged`/
  `_onAddAddressLocationChanged`), así que no hay una ruta que deje pasar el submit sin marcar
  ninguna de las tres.
- **Fidelidad de diseño**: la fila "Envío" reutiliza `_SummaryRow` con `CeltasColors.textMuted`, el
  mismo color/estilo ya usado para "Subtotal" en la misma pantalla — no se introduce ningún color
  nuevo (`Color(0xFF...)` suelto) para esta feature.
- `dart format --set-exit-if-changed` reporta drift en los archivos tocados, pero también en
  archivos completamente ajenos a este diff (`lib/main.dart`, `lib/features/cart/application/
  cart_provider.dart`, sin cambios en `git status`) — confirmado que es un desfase de versión de
  `dart format` preexistente en todo el repo, no una regresión de este trabajo.

❌ Falló:
- Ninguno funcional.

⚠️ Riesgos / observaciones — **no bloqueantes**:
- ~~`verifyNever` vacío en 2 tests (`checkout_screen_test.dart`/`addresses_screen_test.dart`)~~ —
  **corregido en la ronda de corrección** (ver arriba): ambos matchers ahora usan los 6 named args
  reales de `createAddress`. Además, la re-verificación de esta ronda encontró que la premisa
  técnica original de este hallazgo (que el matcher de 3 keys "nunca podría coincidir") era
  imprecisa — ver la nota extensa de arriba sobre el mecanismo real de `noSuchMethod`/mocktail. La
  corrección aplicada sigue siendo válida como mejora de robustez, solo se corrige el motivo
  documentado.
- No hay test unitario dedicado para `deliveryFeeEstimateProvider` en aislamiento (equivalente a
  como sí existe, por ejemplo, para el interceptor de refresh de `dio`) — la cobertura real viene
  entera de los 4 tests del grupo "preview de envío" en `checkout_screen_test.dart`, que sí
  ejercitan el provider de punta a punta (éxito, cambio de dirección, sin dirección, error). Es
  cobertura suficiente para el comportamiento observable, pero no aísla el provider de la UI si en
  el futuro se reutiliza en otra pantalla.
- Sin test de integración end-to-end contra el backend real (`https://backend-celtas.onrender.com`)
  corrido en esta auditoría para `estimate-delivery-fee` — esta auditoría se limitó a análisis
  estático + tests automatizados + lectura de código/contrato, igual que la ronda anterior de
  Geoapify.
- No existe ningún ítem de checklist en `ROADMAP.md` para esta feature ("costo de delivery por
  distancia" no aparece mencionada ahí) — no hay ningún checkbox que marcar como completo en ese
  archivo para este trabajo. Tampoco lo hay para el gate de teléfono en checkout (movido desde el
  registro), que igual carece de ítem propio.
- **Gate de teléfono obligatorio en checkout, sin test de integración end-to-end**: al igual que
  `estimateDeliveryFee`, esta pieza nueva (`_PhoneRequiredDialog` + `PATCH /users/me` vía
  `profileProvider`) solo se verificó con widget tests mockeados en esta ronda, no contra el
  backend real.
- El modal de teléfono no re-lee `authControllerProvider` después de guardar para confirmar que
  `phone` efectivamente quedó actualizado en el estado de auth antes de continuar — confía en que
  `ProfileNotifier.updateProfile` haya llamado a `authControllerProvider.notifier.updateUser`
  (que si) y en que el `Navigator.pop(context, true)` sea la única señal de éxito. Es el mismo
  patrón ya usado por `profile_screen.dart`, no una inconsistencia introducida acá, pero vale la
  pena tenerlo presente si en el futuro se agrega algún otro punto que dependa de leer
  `user.phone` inmediatamente después de este flujo.

**Veredicto: LISTO CON OBSERVACIONES** (se mantiene sobre la base de la auditoría original, con la
corrección de esta ronda plenamente verificada). Ningún bug funcional encontrado en ninguna de las
2 rondas: el contrato de API coincide con el backend real, `isFarOrder`/`distanceMeters` nunca se
filtran al cliente, el bloqueo por coordenadas obligatorias funciona sin excepciones, y el nuevo
gate de teléfono en checkout bloquea/deja pasar correctamente en los 5 casos verificados (sin
teléfono, vacío, formato inválido, cancelar, falla de guardado) tanto para cuentas `local` como
`google`. La reversión de "teléfono obligatorio en registro" es completa y verificable
(`git diff` vacío + archivo de test eliminado). El hallazgo de calidad de test de la ronda anterior
(`verifyNever` con matcher incompleto) está corregido y confirmado funcionalmente correcto — con
la salvedad de que la explicación técnica original de por qué fallaba resultó imprecisa (ver nota
arriba), sin impacto en el veredicto. Quedan pendientes las mismas observaciones no bloqueantes de
siempre (sin test aislado del provider, sin e2e contra el backend real, sin ítem en `ROADMAP.md`),
más una equivalente nueva para el gate de teléfono — ninguna bloquea dar el módulo por
funcionalmente correcto, pero conviene cerrarlas antes de considerar esta feature 100% verificada
de punta a punta.

---

## Estrellas (Rewards)

Sección nueva — el programa de fidelización "Estrellas" (`lib/features/rewards/`, commits
`e43fa86`/`2fb671b` + la migración de esta auditoría) nunca había tenido una entrada propia en
este checklist ni en `ROADMAP.md` (no hay ítem "Estrellas"/"Rewards" en ningún módulo 0-10 del
roadmap pese a llevar 3 rondas de trabajo) — se crea acá siguiendo el mismo formato del resto del
documento. **Pendiente para la sesión principal**: agregar un módulo/ítem propio en `ROADMAP.md`
para esta feature (no es algo que `@tester` deba decidir por su cuenta).

- [x] `flutter analyze` sin errores ni warnings nuevos
- [x] `flutter test` pasa (suite completa)
- [x] Colores usados coinciden con `CeltasColors` (sin `Color(0xFF...)` sueltos en
      `lib/features/rewards/` — confirmado con `grep -rn "Color(0x" lib/features/rewards/`, 0
      resultados)
- [x] Toda pantalla que llama a la API maneja loading, error y vacío explícitos
      (`RewardsScreen`/`RewardRedeemScreen`, ambas con `SlowBackendNotice` en `loading`, error con
      REINTENTAR, y estado vacío explícito en el catálogo de canje)
- [x] Ningún texto de UI en inglés
- [ ] Verificación en dispositivo/emulador real del flujo completo (progreso → premio
      desbloqueado → canje → WhatsApp) — no verificado en esta auditoría ni, hasta donde
      muestra el historial de commits, en ninguna ronda anterior de esta feature

### Migración del esquema fijo "cada N estrellas = 1 premio" al esquema de HITOS configurables (ej. 5, 8, 15 + premio especial)

Alcance: los cambios sin commitear sobre `HEAD` (`2fb671b`) descritos en el encargo — modelos
(`reward_progress.dart` + `.freezed.dart`/`.g.dart` regenerados), `reward_repository.dart`
(`getCatalog(especial: bool)`), `reward_providers.dart` (`rewardCatalogProvider.family<...,
bool>`), `app_router.dart` (query param `especial` en `/rewards/redeem/:redemptionId`),
`reward_redeem_screen.dart` (`isSpecial`), `rewards_screen.dart` (tablero dinámico de hitos +
overlay de celebración normal/especial/tanda mixta), `reward_terms_sheet.dart`.

`flutter analyze` (salida cruda propia): `No issues found! (ran in 5.3s)`. `flutter test` (suite
completa, salida cruda propia): `00:22 +505: All tests passed!`. `dart run build_runner build`
(salida cruda propia): `Built with build_runner/aot in 10s; wrote 0 outputs.` — confirma que
`reward_progress.freezed.dart`/`.g.dart` ya escritos en el working tree son byte-idénticos a lo
que generaría el toolchain real, sin drift a mano (revisé también el diff de esos dos archivos
generados: `RewardSlot.esEspecial` y `RewardMilestoneProgress` completo aparecen con el patrón
estándar de `freezed` — `copyWith`, `==`, `hashCode`, `toString()`, `fromJson`/`toJson` —, no
escritos a mano). `dart format --set-exit-if-changed` sobre `lib/features/rewards/` y
`test/features/rewards/`: `Formatted 18 files (0 changed)`.

**Contrato de API verificado por lectura directa del backend real** (no por el resumen del
encargo): `backend-celtas/src/modules/rewards/rewards.service.ts` (`getProgress`/`getCatalog`) y
`rewards.controller.ts`. Coincide exactamente con los modelos Dart: `GET /rewards/progress` →
`{ estrellasDelMes: number, hitos: [{estrellasRequeridas, alcanzado, esEspecial}],
premiosDisponibles: [{id, expiresAt, esEspecial}], promocionActiva: {...} | null }`; `GET
/rewards/catalog?especial=true` compara `especial === 'true'` como **string** en el controller
(`getCatalog(@Query('especial') especial?: string)`), no como bool — el repositorio Dart lo
respeta mandando `{'especial': 'true'}` explícito y omitiendo el parámetro por completo cuando es
`false`, cubierto con 2 tests que verifican `queryParameters: null` en ese caso (no
`{'especial': 'false'}`, que también funcionaría del lado del backend pero no es lo que manda el
código). `especial=false` y `especial=true` son catálogos EXCLUYENTES (`redeemableWithStars` vs.
`specialReward`, nunca una unión) — reflejado 1:1 en el comentario del repositorio y verificado
con el test de `reward_redeem_screen_test.dart` que confirma que el catálogo especial nunca
mezcla ítems del normal.

✅ Pasó (verificado por mí, no solo por lectura del diff):

- **Numeración "Premio N" con distintas combinaciones de hitos, confirmada con mutación real, no
  solo porque los tests ya estaban en verde**: reverté `_premioNumbers` (quité el filtro
  `!h.esEspecial`, así que los hitos especiales también consumían un número) y corrí la suite de
  `rewards_screen_test.dart` — fallan exactamente los 2 tests que dependen de la numeración
  correcta ("especial en el MEDIO" y "4 combinaciones"), con el patrón de evidencia esperado
  (`Expected: exactly one matching candidate / Actual: Found 0 widgets with text "Premio 2"`);
  los demás tests del archivo (incluidos los de overlay/premios disponibles, que no dependen de
  `_premioNumbers`) siguen en verde. Revertido con `Copy-Item` desde una copia de respaldo hecha
  antes de mutar, confirmado `git diff --stat` idéntico al estado previo y `flutter analyze`
  limpio de nuevo. La lógica real (`hitos.where((h) => !h.esEspecial).toList()..sort(...)`,
  índice `+1` por posición) numera SOLO los hitos no-especiales por su umbral ascendente,
  ignorando en qué posición del tablero completo cae el especial — correcto para los 3
  escenarios pedidos: 2 hitos normales sin especial, 4 hitos con el especial en el medio (2, 4,
  [6-especial], 8, 10 → "Premio 1/2/3/4" para 2/4/8/10, "★ Especial" para 6, nunca "Premio 5"), y
  el caso original de 3 hitos.
- **`hitos: []` no crashea la pantalla, confirmado con mutación real (no solo con el test ya
  existente)**: cambié el guard `if (hitos.isEmpty)` por `if (false)` en `_ProgressCard.build` —
  el test `'hitos vacío...'` no solo falla la aserción esperada, sino que Flutter reporta
  "Multiple exceptions (2) were detected... at least one was unexpected", confirmando que sin el
  guard `hitos.map((h) => h.estrellasRequeridas).reduce(max)` sobre una lista vacía lanza un
  `StateError` real (`Bad state: No element`), no solo un valor incorrecto — el guard es
  genuinamente necesario, no defensivo de más. Revertido y reconfirmado limpio de la misma forma
  que el punto anterior.
- **El query param `especial` viaja correctamente en las 3 etapas del flujo**, verificado en
  código y con test, no solo en una etapa suelta:
  1. `_RewardSlotCard` (`rewards_screen.dart`) → `context.push('/rewards/redeem/${slot.id}${special
     ? '?especial=true' : ''}')` — solo agrega el query param cuando `slot.esEspecial` es `true`,
     nunca `especial=false` explícito.
  2. `app_router.dart` → `isSpecial: state.uri.queryParameters['especial'] == 'true'` — comparación
     exacta contra el string `'true'` (no `??`/truthy genérico), consistente con cómo lo lee el
     backend real para el otro extremo del mismo parámetro.
  3. `RewardRedeemScreen` → `ref.watch(rewardCatalogProvider(isSpecial))` — el `isSpecial` recibido
     por constructor decide el `.family` sin reinterpretarlo.
     Cubierto end-to-end con navegación real de `go_router` en `rewards_screen_test.dart`
     (tap en una tarjeta de premio especial → captura el query param real que le llega a la ruta
     de canje, `capturedEspecialParam == 'true'`; el caso normal confirma que NO viaja el param,
     `isNull`, no `'false'`) y con `reward_redeem_screen_test.dart` (`isSpecial: true/false` →
     `rewardCatalogProvider(true)`/`rewardCatalogProvider(false)`, con overrides independientes por
     cada valor del `.family` que confirman que nunca se mezclan las dos listas).
- **`_syncAnimations()` revisado línea por línea, no solo por los tests**: `hasTrophy =
  hitos.any((h) => h.alcanzado)` controla el trofeo+confetti (arrancan en loop SOLO si hay al
  menos un hito alcanzado); `hasPendingSpecial = hitos.any((h) => h.esEspecial && !h.alcanzado)`
  se suma para el glow (arranca también si hay un especial pendiente, aunque nada esté alcanzado
  todavía) — coincide exactamente con lo que `_MilestoneCell` realmente anima: la celda
  "alcanzado" (normal o especial) usa `trophyScale`+`glowOpacity`+confetti; la celda "especial
  pendiente" usa solo `glowOpacity`; la celda "normal pendiente" no anima nada. Cada rama chequea
  `isAnimating` antes de llamar `repeat()` (evita reiniciar la animación desde cero en cada
  rebuild/refresh si ya estaba en loop) y llama `stop()` explícito en el caso contrario (evita
  dejar un controller corriendo sin una celda real que lo necesite). `hitos: []` → las 3
  condiciones dan `false` → los 3 controllers se detienen, consistente con el early-return de
  `build()` que ni siquiera construye `_MilestoneCell`. Sin loop infinito innecesario en ningún
  caso alcanzable.
- **`_highestReachedSpecialThreshold`** usa el umbral REAL (`reduce(max)` sobre los hitos
  `esEspecial && alcanzado`) para el copy del overlay dorado — nunca un número hardcodeado,
  confirmado con el test que usa `estrellasRequeridas: 12` (no el 15 del ejemplo original del
  comentario del modelo) y espera el texto "Completaste las 12 estrellas del mes...".
- **Celebración de tanda mixta (normal + especial simultáneos) no pierde ningún premio**: `_pendingNormal`/
  `_pendingSpecial` se calculan una sola vez por tanda nueva (guardados con `_seenStorage.markSeen`
  antes de mostrar el overlay, para no repetir en el próximo refresh), se muestra primero el normal
  y, recién al cerrarlo, aparece el especial — cubierto con test que simula el ciclo completo
  (tap "Ver mis premios" del overlay normal → aparece el especial → tap de nuevo → ambos
  desaparecen).
- **Contrato de `RewardSlot.expiresAt`/`RewardCatalogItem` sin cambios de forma en esta migración**
  (solo ganaron/perdieron el campo `esEspecial` donde correspondía) — no se reintrodujo el bug de
  clase "id en el body de un PATCH" porque no hay ningún PATCH en este módulo, solo `GET` con
  query params.
- **Barrido propio de todo `lib/` y `test/`** buscando referencias sueltas a los nombres viejos
  (`estrellasParaProximoPremio`, `estrellasPorPremio`): el único resultado es un comentario de
  `reward_progress.dart` que documenta a propósito el cálculo VIEJO del backend (`% estrellasPorPremio`)
  para contrastarlo con el esquema nuevo — no es código muerto ni una referencia rota.

❌ Falló (no bloqueante para el veredicto, pero real, a corregir):

- **`reward_terms_sheet.dart`, punto "La meta más alta del tablero entrega, además, un premio
  especial distinto del resto."**: esta frase asume que el hito especial es siempre el de mayor
  `estrellasRequeridas`, pero eso no es una regla del backend — `RewardMilestonesService.create`/
  `update` no restringen `isSpecial` a un único hito ni a la posición más alta (cualquier hito
  puede marcarse especial desde el admin, y el propio código de `rewards_screen.dart` está
  preparado para eso: hay un test dedicado, `'especial en el MEDIO'`, que ejercita exactamente
  este caso). Si el admin configura el hito especial en una posición intermedia (como en el
  ejemplo `2 (normal) / 4 (normal) / 6 (ESPECIAL) / 8 (normal) / 10 (normal)` que ya prueba el
  propio código), este texto le muestra al cliente una regla que no es cierta ese mes. Sugerencia:
  "Una de las metas del tablero (marcada por el admin) entrega, además, un premio especial
  distinto del resto." — sin asumir posición, igual que ya se cuidó de no hardcodear el número de
  estrellas.

⚠️ Riesgos / casos borde no cubiertos, no bloqueantes:

- Si el admin configurara **más de un hito** como `isSpecial: true` alcanzados en la misma tanda,
  `_highestReachedSpecialThreshold` usa el umbral MÁS ALTO de los especiales recién alcanzados
  para el copy del overlay — funciona sin crashear, pero el texto no distingue cuál de los dos
  especiales corresponde a cuál `RewardSlot` de `premiosDisponibles`. Caso borde teórico (nada en
  el schema de `RewardMilestone` impide 2+ hitos especiales), no cubierto por ningún test, sin
  evidencia de que el admin lo configure así en la práctica.
- El comentario de la ruta `/rewards/redeem/:redemptionId` en `app_router.dart` referencia un
  mockup `/product/:id` como patrón — correcto — pero el propio `RewardRedeemScreen` menciona en
  su docstring un mockup `estrellas-03-canje.png` que no existe en `design-reference/` (solo están
  `estrellas01progreso.*`, `estrellas02desbloqueo*.*`, `estrellas04terminos.png`) — no es parte de
  esta migración (el comentario es anterior), pero es una referencia rota menor que vale la pena
  limpiar si se vuelve a tocar ese archivo.
- No hay verificación en dispositivo/emulador real de esta migración específica (tablero dinámico,
  overlay dorado, canje del catálogo especial) — mismo pendiente general ya declarado arriba para
  todo el módulo Estrellas.
- `ROADMAP.md` no tiene ninguna entrada para el módulo/feature "Estrellas" (ni en los módulos 0-10
  numerados ni como mejora post-cierre de otro módulo) — no se puede "marcar como completo" un
  ítem que no existe; queda para la sesión principal decidir dónde ubicarlo.

**Veredicto: LISTO** (para el alcance de esta auditoría — la migración al esquema de hitos
configurables + premio especial). No se marca ningún checkbox de `ROADMAP.md` porque no existe
ninguna entrada de "Estrellas" ahí para marcar; queda pendiente que la sesión principal cree esa
entrada. El único hallazgo real (copy de términos asumiendo que el especial es siempre la meta más
alta) es de contenido/UX, no funcional, y no bloquea: la lógica de negocio real (numeración,
tablero, celebración, catálogo, animaciones) maneja correctamente un especial en cualquier
posición — solo el texto estático del bottom sheet de términos quedó desalineado con esa
flexibilidad.

---

## Auditoría: pase de mantenimiento 2026-09-02 (release nuevo + fix login Google) — ✅ LISTO con hallazgo menor no bloqueante

HEAD `24c0aaa`, cambios en working tree sin commitear. Fix real del login Google = certificado
de firma no registrado en Google Cloud/Firebase (no era bug de código); confirmado E2E en
dispositivo real por el dueño. Esta auditoría cubre el pase de mantenimiento que acompañó al
release.

Herramientas propias (salida cruda), tras `flutter pub get` (`Got dependencies!`, sin conflictos):
- `flutter analyze` → `No issues found!`
- `flutter test` → `+514 ~1: All tests passed!` (514 pasan, 1 `skip` = test de regresión del
  hallazgo menor, ver abajo).

✅ Pasó:
- **Revert byte a byte de `auth_repository.dart` y `auth_repository_test.dart` al baseline
  `4df16d2`**: `git diff 4df16d2 -- <archivo>` vacío en ambos; `git hash-object` del working tree
  == `git show 4df16d2:<archivo> | git hash-object` (auth repo `3fb05f4a…`, test `0ea96001…`).
  Idénticos, no "parecidos".
- **`google_sign_in` en 7.2.0** (pubspec `^7.2.0`, lock `7.2.0`; `_android 7.2.17`, `_ios 6.3.2`,
  `_web 1.1.3`, `_platform_interface` dev `3.1.0`). `auth_repository.dart` usa el patrón v7
  documentado en ROADMAP §1: `GoogleSignIn.instance.initialize(serverClientId:)` una sola vez
  detrás del flag de instancia `_googleInitialized` (queda en `false` si falla → reintenta) +
  `authenticate()`. Cancelación (`canceled`/`interrupted`/`uiUnavailable`) →
  `GoogleSignInCanceledException` (la UI la ignora). Nunca envía `password`.
- **AndroidManifest**: los 3 `<meta-data>` que deshabilitaban Credential Manager fueron
  removidos; no quedó ninguno. Coherente con el flujo v7 confirmado en dispositivo.
- **SDK / build**: `compileSdk = 37` (override explícito sobre el default 36 de Flutter),
  `targetSdk = flutter.targetSdkVersion` y `minSdk = flutter.minSdkVersion` → en Flutter 3.47.0
  `FlutterExtension.kt` define `targetSdkVersion = 36`, `minSdkVersion = 24` (verificado leyendo
  el archivo real del tool). AGP `9.0.1` (settings.gradle.kts), Gradle `9.1.0` (wrapper),
  Kotlin `2.3.20`. Target 36 cumple el mínimo de Google Play (API 36 es el último estable);
  compile 37 lo supera. Sin cambio de comportamiento en `build.gradle.kts` (solo comentario).
- **Enum `AuthorizationStatus.deniedPermanently`** (firebase_messaging 16.6.0): los 2 `switch`
  sobre `AuthorizationStatus` quedan exhaustivos (analyze limpio lo garantiza, ambos sin
  `default`/`_`) —
  `notification_permission_action.dart` (`deniedPermanently` agrupado con `denied` →
  `openSystemSettings`, correcto: doc upstream dice "el usuario debe habilitar desde ajustes del
  sistema") y `profile_screen.dart` (`deniedPermanently` en el patrón `||` con
  `denied`/`notDetermined` → "Desactivadas"/`redLight`). Barrido de `lib/` + `test/`: no hay otro
  `switch`/`switch expression` sobre `AuthorizationStatus` (el de `notification_providers.dart:142`
  es sobre `NotificationPermissionAction`, no afectado). Nuevo test en
  `notification_permission_action_test.dart` cubre el caso 1:1.
- **`go_router 18.0.0`**: tests de `test/core/router/` verdes (22/22). Barrido de la API usada en
  `lib/` (`GoRouter`, `GoRoute`, `StatefulShellRoute.indexedStack`, `StatefulShellBranch`,
  `redirect:`, `context.go/push/pop`, `routerConfig`, `state.pathParameters`/`uri.queryParameters`/
  `extra`) — todo API estable en v18; el "breaking change" del changelog es solo el bump de min
  SDK (Flutter 3.44/Dart 3.12), satisfecho por 3.47.0/3.13.0. Router sigue creándose una sola vez
  con `ref.listen` + `router.refresh()` (patrón anti-bug del Splash intacto). Transitivas nuevas
  `material_ui`/`cupertino_ui` son el split estándar de Flutter 3.44+, no dependencias pesadas.
- **Limpieza de cruft**: `.gitignore` cubre `playstore-instalado.apk` (regla `*.apk` línea 63) y
  `android/build/…` / `android/app/build/…` (líneas 55-56) — verificado con `git check-ignore -v`.
  `google-services.json` conserva la entrada nueva del cert `86:7e…` (parte del fix real).

❌ Falló:
- Ninguno.

⚠️ Riesgos / hallazgos no bloqueantes:
- **Perfil muestra datos del usuario anterior tras `logout()` + `login()` de otra cuenta sin
  reiniciar la app** (hallazgo reportado, reproducido de forma aislada). Causa:
  `profileProvider` es un `AsyncNotifierProvider` keep-alive (no `autoDispose`) y **nadie lo
  invalida** en `AuthController.logout()` ni en `login()` — retiene `AsyncData(userA)` hasta que
  algo más fuerce el re-fetch o se reinicie la app. **No es regresión de esta sesión** (el código
  de estado auth/perfil no se tocó salvo el enum). Test de regresión `skip`eado en
  `test/features/profile/application/profile_stale_user_repro_test.dart` (falla con
  `Expected: 'Bob B' / Actual: 'Alice A'`). Fix pendiente para la sesión principal: decidir dónde
  va la invalidación — `auth_controller.dart` no debería importar `profile_providers.dart`
  (capa auth → profile es mala dirección), así que probablemente `ref.listen` del auth state en la
  capa de profile, o `profileProvider` como `autoDispose` + `ref.watch` del estado de sesión.
  Quitar el `skip` al corregir.
- **`denied` vs `deniedPermanently` (semántica upstream 16.6.0)**: la doc nueva de
  `firebase_messaging` recomienda para `denied` (Android 13+, aún re-preguntable) *preferir*
  `requestPermission()` antes que mandar a ajustes; el proyecto mapea ambos a
  `openSystemSettings`. Es una decisión de diseño **preexistente** y documentada extensamente en
  `notification_permission_action.dart` (no introducida esta sesión). El split del enum ahora
  permitiría distinguirlos si se quisiera afinar el UX — mejora futura, no bug.
- `docs/testing-checklist.md` §"Gestión del permiso de notificaciones" línea ~1789 dice "cubre
  los 4 casos" — quedó en 5 con `deniedPermanently`. Staleness de doc, sin impacto.
- Sin verificación de build real de release (`bundle`/`assembleRelease`) en esta sesión — el
  merge del manifiesto y la resolución final de `targetSdk` no se confirmaron contra un APK/AAB
  armado, solo contra el `FlutterExtension.kt` del tool.

Veredicto: **LISTO con hallazgo menor aceptado como no bloqueante** (Perfil con usuario stale
tras cambio de cuenta sin restart — preexistente, con test de regresión `skip`eado, fix
delegado a la sesión principal).

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
