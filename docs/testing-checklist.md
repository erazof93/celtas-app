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
- [ ] Un 401 dispara el refresh una sola vez, no un loop
- [ ] Si el refresh falla con 401 definitivo, limpia sesión y redirige a Login; errores
      transitorios (red, 5xx) NO limpian la sesión
- [ ] Persistencia de sesión al reabrir la app funciona (recupera accessToken vía refresh)

## Navegación

- [ ] Rutas protegidas redirigen a Login sin sesión
- [ ] Bottom nav funciona y refleja la pantalla activa

## Home / Menú

- [ ] Banners respetan vigencia (ya calculada por el backend)
- [ ] Menú agrupado por categoría, con imágenes cacheadas correctamente

## Carrito / Checkout

- [ ] El total lo calcula el backend, la app nunca lo envía ni lo asume
- [ ] Ningún flujo de pago procesado dentro de la app en ningún punto
- [ ] `whatsappUrl` se abre correctamente; caso de WhatsApp no instalado manejado con mensaje
      claro, no crash
- [ ] Carrito se limpia tras confirmar pedido exitosamente
- [ ] Validación de cupón (`/coupons/validate`) no lo marca como usado antes de confirmar

## Perfil / Direcciones

- [ ] DTO de edición de perfil no permite cambiar campos que el backend no acepta
- [ ] CRUD de direcciones con verificación de que pertenecen al usuario (aunque esto lo
      garantiza el backend, confirmar que la UI no intente operar sobre IDs ajenos)

## Pedidos / Cupones

- [ ] Badges de estado de pedido visualmente distinguibles entre sí (los 5 estados)
- [ ] Paginación de historial funciona
- [ ] Cupones muestran estado (activo/usado/expirado) correctamente

## Notificaciones

- [ ] Token de FCM se registra tras login (`PATCH /users/me/fcm-token`)
- [ ] Falla de registro de token no rompe el flujo de login

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
