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

- [ ] Rutas protegidas redirigen a Login sin sesión
- [ ] Bottom nav funciona y refleja la pantalla activa

## Home / Menú

- [x] Banners respetan vigencia (ya calculada por el backend)
- [x] Menú agrupado por categoría, con imágenes cacheadas correctamente
- [x] Error de banners visible con reintento (no tragado en silencio)
- [x] Pull-to-refresh sin excepción async sin manejar

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
