# Testing y verificación vigentes

Guía para tareas autorizadas. Esta migración no ejecutó formatter, analyze,
tests, generación, builds, FlutterFire, ADB ni servicios productivos.
Resultados antiguos no sustituyen evidencia actual.

## Estrategia proporcional

- Documento/configuración de agente: diff, enlaces, referencias, secretos e
  integridad de archivos protegidos; no necesita compilar la app.
- Modelo/repositorio/provider: tests unitarios del contrato y casos borde.
- Widget/navegación: tests de estado, interacciones, errores y lifecycle relevantes.
- Auth/interceptor/carrito: regresiones de concurrencia e invariantes afectadas.
- Permisos/plugins/native/release: pruebas en plataforma/dispositivo autorizado.
- Cambios amplios: suite y análisis adecuados al alcance; no repetir builds
  costosos si no aportan nueva evidencia.

test/ contiene unit y widget tests, Mocktail, fakes de plataformas, adapters
HTTP y preferencias simuladas. integration_test/ contiene dos E2E con servicios
reales. No se encontraron golden tests implementados en la auditoría.
Los números de tests previos no son promesas sobre la suite vigente.

## Escenarios según el cambio

| Área | Comprobar |
|---|---|
| Auth | Access no persistido, secure refresh, bootstrap, 401 definitivo vs red, retry único/cola, logout/login concurrente y cambio de cuenta |
| Router | Instancia estable, refresh del guard, cinco tabs, rutas protegidas, navegación desde push y back |
| Carrito | Persistencia filtrada, fusión/edición, cantidades, flags Sin X, precios preview y mínimo del cupón |
| Contrato | Envelope, tipos/números/nullable, omitido/null/[], DTOs y snapshots del backend local |
| Direcciones | Coordenadas requeridas al guardar, históricos nullable, principal vs selección, permisos/GPS, overlays y respuestas tardías |
| Delivery | Estimación/fallo, dirección sin coordenadas, cálculo definitivo y ausencia de bloqueo por distancia |
| Checkout | Teléfono/revisión, cierre, pedido registrado aunque falle URL, reabrir WhatsApp sin duplicar pedido |
| Rewards | Hitos dinámicos/vacíos, catálogos separados, pending/redeemed, fin de mes Lima y celebración una vez |
| Version gate | Build menor/igual/mayor, datos ausentes/mal tipados, red, Navigator, back/barrera y fallo de tienda |
| FCM | Login/rotación/refresh, permisos y resumed, foreground/tap/terminated, payload, cola del historial y logout |
| Históricos | Recursos borrados, snapshots incompletos/JSON inválido, campos opcionales y fechas |
| Visual | Tema, fuentes, espacios seguros y parser SVG; validar en dispositivo cuando cambie renderizado |

No validar integración completa de NotificationService solo con tests de
NotificationTarget. Test de UI envuelto en ProviderScope no acredita que
el main real tenga bootstrap correcto. Animaciones continuas requieren
pumps controlados; pumpAndSettle no siempre termina.

## Comandos clasificados por efectos

| Comando | Clasificación / efectos |
|---|---|
| rg, Get-Content, inventario; git status/diff/diff --stat/diff --check | Inspección; no generación funcional |
| dart format --output=none --set-exit-if-changed ... | Verifica formato sin reescribir fuentes |
| dart format ...; dart format --set-exit-if-changed ... | Modifica fuentes; exit flag no impide escribir |
| dart analyze | Verificación; infraestructura puede usar/escribir cachés |
| flutter analyze | Verificación, posible pub automático y metadatos/cachés |
| flutter analyze --no-pub | Evita pub automático; no garantiza cero escritura |
| flutter test / --no-pub | Compila y crea artefactos/cachés; tests pueden tener otros efectos |
| flutter test --coverage | Además genera cobertura |
| flutter test integration_test/... | Build/dispositivo, servicios externos y posible mutación backend |
| flutter pub get / pub upgrade | Resolución, descargas, metadatos/cachés y posible cambio del lock |
| dart run build_runner build | Genera .g.dart/.freezed.dart y cachés |
| build_runner con --delete-conflicting-outputs | También puede eliminar outputs conflictivos |
| dart run flutter_launcher_icons | Genera/modifica iconos y recursos/configuración nativa |
| dart run flutter_native_splash:create | Genera/modifica splash y recursos/configuración nativa |
| flutterfire configure | Genera configuración y puede operar contra Firebase |
| flutter build apk/appbundle/ios/web | Genera artefactos, usa cachés/dependencias y firma cuando corresponde |
| flutter build apk --analyze-size --target-platform=android-arm64 | Build más reporte de tamaño |
| flutter run | Build/instalación/dispositivo; app puede mutar backend |
| flutter clean | Elimina artefactos/cachés |
| dart fix --dry-run | No aplica fixes; no garantiza ausencia de cachés |
| dart fix --apply | Modifica fuentes |
| ADB inventario/logs | Consulta dispositivo; logs pueden contener datos sensibles |
| ADB captura a archivo | Genera archivo |
| ADB install/uninstall/tap/text/ajustes | Cambia dispositivo; interacción puede mutar backend |

No ejecutar comandos de esta tabla durante una tarea declarada solo lectura
si pueden escribir. Los flags --no-pub no convierten un comando en inspección pura.

## E2E y dispositivo

Los E2E existentes cargan .env y contienen credenciales de prueba embebidas:
no reproducirlas en documentación/logs. El flujo de salsas puede crear
dirección, guardar teléfono y crear pedido real; su fallback POST puede
crear otro pedido si UI no fue detectada. GET rewards/progress también
puede recalcular/conceder premios en servidor.

Autorizar previamente backend/cuenta/dispositivo y efectos, preferir entorno
aislado y definir limpieza de datos por el responsable. Detector basado en
crecimiento de /orders/me necesita revisión por límite default 20.
Estos tests montan CeltasApp con ProviderScope; no ejercitan main completo.

Para QA visual: identificar dispositivo/resolución reales, verificar cada
acción con estado visible y logs pertinentes y reportar pasos realmente
observados. No incluir capturas ni dumps con credenciales/datos innecesarios.
No usar coordenadas de otra sesión como evidencia.

## Criterios de cierre

- Cambio dentro del alcance y contratos/invariantes preservados.
- Pruebas relevantes ejecutadas con resultado real, o limitación explícita.
- Sin nuevos errores relevantes; distinguir inspección estática de reproducción.
- Diff revisado, outputs generados consistentes si se autorizó generación.
- Secretos omitidos; runtime/versionado no cambian incidentalmente.
- Documentación actualizada solo donde cambie una regla.
- No marcar pendiente como resuelto por una auditoría histórica ni por
  un fallback E2E que no recorrió el flujo solicitado.

Reglas: [negocio](business-rules.md). Contratos: [backend](backend-integration.md).
Riesgos pendientes: [roadmap](../ROADMAP.md). Evidencia antigua opcional:
[historia](history/development-audits.md).
