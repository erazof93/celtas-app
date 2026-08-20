# 🪓 Celtas Mobile — Roadmap de desarrollo

App cliente en **Flutter** que consume el mismo backend NestJS que el panel admin:
`https://backend-celtas.onrender.com`. Mismo patrón de trabajo que `celtas-backend` y
`celtas-admin`: se avanza **módulo por módulo**, cada uno auditado por `@tester` antes de
marcarlo completo, con commits por módulo.

---

## Stack técnico

| Capa | Tecnología |
|---|---|
| Framework | Flutter (Dart) |
| Estado | Riverpod (`flutter_riverpod`) — sin codegen, mantenerlo simple |
| Cliente HTTP | `dio` (equivalente a Axios: soporta interceptores) |
| Modelos de datos | `freezed` + `json_serializable` (generados, nunca serialización a mano) |
| Navegación | `go_router` (bottom nav + shell route) |
| Auth token en memoria | Riverpod state (nunca persistido) |
| Refresh token persistido | `flutter_secure_storage` (encriptado en el dispositivo — mejor que el trade-off que aceptamos en el panel web, acá sí hay almacenamiento seguro real) |
| Login con Google | `google_sign_in` |
| Notificaciones push | `firebase_messaging` + `flutter_local_notifications` |
| Imágenes | `cached_network_image` (fotos de Cloudinary) |
| Redirección a WhatsApp | `url_launcher` |
| Config de entorno | `flutter_dotenv` (`.env` con `API_BASE_URL`, igual patrón que los otros dos proyectos) |
| Testing | `flutter_test` + `mocktail` |

## Backend que consume

```
Base URL (prod):  https://backend-celtas.onrender.com
Swagger UI:       https://backend-celtas.onrender.com/docs
Swagger JSON:     https://backend-celtas.onrender.com/docs-json
Fuente real:      ~/proyectos/celtas-app/celtas-backend/src/  (para responses, que Swagger no documenta)
```

**Regla del proyecto** (igual que en el panel admin): antes de construir cualquier pantalla que
hable con la API, confirmar el contrato exacto contra el Swagger o el código fuente real del
backend — nunca asumir la forma de los datos ni inventar campos.

## Referencia de diseño

Los mockups completos (12 pantallas, exportados como "Project archive" desde Claude Design)
viven en `design-reference/` en la raíz de este repo. **Es la fuente de verdad visual** — antes
de construir cualquier pantalla, revisar ahí los colores, espaciados, tipografía y layout
exactos, no aproximar a ojo.

### Paleta (ya verificada con contraste WCAG en el panel admin, reusar tal cual)

```
Negro:        #0D0D0D
Naranja:      #E8590C
Rojo (marca): #C1121F   (solo iconos/acentos, no texto — falla WCAG AA para texto)
Rojo claro:   #F87171   (el que sí cumple contraste, usar para texto/errores)
Dorado:       #FFB800
Crema:        #F5F1E8
```

### Ajuste pendiente del mockup (anotado en la revisión, no bloqueante)

Los badges de estado de pedido (`pendiente`/`confirmado`/`en_camino`/`entregado`/`cancelado`) en
el mockup usan tonos muy parecidos entre sí (dorado→naranja→rojo), y `en_camino`/`cancelado` se
confunden a simple vista. Al implementar el componente de badge real, dar más separación visual
entre los 5 estados — reservar el rojo casi exclusivamente para `cancelado`, y usar el dorado/
naranja de forma más escalonada para el resto. No es un bloqueo, es una mejora sobre el mockup.

---

## Reglas de negocio (recordatorio, ya establecidas en todo el proyecto)

- **No hay pago dentro de la app.** El checkout arma el pedido, lo envía al backend
  (`POST /orders`), y el backend devuelve un `whatsappUrl` ya armado — la app solo lo abre con
  `url_launcher`. Nunca se construye un flujo de pago propio.
- Login tradicional (email/password) **y** con Google — ambos igual de soportados.
- Estados de pedido: `pendiente` → `confirmado` → `en_camino` → `entregado` / `cancelado`.
- Cupones (`percentage`/`fixed_amount`) se aplican en el checkout antes de confirmar.
- El carrito es 100% local (Riverpod), no existe en el backend hasta que se confirma el pedido.
- El `id` de cualquier recurso va siempre en la URL/path de la request, nunca en el body de un
  PATCH — la misma regla que ya nos mordió dos veces en el panel admin.

---

## Prerrequisitos externos (antes de los módulos que los necesiten)

- **Firebase**: reutilizar el MISMO proyecto de Firebase ya creado para el backend (no crear uno
  nuevo) — así los FCM tokens que registre la app son válidos para el `firebase-admin` que ya
  usa el backend. Se necesita descargar `google-services.json` (Android) y
  `GoogleService-Info.plist` (iOS) desde la consola de Firebase, agregar la app Android/iOS al
  proyecto existente si no está agregada.
- **Google Sign-In**: usar el mismo Client ID de Google Cloud del proyecto, más un Client ID
  adicional de tipo Android/iOS (con el SHA-1 del certificado de firma para Android) — distinto
  al "Web application" que ya se creó para el backend. Se resuelve en el módulo 1.

---

## Estructura de carpetas

```
celtas-mobile/
├── design-reference/            # export de Claude Design (Project archive), NO editar
├── lib/
│   ├── main.dart
│   ├── app.dart                 # MaterialApp + router + tema
│   ├── core/
│   │   ├── config/
│   │   │   └── env.dart         # lee flutter_dotenv
│   │   ├── network/
│   │   │   └── api_client.dart  # dio + interceptores
│   │   ├── theme/
│   │   │   └── app_theme.dart   # colores/tipografía de design-reference/
│   │   └── router/
│   │       └── app_router.dart  # go_router + shell de bottom nav
│   ├── features/
│   │   ├── auth/
│   │   │   ├── data/            # models (freezed), repository
│   │   │   ├── application/     # providers de Riverpod
│   │   │   └── presentation/    # pantallas (Login, Registro, Splash)
│   │   ├── home/
│   │   ├── menu/                # detalle de producto
│   │   ├── cart/
│   │   ├── checkout/
│   │   ├── profile/
│   │   ├── addresses/
│   │   ├── orders/
│   │   ├── coupons/
│   │   └── notifications/
│   └── shared/
│       └── widgets/             # componentes reutilizables (botones, badges, etc.)
├── test/
├── .env / .env.example
├── .opencode/
│   ├── agents/
│   │   ├── celtas-mobile.md
│   │   └── tester.md
│   └── skills/
│       └── flutter-celtas/
│           └── SKILL.md
├── opencode.json
├── ROADMAP.md
└── pubspec.yaml
```

---

## Checklist por módulos

### 0. Setup inicial — ✅ COMPLETO
- [x] `flutter create` + dependencias (Riverpod, dio, go_router, freezed, secure_storage, google_sign_in, firebase_core/messaging, cached_network_image, url_launcher, flutter_dotenv, mocktail)
- [x] `design-reference/` copiado, tema visual extraído del CSS real (no aproximado): paleta,
  tipografía (`Cinzel` display/títulos, `Manrope` cuerpo, vía `google_fonts`), radios (`CeltasRadii`)
- [x] `.env`/`.env.example` con `API_BASE_URL`, nota de `10.0.2.2` para emulador Android
- [x] `api_client.dart` con estructura base (interceptor completo en módulo 1)
- [x] Estructura de carpetas completa, `analysis_options.yaml` con `flutter_lints` estricto
- [x] `flutter analyze` sin issues, `flutter run` (web) compila y sirve 200
- ⚠️ Nota: esta sesión corrió en el agente `build` por descuido (no `celtas-mobile`) — sin
  impacto real porque el módulo no requería `@tester` ni las instrucciones específicas del
  agente, y la skill ya está habilitada a nivel de proyecto. Confirmar el agente correcto con
  Tab antes del módulo 1 (Auth), donde sí importa.

### 1. Auth — ✅ COMPLETO (8/8)
- [x] Prerrequisito: Client ID de Google (Android) creado con SHA-1 real; login con Google
  implementado con `google_sign_in` 7.x (`initialize()` una sola vez + `authenticate()`),
  `GOOGLE_SERVER_CLIENT_ID` en `.env`. **Bug mayor corregido**: `initialize()` se llamaba más de
  una vez (comportamiento indefinido según la SDK), fijado a llamada única de instancia.
  Cancelación del picker manejada sin error, 409 de email duplicado con mensaje real del
  backend. 45/45 tests (repositorio con fake, controller, widget del botón)
- [x] **Confirmado con evidencia real** (no suposición): `google-services.json` NO es necesario
  — cero imports de Firebase en `lib/`, cero plugin `google-services` en Gradle, y la
  documentación del propio paquete confirma que `serverClientId` tiene precedencia sobre ese
  archivo. El backend se identifica por package name + SHA-1 registrados en Google Cloud
- [x] **Prueba real en dispositivo** (Xiaomi por USB): login con Google completo de punta a
  punta — picker nativo, consentimiento OAuth, `idToken` real, backend acepta el token, sesión
  restaurada al reabrir la app. La prueba encontró y corrigió 2 bugs reales que solo aparecen
  en dispositivo (los tests automatizados los enmascaraban):
  1. `ProviderScope` faltante en `main.dart` → crash "Bad state: No ProviderScope found" al
     arrancar (los widget tests lo ocultaban porque ellos mismos envuelven con su propio
     `ProviderScope`)
  2. El router se recreaba en cada cambio de estado de auth → tras login, la app quedaba
     pegada en el Splash con spinner infinito en vez de navegar a Home. Fix: `ref.listen` +
     `router.refresh()` en vez de reconstruir el router, + redirect explícito de `/` → `/home`
     para usuarios autenticados. 2 tests de regresión del router agregados (47/47 verdes)
- [x] Modelos `freezed`: `User`, `AuthTokens` — contrato verificado contra el backend real
- [x] `AuthRepository`: login, registro, refresh (Google aislado a propósito)
- [x] Provider de Riverpod: `accessToken` en memoria, `user` actual
- [x] `flutter_secure_storage` para el `refreshToken`
- [x] Interceptor de `dio` completo: request/response/error, refresh-once, cola de pendientes
  con `Completer`, `/auth/login`+`/auth/refresh`+`/auth/register` excluidos del ciclo
- [x] Pantallas Splash/Login/Registro según `design-reference/`, con aviso de backend lento (5s)
- [x] Persistencia de sesión al reabrir la app
- [x] **Deadlock teórico corregido**: una request encolada reintentada no marcaba `_retry`, así
  que si el token recién rotado fallaba en su reintento, se re-encolaba esperando un
  `_flushQueue` que ya no iba a llegar — colgada para siempre. Verificado bidireccionalmente
  (falla sin el fix con `TimeoutException`, pasa con el fix)
- [x] **Bug de clase encontrado vía widget test del Splash**: `parseSvgPath` no soportaba
  notación compacta ni comandos relativos/arcos SVG — `CeltasFlame` y `GoogleLogo` habrían
  crasheado la app en la primera pantalla (compilaba bien, fallaba en runtime al pintar).
  Parser reescrito con la gramática SVG completa, 6 tests con los paths reales
- [x] Auditado por `@tester` + código verificado por mí (evidencia cruda de ambos archivos
  clave): 27/27 tests, `flutter analyze` limpio

### 2. Navegación base — ✅ COMPLETO (3/3)
- [x] `go_router` con shell route: bottom nav bar (Inicio, Pedidos, Cupones, Perfil)
- [x] Guard de rutas: pantallas protegidas requieren sesión
- [x] Tema aplicado consistente en toda la navegación
- [x] `StatefulShellRoute.indexedStack` (cada tab mantiene su propio stack — necesario
      para los módulos 3-8). Bottom nav custom con valores exactos del mockup (alto 78px,
      fondo `#111010`, borde `#241F19`, íconos SVG 21px stroke 2.2 activo naranja / 2
      inactivo `#6B6357`, labels 10px). Guard por prefijo cubre rutas anidadas futuras
      (`/orders/123`). Patrón `ref.listen` + `router.refresh()` conservado (sin bug de
      recreación). 50/50 tests, `flutter analyze` limpio, probado en dispositivo real
      (registro → shell → 4 tabs → reabrir app con sesión persistida). Auditado por
      `@tester`: veredicto LISTO
- [x] **Mejora post-cierre — doble-atrás para salir** (`_ShellScaffold`,
      `lib/core/router/app_router.dart`): `PopScope canPop: false` en el shell; primer back
      muestra el aviso "Presiona de nuevo para salir" (mismo patrón visual de `SnackBar` que
      `cart_screen.dart`/`product_detail_screen.dart`/`home_screen.dart`), segundo back dentro
      de 2s cierra la app con `SystemNavigator.pop()`. Solo se dispara con el shell como ruta
      visible — las pantallas empujadas sobre el shell (carrito, checkout, detalle, direcciones)
      son rutas top-level, así que el back del sistema las pop-ea antes de llegar al `PopScope`
      del shell. `flutter analyze` limpio, 234/234 tests. Auditado por `@tester`: veredicto
      LISTO (detalle en `docs/testing-checklist.md`, sección Navegación)

### 3. Home — ✅ COMPLETO (3/3)
- [x] Consume `GET /banners/active` — carrusel de banners
- [x] Consume `GET /menu` — categorías + productos, con botón rápido de "+" para agregar al
      carrito sin entrar al detalle
