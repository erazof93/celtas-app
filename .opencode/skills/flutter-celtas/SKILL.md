---
name: flutter-celtas
description: Convenciones y patrones específicos de la app Flutter de Celtas (manejo de auth con Riverpod + flutter_secure_storage, cliente dio con refresh automático, paleta de colores, diseño de referencia, reglas de negocio del checkout sin pago). Usar siempre que se cree o modifique un widget, provider, modelo o llamada a la API.
license: MIT
metadata:
  project: celtas-mobile
  audience: opencode-agent
---

## Cuándo usar esta skill

Cargar esta skill antes de crear o modificar cualquier widget, provider de Riverpod, modelo, o
llamada a la API dentro de `lib/`. Contiene las decisiones de diseño ya tomadas para este
proyecto.

## Fuentes de verdad (en este orden)

1. **Contrato de API**: `../celtas-admin/src/types/api.d.ts` (ya generado y verificado) o
   `https://backend-celtas.onrender.com/docs-json`.
2. **Diseño visual**: `design-reference/` (export real de Claude Design, HTML/CSS con valores
   exactos) — nunca aproximar colores/tipografía/espaciados a ojo.

Nunca escribas un modelo Dart ni un valor de estilo sin haber confirmado contra una de estas dos
fuentes primero.

## Paleta de colores (Dart)

```dart
class CeltasColors {
  static const black = Color(0xFF0D0D0D);
  static const orange = Color(0xFFE8590C);
  static const red = Color(0xFFC1121F);       // solo iconos/acentos, NUNCA texto
  static const redLight = Color(0xFFF87171);  // texto de error/estados
  static const gold = Color(0xFFFFB800);
  static const cream = Color(0xFFF5F1E8);
}
```

Definidos una sola vez en `lib/core/config/theme.dart`, nunca como `Color(0xFF...)` suelto
dentro de un widget.

### Badges de estado de pedido — separación cromática deliberada

El mockup usa una escala cálida (dorado→naranja→rojo) para los 5 estados, y `en_camino` se
confunde visualmente con `cancelado`. Al implementar, usar esta asignación con más contraste
entre sí:

```dart
Color statusColor(OrderStatus status) => switch (status) {
  OrderStatus.pendiente => CeltasColors.gold,
  OrderStatus.confirmado => CeltasColors.orange,
  OrderStatus.enCamino => Colors.blueAccent,       // fuera de la paleta cálida a propósito
  OrderStatus.entregado => Colors.greenAccent,     // fuera de la paleta cálida a propósito
  OrderStatus.cancelado => CeltasColors.redLight,  // el único que usa rojo
};
```

## Auth (Riverpod + flutter_secure_storage)

- `accessToken`: **solo en memoria**, dentro del estado de un `Notifier`/`StateNotifier` de
  Riverpod — se pierde al cerrar la app a propósito, se recupera con el refresh al abrir.
- `refreshToken`: **en `flutter_secure_storage`** (nunca `SharedPreferences` — es un dispositivo
  de cliente final, no un panel interno; el trade-off de `localStorage` que aceptamos en
  `celtas-admin` NO aplica acá).
- El login con Google nunca envía `password` — el backend lo recibe vía `POST /auth/google` con
  el `idToken` real obtenido de `google_sign_in`.

## Cliente `dio` (`lib/core/network/api_client.dart`)

Mismo patrón que ya implementamos y verificamos en `celtas-admin/src/lib/api-client.ts` —
revisar ese archivo como referencia de la lógica exacta (interceptor de request adjunta el
token, interceptor de error intenta refresh una sola vez en 401, cola de requests pendientes
durante el refresh, nunca reintenta en loop, excluye `/auth/login` y `/auth/refresh` del ciclo
de retry).

## El `id` nunca viaja en el body de un PATCH/PUT

Mismo bug de clase que se encontró y barrió en `celtas-admin` (dos veces: Banners y luego Menú).
Antes de escribir cualquier request de actualización, confirmar contra el DTO real si el `id`
va en el path únicamente (el caso normal) o si el backend lo espera también en el body
(inusual, pero verificar, no asumir).

## Checkout — regla de negocio no negociable

- La app **nunca** calcula ni envía el total del pedido — lo calcula el backend a partir de
  `items` (menuItemId + quantity). Enviar un total desde el cliente sería ignorado o rechazado,
  y además es la superficie de fraude más obvia si se llegara a usar.
- La app **nunca** implementa ni sugiere un flujo de pago procesado internamente. El backend
  devuelve `whatsappUrl` ya armado en la respuesta de `POST /orders`; la app solo lo abre con
  `url_launcher` (`canLaunchUrl` antes de `launchUrl`, y manejar el caso de que WhatsApp no esté
  instalado con un mensaje claro, no un crash silencioso).

## Manejo de "el backend puede estar dormido"

Render pone a dormir el servicio free tier tras inactividad — la primera request tras un rato
puede tardar 30-50 segundos. Todo estado de carga que dependa de una request a la API debe
comunicar esto tras ~5 segundos (mismo criterio que en `celtas-admin`), no un spinner indefinido
sin contexto.

## Variables de entorno

- `API_BASE_URL` vía `flutter_dotenv`, nunca hardcodeada en un widget o servicio.
- Para desarrollo contra el backend local desde el emulador Android: usar `http://10.0.2.2:3000`,
  NO `http://localhost:3000` (el emulador tiene su propia red virtual, `localhost` apunta al
  propio emulador, no a tu máquina host).
