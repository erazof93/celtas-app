---
name: geoapify-direcciones
description: Convenciones para integrar Geoapify (Address Autocomplete, Geocoding, Reverse Geocoding, Map Tiles) en el formulario de direcciones de la app Flutter de Celtas — decisión de proveedor ya tomada, flujo de UX acordado, manejo del rate limit, y qué paquetes usar (y cuáles evitar). Usar siempre que se cree o modifique el formulario de direcciones, el selector de ubicación por GPS, o cualquier widget de mapa.
license: MIT
metadata:
  project: celtas-mobile
  audience: claude-code
---

## Por qué Geoapify (contexto de la decisión — no reabrirla sin evidencia nueva)

Evaluado contra Google Maps Platform, Mapbox, LocationIQ y Nominatim en una sesión de Cowork
(2026-08-20), con las páginas de precios oficiales verificadas en el momento, no de memoria.
Elegido por: gratis de verdad, sin pedir tarjeta de crédito en ningún paso del registro (a
diferencia de Mapbox y de Google Maps Platform, que sí la piden aunque el uso se mantenga en el
nivel gratuito); plan gratis de 3.000 créditos/día (~90.000/mes) que cubre Autocomplete +
Geocoding + Reverse Geocoding + Map Tiles bajo una sola cuenta/API key; y basado en datos
abiertos (OpenStreetMap + OpenAddresses + GeoNames) — misma calidad de datos base que LocationIQ,
pero resolviendo las 4 piezas necesarias con un solo proveedor en vez de combinar varios.

Si en algún momento hace falta reconsiderar esta decisión, verificar primero contra la
documentación oficial vigente de cada proveedor — los precios y límites de estos servicios
cambian con cierta frecuencia, no asumas que las cifras de este doc siguen siendo exactas sin
chequear.

## APIs de Geoapify que usa este proyecto (y las que NO)

- **Address Autocomplete API**: sugerencias de direcciones reales mientras el usuario escribe.
- **Geocoding API**: texto → lat/lng (fallback si el usuario no usó el autocompletado, ej. pegó
  una dirección completa de una vez).
- **Reverse Geocoding API**: lat/lng → texto, para autocompletar `fullAddress`/`district` en
  cuanto el usuario suelta el pin en el mapa (por selección de sugerencia o por drag manual).
- **Map Tiles**: para renderizar el mapa visual con `flutter_map`.
- **Routing API / Isoline API**: NO se usan en este proyecto — no hay funcionalidad de rutas ni
  de zonas de cobertura por tiempo/distancia planeada. Si aparecen como opción en el dashboard
  de Geoapify al generar código de ejemplo, ignoralas.

## Flujo de UX ya acordado — no improvisar uno distinto

Tres formas de que el pin llegue a un punto de partida, todas convergiendo en el mismo paso
final de confirmación manual:

1. **Autocompletado de texto** (Address Autocomplete) mientras el usuario escribe — funciona
   bien para direcciones con nombre de calle/avenida.
2. **Botón "Usar mi ubicación actual"** (GPS, vía `geolocator`) — centra el pin en la posición
   real del dispositivo. Es la opción más confiable para direcciones tipo Mz/Lt (muy comunes en
   San Juan de Miraflores, urbanizaciones/AAHH sin nomenclatura postal estándar), porque el
   geocoding por texto es poco confiable ahí en CUALQUIER proveedor — Google incluido, ya
   confirmado probando direcciones reales antes de tomar esta decisión. No es un problema que un
   mejor proveedor de mapas resuelva solo.
3. **Mapa siempre visible con pin arrastrable** — sea cual sea el punto de partida (1 o 2), el
   usuario SIEMPRE puede corregir el pin a mano antes de guardar. Este paso es el que garantiza
   precisión real; los otros dos son solo atajos para no tener que ubicarse a ojo desde cero.
   Nunca fuerces al usuario a ajustar el mapa si el autocompletado ya le sirvió tal cual.

Al soltar el pin, dispara Reverse Geocoding para autocompletar `fullAddress`/`district` — nunca
dejes esos campos vacíos si ya hay lat/lng disponible.

## Paquetes a usar (y cuáles evitar)