- [x] Imágenes vía `cached_network_image`
      (carrusel con puntos indicadores, chips de categorías con filtro, estados loading/error/
      vacío explícitos para banners y menú, error de banners con REINTENTAR, pull-to-refresh sin
      excepción async, gradiente del banner con `CeltasColors.black.withValues(alpha: 0.85)` +
      `Colors.transparent` = CSS real `rgba(13,13,13,.85) 20% → transparent 70%`, placeholder
      eliminado. 79/79 tests, `flutter analyze` limpio. Auditado por `@tester`: veredicto LISTO)
- [x] **Mejora post-cierre: tap sobre banners según `actionType`** (`home_screen.dart`,
      `home_providers.dart`). `Banner.actionType`/`actionValue` ya existían en el modelo pero no
      se usaban al tocar el banner:
      - `none`: sin acción, sin afordancia visual.
      - `category`: `actionValue` = **id real** de la categoría, NO un slug pese a que el Swagger
        del backend lo describe como tal — confirmado leyendo `BannerForm.tsx` del panel admin
        (el `<Select>` usa `category.id` como `value`). Selecciona la categoría vía
        `selectedCategoryIdProvider` (`StateProvider<String?>` nuevo, compartido con `_MenuList`
        — antes ese estado vivía local en `_MenuListState`, ahora `_MenuList` es `ConsumerWidget`).
        Categoría sin productos disponibles (o borrada): `GET /menu` ya excluye del todo las
        categorías sin productos, así que se reutiliza el `_EmptyMenu` existente sin código nuevo.
      - `menuItem`: `actionValue` = id real del producto (mismo contrato verificado). Navega a
        `/product/:id`, mismo flujo que una tarjeta de producto. Producto ya no disponible: sin
        manejo especial — `ProductDetailScreen` ya busca en el menú cargado y ya tiene el estado
        "Producto no encontrado" (el backend también excluye productos no disponibles de
        `GET /menu`), así que cae ahí solo.
      - `external_url`: `launchUrl` directo, mismo criterio ya aprendido con el `whatsappUrl` del
        checkout (módulo 5) — no usa `canLaunchUrl` como gate.
      - Afordancia visual opcional: chevron sutil (`Icons.chevron_right_rounded`) cuando
        `actionType != none`.
      244/244 tests, `flutter analyze` limpio. **Auditado por `@tester` en dos pasadas**: la
      primera encontró un bug real (el título del banner sin `maxLines`/`overflow` se solapaba
      con el chevron en títulos largos, verificado con `tester.getRect`); corregido acotando el
      `Positioned` del título (`right: tappable ? 40 : 16`) + `maxLines: 1` +
      `overflow: TextOverflow.ellipsis`, con test de regresión que falla si se revierte el fix.
      La segunda pasada dio veredicto **LISTO**, con un riesgo no bloqueante (medición conservadora
      con `TextPainter` sugería que títulos reales largos podrían truncarse con "…" en pantallas
      angostas) — **cerrado verificando en el dispositivo real** (Xiaomi, `wm density` 450dpi,
      ancho lógico ≈384dp) que los 2 títulos señalados ("APROVECHA LA 2X1", "CARNES SALTADOS") se
      ven completos, sin truncar. **Prueba real en dispositivo** con 3 banners reales creados
      desde el panel admin (uno por `actionType`) + 1 preexistente (`none`): `category` → chip
      "pollo" seleccionado y menú filtrado correctamente; `menuItem` → navegó al detalle exacto
      de "Pollo Broaster"; `external_url` → abrió `com.google.android.youtube/.UrlActivity`
      (confirmado por logcat); `none` → sin chevron, tap sin efecto. Sin `FATAL EXCEPTION` en
      logcat durante toda la sesión.
- [x] **Mejora post-cierre: fix del ícono de ubicación + campana de notificaciones + barra
      flotante de carrito** (`home_screen.dart`, más módulo nuevo `features/notifications/`).
      Tres mejoras de UX, investigadas y verificadas antes de tocar código:
      - **Ícono de ubicación distorsionado** ("alargamiento visual" reportado): investigación
        primero confirmó que el pin NO es `Icon(Icons.xxx)` de Material ni SVG vía
        `flutter_svg`/`CustomPainter` con aspect ratio mal configurado (la hipótesis inicial) —
        es `SvgStrokeIcon` (`shared/widgets/svg_stroke_icon.dart`), un `CustomPaint` cuadrado con
        escala uniforme X/Y, así que el contenedor no podía ser la causa. La causa real: el punto
        interior del pin es un `<circle cx="12" cy="10" r="2.5">` en el SVG del mockup real
        (`design-reference/Celtas App Mockups.dc.html:133`), convertido a mano a un path de arco
        que arrancaba en (12,10) — el CENTRO del círculo, no un punto de su circunferencia — lo
        que desplazaba el círculo resultante a estar centrado en (12,7.5), invadiendo la punta del
        pin. Confirmado con `Path.getBounds()` antes/después del fix (`OLD: Rect.fromLTRB(9.5, 5.0,
        14.5, 10.0)` → centro real (12,7.5); `NEW: Rect.fromLTRB(9.5, 7.5, 14.5, 12.5)` → centro
        real (12,10), como el mockup). Test de regresión en `svg_path_test.dart`.
      - **Campana de notificaciones**: nueva pantalla `/notifications` (sin mockup en
        `design-reference/`, diseño nuevo consistente con el resto de la app) con historial local
        de notificaciones recibidas. Nuevo módulo `features/notifications/data/models/
        notification_history_item.dart` (freezed + json_serializable) +
        `notification_history_repository.dart` (persistido con `shared_preferences` — justificado:
        no es dato sensible como el `refreshToken`, que sigue en `flutter_secure_storage` sin
        cambios) + `NotificationHistoryNotifier` (`AsyncNotifier`, en `notification_providers.dart`).
        `NotificationService` (módulo 9) guarda cada notificación desde los mismos 3 puntos donde
        ya intercepta foreground/background/terminated (`_saveToHistory`, nuevo). La campana del
        Home navega a `/notifications`; cada ítem, al tocarlo, navega igual que la notificación
        real vía `NotificationTarget.fromPayload` (sin duplicar esa clasificación). Estado vacío
        explícito ("No tienes notificaciones todavía").
      - **Barra flotante de carrito en Home** (`_CartSummaryBar`): visible solo con
        `cartProvider.totalCount > 0`, vive en un `Stack` dentro del `Scaffold.body` del propio
        Home (por eso queda encima del bottom nav del shell sin reemplazarlo). Muestra "N item(s)
        · S/ total" + botón "VER CARRITO" que navega a `/cart`. Sin precedente en
        `design-reference/` — diseño nuevo, consistente con la paleta/radios del resto de la app.
      - **Bug real encontrado por `@tester`, corregido**: `NotificationHistoryNotifier.add()`
        tenía una condición de carrera real — el fix inicial (esperar `future` antes de mutar)
        solo cerraba "`add()` vs `build()` todavía en curso", no "`add()` vs `add()` en curso": dos
        notificaciones casi simultáneas (ej. cambio de estado de pedido + cupón nuevo con pocos ms
        de diferencia) podían pisarse y perder una. Corregido serializando las mutaciones sobre una
        `Future` interna (`_mutationQueue`), que sigue avanzando aunque una mutación falle. Test de
        regresión que reproduce la carrera exacta (fallaba con `Expected: <2>, Actual: <1>` antes
        del fix). De paso se cerraron dos riesgos menores que `@tester` marcó como no bloqueantes:
        `add()` ahora recorta la lista en memoria al mismo tope que lo persistido
        (`NotificationHistoryRepository.maxItems`, antes privado), y se agregó cobertura para el
        estado de error de `NotificationsScreen` y la transición 1→0 ítems de la barra del
        carrito. Riesgos documentados sin corregir (no bloqueantes, sin evidencia de que ocurran
        con el contrato actual del backend): `NotificationService._saveToHistory` descarta en
        silencio cualquier notificación sin `orderId`/`couponCode` reconocible (asimetría con
        `_showLocalNotification`, que sí la muestra en el sistema), y falta
        `notification_service_test.dart` (gap preexistente al módulo 9).
      262/262 tests, `flutter analyze` limpio. **Prueba real en dispositivo** (Xiaomi, Android 15,
      capturas vía `adb`): pin de ubicación visualmente correcto (círculo normal, sin
      distorsión); campana → pantalla "Notificaciones" con estado vacío correcto y back funcional;
      agregar un producto → aparece la barra "1 item · S/ 15.50" + "VER CARRITO" encima del bottom
      nav, sin reemplazarlo; tocar "VER CARRITO" navega a "Tu carrito" con el ítem real. Sin
      `FATAL EXCEPTION` en logcat durante la sesión. Auditado por `@tester` en dos pasadas: la
      primera encontró la condición de carrera de `add()`; la segunda, tras corregirla,
      verificó de forma independiente (`flutter analyze`/`flutter test` propios + trazado manual
      de la semántica síncrona del encadenado sobre `_mutationQueue`) que el fix cierra la carrera
      de verdad, y confirmó veredicto final **LISTO** — detalle completo en
      `docs/testing-checklist.md`, sección Notificaciones.
- [x] **Mejora post-cierre: fix de RAÍZ del ícono de ubicación + campana (el fix anterior solo
      había corregido el punto interior del pin, no la causa real).** El "alargamiento" seguía
      visible tras el fix del punto del pin porque la causa real estaba en el parser compartido
      `svg_path.dart`, no en un path individual: `smoothCubicTo`/`smoothQuadTo` (comandos SVG
      `S`/`s` y `T`/`t`) calculaban el primer punto de control en coordenadas YA absolutas, pero
      delegaban en `cubicTo`/`quadTo` con el `relative` original del comando — que le volvía a
      sumar `x,y`, duplicando el offset. Bug de clase real (un solo parser compartido, un solo
      fix): afectaba cualquier ícono con `s`/`t` relativo — el pin y la campana de
      `home_screen.dart`, la campana de `profile_screen.dart`, el ícono de WhatsApp de
      `checkout_screen.dart`, y el ícono "Perfil" del bottom nav (`celtas_bottom_nav.dart`).
      Verificado con `Path.getBounds()` antes/después (bounds pasaban de salirse hasta el doble
      del viewBox 24×24 a quedar dentro) y visualmente en dispositivo real (Xiaomi): pin y
      campana se ven como íconos normales. Auditado por `@tester` de forma independiente
      (revisión línea por línea de la lógica corregida + barrido propio de todo `lib/` para
      confirmar que ningún otro ícono usa `s`/`t`) — sin bugs, veredicto LISTO. Detalle completo
      en `docs/testing-checklist.md`, sección Notificaciones (auditoría conjunta con las mejoras
      de Producto/Carrito y Notificaciones de esta misma ronda).
- [x] **Mejora post-cierre: cartel de "local cerrado" en el Home, event-driven vía `nextChangeAt`
      (última pieza de la feature cross-repo "horario de atención"; backend y `celtas-admin` ya
      cerrados en sus propios repos; el bloqueo real del checkout — 409 de `POST /orders` — y su
      aviso preventivo, auditados en una sesión anterior, sin cambios ahí salvo extraer el widget
      visual a uno compartido, `shared/widgets/business_closed_notice.dart`).** Reemplaza un
      intento previo con `Timer.periodic` (descartado, nunca comiteado) por un mecanismo
      **event-driven**, decisión de arquitectura explícita para reducir carga sobre un backend en
      Render free con muchos usuarios concurrentes: `GET /settings/business-hours` ahora también
      devuelve `nextChangeAt` (ISO 8601 UTC o `null`), el instante exacto en que `open` va a
      cambiar, calculado por el backend (`null` con cierre manual o si el horario nunca abre).
      `HomeScreen` pasó de `ConsumerWidget` a `ConsumerStatefulWidget` con
      `WidgetsBindingObserver`: `ref.listenManual(businessHoursProvider, ...,
      fireImmediately: true)` programa un único `Timer` (no periódico) contra `nextChangeAt` + un
      margen de deriva de reloj de 5s; al disparar, invalida el provider — que a su vez entrega un
      `nextChangeAt` nuevo y se reprograma solo, autoperpetuándose sin adivinar ningún intervalo.
      `AppLifecycleState.resumed` cancela cualquier timer pendiente y reconsulta de inmediato. El
      cartel es puramente informativo: NO deshabilita nada, el cliente sigue pudiendo navegar y
      agregar productos al carrito con el local cerrado — el único bloqueo real sigue siendo el
      409 del checkout. **Bug real encontrado y corregido durante el desarrollo**: la primera
      versión decidía si reprogramar con `next.valueOrNull` a secas; Riverpod 2.x, mientras un
      `invalidate()` está en vuelo, entrega `AsyncData(isLoading: true, value: <valor ANTERIOR>)`
      — sigue siendo `AsyncData` pero con datos viejos, y reaccionar a eso reprogramaba un timer
      contra un `nextChangeAt` ya vencido, generando un `invalidate()` fantasma en carrera con el
      refetch real todavía en vuelo. Corregido exigiendo
      `next is! AsyncData<BusinessHours> || next.isLoading` — con un test que reproduce la carrera
      exacta. 359/359 tests, `flutter analyze` limpio. Auditado por `@tester`: repitió las 3
      mutaciones de forma independiente (fires-not-early, `nextChangeAt: null`, y la del
      `isLoading` que causó el bug real) confirmando que cada una hace fallar el test
      correspondiente; verificó con `grep` que ningún otro test monta el `HomeScreen` real sin
      stubear `businessHoursProvider`; confirmó contra el código fuente real del backend
      (`settings.controller.ts`/`settings.service.ts`) que `nextChangeAt` nunca puede llegar
      "vencido" salvo por latencia de red/cold-start de Render, caso ya manejado correctamente
      (`Duration.zero` en vez de un delay negativo inválido). **Pendiente**: no se pudo verificar
      en vivo con el Home realmente abierto en dispositivo/emulador (sin credenciales de admin
      para `celtas-admin` ni dispositivo conectado en esta sesión) — solo se verificó en vivo el
      contrato de `GET /settings/business-hours` contra producción. Veredicto: **LISTO**. Detalle
      completo en `docs/testing-checklist.md`, sección "Cartel de 'local cerrado' en el Home,
      event-driven vía `nextChangeAt`".

