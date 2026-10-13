# Gate declarativo de versión mínima

Este documento describe la implementación vigente y reemplaza la descripción
del gate en la inspección histórica de `release-versioning.md` del 2026-10-05.

La comparación conserva el contrato `min_app_version`: únicamente compara el
entero posterior a `+`, sin ordenar por semver ni cambiar versiones de release.

`appVersionCheckProvider` obtiene la versión instalada y los settings públicos.
Conserva errores de red, tipo y plataforma como `AsyncError`.
`appVersionGateProvider` mantiene cuatro estados:

- `loading`: espera inicial; no monta el contenido del Router.
- `allowed`: comparación válida y compatible; navegación normal.
- `updateRequired`: comparación válida incompatible; pantalla obligatoria.
- `error`: no se pudo verificar inicialmente; permite continuar (fail-open).

Un error o dato ausente/inválido posterior a `updateRequired` conserva el
bloqueo y la mínima anterior. Solo una comparación válida compatible lo retira.
El resultado `noBlock` de datos no verificables no acredita compatibilidad.

El gate vive en `MaterialApp.router.builder`, fuera de las rutas. No utiliza
`showDialog`, flags de presentación ni temporizadores. Mientras bloquea, el
Router no se monta: no inicializa Home ni sus solicitudes. `go`, `push` y
notificaciones pueden cambiar la ubicación solicitada, pero no montar pantallas.
La instancia de GoRouter y la sesión permanecen en Riverpod; el procesamiento
normal de rutas y redirecciones continúa cuando el gate permite el acceso.

La pantalla usa el tema y botón de Celtas, abre la ficha Android existente en
Play Store y muestra un error si falla el launcher. Un Navigator independiente,
PopScope y el observador de back impiden retirar la interfaz con Atrás.

Al reanudar, el controlador reevalúa si no hay una consulta en curso. Conserva
la interfaz previa durante los rechequeos: una app permitida no se desmonta
innecesariamente y una bloqueada permanece bloqueada. El observador se retira
al desmontarse el gate. No se modifican autenticación, tokens ni servicios FCM.

Límites: el bloqueo confirmado persiste en el contenedor del proceso, no entre
arranques; cada nuevo arranque conserva la política de fail-open inicial.
`package_info_plus` cachea PackageInfo dentro del proceso. Una actualización
real normalmente reinicia la app, que obtiene la versión nueva al arrancar.
Se mantiene exclusivamente el destino Play Store; no se agrega App Store.

Las pruebas automatizadas cubren estados, errores, datos inválidos, ambos
órdenes de bootstrap, navegación, ausencia de Home, reconstrucciones y retorno
simulado de tienda. No sustituyen QA visual, actualización instalada, back
predictivo ni entrega real de notificaciones en un dispositivo.
