# Integración con backend-celtas

Contraste realizado con `../backend-celtas` durante la auditoría del
2026-10-05. Describe el código LOCAL inspeccionado; no confirma qué revisión
ni valores están desplegados en producción. Admin es referencia secundaria.

## Configuración y envelopes

AppConfig lee API_BASE_URL desde dotenv; fallback:
`https://backend-celtas.onrender.com`. No hay flavors ni selector formal
de entorno. main carga .env antes; el fallback no rescata la ausencia del archivo.
El cliente embebe .env, por lo que no protege secretos.

TransformInterceptor backend produce `{ success: true, data }`; respeta
respuestas ya envueltas. ApiClient devuelve data a repositorios.
HttpExceptionFilter normaliza `{ success: false, message, statusCode }`,
con message string, incluyendo validaciones. ApiException conserva mensaje
y estado HTTP; fallos de parseo requieren manejo adicional.

## Contratos consumidos

| Área | Superficie Mobile |
|---|---|
| Auth | POST /auth/login, /register, /google, /refresh |
| Catálogo | GET /menu y /banners/active |
| Cuenta | GET/PATCH /users/me; CRUD /users/me/addresses |
| Compra | POST /orders; POST /orders/estimate-delivery-fee |
| Historial | GET /orders/me y /orders/:id |
| Cupones | GET /coupons/me; POST /coupons/validate |
| Estrellas | GET /rewards/progress; /rewards/catalog con especial=true cuando aplica |
| Settings | GET /settings/business-hours y /settings/public |
| FCM | PATCH/DELETE /users/me/fcm-token |

Menú devuelve categorías activas/productos disponibles y opciones con
required/max/allowWithout. Banners activos se filtran en servidor;
acciones category/menuItem utilizan IDs reales, no slugs.
Modelos Dart son proyecciones: campos ignorados no desaparecen del servidor.

## Auth y refresh

Login/registro/Google/refresh devuelven accessToken, refreshToken y user.
Google recibe idToken real; el cliente no envía password en ese flujo.
ApiClient adjunta Bearer, intenta refresh una vez y libera su cola con el
token nuevo. Errores transitorios conservan sesión; 401 definitivo la limpia.

El backend firma un nuevo refresh JWT, pero no invalida el anterior mediante
almacenamiento/revocación ni dispone aquí de logout que los revoque.
“Rotación” significa reemplazo local del token recibido, no protección
confirmada contra reutilización del anterior. No modificar este contrato
sin una tarea específica en el servidor.

## Pedido, direcciones y delivery

POST /orders manda items con menuItemId/quantity y, según selección,
sauceIds, beverageIds, extraPortionIds, friesTypeIds, comment y
rewardRedemptionId; couponCode es opcional. No manda total ni unitPrice.
Backend valida catálogo/grupos, calcula importes y guarda snapshots.

OrderRepository tiene assert de exclusividad addressId/addressSnapshot.
La UI actual utiliza addressId; guarda una dirección si hace falta.
addressSnapshot es JSON string, no objeto. Backend local prioriza addressId
si llegan ambas alternativas; no está comprobado el rechazo que describía
la documentación antigua. Sin ninguna, rechaza el pedido.

Direcciones admiten coordenadas nullable en backend; formularios Mobile
exigen coordenadas para guardar nuevas/editar. PATCH se vuelve a consultar
para direcciones; perfil sí utiliza su respuesta para actualizar estado.
El backend actual utiliza merge para evitar sobrescritura por undefined.

La estimación de delivery recibe addressId y devuelve deliveryFee,
isFarOrder y distanceMeters. Mobile solo consume la tarifa. El servidor
aplica distancia/configuración; sin coordenadas utiliza tarifa cero sin
bloquear. Este fallback no autoriza a eliminar el guard de formularios.

## Cupones, estrellas y settings

Validar cupón no lo consume. Backend lo bloquea, valida mínimo/propiedad/
vigencia y lo canjea en la transacción del pedido; usado/expirado puede producir
400. No interpretar genéricamente todo conflicto como una única causa.

Rewards devuelve estrellasDelMes, hitos, premiosDisponibles y promocionActiva.
premiosDisponibles incluye estado pending/redeemed y usedAt; el nombre
histórico no significa exclusivamente “canjeable”.
Catálogos normal/especial son separados. Canje ocurre en POST /orders.

**GET /rewards/progress puede escribir:** recalcula progreso y concede premios
en backend. No tratar cualquier GET como una inspección libre de efectos.

Settings public expone whitelist de strings, incluida min_app_version;
business-hours devuelve apertura y próximo cambio. No reconstruir el estado
a partir del texto de una notificación. Reglas: [negocio](business-rules.md);
gate de versión: [release](release-versioning.md).

## FCM y divergencias actuales

PATCH fcm-token guarda un token por usuario; DELETE lo deja null.
No elimina asociaciones de ese token en otras cuentas. Logout Mobile hace
DELETE best-effort antes de limpiar sesión, sin garantizar éxito.
Payloads reconocidos: orderId/status, couponCode, businessHoursChanged o link.
Broadcast sin claves reconocidas no se conserva en el historial Mobile.

Divergencias comprobadas por código/configuración:

- GET /orders/me usa límite backend default 20, máximo 100; Mobile no lo pide
  ni dispone de paginación. La respuesta sigue siendo array.
- OrderItem Mobile no modela snapshots de opciones/comentario; Order no modela
  desglose de delivery/descuento. El detalle muestra una proyección reducida.
- Order.address decodifica JSON con campos obligatorios; datos históricos
  mal formados pueden fallar aunque el pedido exista.
- Exclusividad de direcciones y “rotación revocable” no son garantías backend.
- Estado de despliegue, stores y valores actuales remotos no fue verificado.

Para cambios de contratos compara DTOs, servicios, entidades, interceptores
y tests reales; no basta un tipo de Admin o ejemplo Swagger. Pendientes:
[roadmap](../ROADMAP.md).