### 4. Producto + Carrito — ✅ COMPLETO
- [x] Pantalla de detalle de producto (selector de cantidad, agregar al carrito)
- [x] Estado del carrito 100% local (Riverpod `Notifier`)
- [x] Pantalla de carrito: editar cantidades, aplicar cupón (`POST /coupons/validate` antes de
      confirmar, no solo al final)
      (detalle con hero 400px + stepper + botón precio×cantidad, carrito con steppers/subtotales/
      total + cupón con error real del backend, checkout placeholder → módulo 5. 122/122 tests,
      `flutter analyze` limpio, test de integración en dispositivo real contra el backend real
      2/2 — flujo Home→detalle→carrito→cupón inválido. Fix de bug de clase: SnackBar que tapaba
      CTAs al navegar. Auditado por `@tester`: veredicto LISTO)
- [x] **Mejora post-cierre: monto mínimo de compra en cupones** (`Coupon.minPurchaseAmount`,
      deployado en el backend después de cerrar este módulo). `CouponRepository.validateCoupon`
      manda el subtotal actual del carrito como número real en el body de
      `POST /coupons/validate` (no string — el DTO del backend lo rechaza con 400 si no es
      numérico); cuando el backend rechaza por no alcanzar el mínimo, el mensaje real
      ("Este cupón requiere un pedido mínimo de S/X.XX") se propaga tal cual al campo del
      cupón, sin mensaje genérico. **Bug real encontrado por `@tester`** en la auditoría de esta
      mejora: el cupón ya aplicado no se re-validaba si el usuario bajaba cantidades después,
      dejando un descuento de vista previa que el backend igual habría rechazado al confirmar —
      corregido en `CartNotifier._clearCouponIfInvalid` (llamado desde `decrement`/`removeItem`):
      si el subtotal cae por debajo del mínimo con el carrito todavía con ítems, quita el cupón
      y avisa con un `SnackBar` (estilo `CeltasColors.surface`/`floating`, igual que el resto de
      la app); si el carrito queda vacío, lo quita sin aviso (no hay ítems visibles para
      asociarlo). Al corregir esto apareció una segunda variante del mismo problema: una
      condición de carrera entre aplicar el cupón (`await` a `POST /coupons/validate`, que puede
      tardar 30-50s si Render está frío) y una edición de cantidades mientras esa respuesta
      todavía no llega — los steppers no se bloquean durante la espera. Cerrada haciendo que
      `CartNotifier.applyCoupon` re-chequee el mínimo contra el subtotal ACTUAL (no el que
      existía cuando arrancó la validación) antes de aceptar el cupón, devolviendo `false` si ya
      no alcanza. Cubierto con un test de regresión que fuerza la carrera con un `Completer`
      controlado a mano. Verificado en dispositivo real (Xiaomi) con un cupón real generado
      desde el panel admin (mínimo de compra real S/80): rechazo con subtotal insuficiente sin
      crashear, aceptación al alcanzar el mínimo, remoción automática con aviso al bajar
      cantidades después de aplicado, cupones sin mínimo (o con `minPurchaseAmount: 0`, mismo
      criterio que "sin mínimo" ya usado en `celtas-admin`) sin cambios de comportamiento.
      215/215 tests, `flutter analyze` limpio. Auditado por `@tester` en dos pasadas (la primera
      encontró el riesgo del cupón sin re-validar; la segunda, tras corregirlo, encontró la
      condición de carrera y la inconsistencia de estilo del `SnackBar` — ambas corregidas antes
      del veredicto final LISTO)
- [x] **Mejora post-cierre: vaciar carrito.** Ícono de borrado en el header de la pantalla de
      carrito ("Tu carrito"), visible solo con ítems, que pide confirmación (`AlertDialog`
      CANCELAR/VACIAR) antes de llamar a `CartNotifier.clear()`, que resetea a
      `const CartState()` limpiando ítems y cupón aplicado en un solo paso. **Hallazgo real de
      `@tester`** en la primera auditoría: el ícono usaba `IconButton` de Material (el único de
      todo `lib/`, introducía el ripple/tap target por defecto que rompe la estética plana sin
      ripple del resto de la app) con color `CeltasColors.textMuted` para una acción destructiva
      — inconsistente con el precedente ya establecido en `addresses_screen.dart` para el mismo
      ícono (`Icons.delete_outline`) y semántica (borrar con confirmación previa), que usa
      `GestureDetector` + `color: CeltasColors.redLight`, `size: 18`. También señaló que el
      comentario del código describía mal el patrón que decía seguir. Corregido replicando
      exactamente el widget de `addresses_screen.dart` y ajustando el comentario para referenciar
      ese precedente real. 219/219 tests, `flutter analyze` limpio. Auditado por `@tester` en dos
      pasadas (la primera encontró la desviación de patrón de UI; la segunda, tras corregirla,
      confirmó veredicto final LISTO)
- [x] **Mejora post-cierre: selector de cupón propio desde el carrito** (commit `b911bb7`).
      Link "VER MIS CUPONES" junto al campo manual (solo visible sin cupón ya aplicado) que abre
      `CouponPickerSheet` (`GET /coupons/me`, mismo provider que "Mis cupones"): lista solo
      `effectiveStatus == active` (el campo derivado que corrige el desfase del cron diario, no
      el `status` crudo), atenúa (opacidad 0.55) y bloquea el tap de los activos que no alcanzan
      `minPurchaseAmount` contra el subtotal actual, con el monto exacto que falta; al elegir uno
      elegible solo devuelve el `code` vía `Navigator.pop` — la validación real sigue pasando por
      el mismo flujo de `POST /coupons/validate` ya existente para el input manual, sin
      duplicarla en el sheet. Auditado por `@tester`: sin bugs — `effectiveStatus` correcto
      (confirmado contra `findMyCoupons` en `coupons.service.ts`, que devuelve la entidad cruda
      sin la corrección del cron), criterio de mínimo consistente con `hasMinPurchase`
      (`0`/`null` igual a "sin mínimo"), boundary `subtotal >= minPurchaseAmount` (igual, no
      menor) verificado con test nuevo, sin `Color(0xFF...)` sueltos (usa `CeltasColors`/
      `CeltasRadii.input`/`CeltasRadii.card`, consistente con el resto de tarjetas de cupón y
      checkout). Se agregaron 2 tests de regresión no cubiertos por el commit original (límite
      exacto del mínimo y reapertura del sheet tras cerrarlo sin elegir nada). 227/227 tests,
      `flutter analyze` limpio. Veredicto: LISTO
- [x] **Mejora post-cierre: ajustes visuales en el carrito** (`cart_screen.dart`). Ícono de
      papelera (vaciar carrito, `ValueKey('cart-clear')`) agrandado de `size: 18` a `size: 24` +
      `Padding(4)` (tap target ~32dp) — era chico y difícil de acertar para una acción
      destructiva; sigue siendo `GestureDetector` + `Icon`, no `IconButton` (confirmado de nuevo
      con `grep -rn "IconButton(" lib`: 0 matches reales, mismo criterio ya verificado en la
      mejora de "vaciar carrito"). "VER MIS CUPONES" pasó de `Text` plano a un chip real
      (`Container` con `CeltasColors.buttonSurface` + `border: Border.all(color:
      CeltasColors.orange)` + `CeltasRadii.pill`) — mismo `ValueKey('cart-coupon-picker')`, sin
      cambiar el comportamiento. `CeltasColors.buttonSurface` no es un token nuevo: ya lo usa el
      botón "Aplicar" del cupón en la misma pantalla, confirmado con `grep`. Ambos cambios
      cubiertos por los tests ya existentes (mismos `ValueKey`, sin necesidad de tests nuevos).
      262/262 tests, `flutter analyze` limpio. **Prueba real en dispositivo** (Xiaomi, Android 15):
      papelera visiblemente más grande en la captura, chip "VER MIS CUPONES" con borde naranja
      claramente tocable. Auditado por `@tester`: sin bugs, veredicto LISTO (parte de la misma
      auditoría que la mejora de Home de arriba — ver `docs/testing-checklist.md`, sección
      Carrito/Checkout, para el detalle completo).
- [x] **Mejora post-cierre: 3 ajustes en el detalle de producto** (`product_detail_screen.dart`).
      (1) Se quitó el ícono de favoritos (corazón) — no hay funcionalidad de favoritos en el
      alcance del proyecto; solo queda el botón de volver. (2) `SafeArea`: auditoría de TODOS los
      `Scaffold(` del proyecto encontró que esta era la única pantalla sin envolver su `body` en
      `SafeArea` — corregido con `SafeArea(top: false, child: ...)` (mismo criterio que
      `celtas_bottom_nav.dart`: `top: false` porque el hero de 400px es full-bleed a propósito);
      sin este fix, el botón "AGREGAR AL CARRITO" quedaba tapado por la barra de navegación del
      sistema en dispositivos sin gesture nav. (3) El `SnackBar` "Agregado" (acá y en el "+"
      rápido del Home) ahora lleva `margin: EdgeInsets.fromLTRB(16, 0, 16, 88)` para no quedar
      tapado por `_CartSummaryBar` cuando el carrito ya tiene ítems. Auditado por `@tester`: sin
      bugs, veredicto LISTO — detalle completo en `docs/testing-checklist.md`, sección
      Notificaciones (auditoría conjunta de esta ronda).
