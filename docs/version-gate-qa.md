# QA Android aislado del Version Gate

Variante compilada y auditada estáticamente; no se ha instalado ni iniciado.
No acredita funcionamiento en el Xiaomi físico.

## Aislamiento y activación

El flavor `qa` existe únicamente cuando Gradle recibe `CELTAS_QA=true` o el
target QA. Solo habilita `qaDebug`, y exige ambos parámetros simultáneamente.
El entry point también exige `kDebugMode`, flag explícito, escenario explícito
y package real `com.celtas.celtas_mobile.qa`. QA release/profile están
deshabilitados. Un intento de usar esos parámetros para la app habitual no
habilita una variante productiva.

Los builds normales conservan sus variantes, comandos, identificador,
firma release y nombres de artefactos. `pubspec.yaml`, versión y `main.dart`
permanecen sin cambios. QA usa firma debug y no lee el keystore release.
Cada paquete tiene almacenamiento Android independiente; no se extraen ni
copian datos de la app instalada.

`main_qa.dart` no arranca Firebase, NotificationService, preferencias,
auth, Secure Storage ni `.env`. Inicializa únicamente Flutter y PackageInfo.
El router QA tiene Splash/Home/ruta de prueba sin providers de datos.
Los accesos accidentales a los providers de auth/sesión/storage fallan antes
del bootstrap. Settings es un repositorio local: se conservan el FutureProvider,
el comparador del entero después de `+`, el controlador y CeltasApp reales.

Tres barreras de red:

- El overlay `src/qaDebug/AndroidManifest.xml` retira INTERNET, permisos de
  notificaciones/ubicación y componentes de inicialización/recepción Firebase.
- `HttpOverrides` impide crear clientes HTTP Dart; el adapter de Dio deniega
  todas las solicitudes, incluyendo URLs absolutas.
- API configurada a `https://qa.invalid`, hooks de sesión desconectados,
  descarga de fuentes desactivada y Google Services QA deshabilitado.

El task `copyFlutterAssetsQaDebug` excluye `.env` y `.env.*` al copiar assets
hacia el paquete Android y comprueba su ausencia en el destino. No cambia el
asset bundle intermedio ni el archivo original; los builds normales mantienen
su configuración. El manifiesto QA elimina los componentes de Firebase/FCM,
Credentials, Google Sign-In, DataTransport, ubicación, WebView y AndroidX Startup.
`QaActivity` registra JniPlugin, JniFlutterPlugin, PackageInfo y UrlLauncher; no llama al
registrador generado que contiene los plugins productivos.

El APK debug conserva bibliotecas y código compartido sin ejecutar, incluida
una URL pública de respaldo del backend. QA reemplaza la configuración con
`qa.invalid` antes de crear el cliente y deniega HTTP/Dio. Las referencias al
nombre `.env` en manifiestos de assets no contienen el archivo ni sus valores.
La inspección estática no acredita aislamiento absoluto ni sustituye QA físico.

## Escenarios deterministas

| CELTAS_QA_SCENARIO | Resultado |
|---|---|
| compatible | Mínimo igual al build instalado: Allowed |
| required | Mínimo igual al build instalado + 1: UpdateRequired |
| initial_error | Primera consulta y siguientes fallan: Error, permite continuar |
| blocked_error | Primera consulta confirma bloqueo; siguientes fallan y lo conservan |

La primera validación espera el botón **Verificar**; no usa temporizadores.
**Bootstrap QA** completa un bootstrap simulado y solicita Splash → Home.
Probar ambos órdenes pulsando Bootstrap/Verificar o Verificar/Bootstrap.
**go Home** y **push ruta** fuerzan navegación incluso durante el bloqueo.
No debe aparecer ni montarse Home QA durante Loading/UpdateRequired.
Tras la primera validación, Verificar hace un rechequeo real del controlador.
Resumed también lo hace y comparte consultas pendientes.

La sesión es simulada: este APK no prueba restauración real, FCM ni operaciones
de negocio. La ausencia de montaje del Home productivo durante el bloqueo
se cubre adicionalmente en los widget tests existentes del gate.

## Logs depurados

Solo eventos del enum VersionGateEvent: prefijo `[CELTAS_QA]`, sin URLs,
tokens, datos personales, payloads ni respuestas HTTP. Incluyen arranque,
validación/resultados, estados, bootstrap simulado, go/push, montaje de Home,
tienda, resumed, back y solicitudes denegadas. Errores Flutter/Dart se registran
con categoría genérica, sin texto/stack potencialmente sensible.
En producción el provider de diagnóstico no realiza ninguna operación.

