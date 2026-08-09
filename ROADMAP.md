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

### 0. Setup inicial
- [ ] `flutter create celtas_mobile --org com.celtas --platforms=android,ios`
- [ ] Copiar el export de Claude Design a `design-reference/`
- [ ] Dependencias en `pubspec.yaml`: `flutter_riverpod`, `dio`, `go_router`, `freezed_annotation`,
      `json_annotation` (+ `build_runner`, `freezed`, `json_serializable` como dev deps),
      `flutter_secure_storage`, `google_sign_in`, `firebase_core`, `firebase_messaging`,
      `flutter_local_notifications`, `cached_network_image`, `url_launcher`, `flutter_dotenv`,
      `mocktail` (dev)
- [ ] `.env`/`.env.example` con `API_BASE_URL=https://backend-celtas.onrender.com` (y nota de
      cómo apuntar al backend local para desarrollo)
- [ ] Tema visual (`app_theme.dart`) con la paleta exacta, tipografía de `design-reference/`
- [ ] `api_client.dart`: instancia de `dio` con interceptores (estructura base, se completa en
      el módulo 1)
- [ ] Estructura de carpetas completa según el diagrama
- [ ] `flutter analyze` y `flutter run` limpios (en un emulador o dispositivo)

### 1. Auth
- [x] Prerrequisito: Client ID de Google creado en Google Cloud (proyecto `celtas-b0bd5`).
      El Client ID "Web application" (`614499893538-sn5adeq44eog889k15c7s3pmqosapen6...`)
      vive en `.env` como `GOOGLE_SERVER_CLIENT_ID` y se pasa a
      `GoogleSignIn.initialize(serverClientId:)`. El de tipo Android se vincula por
      package name + SHA-1 en Google Cloud (NO requiere `google-services.json`:
      verificado en dispositivo real Xiaomi — el picker, el consentimiento y el
      `POST /auth/google` funcionaron sin ese archivo; el README de
      `google_sign_in_android` documenta `serverClientId` como alternativa a
      google-services.json).
- [x] Verificación en dispositivo real (Xiaomi 24117RN76L, debug SHA-1
      `27:4B:79:B2:5B:7E:5E:C5:D4:6A:3A:1C:CD:9C:3B:2D:0F:EE:F6:5C`): login con Google
      completo (picker → consentimiento → idToken → sesión persistida → `/home`).
      Bugs reales encontrados y corregidos: `main.dart` sin `ProviderScope` (crash
      "No ProviderScope found") y `routerProvider` recreando el `GoRouter` en cada
      cambio de auth (la app saltaba al Splash tras login/logout; ahora usa
      `ref.listen` + `router.refresh()`).
- [x] Modelos (`freezed`): `User`, `AuthTokens` — confirmar contrato real contra el backend
- [x] `AuthRepository`: login, registro, login con Google (`google_sign_in` 7.x:
      `initialize()` + `authenticate()` → `idToken` → `POST /auth/google`; cancelación del
      picker → `GoogleSignInCanceledException` que la UI ignora; 409 → `ApiException` con el
      mensaje del backend), refresh
- [x] Provider de Riverpod: `accessToken` en memoria, `user` actual
- [x] `flutter_secure_storage` para el `refreshToken`
- [x] Interceptor de `dio` completo: agrega el token, maneja 401 con refresh-once (mismo patrón
      verificado a fondo en el panel admin, incluida la cola de requests pendientes)
- [x] Pantallas: Splash (con bootstrap de sesión), Login, Registro — según `design-reference/`
- [x] Persistencia de sesión al reabrir la app

### 2. Navegación base
- [ ] `go_router` con shell route: bottom nav bar (Inicio, Pedidos, Cupones, Perfil)
- [ ] Guard de rutas: pantallas protegidas requieren sesión
- [ ] Tema aplicado consistente en toda la navegación

### 3. Home
- [ ] Consume `GET /banners/active` — carrusel de banners
- [ ] Consume `GET /menu` — categorías + productos, con botón rápido de "+" para agregar al
      carrito sin entrar al detalle
- [ ] Imágenes vía `cached_network_image`

### 4. Producto + Carrito
- [ ] Pantalla de detalle de producto (selector de cantidad, agregar al carrito)
- [ ] Estado del carrito 100% local (Riverpod `StateNotifier` o `Notifier`)
- [ ] Pantalla de carrito: editar cantidades, aplicar cupón (`POST /coupons/validate` antes de
      confirmar, no solo al final)

### 5. Checkout
- [ ] Selector de dirección guardada (o agregar nueva)
- [ ] Resumen del pedido con descuento aplicado
- [ ] `POST /orders` con `items` + `addressId`/`addressSnapshot` + `couponCode` opcional
- [ ] Al recibir la respuesta, abrir el `whatsappUrl` con `url_launcher`
- [ ] Limpiar el carrito local tras confirmar

### 6. Perfil + Direcciones
- [ ] Ver/editar perfil (`GET`/`PATCH /users/me`)
- [ ] CRUD de direcciones (`GET/POST/PATCH/DELETE /users/me/addresses`)
- [ ] Logout

### 7. Historial de pedidos
- [ ] Listado (`GET /orders/me`), badges de estado con la paleta ajustada (ver nota de diseño)
- [ ] Detalle de pedido (items, dirección, estado, total)

### 8. Mis cupones
- [ ] Listado (`GET /coupons/me`), distinción visual clara entre activo/usado/expirado

### 9. Notificaciones push
- [ ] Configurar Firebase en la app (archivos de configuración del proyecto ya existente)
- [ ] Registrar el `fcmToken` del dispositivo (`PATCH /users/me/fcm-token`) tras login
- [ ] Manejo de notificaciones en foreground/background/terminated
- [ ] Probar recibiendo una notificación real (cupón generado o cambio de estado de pedido)

### 10. Deploy y Calidad
- [ ] Pase de auditoría general: estados de carga/error en todas las pantallas, sin datos
      hardcodeados, manejo de "backend dormido" (cold start de Render)
- [ ] Build de release (APK firmado para Android como mínimo)
- [ ] Verificación end-to-end manual contra el backend real de producción (pedido real, cupón
      real, notificación real)
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
