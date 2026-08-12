---
name: flutter-celtas
description: Convenciones y patrones específicos de la app Flutter de Celtas (manejo de auth con Riverpod + flutter_secure_storage, cliente dio con refresh automático, paleta de colores, diseño de referencia, reglas de negocio del checkout sin pago). Usar siempre que se cree o modifique un widget, provider, modelo o llamada a la API.
license: MIT
metadata:
  project: celtas-mobile
  audience: claude-code
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

### Badges de estado de pedido — separación cromática deliberada (resuelto en el módulo 7)

El mockup original (pantalla 10 · Historial de pedidos) usaba el MISMO color naranja para
`confirmado` (relleno) y `en_camino` (contorno) — distinguibles solo por relleno vs. contorno —
y `en_camino`/`cancelado` compartían el estilo de contorno con colores cálidos vecinos (naranja
vs. rojo claro), difícil de distinguir de un vistazo y peor para daltonismo rojo-verde
(protanopia/deuteranopia confunden naranja y rojo). `pendiente` (dorado relleno) y `entregado`
(crema relleno) ya eran distinguibles en el mockup original y se mantuvieron igual.

Paleta final implementada (`OrderStatusBadge`, `lib/features/orders/presentation/widgets/
order_status_badge.dart`):

```dart
OrderStatus.pendiente  => fondo CeltasColors.gold,   texto negro   // igual al mockup
OrderStatus.confirmado => fondo CeltasColors.orange, texto crema   // igual al mockup
OrderStatus.enCamino   => fondo CeltasColors.statusEnCamino (#3B7DDE, azul), texto crema
                           // ÚNICO color fuera de la paleta cálida, a propósito: ya no
                           // comparte hue con `confirmado` ni con `cancelado`
OrderStatus.entregado  => fondo CeltasColors.cream,  texto negro   // igual al mockup
OrderStatus.cancelado  => contorno CeltasColors.redLight (sin relleno), texto redLight
                           // el ÚNICO estado que usa rojo, y el único con contorno en vez
                           // de relleno (refuerza que es el estado "negativo")
```

`CeltasColors.statusEnCamino` es la única constante de color del proyecto definida fuera de la
paleta de marca — documentada con esa justificación directamente en `app_theme.dart`.

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

## Nunca depender de la respuesta de un PATCH — invalidar y re-fetchear

Bug real encontrado en el módulo 6 (`updateAddress`): el backend puede devolver una entidad
parcial/incompleta en la respuesta de un `PATCH` (bug de backend ya corregido, pero el patrón
correcto del cliente no debería depender de eso ni aunque el backend esté perfecto). Regla del
proyecto: después de una mutación (`PATCH`/`PUT`/`DELETE`), **invalida el provider/query
correspondiente y vuelve a pedir la lista completa con `GET`** — nunca parsees ni uses
directamente el body de la respuesta de la mutación para actualizar el estado local, salvo un
caso ya documentado y con manejo explícito (ver `lib/features/orders/merge.ts` — ahí SÍ se lee
la respuesta de un `PATCH` a propósito, porque el backend no recarga la relación `items`, y el
merge selectivo está intencionalmente diseñado y testeado para ese caso puntual).
`celtas-admin` ya sigue este patrón consistentemente (invalidate + refetch) en sus hooks de
React Query — es el mismo patrón que hay que replicar acá con los providers de Riverpod.

## Parser SVG propio (`lib/shared/widgets/svg_path.dart`) — verificar siempre en dispositivo real

Este archivo ya causó 2 bugs de clase reales: el crash del Splash por comandos SVG no
soportados (módulo 1) y, en una sesión posterior, un desfase geométrico en los comandos suaves
`S`/`s`/`T`/`t` que mezclaba coordenadas absolutas y relativas (afectó 5 íconos a la vez: pin y
campana del Home, campana de perfil, WhatsApp del checkout, y el ícono "Perfil" del bottom nav).
Que compile y que los tests unitarios del parser pasen **no fue suficiente** para atrapar ese
segundo bug — hacía falta comparar bounds/renderizado real.

Cualquier cambio a este archivo, o cualquier ícono SVG custom nuevo que se agregue con él, debe
verificarse **visualmente en dispositivo real** antes de darse por bueno.

## Checkout — regla de negocio no negociable

- La app **nunca** calcula ni envía el total del pedido — lo calcula el backend a partir de
  `items` (menuItemId + quantity). Enviar un total desde el cliente sería ignorado o rechazado,
  y además es la superficie de fraude más obvia si se llegara a usar.
- La app **nunca** implementa ni sugiere un flujo de pago procesado internamente. El backend
  devuelve `whatsappUrl` ya armado en la respuesta de `POST /orders`; la app solo lo abre con
  `url_launcher`.
- **No uses `canLaunchUrl` antes de `launchUrl` para `wa.me`** — se confirmó en el módulo 5 que
  su resolución es ambigua/poco confiable específicamente para ese dominio (falsos negativos
  entre WhatsApp y el navegador). Llama `launchUrl` directo y trata `false`/`PlatformException`
  como la señal real de fallo (WhatsApp no instalado u otro problema), mostrando un mensaje
  claro — nunca un crash silencioso.

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