Después de instalar, consultar UID/PID del **paquete QA**, nunca del productivo.
Propuesta de consulta sin guardar logs completos:

```powershell
adb -s gykrbeq8gy4xnvrg shell pidof com.celtas.celtas_mobile.qa
# Sustituir PID_QA por el PID consultado; reinicios requieren consultarlo de nuevo.
adb -s gykrbeq8gy4xnvrg logcat --pid=PID_QA -v threadtime --regex='\[CELTAS_QA\]'
```

ADB convencional falla en el sandbox actual. Allí usar el canal de consulta
al servidor local ya disponible, o ejecutar los comandos en PowerShell del
usuario; no cambiar permisos/configuraciones globales. No limpiar logcat.

## Compilación y posterior instalación autorizada

Comando de compilación ejecutado desde celtas-app:

```powershell
flutter build apk --debug --flavor qa -t lib/main_qa.dart --dart-define=CELTAS_QA=true --dart-define=CELTAS_QA_SCENARIO=required --no-pub
```

Cambiar únicamente el escenario por compatible/initial_error/blocked_error
para los otros APK. No aumentar versión/build ni utilizar release/profile.
Artefacto esperado: `build/app/outputs/flutter-apk/app-qa-debug.apk`.

**Antes de autorizar instalar o iniciar**, revisar el APK final con herramientas
Android locales (`apkanalyzer manifest application-id`, `manifest permissions`,
`manifest print`, `apksigner verify --print-certs`), sin imprimir secretos:

1. ID exacto `.qa`, versión 1.0.1/code 21, firma debug.
2. INTERNET ausente del manifiesto fusionado, componentes Firebase retirados,
   y ausencia de configuración Google Services generada para QA.
3. Confirmar si `.qa` ya existe; si existe, comparar firma y versionCode antes
   de reemplazarla. Nunca usar el APK productivo ni un downgrade.
4. Confirmar dispositivo/serial y que el paquete productivo conserva su versión.

Solo después de esas comprobaciones y autorización de instalación:

```powershell
adb -s gykrbeq8gy4xnvrg install -r build/app/outputs/flutter-apk/app-qa-debug.apk
```

No ejecutar uninstall, pm clear, limpieza de caché ni copia de datos.
Play Store abre la ficha productiva en una aplicación externa: volver **sin
actualizar ni instalar**. No actualiza el paquete QA y no necesita habilitar
Internet en él. Confirmar visualmente Atrás, retorno y permanencia del bloqueo.

## Verificación automatizada y límites

Permitido por AGENTS.md y testing-checklist: format, analyze y unit/widget
tests sin pub automático. Los E2E existentes usan servicios reales y quedan
excluidos. Ejecutar:

```powershell
flutter test --no-pub --dart-define=CELTAS_QA=true test/qa
flutter test --no-pub test/qa test/features/settings test/core/router/app_router_test.dart test/features/auth
```

Las pruebas QA verifican escenarios con providers reales, bloqueo tras error,
desbloqueo compatible, auth/storage rechazados, red Dart/Dio denegada, ambos
órdenes bootstrap/versión, go/push/back/rebuild, Home y store/resumed simulados.
La ejecución sin flag comprueba rechazo de activación accidental.

Resultados de la corrección de aislamiento (2026-10-10): 14 tests QA con flag
y 107 tests de gate/router/auth y rechazo QA sin flag, todos aprobados.
El test de aislamiento comprueba además que la activación borra claves sintéticas
previamente cargadas. Análisis Dart QA sin incidencias; formato verificado.
Build debug QA `required` completado con dependencias locales offline.

Auditoría reproducible: `tool/qa/audit_apk.ps1`, con parámetros Apk, AndroidSdk
y ExpectedDebugCertificateSha256. Rechaza permisos/componentes inesperados,
configuración o material de firma empaquetados, firma distinta, valores sensibles
de `.env`, registro nativo no permitido y kernel/entrypoint que no coinciden con
el build QA. No imprime valores del entorno. Revisar por separado las constantes
públicas reportadas y las rutas de inicialización; el script no prueba ejecución.

