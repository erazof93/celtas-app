# Arquitectura vigente

Referencia de lectura estática: 2026-10-05. Describe la implementación;
no acredita ejecución ni preparación productiva de todas las plataformas.

## Bootstrap y organización

`lib/main.dart` inicializa bindings, carga dotenv, inicializa Firebase,
precarga SharedPreferences y crea un ProviderContainer con overrides de
CartStorage y AddressSelectionStorage. NotificationService recibe ese container
antes de runApp; UncontrolledProviderScope lo expone a CeltasApp.
Estas operaciones se esperan antes del primer frame; no existe recuperación
global si alguna falla.

La organización por features es práctica, no Clean Architecture completa ni
MVVM estricto. `data/` contiene repositorios, modelos y almacenamiento;
`application/`, providers/notifiers; `presentation/`, pantallas y widgets.
Las pantallas también poseen controllers y estado local de formularios.
No hay una capa uniforme de interfaces/casos de uso de dominio.

## Estado e inyección

Riverpod 2.x usa declaraciones manuales: Provider, FutureProvider,
NotifierProvider y AsyncNotifierProvider, algunas family/autoDispose.
Repositorios reciben Dio o wrappers de plataforma y se pueden sustituir
mediante overrides en tests. No se genera código de providers.

Hay dependencias cruzadas entre features y dos singletons relevantes:
ApiClient y NotificationService. AuthSessionBridge desacopla el interceptor
de la implementación concreta del controlador auth.

Perfil, lista de pedidos, cupones y progreso de estrellas escuchan cambios
de user.id e invalidan su estado. Esta protección no está extendida a todos
los datos de usuario; véase [roadmap](../ROADMAP.md).

## Navegación

GoRouter se construye una vez en routerProvider; un listener de auth llama
router.refresh(). Los estados unknown/error se relacionan con el bootstrap
y el Splash; las áreas funcionales requieren sesión.

StatefulShellRoute.indexedStack mantiene cinco ramas: Inicio, Pedidos,
Cupones, Estrellas y Perfil. Detalles de producto/pedido, carrito, checkout,
direcciones, notificaciones y canje son rutas sobre el shell.
El back del shell utiliza confirmación de dos pulsaciones.
rootNavigatorKey permite montar el diálogo obligatorio de actualización.

## Red, sesión y errores

ApiClient instancia Dio con base URL de AppConfig y timeouts de conexión/
recepción de 15 segundos. Interceptores añaden Bearer, desenvuelven
success/data y realizan refresh/reintento único ante 401 con cola concurrente.
Endpoints de auth y requests ya reintentadas quedan excluidos del ciclo.

AuthController conserva access token/usuario en memoria y delega persistencia
del refresh token a Flutter Secure Storage. Bootstrap restaura vía refresh;
logout elimina almacenamiento local de sesión y solicita desregistro FCM.
La semántica servidor está en [integración](backend-integration.md).

Los repositorios convierten DioException a ApiException usando el mensaje
del backend o mensajes de red/timeout. Errores de deserialización no se
normalizan universalmente. La UI suele usar AsyncValue para carga/error/vacío
y SlowBackendNotice para explicar carga prolongada; esto no cambia el timeout.

Geoapify usa un Dio separado, sin Bearer ni interceptores del backend.
Fallas de autocomplete/geocoding/reverse devuelven listas vacías o null.

## Modelos y almacenamiento

Freezed/JSON Serializable generan modelos y algunos estados.
Existen serializadores manuales deliberados para carrito, sugerencias Geoapify
y snapshot de dirección. No asumir que toda serialización debe ser generada.

| Datos | Persistencia |
|---|---|
| Access token / usuario de sesión | Memoria |
| Refresh token | Flutter Secure Storage |
| Carrito normal | SharedPreferences, cart_v1 |
| Selección de dirección | SharedPreferences |
| Historial de notificaciones | SharedPreferences, máximo 30 |
| Premios ya celebrados | SharedPreferences |
| Imágenes remotas | Cached Network Image |

No hay monitor de conectividad ni sincronización offline general.
No se detectaron analytics/crash reporting propios.

## Tema, widgets y lifecycle

AppTheme.dark usa Material 3, CeltasColors/Radii/Spacing y Google Fonts
(Cinzel/Manrope); no hay fuentes propias declaradas como assets.
Shared contiene botones, campos, snackbar, bottom nav, avisos y parser SVG.
Las referencias visuales se consultan solo cuando una tarea lo necesita.

Home escucha businessHoursProvider: programa un timer para nextChangeAt,
cancela/reconsulta al reanudar y evita programar con datos anteriores aún
cargando. Perfil reconsulta permisos al volver al foreground.
El gate de versión no aplica hoy ese recheck; véase [release](release-versioning.md).

## Firebase y notificaciones

NotificationService crea canal Android celtas_default e inicializa notificaciones
locales; solicita permiso durante bootstrap. Escucha autenticación,
onTokenRefresh y el hook de refresh de ApiClient para sincronizar token.

Foreground: invalida providers, muestra notificación local y guarda historial.
Background: procesa el tap mediante onMessageOpenedApp.
Terminated: getInitialMessage y navegación diferida hasta autenticar.
No hay onBackgroundMessage: recibir sin tocar no garantiza historial local.

NotificationTarget clasifica payload por claves; navegación e invalidación
se centralizan en el servicio. La cola del historial serializa inserciones y
marcado de lectura. No hay App Links/Universal Links propios configurados.
Los límites de FCM están en [backend](backend-integration.md) y
[testing](testing-checklist.md).
