# Celtas Mobile

Aplicación Flutter de Celtas Fast Food para delivery. Permite consultar el
menú, personalizar productos, gestionar carrito/direcciones, crear pedidos
y continuar por WhatsApp, consultar cupones y estrellas y recibir notificaciones.
Los importes definitivos y reglas del servidor pertenecen a backend-celtas.

## Stack y requisitos

Flutter/Dart, Riverpod manual, go_router, Dio, Freezed/JSON Serializable,
Firebase Messaging, Google Sign-In y Geoapify.

- `pubspec.yaml`: Dart `^3.12.2`; lock: Flutter `>=3.44.0`.
- SDK local inspeccionado el 2026-10-05: Flutter 3.47.0 / Dart 3.13.0.
  No hay pin de SDK portable que garantice esa instalación en otra máquina.
- Para Android: SDK compatible con compile 37 y Java 17; el proyecto usa
  AGP 9.0.1 y Gradle 9.1.0.
- Para iOS: macOS/Xcode y preparación nativa adicional; no está listo para release.

## Preparación

1. Instala un SDK compatible y abre la raíz del repositorio.
2. Copia `.env.example` a `.env` y completa los valores localmente:
   `API_BASE_URL`, `GOOGLE_SERVER_CLIENT_ID` y `GEOAPIFY_API_KEY`.
   No publiques credenciales. El archivo se incluye en el bundle del cliente.
3. El fallback de API apunta a producción; elige conscientemente el entorno.
   Si falta el propio archivo `.env`, el bootstrap puede fallar.
   En emulador Android el host local suele ser `10.0.2.2`; la compatibilidad
   de HTTP sin TLS debe comprobarse, no está explícitamente habilitada aquí.
4. Resuelve dependencias con `flutter pub get` cuando esté autorizado.
   Puede crear metadatos/cachés y cambiar el lock; revisa su diff.
5. Para release Android solicita al responsable la configuración local de
   firma. No hay claves ni contraseñas de firma documentadas aquí.
   Gradle carga `android/app/key.properties`; sin configuración válida,
   incluso configurar el proyecto puede fallar.

## Comandos habituales

Los siguientes son instrucciones para tareas autorizadas, no comprobaciones
ejecutadas por esta migración:

| Objetivo | Comando | Efecto |
|---|---|---|
| Dependencias | `flutter pub get` | Resolución, metadatos/cachés y posible lock |
| Análisis | `flutter analyze --no-pub` | Verifica; puede escribir cachés |
| Tests locales | `flutter test --no-pub` | Compila y crea artefactos |
| Revisar formato | `dart format --output=none --set-exit-if-changed lib test` | No reescribe fuentes |
| Modelos | `dart run build_runner build` | Genera outputs/cachés |
| Desarrollo | `flutter run` | Compila, instala y puede mutar backend |
| Release Android | `flutter build appbundle --release` | Genera AAB firmado |

Los E2E actuales usan backend real y pueden crear pedidos, direcciones y
actualizar teléfono. No los ejecutes como una comprobación local inocua.
Consulta la [guía de testing](docs/testing-checklist.md) antes de generación,
limpieza, pruebas con dispositivo o servicios.

## Plataformas y estructura

Android tiene configuración de Firebase, permisos y firma release.
iOS conserva un bundle de ejemplo e integración nativa incompleta.
Existe `web/`, pero no acredita una plataforma productiva: no hay service
worker FCM propio y el flujo Google/plataforma requiere verificación.

`lib/core/` contiene configuración, HTTP, router y tema; `lib/features/`
agrupa data/application/presentation; `lib/shared/` contiene widgets y utilidades.
`test/` reúne pruebas locales y `integration_test/` pruebas con dispositivo.
`assets/` y `design-reference/` conservan branding y referencias visuales.

## Documentación

- [Arquitectura](docs/architecture.md)
- [Integración backend](docs/backend-integration.md)
- [Reglas de negocio](docs/business-rules.md)
- [Release y versionado](docs/release-versioning.md)
- [Testing y comandos](docs/testing-checklist.md)
- [Pendientes actuales](ROADMAP.md)
- [Historia técnica opcional](docs/history/development-audits.md)

Cada documento se consulta según la tarea. El historial no establece reglas vigentes.
