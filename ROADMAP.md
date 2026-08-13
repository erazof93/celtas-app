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
