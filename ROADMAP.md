# Celtas Mobile — pendientes actuales

Base: auditoría estática del 2026-10-05 y migración documental.
No se ejecutaron analyze, formatter, tests, builds ni pruebas contra producción.
Los riesgos siguientes proceden de lectura de código; **NO están reproducidos**
en esta auditoría salvo la constatación textual del contrato/configuración.
Son candidatos a trabajo independiente, no autorización para corregirlos.

## Prioridad 1 — aislamiento y sesión

- Definir política de cambio de cuenta: direcciones y detalle de pedidos
  conservan providers sin invalidación por usuario; historial de notificaciones
  no está separado por cuenta; carrito conserva premios/cupones en memoria.
- Revisar refresh concurrente con logout/login: no hay guard de generación
  de sesión que descarte resultados pertenecientes a una sesión anterior.
- Revisar FCM: desregistro best-effort, un token por usuario y ausencia de
  desasociación del token en otras cuentas al registrar una cuenta nueva.
- Elegir alcance de revocación/logout del servidor. La emisión de un refresh
  JWT nuevo no invalida automáticamente el anterior.

## Prioridad 2 — contratos y experiencia de compra

- Decidir acceso a pedidos antiguos: backend local limita `GET /orders/me`
  a 20 por defecto; Mobile no solicita límite ni explica el recorte.
- Decidir si el detalle debe mostrar snapshots de opciones, comentario,
  descuento y envío que backend conserva pero Mobile no modela.
- Revisar límites de cantidad: el detalle limita a 99, pero acumulación y
  steppers/notifier del carrito pueden superarlo.
- Revisar revalidación de cupón tras `updateLine`: puede bajar subtotal sin
  aplicar la limpieza usada por decrement/remove.
- Revisar identidad de filas: segmentos sin categoría permiten colisiones
  estructurales; flags explícitos “Sin X” no forman parte de `lineKey`.
- Definir revalidación de precios/opciones rehidratados y compatibilidad
  de JSON histórico corrupto o incompleto, incluido el historial local de
  notificaciones, que no tiene recuperación uniforme ante corrupción.

## Prioridad 3 — lifecycle, integraciones y QA

- Revisar errores de arranque (dotenv/Firebase/permisos), obtención de token
  fuera del try, callbacks FCM y lanzamiento desde notificación local.
- Revisar respuestas Geoapify fuera de orden y uso de `mounted` después
  de awaits en auth/GPS. Verificar mapa, overlays y debounce en dispositivo.
- Definir conversión de instantes UTC para fechas visibles; preservar fechas
  civiles de promociones y reglas mensuales de Lima.
- Revisar crecimiento de SeenRewardsStorage y términos con S/10 fijo pese
  a configuración backend.
- Verificar atribución/restricciones del proveedor de tiles.
- Revalidar QA pendiente de dispositivo y decisiones visuales de Rewards.
  No se trasladan como fallos actuales los resultados antiguos de formato.
- Preparar entorno E2E aislado y credenciales fuera de fuentes; detector
  de pedido nuevo por tamaño de lista falla potencialmente al llegar a 20.
- Aumentar cobertura de integración de NotificationService según el cambio.

## Decisiones de plataforma y actualización

- Confirmar Android como plataforma operativa; decidir alcance de iOS/web.
  iOS no tiene preparación suficiente para distribución.
- Decidir reconsulta de `min_app_version` al reanudar y recuperación del gate
  si aún no existe Navigator; revisar datos mal tipados además de errores HTTP.
- Definir destino App Store antes de habilitar bloqueo en iOS. Hoy el destino
  es exclusivamente Play Store.
- Confirmar qué revisión/configuración está desplegada en backend y qué build
  está publicado. El código local no prueba el estado de producción.

## Límites de esta planificación

No cambiar versiones, identificadores, firma ni comportamiento como consecuencia
de la migración documental. Cada corrección requiere alcance, validación y
decisión propios. Los ejemplos de configuración no son valores de negocio fijados.

Detalles: [contratos](docs/backend-integration.md),
[negocio](docs/business-rules.md), [release](docs/release-versioning.md)
y [QA](docs/testing-checklist.md). La [historia](docs/history/development-audits.md)
es opcional y no sirve como lista de pendientes.