- [ ] **Mejora nueva (en curso): selección de salsas/cremas en el detalle de producto.**
      Feature cross-repo pedida por el dueño del negocio (backend y `celtas-admin` ya cerrados y
      verificados en sesiones previas contra Postgres/servidor reales — ver `ROADMAP.md` de esos
      dos repos, sección Menu/Orders). Cambios en este repo, hechos en una sesión **sin acceso al
      toolchain de Flutter** (sandbox sin `flutter`/`dart` instalado ni acceso de red para
      instalarlo) — todo el código, incluido el código generado de `freezed`/`json_serializable`
      (`*.freezed.dart`, `*.g.dart`), se escribió a mano replicando exactamente el patrón de
      salida real de `build_runner` ya presente en el resto del repo (mismos comentarios
      `GENERATED CODE`, mismo uso de `DeepCollectionEquality`/`EqualUnmodifiableListView` para
      campos `List`, mismo formato de `@JsonKey()` en campos `@Default`). **Esto NO reemplaza
      correr `flutter pub get && dart run build_runner build --delete-conflicting-outputs`,
      `flutter analyze` y `flutter test` de verdad** — es un paso obligatorio antes de dar esta
      mejora por completa, y antes de la auditoría de `@tester`.
      - `SauceOption` (`features/home/data/models/sauce_option.dart`, nuevo): `{id, name}`,
        mismo shape que ya expone `GET /menu` para las salsas de cada producto
        (`MenuService.findPublicMenu` en el backend, ya filtrado a `active: true` y ordenado).
        Se reusa para `CartItem.selectedSauces` (ahí no viene de un `fromJson`, se arma a mano en
        el detalle a partir de las opciones ya cargadas).
      - `PublicMenuItem.sauces` (nuevo campo, `@Default(<SauceOption>[])`): lista vacía = el
        producto no ofrece selector de salsas (ej. arroz chaufa) — mismo criterio que ya usa
        `celtas-admin` para decidir si el checklist de salsas aparece en el formulario de un
        producto.
      - `product_detail_screen.dart`: nueva sección "SALSAS Y CREMAS" (chips multi-selección,
        solo si `item.sauces` no está vacío) entre el precio y el selector de cantidad — no
        estaba en el mockup original de 12 pantallas, se siguió el lenguaje visual ya establecido
        (borde dorado/naranja en seleccionado, mismo criterio que el círculo de selección de
        `_AddressCard` en checkout y el chip "VER MIS CUPONES" del carrito). Selección 100%
        opcional (el backend acepta `sauceIds` ausente o vacío sin problema).
        **Cambio de comportamiento pedido explícitamente por el dueño del negocio:** al tocar
        "AGREGAR AL CARRITO" ahora se hace `context.pop()` después de agregar (antes se quedaba
        en el detalle con un `SnackBarAction` "VER CARRITO"), para volver a Home y seguir
        agregando productos sin fricción — el flujo de "captura" normal de la app. Se quitó la
        acción "VER CARRITO" del `SnackBar` (ya no tiene sentido: el usuario ya vuelve a Home,
        que muestra su propia barra flotante de carrito) y se evitó dejar un callback capturando
        el `context` de una pantalla que está por hacer `pop()`.
      - `CartItem.selectedSauces` (nuevo campo) + `CartItem.lineKey` (getter nuevo): identifica
        una fila única del carrito por `menuItemId` + salsas seleccionadas (ordenadas antes de
        comparar, para que el orden de selección no importe). Sin salsas, `lineKey == menuItemId`
        — mismo valor que ya usaban `increment`/`decrement`/`removeItem`/los `ValueKey` del
        carrito antes de este cambio, así ningún producto sin salsas cambia de comportamiento.
        **Decisión de producto:** el mismo producto agregado con distinta combinación de salsas
        queda en una fila aparte del carrito (no se fusiona) — una Celtas Burguesa con mayonesa y
        otra sin nada son dos líneas con su propio stepper de cantidad. `CartNotifier.addItem`
        ahora recibe `selectedSauces` opcional (default `[]`, no rompe ningún caller existente);
        `increment`/`decrement`/`removeItem` cambiaron su parámetro de `menuItemId` a `lineKey`
        (mismo tipo `String`, mismos valores para cualquier producto sin salsas — no rompe los
        tests existentes que ya llamaban a estos métodos con el id plano del producto).
      - `cart_screen.dart`: línea nueva "cremas: mayonesa, mostaza..." debajo del nombre y arriba
        del precio unitario de cada ítem (solo si `selectedSauces` no está vacío) — pedido
        explícito del dueño del negocio, mismo lugar que marcó en su captura de referencia. Los
        `ValueKey`/llamadas al notifier de los steppers pasaron de `item.menuItemId` a
        `item.lineKey`.
      - `order_repository.dart`: cada ítem del payload de `POST /orders` manda `sauceIds` (los
        ids de `selectedSauces`) SOLO si el ítem tiene salsas seleccionadas — nunca una lista
        vacía, mismo criterio que el resto del DTO (`addressSnapshot`/`couponCode` también se
        omiten cuando no aplican). El mensaje de WhatsApp con las salsas concatenadas ya lo arma
        el backend (`OrdersService.buildWhatsappUrl`, verificado y cerrado en la sesión de ese
        repo) — este repo no necesita tocar nada para eso.
      - El botón "+" rápido del Home (`_AddButton` en `home_screen.dart`) agrega sin pasar por el
        selector de salsas SOLO si el producto no ofrece salsas — agregar sin salsas sigue siendo
        un estado válido para el backend, y es el atajo de "agregar rápido" ya probado. Si el
        producto SÍ ofrece salsas, el "+" navega al detalle en vez de agregar directo (ver
        **hallazgo de dispositivo real** más abajo — este comportamiento cambió después del cierre
        inicial del módulo).
      - Tests actualizados/agregados a mano (no corridos — ver advertencia arriba):
        `product_detail_screen_test.dart` (reescrito para navegar con `GoRouter` real en vez de
        `MaterialApp(home: ...)` suelto, necesario porque ahora `_addToCart` llama a
        `context.pop()`; casos nuevos de selector de salsas y de fusión/no-fusión de filas),
        `cart_provider_test.dart` (grupo nuevo "salsas/cremas"), `cart_screen_test.dart` (línea
        "cremas: ..." visible/ausente), `order_repository_test.dart` (nuevo — no existía; cubre
        el contrato de `sauceIds` en el payload).
      - **Bug encontrado y resuelto:** corriendo `flutter test` de verdad (primera corrida real
        contra el toolchain) aparecieron 2 fallos "too many elements" en
        `product_detail_screen_test.dart` al buscar el `SnackBar` justo después de tocar
        "detail-add". Causa: en `_addToCart()`, `context.pop()` se llamaba en el mismo frame en
        que se insertaba el `SnackBar`, y `ScaffoldMessenger` lo duplicaba momentáneamente en el
        árbol de widgets durante ese frame. Arreglado diferiendo el `pop()` con
        `WidgetsBinding.instance.addPostFrameCallback((_) { if (!mounted) return;
        context.pop(); });`; los 2 tests afectados ahora agregan `await tester.pumpAndSettle();`
        tras el `pump()` que sigue al tap (el `Navigator` necesita un frame extra para reflejar
        la ruta removida por el pop diferido). `flutter analyze` limpio, `flutter test` completo
        (301 tests) verde. Auditado por `@tester`: veredicto **LISTO** para este hallazgo puntual
        — detalle en `docs/testing-checklist.md`, sección Salsas/cremas → "Auditoría puntual: fix
        de la carrera SnackBar/`pop()` en `_addToCart()`".
      - **Dos hallazgos de dispositivo real (probados por el dueño del negocio, no encontrados en
        revisión de código):**
        1. El "+" rápido del Home agregaba SIEMPRE directo al carrito, incluso en productos que sí
           ofrecen salsas — el atajo se sentía roto porque nunca dejaba elegirlas. Arreglado: si
           `item.sauces.isNotEmpty`, el "+" navega a `/product/:id` (mismo `context.push` que ya
           usa el tap sobre la tarjeta) en vez de agregar directo.
        2. Faltaba poder editar la selección de salsas de un ítem ya agregado al carrito sin
           borrarlo y repetir el flujo desde cero. Agregado: `ProductDetailScreen` gana un modo de
           edición (`editingItem`, un `CartItem?` opcional) — precarga cantidad/salsas, el botón
           dice "GUARDAR CAMBIOS", y confirma con `CartNotifier.updateLine` (nuevo método:
           reemplaza cantidad y salsas de la fila, fusiona con otra fila si la combinación nueva
           de salsas coincide con una ya existente) en vez de `addItem`. El carrito
           (`cart_screen.dart`) gana un ícono de lápiz por ítem (visible solo si el producto ofrece
           salsas) que navega a `/product/:id` pasando el `CartItem` por `extra` de `go_router`
           (sin serializar). El `pop()` diferido tras guardar es el mismo en ambos modos: como el
           modo edición siempre se llega con `push` desde `/cart`, cae de vuelta ahí solo, sin
           necesitar una rama de navegación aparte.

        Tests nuevos en `home_screen_test.dart`, `cart_provider_test.dart` (grupo `updateLine`),
        `cart_screen_test.dart` (grupo del ícono de lápiz) y `product_detail_screen_test.dart`
        (grupo "modo edición"). `flutter analyze` limpio, `flutter test` completo (316 tests)
        verde. Verificado en dispositivo Android real (vía `adb` + automatización de toques) los 4
        escenarios: "+" con salsas → abre detalle; "+" sin salsas → agrega directo; lápiz del
        carrito → modo edición con precarga; guardar cambios → vuelve al Carrito (no a Home) con
        la fila actualizada sin duplicar. Auditado por `@tester`: veredicto **LISTO** para estos
        dos hallazgos — detalle en `docs/testing-checklist.md`, sección Salsas/cremas.
      - **Pendiente antes de poder marcar esto LISTO:** una verificación visual real (emulador o
        dispositivo) del flujo completo Home → detalle con salsas → Agregar (vuelve a Home) →
        VER CARRITO → "cremas: ..."/"Sin salsas" visible → Checkout → WhatsApp con las salsas (o
        "Sin salsas") concatenadas — sin dispositivo conectado en ninguna de las sesiones hasta
        ahora. `flutter pub get` + `build_runner` sí se corrieron de verdad (ver mejora de
        tri-state justo abajo, que corrió todo el toolchain real por primera vez sobre este
        módulo) y no generaron diffs distintos a lo escrito a mano.
      - **Mejora nueva: tri-state real de salsas (no aplica / "Sin salsas" explícito / con
        salsas), pedida por el dueño del negocio.** Hasta acá, un producto con catálogo de salsas
        donde el cliente no tocaba ningún chip quedaba indistinguible de un producto sin catálogo
        — ambos casos guardaban `selectedSauces: []` y el backend nunca recibía `sauceIds`. El
        backend (`backend-celtas`, ya cerrado en su propia sesión) implementa el tri-state real en
        `POST /orders` (`resolveSelectedSauces` en `orders.service.ts`): `sauceIds` OMITIDO →
        `selectedSauces: null` ("no aplica"); `sauceIds: []` MANDADO explícito → `selectedSauces:
        []` ("Sin salsas" real, mostrado literal en WhatsApp/admin); con ids → como siempre.
        - `CartItem` (`cart_item.dart`) gana `@Default(false) bool explicitlyNoSauces` — solo
          puede ser `true` cuando el producto ofrece salsas Y el cliente tocó explícitamente el
          chip "Sin salsas" del selector. `lineKey` no cambia (sigue dependiendo solo de
          `selectedSauces`), así que la fusión/no-fusión de filas del carrito no se ve afectada.
        - `CartNotifier.addItem`/`updateLine` (`cart_provider.dart`) propagan el campo nuevo hasta
          la fila construida/fusionada (en fusión, `OR` entre el valor existente y el nuevo).
        - `product_detail_screen.dart`: `_SauceSelector` gana un chip "Sin salsas"
          (`detail-sauce-none`), mutuamente excluyente con los chips de salsas reales — elegir
          cualquier salsa real desmarca "Sin salsas" y viceversa. Cuando el producto ofrece
          salsas, "AGREGAR AL CARRITO"/"GUARDAR CAMBIOS" queda deshabilitado (`onPressed: null`,
          deshabilitación real vía `CeltasButton`, no solo visual) hasta que haya una elección
          real, con un aviso (`_SauceChoiceNotice`, mismo patrón visual que
          `_MissingAddressNotice` de `checkout_screen.dart`) mientras tanto. Productos sin
          catálogo de salsas no se ven afectados por esta validación. Modo edición precarga el
          chip "Sin salsas" cuando `editingItem.explicitlyNoSauces == true`.
        - `cart_screen.dart`: la línea de salsas por ítem ahora es tri-state: salsas elegidas →
          "cremas: ..."; vacío pero `explicitlyNoSauces == true` → texto "Sin salsas"; ninguno de
          los dos (sin catálogo) → no muestra nada.
        - `order_repository.dart`: `POST /orders` manda `sauceIds: []` EXPLÍCITO cuando
          `selectedSauces` está vacío pero `explicitlyNoSauces == true` (antes esto se omitía
          siempre); sigue mandando los ids con salsas elegidas; sigue omitiendo la llave cuando
          ninguno de los dos aplica.
        - Tests nuevos/actualizados en los 4 archivos (`order_repository_test.dart`,
          `product_detail_screen_test.dart`, `cart_provider_test.dart`, `cart_screen_test.dart`),
          incluida la reescritura de un test viejo que asumía que elegir salsas era opcional (ya
          no lo es para productos con catálogo). 330/330 tests, `flutter analyze` limpio.
          Auditado por `@tester` con mutación real sobre los dos puntos críticos del cambio: (a)
          revertir la exclusión mutua de los chips hizo fallar 2 tests reales (`Found 2 widgets
          with icon` en vez de 1), (b) revertir la condición nueva de `order_repository.dart` hizo
          fallar exactamente el test de `sauceIds: []` — ambas mutaciones revertidas después de
          confirmar el fallo, `git diff` verificado idéntico byte a byte al estado previo.
          Veredicto: **LISTO** para este cambio puntual (contrato del backend re-verificado por
          lectura directa de `orders.service.ts`/`create-order.dto.ts`, no por el resumen del
          encargo). Riesgo no bloqueante documentado en `docs/testing-checklist.md`: el mensaje de
          WhatsApp con "Sin salsas" literal y el flujo visual completo siguen sin verificarse en
          dispositivo real (mismo pendiente que el resto de este módulo, ver arriba).
      - **Ajustes de UX tras feedback real de uso en dispositivo (capturas del dueño del
        negocio): hero reducido a 270px + `CeltasButton.enabled` separado de `onPressed`.** Dos
        cambios puntuales sobre lo ya cerrado arriba:
        - `product_detail_screen.dart`: el hero de la imagen del producto (400px, valor del
          mockup original) empujaba el selector de salsas y su aviso de elección pendiente fuera
          de la pantalla visible sin deslizar en la mayoría de celulares — reducido a 270px.
        - `celtas_button.dart` (`CeltasButton`): antes, `onPressed: null` controlaba a la vez el
          estilo visual (gris) y si el `InkWell` recibía el toque — un botón deshabilitado no daba
          NINGÚN feedback al tocarlo. Se agregó `bool enabled = true` que controla SOLO el
          estilo; el toque sigue dependiendo únicamente de `onPressed != null && !loading`. El
          botón "AGREGAR AL CARRITO"/"GUARDAR CAMBIOS" de `product_detail_screen.dart` ahora usa
          `enabled: _hasRequiredSauceChoice` con un `onPressed` real que muestra un `SnackBar`
          (mismo texto que `_SauceChoiceNotice`) cuando falta elegir salsas, en vez de ignorar el
          toque en silencio.
        - Auditado por `@tester` con mutación real sobre los 3 puntos críticos: (a) revertir
          `onTap: canTap ? onPressed : null` a `onTap: looksEnabled ? onPressed : null` en
          `celtas_button.dart` hizo fallar exactamente el test nuevo de `enabled: false` +
          `onPressed` no nulo; (b) revertir el botón de `product_detail_screen.dart` a
          `onPressed: _hasRequiredSauceChoice ? _addToCart : null` (patrón viejo) hizo fallar el
          test del `SnackBar` de aviso; (c) revertir el hero a 400px con el test nuevo de bounds
          del aviso (`tester.getBottomRight` del `_SauceChoiceNotice` contra el alto lógico del
          viewport) **NO hizo fallar el test** — con el fixture de prueba existente (`i-3`, sin
          `description`) el aviso ya cabía dentro del viewport de 390×844 lógicos incluso con el
          hero de 400px (`noticeBottom≈751.4` vs. `logicalHeight=844.0`, margen de ~93px); ver
          hallazgo no bloqueante en `docs/testing-checklist.md`. Las 3 mutaciones se revirtieron
          después de confirmar el resultado, `git diff` verificado idéntico byte a byte al estado
          previo. `flutter analyze` limpio, `flutter test` 334/334 (333 + 1 test nuevo de bounds
          agregado por `@tester`). Confirmado por lectura que ninguno de los ~13 usos existentes de
          `CeltasButton` en `lib/` pasa `enabled` explícitamente — el default `enabled: true` no
          cambia su comportamiento.
        - Este cambio agrega una 5ª ocurrencia del bloque `ScaffoldMessenger..hideCurrentSnackBar()
          ..showSnackBar(...)` duplicado byte a byte (2 dentro del mismo `product_detail_screen.dart`
          ahora, más `cart_screen.dart`/`home_screen.dart`/`app_router.dart`) — mismo riesgo de
          mantenimiento ya documentado en la sección de Navegación, sin agravarse de forma nueva
          (**consolidado en la siguiente mejora, ver abajo**).
        - Veredicto: **LISTO**. Sin verificación en dispositivo/emulador real en esta sesión — había
          un dispositivo Android conectado (`flutter devices`), pero llegar a `/product/:id`
          requiere sesión autenticada contra el backend real y esta auditoría no contaba con
          credenciales de prueba; no se intentó crear una cuenta nueva en el backend de producción
          solo para esta verificación visual puntual. Detalle completo en
          `docs/testing-checklist.md`.
