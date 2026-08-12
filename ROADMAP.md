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