El APK final no contiene `.env`, valores originales Geoapify/client ID, INTERNET,
providers, servicios ni receivers. Conserva solamente QaActivity y el permiso
interno DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION. No se ejecutaron E2E,
instalación, inicio ni acciones ADB. Pendientes: renderizado, back predictivo
Android 16, intents de tienda, logs nativos y observación visual en dispositivo.

## Evidencia histórica del APK auditado antes de la corrección JNI

- Ruta: `build/app/outputs/flutter-apk/app-qa-debug.apk`.
- Tamaño: 184368065 bytes (175.83 MiB).
- Package ID: `com.celtas.celtas_mobile.qa`; versión `1.0.1+21`; debuggable.
- SHA-256 APK: `eef8234504994a034b037400cd89f1f646e11ac0b33b4bfb079111923574b831`.
- Firma APK v2 válida, Android Debug RSA 2048. Certificado SHA-256:
  `251d68b53f305a490e65a3bd62563fdead04a81e6e2e81a5c0f613cd2478cb5f`.
- Kernel empaquetado coincide por SHA-256 con `app.dill` del build QA;
  inputs contienen `lib/main_qa.dart` y no `lib/main.dart`. Comando usado:
  debug, flavor qa, CELTAS_QA=true y CELTAS_QA_SCENARIO=required.
- DEX de QaActivity confirma solo PackageInfo/UrlLauncher, sin llamada a
  GeneratedPluginRegistrant ni al configureFlutterEngine de la superclase.
- Sin recursos Google Services de app ID, API key, client ID o sender ID.
- Assets JSON revisados: FontManifest y NativeAssetsManifest; metadatos de
  fuentes y assets nativos, sin valores sensibles originales de `.env`.
- El único valor del entorno original encontrado es API_BASE_URL, como URL
  pública en el kernel de código compartido. No se eliminó ese fallback de
  producción ni se afirma que el debug esté libre de todo código productivo.

Las bibliotecas nativas de plugins siguen presentes como dependencias comunes;
sus componentes Android y su registro automático están retirados en QA. El
registro limitado permite información de paquete y apertura de tienda externa.
La tienda puede usar su propia red: es una acción externa explícita, no una
solicitud HTTP de QA. El permiso interno restante protege receivers dinámicos
AndroidX; no concede acceso a red, datos productivos o credenciales.

Se usaron mirrors y cachés locales offline por las restricciones del sandbox,
sin alterar permisos globales. Las referencias temporales de package_config,
plugins y local.properties se restauraron con hashes idénticos. Advertencias
de KGP/firebase_core y versión XML SDK no impidieron la compilación.

## Corrección del arranque JNI

El APK anterior pasó auditoría estática, pero falló físicamente en Android 16
con SIGSEGV en libdartjni/FindClassUnchecked. La actividad limitada omitía la
inicialización nativa JNI requerida por código Dart compartido.

QaActivity registra primero JniPlugin: su inicializador carga dartjni y establece
JNIEnv, JVM, class loader, método loadClass, TLS y referencias de excepciones.
Después registra JniFlutterPlugin: aporta contexto Android y actividad por engine.
Finalmente registra PackageInfo y UrlLauncher. Las implementaciones inspeccionadas
no arrancan servicios, no registran tokens ni realizan peticiones remotas.
No se llama al registrador generado ni se adjuntan plugins nativos productivos.

El auditor verifica el conjunto exacto y orden de constructores en el DEX;
rechaza el APK histórico sin JNI. Los tests Dart no validan por sí solos este
arranque nativo: se requiere reconstrucción, auditoría y prueba física autorizada.
Verificación de la corrección JNI (2026-10-10): 14 tests QA y 107 de regresión
aprobados; análisis Dart sin incidencias; formato Dart y diff check correctos.
Kotlin compilado por Gradle. APK required SHA-256:
`4ae02123c7a0e17aa475844b5be1dca4a18cda7d0b2fb16638896b035bf0bc48`;
184369333 bytes, mismo package .qa, versión 1.0.1+21 y certificado debug.
Auditoría aprobada, sin INTERNET, .env ni valores sensibles originales; único
componente QaActivity y permiso interno AndroidX. El kernel Dart no cambió.

Instalación QA actualizada con Success en gykrbeq8gy4xnvrg (API 36).
Arranque COLD aceptado por Android; proceso 28969 activo, eventos appStarted,
gateLoading y validationStarted. No SIGSEGV observado en este arranque.
La app productiva permanece instalada en 1.0.1+21. La validación simulada inicial
requiere pulsar Verificar; pantalla obligatoria y confirmación visual pendientes.