- [x] **Refactor de limpieza: helper compartido `showCeltasSnackBar`** (deuda técnica detectada
      en la auditoría anterior — el bloque `ScaffoldMessenger.of(context)..hideCurrentSnackBar()
      ..showSnackBar(...)` llevaba 3 auditorías señalado como riesgo de mantenimiento sin
      corregirse). Extraído a `lib/shared/widgets/celtas_snackbar.dart` →
      `showCeltasSnackBar(context, message, {backgroundColor, duration, margin})`, con
      `backgroundColor: CeltasColors.surface` y `duration: Duration(seconds: 2)` por default
      (iguales en los 6 sitios reales) y `margin: null` por default (solo 2 de los 6 sitios
      necesitaban el margen de 88px por `_CartSummaryBar`/`CeltasBottomNav`; el resto dependía del
      cálculo default de `SnackBar`).

      **6 sitios migrados, no 5**: además de los 5 con la cascada literal `..hideCurrentSnackBar()
      ..showSnackBar()` (`app_router.dart` — doble-atrás —, `home_screen.dart` — error de banner
      —, `product_detail_screen.dart` ×2 — agregar/guardar y aviso de salsas —,
      `cart_screen.dart` — cupón quitado por mínimo —), `@tester` encontró un 6º sitio
      funcionalmente idéntico pero con `hideCurrentSnackBar()`/`showSnackBar()` como dos sentencias
      separadas (`home_screen.dart`, botón "+" rápido de agregar), que el `grep` inicial no había
      capturado por buscar solo la cascada literal — también migrado.

      **Auditado por `@tester` en dos pasadas.** La primera encontró 4 problemas reales, los 4
      corregidos antes de la segunda:
      1. El test nuevo (`celtas_snackbar_test.dart`) era tautológico para `backgroundColor`/
         `duration` — su propio `wrap()` reproducía los defaults reales con `?? default` antes de
         llamar al helper, así que nunca ejercitaba el default de verdad (confirmado con mutación:
         cambiar los defaults en `celtas_snackbar.dart` no hacía fallar ningún test). Corregido
         separando `wrapDefault()` (sin argumentos opcionales) de `wrapCustom()` (para el caso de
         overrides); re-verificado con la misma mutación, ahora sí falla el test correspondiente.
      2. El 6º sitio (arriba) no estaba migrado — corregido.
      3. El sitio del aviso de salsas ("Elegí tus salsas...") no es una relocalización pura de
         código preexistente en `git log`: se agregó en la mejora inmediatamente anterior de este
         módulo (tri-state de salsas / `CeltasButton.enabled`), todavía sin commitear cuando
         arrancó este refactor — por eso cuenta como uno de los sitios a consolidar aunque no
         aparezca en el `HEAD` de git al momento de auditar. Aclarado en
         `docs/testing-checklist.md` para que no se lea como comportamiento nuevo introducido por
         el refactor.
      4. El test existente del sitio de `cart_screen.dart` (cupón quitado por mínimo) solo
         verificaba el texto (`find.text(...)`) sin confirmar que vivía dentro de un `SnackBar` —
         reforzado con `find.descendant(of: find.byType(SnackBar), ...)`, mismo patrón que ya usa
         `product_detail_screen_test.dart` para el aviso de salsas.
      **Segunda pasada de `@tester`** (verificación independiente de las 4 correcciones, no solo
      lectura del diff): repitió la mutación de defaults sobre `celtas_snackbar.dart` y confirmó
      que ahora sí falla el test correspondiente (antes de la corrección no fallaba ninguno),
      revirtió y confirmó el archivo byte a byte idéntico al original; confirmó por lectura del
      código actual que el 6º sitio quedó migrado con el margen de 88 preservado y su test
      existente intacto; confirmó que la aclaración sobre el sitio del aviso de salsas es honesta,
      no un intento de esconder el hallazgo; confirmó el cambio de aserción del sitio de
      `cart_screen.dart`. `flutter analyze` limpio, `flutter test` 338/338 (salida cruda propia).
      **Veredicto final: LISTO.** Ver detalle completo (comparación sitio por sitio, salida cruda
      de ambas pasadas de mutación) en `docs/testing-checklist.md`, sección "Refactor:
      `showCeltasSnackBar` compartido".
- [x] **Mejora post-cierre: comentario/nota libre opcional por ítem del carrito (`comment`)**,
      espejo de un campo que backend y `celtas-admin` ya soportan en producción
      (`OrderItem.comment`). Contrato verificado por lectura directa:
      `create-order.dto.ts` (`CreateOrderItemDto.comment?: string`, `@IsOptional()`,
      `@MaxLength(140)`) + `orders.service.ts` (`resolveComment`: trimea, `null` si queda vacío;
      el mensaje de WhatsApp agrega ` — Nota: {comment}` cuando no es `null`).
      - `CartItem` gana `String? comment` (default `null`). `lineKey` ahora incluye el comentario
        además de `menuItemId` + salsas ordenadas — mismo criterio que ya existía para salsas
        (fila separada si difiere), agregado como segmento condicional (solo si hay comentario)
        para no romper el formato viejo de filas sin nota.
      - `CartNotifier.addItem`/`updateLine` reciben `comment` opcional y lo propagan; al
        participar en `lineKey`, la fusión por misma fila ya garantiza mismo comentario sin
        necesitar un `OR` como el que sí usa `explicitlyNoSauces`.
      - `product_detail_screen.dart`: sección nueva "NOTA PARA TU PEDIDO" (`_CommentField`),
        `TextField` `maxLength: 140`, SIEMPRE visible (a diferencia del selector de salsas, que es
        condicional al catálogo del producto) — mismo lenguaje visual que "SALSAS Y CREMAS"
        (label + subtítulo muted). Modo edición precarga el texto de la fila que se edita.
      - `cart_screen.dart`: línea `'nota: ${item.comment}'` debajo de la línea de salsas (o sola
        si el producto no tiene catálogo), mismo estilo visual.
      - `order_repository.dart`: `comment` se manda en el payload SOLO si queda contenido real
        tras `trim()` — mismo criterio que `sauceIds`/`addressSnapshot`/`couponCode`.
      - Tests nuevos en los 4 archivos ya existentes de la feature de salsas
        (`cart_provider_test.dart`, `product_detail_screen_test.dart`, `cart_screen_test.dart`,
        `order_repository_test.dart`) — 399/399 tests, `flutter analyze` limpio.
      - Auditado por `@tester`: contrato re-verificado por lectura directa de
        `create-order.dto.ts`/`orders.service.ts`/`api.d.ts` (no por el resumen del encargo);
        `flutter analyze`/`flutter test` (399/399) corridos de forma independiente; confirmado con
        **mutación real** que el fix de `lineKey` reportado (segmento de comentario condicional en
        vez de incondicional) es real, no cosmético: la versión incondicional rompe 7+ tests
        preexistentes de salsas. Durante esa mutación ocurrió un incidente autoinfligido de
        `@tester` (uso de `git checkout --` sobre un archivo con cambios sin commitear, que borró
        momentáneamente la implementación real además de la mutación) — detectado y reconstruido
        de inmediato contra el contenido ya leído en la misma sesión, sin pérdida real; documentado
        en detalle en `docs/testing-checklist.md` como lección para no repetir el mecanismo de
        reversión en próximas auditorías. Fidelidad visual confirmada consistente con el patrón ya
        establecido de "SALSAS Y CREMAS" (sin mockup de referencia para esta sección nueva, igual
        que no lo hubo para salsas en su momento). **Veredicto: LISTO.** Hallazgo no bloqueante
        (ya señalado en el encargo, confirmado real): el ícono de lápiz del carrito no aparece para
        un producto sin catálogo de salsas que solo tiene un comentario — no se pidió cambiar este
        criterio en este encargo, queda como mejora de UX a evaluar. Detalle completo en
        `docs/testing-checklist.md`, sección "Comentario/nota libre opcional por ítem del carrito
        (`comment`)".

### 5. Checkout — ✅ COMPLETO (5/5)
- [x] Selector de dirección guardada (o agregar nueva): `GET /users/me/addresses` con
      loading/error(REINTENTAR)/vacío explícitos; sin direcciones guardadas se muestra el
      formulario inline directamente; la dirección principal (`isDefault`) queda preseleccionada
      (el backend ya ordena `isDefault DESC, createdAt ASC`)
- [x] Resumen del pedido con descuento aplicado: items + subtotal + descuento del cupón
      ya validado en el carrito (módulo 4, `POST /coupons/validate` sin marcarlo usado) + total,
      fidelidad exacta al mockup 07 · CHECKOUT (colores `#C9A96A`/`#E8590C`/`#8A8378`/`#FFB800`
      ya definidos en `CeltasColors`, sin `Color(0xFF...)` sueltos)
- [x] `POST /orders` con `items` ([{menuItemId, quantity}]) + `addressId` (el checkout siempre
      persiste la dirección nueva vía `POST /users/me/addresses` antes de armar el pedido, así
      que `addressSnapshot` queda soportado en el repositorio para uso futuro pero no se ejercita
      todavía desde la UI) + `couponCode` opcional — contrato verificado contra
      `create-order.dto.ts` + `orders.service.ts`. El total NUNCA lo envía el cliente
- [x] Al recibir la respuesta, abrir el `whatsappUrl` con `url_launcher`. **Desviación
      justificada de la skill**: NO usa `canLaunchUrl` como gate — confirmado en dispositivo real
      (Xiaomi, Android 15) que devuelve `false` para `wa.me` aunque WhatsApp esté instalado
      (`resolveActivity(MATCH_DEFAULT_ONLY)` da `null` con más de una app candidata sin default
      fijado). `launchUrl` directo sí es la señal confiable: `false`/`PlatformException` se tratan
      como "no se pudo abrir" con mensaje claro y botón "ABRIR WHATSAPP" para reintentar, sin
      perder el pedido ya creado
- [x] Limpiar el carrito local tras confirmar: se limpia apenas el backend confirma el pedido
      (antes de intentar abrir WhatsApp), para no reenviarlo por error aunque WhatsApp falle al
      abrirse
- [x] **Prueba real en dispositivo** (Xiaomi por USB, dos corridas): confirmó y corrigió 3 bugs
      reales que solo aparecen fuera de los widget tests:
      1. Overflow de 31px en el botón CTA (`Row` de ícono+label sin `Flexible`) — fix:
         `Flexible` en el label + fontSize 15 para botones con ícono (coincide con el CSS real)
      2. `AndroidManifest.xml` sin `<queries>` para `ACTION_VIEW`/`https` (Android 11+) — sin
         esto `url_launcher` no podía resolver ninguna app externa
      3. `canLaunchUrl` no confiable para `wa.me` (ver desviación arriba) — resuelto con
         `launchUrl` directo. Confirmado por el usuario: pedido real creado, WhatsApp abierto con
         el mensaje correcto, `total` calculado por el backend, `status: "pendiente"`
- [x] 10 widget tests nuevos del checkout (selector vacío/con datos/error, agregar dirección,
      resumen con cupón, confirmar con éxito, error real del backend, WhatsApp no instalado,
      `PlatformException`, carrito vacío deshabilita el botón) — 132/132 tests totales,
      `flutter analyze` limpio. Auditado por `@tester`: veredicto LISTO
