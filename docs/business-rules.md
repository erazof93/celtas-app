# Reglas de negocio vigentes

Referencia: implementación Mobile y backend local auditados el 2026-10-05.
Estas reglas describen comportamiento actual, no autorización para cambios.
Las limitaciones se planifican en [ROADMAP](../ROADMAP.md).

## Carrito, precios e identidad

Carrito local Riverpod, persistido en cart_v1. Solo se guardan líneas normales:
cupón validado, avisos y premios se excluyen de la caché.
La persistencia es best-effort y JSON ilegible del carrito carga vacío.
No existe carrito backend antes de crear pedido.

Preview: `(precio base + bebidas + extras) × cantidad`; salsas y papas
no añaden precio. Backend recalcula importes con catálogo vigente.
Precios/opciones rehidratados pueden estar desactualizados.

lineKey combina producto, IDs de opciones ordenados y comentario; filas
con la misma key se fusionan sumando cantidades. Editar reemplaza cantidad
y puede fusionar con otra fila. Papas incluyen segmento fries; las otras
categorías no tienen etiquetas universales. Flags “Sin X” no forman la key:
al fusionar, flags se combinan. Es implementación actual, con riesgos conocidos;
no prometer una identidad sin colisiones.

Premio usa `reward::redemptionId`, nunca se fusiona con línea normal.
addRewardItem fija base cero/cantidad 1 y evita repetir la redención.
UI no permite stepper/edición del premio; otros métodos del notifier no
imponen universalmente esa invariante. Backend la valida. Extras, si se
envían, no quedan cubiertos por precio base cero.

## Opciones de producto

Salsas, bebidas y extras tienen tres estados:

| Payload | Significado |
|---|---|
| Campo omitido | No aplica/no se decidió; snapshot null |
| [] explícito | Elección deliberada “Sin X” |
| IDs elegidos | Snapshot de nombres y, para opciones pagadas, precios |

No enviar null a listas: backend lo rechaza. Grupos sin catálogo no requieren
elección. En grupo obligatorio, [] puede satisfacer decisión si allowWithout
es true; omisión no. Max limita selecciones; sauceGroupMaxSelectable null
significa sin límite. No convertirlo a cero. Nombres reales incluyen
extraPortionsGroupRequired/MaxSelectable/AllowWithout, en plural.

Papas usan defaults backend, required/max y no tienen “Sin papas” en UI.
Vacío omite friesTypeIds; backend admite semántica [] en su contrato,
pero Mobile no la ofrece. El “+” del Home abre detalle si hay opciones,
en lugar de saltarse selección.

Comentario por línea se trimea y solo se manda si hay contenido;
máximo backend 140 caracteres. No es una nota independiente por unidad.

## Cupones y delivery

Preview de cupón: porcentaje sobre subtotal o monto fijo, descuento acotado
entre cero y subtotal. Validación previa recibe subtotal y no consume.
applyCoupon revalida mínimo tras el await. Decrement/remove limpian cuando
carrito queda vacío o baja del mínimo; updateLine no aplica hoy esa limpieza.

Canje definitivo ocurre transaccionalmente al crear pedido, con propiedad,
vigencia, uso y mínimo resueltos por backend. Cancelación puede reactivar
cupón/premio según reglas servidor, no por una mutación local del carrito.

Delivery se suma después del descuento. Backend calcula distancia por
coordenadas y tramos configurados; la estimación Mobile es informativa.
Error de estimación no bloquea checkout y puede ocultar tarifa en preview.
Dirección sin coordenadas tiene fallback cero en backend.
isFarOrder/distancia son información interna, no bloqueo por lejanía en UI.

## Direcciones y snapshots

Principal (isDefault) y seleccionada son conceptos distintos.
Dirección activa: selección existente → principal → primera → ninguna.
Selección se persiste; logout borra almacenamiento, pero no reinicia hoy
todo el estado en memoria. Al borrar principal, Mobile promueve la primera
restante si ninguna es principal; backend no hace esa promoción.

Nuevas/ediciones desde formularios exigen lat/lng. Direcciones históricas
nullable siguen existiendo y pueden elegirse sin migración automática.
Alias/fullAddress/district se validan; reference es opcional.
Actualizar reference vacío es distinto de omitirlo: el repositorio PATCH
incluye string vacío no nulo, permitiendo limpiar contenido.

Geoapify proporciona autocomplete/geocoding/reverse y tiles; GPS mediante
geolocator. El mapa tiene pin fijo central y se desplaza debajo para corregir
ubicación. Centro visual inicial no significa coordenadas confirmadas.
Autocomplete y movimiento usan debounce 400 ms; fallas retornan []/null.
Permiso denied/unableToDetermine permite request; deniedForever abre ajustes.
La key es cliente y compartida; límites comerciales no se consideran constantes
vigentes sin consulta oficial cuando una tarea los necesite.

Pedido copia dirección/precios/nombres/opciones; borrar o editar catálogo/
direcciones no debe alterar pedidos previos. Conservar nullable/defaults
históricos y no reconstruir snapshots desde recursos vivos.

## Checkout, horarios y estados

No hay pago interno. Se solicita teléfono si falta, con validación y revisión
antes de guardarlo; luego POST /orders crea pedido y devuelve whatsappUrl.
Carrito se limpia al crear, antes de abrir URL. Si WhatsApp falla, reintenta
abrir el link del pedido existente, no crear otro. launchUrl directo, sin
canLaunchUrl como condición previa.

El aviso de cierre es preventivo: no deshabilita por sí solo confirmar.
Backend decide apertura al crear; 409 se muestra como diálogo de cierre.
Home reconsulta al reanudar y programa nextChangeAt con margen de 5 segundos
cuando hay valor asentado; cierre manual puede no tener próximo instante.

Estados representados: pendiente, confirmado, en_camino, entregado, cancelado.
Mobile no cambia estados. No asumir que esa lista define por sí sola todas
las transiciones válidas de servidor. Badges mantienen colores diferenciados.

## Estrellas, fechas y notificaciones

Backend cuenta subtotal de items (sin envío) de pedidos entregados en el
mes calendario de Lima. Promoción aplica multiplicador por fecha de creación.
Soles por estrella es configurable; términos Mobile todavía dicen S/10.

Hitos dinámicos y premios especiales: no fijar cantidad, umbrales ni posición
del especial. Cada hito se gana como máximo una vez por mes, sin arrastre.
Premios vencen al final de su mes de obtención. Progreso puede incluir
reclamados del mes y premios pending; solo pending permite canje.
El producto se elige al canjear, no está ligado al premio disponible.
Celebración local compara IDs ya vistos; no depende de push de premio nuevo.

Promociones endDate son YYYY-MM-DD: no convertir a instante y desplazar día.
Instantes ISO y mes de Lima son conceptos distintos; formato Mobile actual
no convierte explícitamente todos los instantes a esa zona.
Reloj del dispositivo puede alterar etiquetas de vencimiento.

Push de horario solo anuncia cambio: siempre consultar business-hours.
Pedido/cupón invalida sus consultas; link abre aplicación externa.
Historial es local, máximo 30 y sin separación por cuenta; no equivale a
registro completo de todas las notificaciones recibidas.

Actualización mínima y plataformas: [release](release-versioning.md).
Contratos/históricos y límites de historial: [backend](backend-integration.md).
