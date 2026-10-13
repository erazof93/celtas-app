# Android DEV aislado

DEV usa `com.celtas.celtas_mobile.dev`, etiqueta `Celtas DEV`, firma debug y
`lib/main.dart`. Producción sigue sin flavor; QA conserva su entrada y guardas.
Los sandboxes Android separan preferencias, carrito y Secure Storage. No copies
datos, cuentas ni tokens desde producción.

La configuración se entrega explícitamente con `--dart-define-from-file` desde
un archivo local ignorado, por ejemplo `.env.dev.json`. Debe contener
`"CELTAS_DEV": "true"` y `"CELTAS_DEV_ENV"`: un string dotenv con saltos de línea
JSON (`\n`). No agregues secretos: estos valores quedan incluidos en el APK.

Campos obligatorios del string dotenv:

- `ENVIRONMENT=dev`
- `DEV_SERVICES_AUTHORIZED=true`, únicamente tras autorización del entorno real.
- `API_BASE_URL`: URL HTTPS exclusiva del backend DEV autorizado.
- `FIREBASE_PROJECT_ID`, `FIREBASE_MESSAGING_SENDER_ID`, `FIREBASE_APP_ID`,
  `FIREBASE_API_KEY`: configuración Android del proyecto DEV autorizado.
- `GOOGLE_SERVER_CLIENT_ID`: cliente Web OAuth del mismo proyecto DEV.

No hay archivo válido incluido ni endpoints/credenciales inventados. Sin campos
válidos, el arranque muestra error y Reintentar antes de preferencias, Firebase
o providers. Reintentar no cambia defines: corregirlos exige una nueva compilación.
El presupuesto de preparación sigue siendo 20 segundos.
El cliente API DEV rechaza otros orígenes y deshabilita redirects antes de enviar
credenciales. Esta política se instala únicamente tras validar la configuración.

DEV no carga `.env`, no procesa el `google-services.json` raíz, elimina archivos
`.env*` del bundle Android y desactiva FirebaseInitProvider y la inicialización
automática FCM. Firebase solo se inicializa con las opciones validadas de DEV.
No se conecta NotificationService: las pruebas FCM quedan fuera de esta fase.
La política del cliente API DEV también bloquea `/users/me/fcm-token` antes del
transporte, incluido el DELETE que solicita logout. No registra ni elimina tokens.
Google Sign-In requiere registrar el package DEV y SHA de la firma debug en el
entorno OAuth autorizado; el script no crea esos recursos. Geoapify queda sin key
y conserva su comportamiento existente de función no disponible.

La validación rechaza el backend productivo conocido y las identidades Firebase
productivas actuales. No puede demostrar que un hostname alternativo no apunte a
producción ni que un operador haya declarado correctamente su autorización:
revisar destino, redirects, proyecto, OAuth y cuentas de prueba antes de habilitar
el entorno. Los contratos HTTP permanecen intactos.

## Comandos futuros, no ejecutados

Desde celtas-app, con configuración y entorno previamente autorizados:

```powershell
flutter build apk --debug --no-pub --flavor dev -t lib/main.dart --dart-define-from-file=.env.dev.json
./tool/dev/audit_apk.ps1 -Apk build/app/outputs/flutter-apk/app-dev-debug.apk -AndroidSdk <SDK> -ExpectedDebugCertificateSha256 <SHA256-debug-verificado> -DevDefinesFile .env.dev.json
```

El auditor comprueba ID, etiqueta, backup deshabilitado, debug, firma esperada,
guardas nativas Firebase, ausencia de assets de entorno/firma y presencia de la
configuración seleccionada en el kernel debug. Informa permisos y componentes
sin imprimir valores de configuración. La revisión futura del APK debe confirmar
los permisos esperados del manifest fusionado. El auditor también rechaza valores
Firebase/OAuth productivos en los recursos nativos, comparándolos en memoria con
el JSON productivo sin imprimirlos. No basta con cambiar ID.

Los constantes productivos compartidos pueden permanecer como código inactivo en
el kernel debug; no equivalen a selección de producción. La inspección del APK y
la validación física siguen pendientes: no se compiló ni instaló esta variante.