- [x] **Mejora post-cierre: aviso explícito de dirección faltante + botón realmente deshabilitado**
      (`checkout_screen.dart`). Antes el aviso "Elegí o agregá una dirección de entrega" solo
      aparecía como `_orderError` DESPUÉS de tocar "CONFIRMAR PEDIDO" sin dirección — el botón
      nunca estaba deshabilitado por esa causa. Ahora `_MissingAddressNotice` (mismo patrón
      card+ícono+texto que `SlowBackendNotice`, tono gold de advertencia en vez de neutro) se
      muestra de forma reactiva junto al botón mientras `_selectedAddressId == null`, y el
      `onPressed` queda `null` en ese caso (mismo criterio que carrito vacío/`_confirming`). Se
      quitó el `if (addressId == null) { setState... return; }` de `_confirmOrder` por quedar
      inalcanzable con el botón deshabilitado. Auditado por `@tester`: `flutter analyze` limpio
      (`No issues found!`), 284/284 tests (`flutter test` completo). Revisado el diff completo:
      sin código muerto ni referencias rotas, `_orderError` sigue usándose solo para errores
      reales de API/WhatsApp sin colisionar con el nuevo aviso (widgets distintos, en distintas
      zonas del layout). No existía cobertura para el flujo completo (vacío → aviso+deshabilitado
      → dirección agregada → aviso desaparece+habilitado); se agregó un test nuevo en
      `checkout_screen_test.dart` y se confirmó que es un test de regresión real revirtiendo
      temporalmente el fix con `git stash` (el test falla sin el fix con `Found 0 widgets with
      key [checkout-missing-address-notice]`, pasa con el fix restaurado). **Pendiente**: no se
      pudo verificar en dispositivo Android real en esta sesión (`flutter devices` solo listó
      Windows/Chrome/Edge, sin dispositivo conectado) — queda pendiente confirmar visualmente el
      color/contraste del aviso gold y el estado gris del botón en pantalla física antes de dar
      por cerrado el 100% de la verificación. Veredicto: **LISTO CON OBSERVACIONES**.
- [x] **Mejora post-cierre: bloqueo por local cerrado (feature cross-repo, backend y
      `celtas-admin` ya cerrados en sus propios repos).** `POST /orders` ahora puede devolver 409
      (`ConflictException`, chequeado ANTES de tocar la base) cuando el local está cerrado
      (horario programado o cierre manual con motivo desde el panel); `checkout_screen.dart`
      distingue ese caso en `_confirmOrder` (`e.statusCode == 409`) mostrando un `AlertDialog`
      bloqueante (`_showClosedDialog`) con el mensaje real del backend, en vez del texto inline
      (`_orderError`) que sigue usando el resto de errores (ej. producto no disponible, cupón
      inválido) sin cambios. `lib/core/network/api_client.dart` y
      `lib/features/checkout/data/order_repository.dart` no necesitaron tocarse
      (`ApiException.statusCode` y el `catch` con `apiExceptionFromDio` ya existían). Feature
      nueva `lib/features/settings/` (`BusinessHours` freezed, `SettingsRepository`,
      `businessHoursProvider` = `FutureProvider`) consume `GET /settings/business-hours`
      (público) para un aviso preventivo (`_ClosedNotice`, mismo patrón visual que
      `_MissingAddressNotice` pero tono `redLight`) que NO deshabilita el botón de confirmar — el
      409 real al confirmar sigue siendo la única fuente de verdad, porque el local puede cerrar
      recién mientras el checkout está abierto. Auditado por `@tester`: `flutter analyze` limpio
      (`No issues found!`), 349/349 tests (`flutter test` completo, incluye 1 test nuevo agregado
      por la auditoría para el caso "`businessHoursProvider` falla al entrar al checkout" — sin
      aviso, sin crash, el 409 real sigue siendo el único bloqueo). Mutación real repetida de
      forma independiente sobre `if (e.statusCode == 409)`: el test del diálogo falla exactamente
      como se esperaba, revertido y confirmado en verde de nuevo. 2 hallazgos menores señalados
      por la auditoría, corregidos de inmediato después (`flutter analyze`/`flutter test`
      349/349 vueltos a correr limpios): `_showClosedDialog` usaba `CeltasColors.surface` en vez
      de `CeltasColors.card` (el color que usan de forma consistente los otros 3 `AlertDialog` ya
      existentes en la app — logout, vaciar carrito, eliminar dirección), y el mock de 409 en
      `order_repository_test.dart` no calcaba el shape real del error del backend
      (`{success, message, statusCode}` vs. un `error: 'Conflict'` inventado que el backend nunca
      manda). No se pudo probar el 409 real end-to-end contra producción (sin credenciales de
      admin en esta sesión, mismo límite ya declarado en el encargo) ni en dispositivo Android
      real. Veredicto: **LISTO**.

### 6. Perfil + Direcciones — ✅ COMPLETO
- [x] Ver/editar perfil (`GET`/`PATCH /users/me`)
- [x] CRUD de direcciones (`GET/POST/PATCH/DELETE /users/me/addresses`)
- [x] Logout
- [x] **Bug de backend encontrado y corregido**: `AddressesService.update()` (y dos services más
  del mismo módulo) usaban `Object.assign(entity, dto)` para aplicar un `UpdateDto` parcial —
  como el DTO declara todos sus campos como propiedad propia aunque no se hayan enviado, los
  ausentes llegan `undefined` y sobrescriben los del entity antes de serializar la respuesta del
  `PATCH` (la fila en base de datos queda íntegra porque TypeORM ignora columnas `undefined` al
  armar el `UPDATE`, pero el body HTTP de respuesta sí pierde esos campos). Corregido a
  `repository.merge(entity, dto)` en los 3 services, ya deployado en producción.
- [x] **Fix del lado mobile** (no depender del bug del backend, ni aunque ya esté corregido):
  `AddressRepository.updateAddress()` no parsea el body del `PATCH` (`Future<void>`, ver
  `lib/features/addresses/data/address_repository.dart:79`), y
  `AddressListNotifier.updateAddress()`/`removeAddress()` invalidan y vuelven a pedir la lista
  completa con `GET` (`lib/features/addresses/application/address_providers.dart:56-66,86-94`).
  Regla documentada en la skill `flutter-celtas` ("Nunca depender de la respuesta de un PATCH").
- [x] Verificado: 148/148 tests (`flutter test`), `flutter analyze` sin issues

### 7. Historial de pedidos — ✅ COMPLETO
- [x] Listado (`GET /orders/me`), badges de estado con la paleta ajustada (ver nota de diseño)
- [x] Detalle de pedido (items, dirección, estado, total)
      (`GET /orders/me` sin paginar y `GET /orders/:id` — contrato verificado contra
      `order.entity.ts`/`order-item.entity.ts` reales, sin campos inventados; `addressSnapshot`
      decodificado del JSON string crudo; badge de 5 estados con `CeltasColors.statusEnCamino`
      nuevo (azul, fuera de la paleta cálida) para separar `en_camino` de `confirmado`, según la
      nota de diseño ya documentada arriba; `cancelado` es el único con contorno rojo; historial
      se invalida y refetchea tras confirmar un pedido en checkout, nunca se inserta a mano; sin
      `Color(0xFF...)` sueltos, sin texto en inglés, loading/error/vacío explícitos en ambas
      pantallas. 166/166 tests, `flutter analyze` limpio. Verificado en dispositivo real (Xiaomi):
      pedidos reales del checkout aparecen en el listado, los 5 estados comparados lado a lado
      tras cambiar estados desde el panel admin se distinguen claramente, detalle de un pedido
      "en_camino" correcto. Auditado por `@tester`: veredicto LISTO)

### 8. Mis cupones — ✅ COMPLETO
- [x] Listado (`GET /coupons/me`), distinción visual clara entre activo/usado/expirado
      (contrato verificado contra `coupon.entity.ts` — `CouponStatus`/`CouponDiscountType`
      reales, sin campos inventados. **Bug real de negocio encontrado y corregido antes de
      llegar a producción**: el backend solo mueve `status` de `active` → `expired` con un
      cron diario (`handleDailyMaintenance`, 1am) — un cupón puede seguir marcado `active` en
      la respuesta hasta 24h después de que `expiresAt` ya pasó (el propio backend no confía
      en el campo a solas: `validateCoupon` hace la misma comparación contra `Date.now()`).
      `UserCoupon.effectiveStatus` replica esa comparación del lado del cliente y es lo único
      que pinta la UI (nunca `status` crudo), cubierto con el caso explícito del cron
      desfasado y el caso "`used` no se revierte a `expired`" en
      `user_coupon_test.dart`/`coupons_screen_test.dart`. Rediseño justificado del mockup:
      unificado el acento "activo" a un solo dorado (el mockup usaba dorado/naranja sin
      relación con ningún campo real, misma confusión ya corregida en los badges de pedidos
      del módulo 7), estado `used` diseñado desde cero (el mockup nunca lo mostraba), y
      eliminada la línea "Pedido mínimo $X" del mockup — no existe ese campo en la entidad
      `Coupon` real. Montos en `S/ X.XX` (2 decimales), no el separador de miles del mockup.
      `AngledClipper` extraído a `shared/widgets/` (antes vivía privado en `celtas_button.dart`)
      y `spanish_date.dart` extraído de `orders_screen.dart` (`formatShortDate`/
      `formatLongDate`), ambos reutilizados sin duplicación. 183/183 tests, `flutter analyze`
      limpio. Verificado en dispositivo real (Xiaomi): cupones reales del usuario, los 3
      estados comparados lado a lado se distinguen claramente, distinción de tipo de descuento
      visible, pull-to-refresh sin errores. Auditado por `@tester`: veredicto LISTO)
- [x] **Mejora post-cierre: monto mínimo de compra en la tarjeta**. La decisión original de este
      módulo (arriba) fue eliminar la línea "Pedido mínimo $X" del mockup porque el campo no
      existía en la entidad `Coupon` real — ya no aplica: el backend deployó
      `minPurchaseAmount` (decimal nullable) después de cerrar este módulo. La tarjeta ahora
      muestra "Pedido mínimo: S/X.XX" (formato de moneda ya establecido en el resto de la app,
      no el separador de miles del mockup) en la misma línea secundaria que la fecha, unida con
      " · " — el mismo patrón visual que ya traía el mockup original para ese caso
      (`design-reference`: "Pedido mínimo $15.000 · Válido hasta 20 ago 2026"). `0` se trata
      igual que `null` ("sin mínimo", mismo criterio que `celtas-admin`) vía
      `UserCoupon.hasMinPurchase`; los cupones sin mínimo siguen mostrando solo la fecha, sin
      nada de más. Verificado en dispositivo real con un cupón real (mínimo S/80) generado desde
      el panel admin. 215/215 tests, `flutter analyze` limpio. Auditado por `@tester`: veredicto
      LISTO (parte de la misma mejora que también toca el módulo 4, ver esa nota para el detalle
      completo de la re-validación en el carrito)
- [x] **Mejora post-cierre: orden local activos → usados → expirados**. `GET /coupons/me` ya
      se llamaba sin paginar desde el cierre original de este módulo (nada que tocar ahí). Se
      agregó `_sortedByEffectiveStatus` en `coupons_screen.dart`: concatena tres `where()`
      sobre `effectiveStatus` (no `status` crudo, mismo criterio del cron desfasado ya
      documentado arriba) en vez de `list.sort()` con comparador, porque `List.sort` no
      garantiza estabilidad. Decisión de producto explícita: usados/expirados nunca se ocultan
      ni se recortan, sin límite de cantidad ni paginación agregados a esta pantalla. Test de
      widget nuevo en `coupons_screen_test.dart` alimenta el mock en orden "raro" del backend
      (expirado, activo, usado) y confirma el orden visual leyendo los `Text` con "Código:" en
      orden de aparición. 277/277 tests, `flutter analyze` limpio. Auditado por `@tester`:
      veredicto LISTO — 2 huecos de cobertura no bloqueantes señalados en esa auditoría y
      cerrados después con 2 tests adicionales: (1) orden relativo estable dentro de cada
      categoría con 2+ cupones (activo/usado/expirado en pares "B antes que A", confirma que
      `where()` no reordena por código ni por ningún otro criterio propio, solo preserva el
      orden de llegada del backend); (2) el orden se recalcula tras pull-to-refresh sobre datos
      nuevos y distintos de la carga inicial, no queda pegado al primer fetch. 279/279 tests,
      `flutter analyze` limpio.

