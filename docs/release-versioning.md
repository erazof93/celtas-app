# Release y versionado actual

Estado leído el 2026-10-05. No se hicieron builds, cambios de consola,
consultas a tiendas ni comprobaciones de distribución productiva.

## Versión y entornos

pubspec.yaml declara **1.0.1+21**: nombre 1.0.1 y build number 21.
Android deriva versionName/versionCode de Flutter; iOS utiliza
FLUTTER_BUILD_NAME/FLUTTER_BUILD_NUMBER para CFBundleShortVersionString/
CFBundleVersion. Flutter build admite overrides --build-name/--build-number:
la versión del archivo no demuestra el artefacto publicado/instalado.

No hay flavors/productFlavors ni secuencias independientes por entorno.
.env controla API, Google server client ID y Geoapify; fallback API producción.
Mantener build numbers monotónicos requiere decisión de release, no una
actualización incidental por documentación o generación.

## Android

- applicationId/namespace: com.celtas.celtas_mobile.
- compileSdk: 37 explícito.
- minSdk/targetSdk: defaults Flutter; SDK local inspeccionado resuelve 24/36.
  Pueden variar al cambiar SDK, no están fijados numéricamente en el proyecto.
- Java/JVM 17; AGP 9.0.1, Gradle 9.1.0, Kotlin 2.3.20;
  Google Services 4.4.4 y desugaring.
- Release usa firma propia, minify/shrink y reglas ProGuard.
  Gradle lee android/app/key.properties y keystore local ignorados.
  Sin propiedades válidas, storeFile puede fallar al configurar Gradle.
- Permisos: notificaciones y ubicación foreground; INTERNET llega mediante
  dependencia Firebase Messaging. allowBackup=false.
- Sin deep links nativos propios ni autorización explícita de HTTP cleartext.

Firebase: google-services.json, plugin y firebase_options.dart presentes.
Canal/id/icono FCM nativo deben coincidir con NotificationService.
Google usa serverClientId tipo web y asociación Android package/certificado.
Históricamente la firma distribuida por Play difería de la clave de subida:
validar las asociaciones correctas cuando se autorice un release; no documentar
huellas o material de firma como valores permanentes aquí.

## iOS y web

Bundle actual: **com.example.celtasMobile**, coincide con opciones Firebase.
Deployment target declarado: 13.0; compatibilidad real con plugins requiere
validación en macOS. AppDelegate registra plugins.

No se encontró GoogleService-Info.plist, entitlements APNs/background,
URL scheme Google, Podfile/lock ni preparación verificable de distribución.
No configurar ni renombrar como parte de documentación. No hay destino App Store
en el gate. web existe y tiene opciones Firebase Dart, pero no service worker
FCM propio; no equivale a soporte productivo validado.

## Actualización mínima

GET /settings/public expone min_app_version. Backend LOCAL inspeccionado
la incluye en whitelist y siembra 1.0.1+16 si falta; esto no confirma producción.

package_info_plus forma versión instalada nombre+build.
evaluateAppVersion compara únicamente el entero después de +:
bloquea cuando installedBuild < minimumBuild, no por semver.
El parser no valida estrictamente X.Y.Z; campo ausente/vacío, falta de + o
build no entero devuelve noBlock. El provider también hace fail-open ante
ApiException de consulta; no cubre universalmente errores de tipo/plataforma.

CeltasApp muestra ForceUpdateDialog sobre rootNavigatorKey, sin descarte
por barrera/back. Abre exclusivamente:
https://play.google.com/store/apps/details?id=com.celtas.celtas_mobile

No hay rechequeo al volver a foreground. Si no existe Navigator cuando intenta
mostrar, no tiene reintento explícito después de marcar _dialogShown.
No hay revaluación de versión instalada tras abrir tienda en el mismo proceso.

## Preparación de una futura release

Con autorización específica: verificar entorno, SDK/lock, artefacto final,
build number, pruebas proporcionales, firma/OAuth y compatibilidad backend.
Los comandos y sus efectos están en [testing](testing-checklist.md).
No inferir publicación a partir de build local ni autorización a partir de
esta guía. Pendientes de plataforma/gate: [roadmap](../ROADMAP.md).
