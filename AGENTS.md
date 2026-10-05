# Celtas Mobile

App Flutter/Dart de delivery de Celtas. Arquitectura práctica por features:
`data/` (repositorios/modelos), `application/` (estado/DI) y `presentation/`.
Usa Riverpod con providers manuales, go_router, Dio y Freezed/JSON Serializable.
Conserva estos patrones y el comportamiento existente.

## Fuentes y compatibilidad

Prioridad: código vigente → pubspec/configuración → Android/iOS → backend →
tests → Admin como referencia secundaria → documentación vigente → historia.
Para contratos del servidor consulta `../backend-celtas`; `../celtas-admin`
ayuda con reglas compartidas, pero no reemplaza al backend. No modifiques
repositorios vecinos sin autorización.

No inventes endpoints, campos ni envelopes. Preserva compatibilidad con datos
históricos y diferencias entre campo omitido, `null`, vacío y `[]`.
Los precios definitivos los calcula el backend. El checkout crea un pedido
y abre su `whatsappUrl`; no incorpora pagos dentro de la app.

## Sesión y cambios

Access token solo en memoria; refresh token en Flutter Secure Storage.
No expongas tokens, API keys, credenciales ni material de firma en código,
documentación o logs. `.env` se empaqueta en el cliente: no es un almacén
de secretos de servidor. Usa `.env.example` sin valores sensibles.

Edita fuentes de modelos y regenera los outputs cuando la tarea lo requiera;
no edites manualmente `.g.dart` ni `.freezed.dart`. Riverpod no usa codegen.
No cambies versión/build number, identificadores, firma, dependencias o
configuración de distribución fuera del alcance solicitado.

Distingue inspección de comandos que modifican fuentes, generan archivos,
crean cachés o actúan sobre servicios/dispositivos. Respeta restricciones de
cada tarea; incluso analyze/test pueden escribir artefactos. E2E solo con
entorno y dispositivo autorizados: pueden crear pedidos y modificar backend.
Verifica proporcionalmente al cambio; informa comandos ejecutados, resultados
reales y límites. Nunca inventes evidencia ni presentes auditorías históricas
como tests actuales.

Reutiliza tema y widgets existentes. Texto de usuario en español de Perú,
con tuteo. Consulta `design-reference/` únicamente para tareas visuales
relevantes. Sin skills ni subagentes por defecto.

No hagas git add, commit, push, deploy ni release sin autorización explícita.

## Documentación bajo demanda

- [README](README.md): entorno, plataformas y comandos.
- [Arquitectura](docs/architecture.md): bootstrap, estado, router, sesión y FCM.
- [Backend](docs/backend-integration.md): contratos y divergencias.
- [Negocio](docs/business-rules.md): invariantes por feature.
- [Release](docs/release-versioning.md): firma, versiones y gate mínimo.
- [Testing](docs/testing-checklist.md): escenarios y efectos de comandos.
- [Roadmap](ROADMAP.md): pendientes y decisiones, cuando afecten la tarea.

No es obligatorio leer todo el roadmap, docs ni historial antes de trabajar.