### 9. Notificaciones push — ✅ COMPLETO
- [x] Configurar Firebase en la app (archivos de configuración del proyecto ya existente)
- [x] Registrar el `fcmToken` del dispositivo (`PATCH /users/me/fcm-token`) tras login
- [x] Manejo de notificaciones en foreground/background/terminated
- [x] Probar recibiendo una notificación real (cupón generado o cambio de estado de pedido)
      (contrato verificado contra el backend real, no contra Swagger, que no documenta el
      response de este endpoint: `PATCH /users/me/fcm-token` identifica al usuario por JWT, sin
      id en el body — no aplica el patrón de bug de clase ya conocido. El payload de push no
      trae un campo `type` explícito; se infiere por la llave presente en `data` (`orderId` +
      `status` para pedidos, `couponCode` para cupones), confirmado 1:1 contra
      `orders.service.ts`/`coupons.service.ts` reales. `NotificationService` es un singleton
      inicializado en `main.dart` con un `ProviderContainer` creado a mano
      (`UncontrolledProviderScope`), necesario porque `getInitialMessage()` se resuelve antes de
      que exista un `BuildContext`. El registro del token solo se dispara en la transición hacia
      `authenticated` (no en cada refresh silencioso) y en `onTokenRefresh`, fire-and-forget para
      no bloquear el login si falla. Foreground muestra notificación local vía
      `flutter_local_notifications` e invalida el provider correspondiente de inmediato;
      background/terminated los maneja el SDK nativo de FCM solo (canal `celtas_default`
      unificado vía meta-data en el manifest, sin duplicar canal con el de la notificación
      local), con `onMessageOpenedApp`/`getInitialMessage` invalidando y navegando al detalle
      correcto. 189/189 tests, `flutter analyze` limpio. Verificado en dispositivo real (Xiaomi)
      cambiando estados de pedido y generando cupones desde el panel admin real, con logcat en
      vivo confirmando el camino nativo de FCM en background: foreground mostró la notificación
      local y refrescó la lista de Pedidos a CONFIRMADO sin acción manual; background navegó
      directo al detalle del pedido con estado ENTREGADO al tocar la notificación; terminated
      arrancó desde el Splash y navegó a Mis Cupones al tocar una notificación de cupón nuevo.
      Auditado por `@tester`: veredicto LISTO — riesgo documentado y no bloqueante: la lógica de
      ruteo/invalidación (`_invalidateFor`/`_navigateFor`) no tiene cobertura automatizada, solo
      la prueba manual en dispositivo real; configuración de iOS todavía pendiente, fuera de
      alcance del módulo 10 que solo pide APK de Android)
- [x] **Mejora post-cierre: badge de no leídas + marcar leídas al entrar, `maxItems` 50→30.**
      Se agregó el campo `read` (bool, `@Default(false)`) a `NotificationHistoryItem` (freezed,
      regenerado), un provider derivado `unreadNotificationCountProvider`, un método
      `markAllRead()` en `NotificationHistoryNotifier` (misma cola de mutaciones que `add()`, para
      no pisarse con un push concurrente), badge en la campana del Home (mismo patrón visual que
      el badge del carrito) y `NotificationsScreen` llama `markAllRead()` en `initState`.
      `NotificationHistoryRepository.maxItems` bajó de 50 a 30. Verificado end-to-end en
      dispositivo real: badge mostraba "2", al entrar a Notificaciones y volver al Home el badge
      ya no aparece. Auditado por `@tester` de forma independiente: confirmó que `fromJson()`
      sobre JSON persistido ANTES de este cambio (sin la key `read`) no explota y cae en `false`
      por defecto (agregó test propio para este caso, no cubierto); confirmó que `add()` y
      `markAllRead()` comparten `_mutationQueue` de forma estrictamente FIFO (sin `await` entre la
      reasignación de la cola y el encolado del callback), así que no hay ventana de carrera real
      entre ambos — agregó 2 tests propios (carrera `add()`/`markAllRead()`, y que
      `markAllRead()` no reescribe `state` si ya todo está leído) y un test de punta a punta con
      navegación real de `go_router` (no un fake) confirmando el ciclo completo
      badge→campana→`markAllRead()`→vuelta al Home sin badge. Sin bugs encontrados, veredicto
      LISTO — detalle completo en `docs/testing-checklist.md`, sección Notificaciones.
- [x] **Aviso proactivo por push de cambio de horario de atención — última pieza de la feature
      cross-repo "horario de atención"** (backend, `celtas-admin`, bloqueo real del checkout —
      409 de `POST /orders` — y su aviso preventivo, y el cartel event-driven del Home vía
      `nextChangeAt`, todos ya cerrados en rondas anteriores; este era el único pendiente). El
      backend ahora manda una push automática cuando el admin activa/desactiva el cierre manual
      desde el panel: `{ businessHoursChanged: 'true' }`, sin más contenido — un aviso de "algo
      cambió", nunca la fuente del estado real (el título/cuerpo de la notificación no se trata
      como estado, siempre se reconsulta `GET /settings/business-hours`). Extiende el patrón ya
      existente de `NotificationTarget` (sealed class, clasificación por llave presente en
      `data`) con un cuarto caso, `BusinessHoursNotificationTarget`: `_invalidateFor` invalida
      `businessHoursProvider` (mismo provider global que ya usan Home/Checkout, así que el
      cartel event-driven del Home se actualiza solo, sin código adicional); `_navigateFor` no
      navega a ninguna pantalla (sin pantalla propia); `fallbackTitle` de `_saveToHistory` usa
      "Aviso del local". De paso se encontró y cubrió un 4to switch no mencionado en el encargo
      original (`notifications_screen.dart`, `_NotificationCard._handleTap` + el cálculo de
      `tappable`, marcado por el compilador como no exhaustivo) — la tarjeta de este tipo de
      notificación en el historial local queda explícitamente no tocable (`onTap: null`, mismo
      criterio que `NoneNotificationTarget`), para no dejar un toque sin ningún efecto visible.
      361/361 tests, `flutter analyze` limpio. Auditado por `@tester` de forma independiente:
      repitió las 2 mutaciones (el `if` de `fromPayload`, y la exclusión de `tappable`)
      confirmando que cada una hace fallar el test correspondiente y que `git diff` queda
      idéntico tras revertir; `grep` propio en todo `lib/` confirmó que no queda ningún otro
      `switch`/pattern-match sobre `NotificationTarget` sin actualizar; confirmó contra el código
      real de `main.dart`/`settings_providers.dart` que `NotificationService` y el árbol de
      widgets comparten el mismo `ProviderContainer` (`UncontrolledProviderScope`), así que
      `invalidate()` desde `NotificationService` sí llega al `ref.listenManual` del Home, no es
      una suposición sin verificar. **Pendiente, no bloqueante**: sigue sin existir
      `notification_service_test.dart` (gap preexistente del módulo 9, no de esta ronda); no se
      pudo probar en vivo con dispositivo/emulador conectado ni credenciales de admin en esta
      sesión (`flutter devices` solo detectó Windows desktop y navegadores web, ninguno
      representativo de FCM en Android). Veredicto: **LISTO**. Detalle completo en
      `docs/testing-checklist.md`, sección "Aviso proactivo por push de cambio de horario de
      atención".
- [x] **Notificaciones de marketing/fidelización (feature cross-repo: backend `POST
      /notifications/broadcast` + `celtas-admin` sección Marketing, ambos ya implementados) —
      dos partes:**
      - **Parte 1 (verificación, sin cambios de código)**: un push de marketing (sin `orderId`,
        `couponCode` ni `businessHoursChanged` en `data`) ya cae en `NoneNotificationTarget` vía
        `NotificationTarget.fromPayload` — se muestra la notificación
        (foreground/background/terminated) pero no navega ni invalida nada, comportamiento
        correcto para un mensaje informativo. Ya había cobertura de test para "sin llaves
        reconocidas" en `notification_target_test.dart` (payload con clave desconocida y
        payload vacío, ambos → `NoneNotificationTarget`); el switch exhaustivo (sealed class)
        en `_invalidateFor`/`_navegateFor` garantiza en compilación que ese caso no dispara
        nada. **Hallazgo no bloqueante, documentado para decisión del usuario**:
        `_saveToHistory` excluye explícitamente `NoneNotificationTarget` del historial local
        (`if (target is NoneNotificationTarget) return;`, decisión previa al módulo de
        marketing) — una campaña de marketing se muestra como notificación del sistema pero
        NUNCA queda en la pantalla `/notifications` ni en el historial de admin visible al
        cliente. Si se quiere que las campañas queden en el historial local, es un cambio de
        producto a decidir, no un bug de esta verificación.
      - **Parte 2 (feature nueva): gestión del permiso de notificaciones en Perfil.**
        Confirmado contra la doc oficial de FlutterFire: una vez que el usuario rechaza el
        permiso, `requestPermission()` YA NO puede volver a mostrar el diálogo del sistema
        (devuelve `denied` sin interacción) — hay que redirigir a Configuración del sistema, no
        reintentar. Nuevo renglón "Notificaciones: Activadas/Desactivadas" en Perfil, entre
        Historial de pedidos y Cerrar sesión: `NotificationPermissionRepository` (wrap fino de
        `FirebaseMessaging.instance.getNotificationSettings()`/`requestPermission()` +
        `openAppSettings()` de `permission_handler`, nueva dependencia — justificada, chica y
        estándar para este caso puntual, misma decisión ya tomada en el plan). Lógica de acción
        pura y testeable aparte (`actionForAuthorizationStatus`, mismo criterio que
        `NotificationTarget.fromPayload`): `notDetermined` → pedido nativo normal, `denied` →
        abre Configuración del sistema, `authorized`/`provisional` → no hace nada.
        `NotificationPermissionNotifier` (`AsyncNotifier`) expone el estado y `handleTap()`/
        `refresh()`; `ProfileScreen` agrega `WidgetsBindingObserver` (mismo patrón que
        `HomeScreen` con `businessHoursProvider`) y reconsulta el estado real en
        `didChangeAppLifecycleState(resumed)`, por si el usuario lo cambió desde Configuración
        sin reiniciar la app. Tests nuevos: `notification_permission_action_test.dart` (lógica
        pura, 4 casos), `notification_permission_provider_test.dart` (repositorio mockeado con
        `mocktail`, cubre los 3 casos de `handleTap()` + `refresh()` + que tras
        `requestPermission()` se vuelve a preguntar el estado real, nunca se asume), y 6 tests
        nuevos en `profile_screen_test.dart` (los 3 estados visuales, los 3 comportamientos de
        tap, y el refresh real al volver de segundo plano vía
        `tester.binding.handleAppLifecycleStateChanged`).
      - ⚠️ **Limitación real de esta ronda, declarada explícitamente**: se implementó en un
        sandbox cloud sin SDK de Flutter instalado y con `pub.dev` bloqueado por el allowlist de
        red de la sesión — **no se pudo correr `flutter analyze` ni `flutter test` en ningún
        momento**, ni para la Parte 1 (verificación por lectura de código) ni para la Parte 2
        (código nuevo). Todo el código fue escrito con máximo cuidado replicando patrones ya
        probados del propio repo (`HomeScreen`/`businessHoursProvider` para el lifecycle
        listener, `NotificationTarget.fromPayload` para la función pura, `mocktail` +
        `ProviderContainer` para los tests de provider, `notification_history_provider_test.dart`
        como referencia directa de estilo), pero **no está verificado por el compilador ni por
        los tests reales todavía**. Pendiente antes de marcar completo: correr `flutter pub get`
        (agrega `permission_handler` de verdad), `flutter analyze`, `flutter test` completo, y
        la configuración nativa de `permission_handler` en Android/iOS (probablemente ninguna
        adicional más allá de agregar la dependencia, pero sin verificar) — y solo entonces
        invocar a `@tester` para el veredicto LISTO y marcar este ítem completo.
      - ✅ **Limitación cerrada por `@tester`**: `flutter pub get` resolvió `permission_handler`
        en `11.4.0` sin conflictos, `flutter analyze` limpio y `flutter test` 377/377 (salida
        cruda propia). Un test tenía un bug propio (mock estático de `getStatus()` que no
        reflejaba el estado tras `requestPermission()`) — corregido en el propio archivo de
        test, sin tocar código de producción. Lógica de decisión (`actionForAuthorizationStatus`)
        verificada exhaustiva y correcta con mutación real en las 3 capas de test.
        `permission_handler` confirmado en uso exclusivo vía `openAppSettings()` (código nativo
        real revisado, no requiere `<queries>`/`Info.plist`). Detalle completo, incluidos 2
        hallazgos no bloqueantes de cobertura de test, en `docs/testing-checklist.md`, sección
        "Gestión del permiso de notificaciones en Perfil". **Veredicto: LISTO** — ítem marcado
        completo.

### 10. Deploy y Calidad
- [x] Pase de auditoría general: estados de carga/error en todas las pantallas, sin datos
      hardcodeados, manejo de "backend dormido" (cold start de Render)