- `geolocator`: GPS + permiso de ubicación del dispositivo.
- `flutter_map`: renderizado del mapa con tiles. **No uses `google_maps_flutter`** — exige su
  propia API key del Maps SDK de Google con facturación habilitada, justo lo que se descartó al
  elegir Geoapify.
- Llamadas HTTP a Geoapify: usar `dio` (el cliente HTTP que ya usa todo el proyecto, ver
  `lib/core/network/api_client.dart`). No agregues un SDK/paquete dedicado de Geoapify — son
  endpoints REST simples que no lo justifican.

## Permiso de ubicación — replicar el patrón ya construido para notificaciones

Mismo patrón que `NotificationPermissionRepository`/`NotificationPermissionNotifier`
(`lib/features/notifications/`): pedir el permiso una vez; si el usuario lo rechaza (`denied`),
redirigir a Configuración del sistema con `openAppSettings()` (el paquete `permission_handler`
ya está en el proyecto) en vez de reintentar `requestPermission()` a ciegas esperando un
resultado distinto. Mismo criterio de repositorio wrapper + `AsyncNotifier` testeable con mock
que ya se usa ahí.

## Rate limit de Geoapify — 5 RPS compartido por TODA la app, no por usuario

El plan gratis limita a 5 requests/segundo **por API key**, y hay una sola API key para todos
los usuarios de Celtas juntos (no es 5/seg por persona individual). Devuelve
`429 Too Many Requests` si se excede. Dos reglas no negociables al implementar el autocompletado:

1. **Debounce obligatorio**: nunca dispares una petición de Autocomplete por cada tecla — esperá
   una pausa de ~300-500ms sin que el usuario siga escribiendo antes de consultar.
2. **Manejo defensivo del 429**: un rate limit nunca debe romper la pantalla ni bloquear que el
   usuario guarde su dirección — mismo criterio "nunca lanza" que ya usa `NotificationsService`
   en el backend para sus propios fallos. Si el autocompletado falla por rate limit, simplemente
   no se muestran sugerencias nuevas en ese instante; el usuario puede seguir escribiendo, o usar
   el mapa/GPS para ubicarse igual.

## API key

Vía variable de entorno (`flutter_dotenv`, mismo mecanismo que `API_BASE_URL` — ver la skill
`flutter-celtas`). Nunca hardcodeada en un widget/servicio ni commiteada al repo.

## Contrato con el backend — verificar antes de asumir campos

El backend (`../backend-celtas`) ya tiene `latitude`/`longitude` (nullable) en la entidad
`Address` y sus DTOs, y ya expone `POST /orders/estimate-delivery-fee` (body `{ addressId }`,
response `{ deliveryFee, isFarOrder, distanceMeters }`) para el cálculo de envío por distancia —
toda la parte backend/admin de esta feature ya está cerrada y en producción. Si necesitás
confirmar algún detalle del contrato de todos modos, no asumas los nombres de campo por este
doc — revisá `../backend-celtas/src/modules/users/entities/address.entity.ts` y los DTOs
correspondientes, o `/docs-json`.

**Actualizado por la feature "costo de delivery por distancia" (`POST /orders/estimate-delivery-fee`,
que necesita `latitude`/`longitude` reales para calcular la distancia): coordenadas ahora
OBLIGATORIAS para guardar cualquier dirección nueva o editada** — el formulario NO debe poder
enviarse si `latitude`/`longitude` siguen `null` (chequeo manual en `_submitNewAddress`/
`_submitForm`, ya que no viven en un `TextFormField` y `Form.validate()` no los cubre), con un
mensaje de error claro pidiendo tocar el mapa. Direcciones viejas que ya existían sin
coordenadas NO se migran (la regla aplica solo hacia adelante) — pero si el usuario las vuelve a
abrir para editar cualquier campo, la misma validación aplica: debe tocar el mapa esa vez para
poder guardar el cambio.

## Antes de escribir código de parseo de respuestas de Geoapify

No inventes los nombres de campo de la respuesta de Autocomplete/Geocoding/Reverse Geocoding por
memoria — confirmá el shape real contra el Playground de Geoapify (`apidocs.geoapify.com`) o una
llamada real de prueba, igual que se exige para cualquier contrato de API en este proyecto.