- [x] Build de release (APK firmado para Android como mínimo)
- [x] Verificación end-to-end manual contra el backend real de producción (pedido real, cupón
      real, notificación real) (barrido de las 8 pantallas con fetch inicial —Home, Pedidos,
      Cupones, Perfil, Direcciones, Checkout, Detalle de pedido, Detalle de producto— confirmado
      por grep que todas usan `SlowBackendNotice` conectado a la rama `loading:` real de su
      provider, no solo importado; `cart_screen.dart` confirmado exento correctamente (carrito
      100% local, sin GET al montar). Bug real encontrado en dispositivo físico durante la
      auditoría: el CTA con ícono ("CONFIRMAR PEDIDO POR WHATSAPP") se cortaba con ellipsis a
      15px (el CSS real del mockup) en pantallas reales de 1080px — bajado a 14px + padding
      horizontal 24→16 con ícono, verificado visualmente que ya no se corta; cubierto por
      `test/shared/widgets/celtas_button_test.dart` (fontSize/padding exactos y ausencia de
      overflow real de `RenderFlex`; una aserción de "no se corta con ellipsis" se intentó y se
      descartó por poco confiable, ya que `flutter test` no carga las fuentes reales sin tooling
      adicional). De paso se cerró el riesgo documentado en el módulo 9 ("lógica de
      ruteo/invalidación de notificaciones sin cobertura automatizada"): extraída a
      `NotificationTarget` (sealed class pura) con 5 casos de test — sigue sin cobertura unitaria
      propia el `switch` de `_invalidateFor`/`_navigateFor` en sí, mismo criterio no bloqueante ya
      aceptado. Build de release compilado con debug keystore (decisión de Play Store vs. APK
      directo sigue pendiente, ver siguiente punto). Verificación end-to-end en dispositivo real
      (Xiaomi): pedido real creado con cupón real (`D0E1CA42`, -S/5.00 vía `/coupons/validate`,
      total S/10.50), confirmado por WhatsApp real con el order ID y total correctos, estado
      cambiado a "confirmado" desde el panel admin real, notificación push FCM recibida y
      verificada con `dumpsys notification` (texto y order ID exactos), historial de pedidos
      reflejando el nuevo estado tras pull-to-refresh (invalidación no es automática al volver de
      background — comportamiento documentado, no bug). Logcat completo de la sesión sin
      `FATAL EXCEPTION` ni excepciones de red sin manejar. `flutter analyze` limpio, 197/197
      tests. Auditado por `@tester`: veredicto LISTO. Segundo bug real encontrado en dispositivo
      físico, en una segunda pasada por la app ya instalada: la bottom nav (`CeltasBottomNav`,
      módulo 2) quedaba superpuesta ~111px detrás de la barra de navegación del sistema Android en
      todas las pantallas del shell — el `Container` no envolvía el contenido en `SafeArea`.
      Corregido envolviendo el `Row` de ítems en `SafeArea(top: false)` dentro del `Container` de
      fondo (para que el color/borde siga llegando hasta el borde físico sin dejar un hueco negro,
      mientras los ítems tocables quedan por encima del inset del sistema). Verificado con
      `uiautomator dump` en los dos modos de navegación de Android, cambiando el modo en vivo vía
      `adb shell cmd overlay enable/disable com.android.internal.systemui.navbar.*` y revirtiendo
      al terminar: modo botones (bounds del nav terminan en y=2245, barra de sistema empieza en
      y=2267, margen 22px) y modo gestos (nav termina en y=2333, barra empieza en y=2355, mismo
      margen de 22px) — confirma que el fix usa el inset real que reporta el SO en vez de un valor
      fijo por modo. `flutter analyze` limpio, 197/197 tests sin regresión)
- [x] **Branding real: ícono de app + splash nativo con el logo real** (reemplaza la aproximación
      "CeltasFlame" usada hasta ahora solo en el Splash hecho a mano en Flutter, que sigue
      existiendo tal cual — este ítem es solo el ícono del launcher y el splash NATIVO, dibujado
      por el sistema operativo antes de que Flutter tome control).

      **`assets/branding/` es la carpeta fuente fija del logo** — 3 archivos, siempre con estos
      nombres exactos:
      - `logo_completo.jpg` (1000×1000, fondo negro/fuego, opaco) — ícono legacy Android <8 e iOS
        (ninguno soporta transparencia real en el ícono de la app).
      - `logo_sin_banner_transparente.png` (2992×2073, fondo transparente, sin el texto
        "Burger-Chicken" — ilegible a tamaño de ícono/splash) — adaptive icon foreground
        (Android 8+) y splash nativo (pre-Android 12).
      - `logo_con_banner_transparente.png` (2991×2072, fondo transparente, versión completa con
        el texto del banner) — copiado por si se necesita a futuro, no usado en la config actual.

      **Procedimiento para actualizar el logo en el futuro**: reemplazar esos 3 archivos en
      `assets/branding/` (mismos nombres exactos) → correr `dart run flutter_launcher_icons` y
      `dart run flutter_native_splash:create` → recompilar. Si se reemplaza
      `logo_sin_banner_transparente.png`, hay que regenerar también
      `assets/branding/logo_sin_banner_android12_splash.png` (ver bug de abajo) antes de correr
      `flutter_native_splash:create` — no es automático.

      Config completa en `pubspec.yaml` (`flutter_launcher_icons:` / `flutter_native_splash:`),
      con comentario inline explicando por qué esos archivos NO están en `flutter.assets` (los
      generadores leen la ruta directo del `pubspec.yaml`, no del bundle de la app — agregarlos
      ahí solo infla el APK sin necesidad).

      **Bug real encontrado y corregido en dispositivo (Xiaomi, HyperOS)**: el splash nativo de
      Android 12+ usa la `SplashScreen` API del sistema, que trata el ícono como un adaptive icon
      y recorta cualquier contenido fuera de una "zona segura" central (~55-66% del ancho) — el
      logo original casi no tiene margen (el texto toca los bordes), así que el sistema le
      cortaba la "C" inicial y la "S" final (confirmado visualmente: solo se veía "ELTA"), aunque
      el PNG generado en `drawable-xxxhdpi/android12splash.png` sí contenía el logo completo sin
      recortar — el recorte pasa en tiempo de ejecución por la máscara del sistema, no por el
      asset. Fix: se generó `assets/branding/logo_sin_banner_android12_splash.png` (mismo logo
      centrado en un canvas cuadrado transparente, ocupando ~48% del ancho) específicamente para
      `flutter_native_splash.android_12.image`, dejando el `image:` base (splash pre-Android 12,
      que usa `android:gravity="center"` por densidad y no tiene este problema) con el archivo
      original sin relleno. Verificado en dispositivo tras el fix: el splash de Android 12+ ya
      muestra el logo completo sin recortes. El ícono adaptativo del launcher (mismo archivo sin
      relleno) NO tuvo este problema porque `flutter_launcher_icons` inserta automáticamente un
      `<inset android:inset="16%"/>` en el XML del adaptive icon — confirmado en
      `mipmap-anydpi-v26/launcher_icon.xml` — mientras que `flutter_native_splash` no aplica
      ningún inset al `android_12.image`, por eso ahí sí hacía falta el relleno manual. Riesgo
      menor documentado (no bloqueante): el 16% de inset automático deja visible ~68% del canvas,
      un poco más ancho que el ~61-66% de "zona segura" garantizada oficialmente para máscaras
      circulares agresivas — en teoría algunos launchers (Samsung One UI, terceros) podrían
      recortar por un margen pequeño las puntas de las hachas o los bordes de "C"/"S"; no
      verificable sin esos dispositivos a mano.

      **Segundo bug real encontrado (por `@tester`, preexistente, no introducido por este
      cambio) y corregido**: el ícono de las notificaciones push FCM seguía siendo el ala azul
      default de Flutter (`AndroidManifest.xml`, meta-data
      `com.google.firebase.messaging.default_notification_icon` apuntaba a `@mipmap/ic_launcher`,
      que `flutter_launcher_icons` nunca tocó porque el ícono del launcher se configuró con el
      nombre `launcher_icon`, no el nombre default `ic_launcher`). Fix: se generó un ícono
      monocromático (silueta blanca sobre transparente, requisito de Android API 21+ para íconos
      pequeños de notificación — un ícono a color se vería como un blob blanco sólido) a partir
      del canal alfa de `logo_sin_banner_transparente.png`, en los 5 tamaños estándar
      (`android/app/src/main/res/drawable-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/ic_stat_celtas.png`).
      Actualizados los dos lugares que referenciaban `@mipmap/ic_launcher` para notificaciones:
      el meta-data de FCM en el manifest, y `AndroidInitializationSettings` en
      `notification_service.dart` (gobierna el ícono cuando la app muestra la notificación a mano
      en foreground). Es el logo completo convertido a silueta (no un mark simplificado dedicado,
      no existe ese asset todavía) — legible en inspección visual a 96px compuesto sobre negro,
      pero con más detalle del ideal para el tamaño real de 24dp en la barra de estado; validado
      solo de forma indirecta (build compila referenciando el recurso + inspección visual del
      PNG) — no se disparó una notificación push real de punta a punta para no mutar datos de
      producción sin pedido explícito para este fix puntual (a diferencia del módulo 9, que sí
      probó con un cupón/pedido real). Queda como mejora futura opcional: un mark simplificado
      dedicado para este ícono si en el uso real se ve poco legible en la barra de estado.

      `flutter analyze` limpio, tests sin regresión en ambas rondas. Auditado por `@tester` en dos
      pasadas (ícono/splash primero, fix del ícono FCM después) — detalle completo en
      `docs/testing-checklist.md`, sección "Branding / Íconos y Splash nativos".

      **Actualización posterior (ronda de rebranding con assets nuevos)**: los 3 archivos
      descritos arriba (`logo_completo.jpg`, `logo_sin_banner_transparente.png`,
      `logo_con_banner_transparente.png`) ya no existen — se reemplazaron por un set nuevo con
      otros nombres (`logomarcaios.png`, `logobackground.png`,
      `logomarcalienzotransparente.png` para el ícono del launcher; `logo1024splash.png` para el
      splash). El **mismo bug de clase del recorte en Android 12+ reapareció** con el asset
      nuevo: la sección `android_12.image` de `pubspec.yaml` quedó apuntando al PNG base sin
      relleno (el comentario describía la solución correcta — imagen separada con ~48% de
      relleno — pero la clave `image:` nunca se actualizó a un archivo distinto). Refix: se
      generó `assets/branding/logo1024splash_android12.png` (canvas cuadrado 1024×1024, logo
      centrado al ~48% del ancho, relleno transparente) y se apuntó `android_12.image` ahí.
      Verificado en dispositivo real (Xiaomi, HyperOS, Android 15/API 35): splash sin recorte.

      **`CeltasFlame` (el `CustomPainter` a mano) fue eliminado** — reemplazado por el SVG real
      de marca (`assets/branding/iconos.svg`, agregado a `flutter.assets`) vía el paquete
      `flutter_svg` (`SvgPicture.asset` + `colorFilter: ColorFilter.mode(color, BlendMode.srcIn)`
      para tintar el path de un solo color con el color sólido de cada contexto). Los 2 usos:
      Splash (`splash_screen.dart`, dorado `CeltasColors.gold`, 88px) y Login
      (`login_screen.dart`, naranja `CeltasColors.orange`, 24px), verificados visualmente en el
      mismo dispositivo real. El widget `lib/shared/widgets/celtas_flame.dart` se borró; el
      parser SVG casero (`lib/shared/widgets/svg_path.dart`) **no se tocó** — sigue siendo
      necesario para `SvgStrokeIcon`, `google_logo.dart` y `checkout_screen.dart`. Ícono del
      launcher explícitamente NO tocado en esta ronda (ya reemplazado manualmente antes,
      confirmado por timestamps de archivo). `flutter analyze` limpio, tests sin regresión (283
      tras esta ronda, incluye un test nuevo de regresión para el asset del ícono). Auditado por
      `@tester`: veredicto LISTO.
- [x] **Fix transversal: voseo rioplatense → tuteo (español de Perú) en todo `lib/`.** Barrido
      completo de `lib/` (regex sobre verbos conjugados en `-ás/-és/-ís` dentro de strings, más
      grep de `vos`/`sos`) encontró 27 strings de cara al usuario con voseo rioplatense
      ("ingresá", "elegí", "tenés", "verificá", "volvé", "unite", "pedí", "continuá") en 12
      pantallas/servicios (login, registro, perfil, carrito, checkout, detalle de producto,
      cupones, direcciones, notificaciones, home) — quedó de una etapa temprana en la que se
      copió tono de mockups/copys en español rioplatense, incorrecto para el mercado real (Lima,
      Perú). Corregido a tuteo neutro ("ingresa", "elige", "tienes", "verifica", "vuelve",
      "únete", "pide", "continúa") sin cambiar significado ni tono. Los 6 tests de widget que
      buscaban esos strings exactos (`find.text(...)`) se actualizaron en el mismo cambio, más 3
      fixtures de notificación con el mismo texto (`app_router_test.dart`,
      `notifications_screen_test.dart`) aunque no dependían directamente del string de
      producción. 399/399 tests, `flutter analyze` limpio. Regla nueva agregada a
      `.claude/skills/flutter-celtas/SKILL.md` ("Español de Perú, tuteo — NUNCA voseo") para que
      no se repita en texto nuevo.
- [ ] Definir distribución: Google Play (pago único ~$25) vs. APK directo mientras se valida

---

## Cómo trabajar con OpenCode

1. Abre el repo y ejecuta `opencode` en la raíz.
2. Usa el agente **`celtas-mobile`** (Tab para cambiar de agente si es necesario).
3. Antes de construir cualquier pantalla, confirma el contrato real de la API (Swagger o código
   fuente del backend) y el diseño exacto en `design-reference/` — no asumir ninguno de los dos.
4. Al terminar cada módulo, invoca a **`@tester`** para auditar (`flutter analyze`, `flutter
   test`, checklist de `docs/testing-checklist.md`). Solo se marca un módulo como completo
   cuando `@tester` da veredicto **LISTO**.
5. La skill `flutter-celtas` se carga automáticamente — ahí están las convenciones del proyecto.
6. Para módulos sensibles (Auth, manejo de tokens), pide evidencia cruda (código real, no
   resúmenes) antes de dar el visto bueno — mismo criterio que ya aplicamos en el panel admin.
