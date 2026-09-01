# Celtas Core — Reglas y Contexto del Proyecto

Esta skill define los principios arquitectónicos, decisiones de diseño y restricciones no negociables para la app móvil de Celtas.

## Contexto del Ecosistema
- **Frontend:** Flutter + Dart, gestión de estado con **Riverpod**, enrutamiento con **go_router**, cliente HTTP con **dio**.
- **Backend (Producción):** `https://backend-celtas.onrender.com` (NestJS).
- **Documentación API:** Swagger UI en `/docs` y JSON en `/docs-json`. Para esquemas de respuesta exactos, consultar `../celtas-admin/src/types/api.d.ts`.
- **Diseño de Referencia:** HTML/CSS en `design-reference/`. Extraer siempre colores, tipografía y espaciados exactos.

## Reglas No Negociables
1. **Cero Pagos In-App:** El flujo de compra SIEMPRE concluye con redirección a WhatsApp mediante `whatsappUrl`. Nunca implementar pasarelas de pago dentro de la app.
2. **Manejo Seguro de Tokens:** Almacenar ÚNICAMENTE el `refreshToken` en `flutter_secure_storage`. El `accessToken` reside únicamente en memoria.
3. **Instancia Única de Router:** `go_router` debe instanciarse UNA sola vez. Para cambios de estado de autenticación, utilizar `ref.listen` + `router.refresh()`.
4. **ProviderScope:** `ProviderScope` debe envolver la raíz de la app en `main.dart`.

## Historial de Lecciones Aprendidas (Bugs Previos)
- **Deadlock en Interceptor:** Mantener la corrección de la cola de refresh en `lib/core/network/api_client.dart`.
- **Parser SVG:** El archivo `lib/shared/widgets/svg_path.dart` soporta la gramática SVG completa (notación compacta, comandos relativos, arcos). No simplificarlo.
- **Transiciones de Navegación:** No recrear la instancia del router en cambios de auth para prevenir que la navegación se quede pegada en el Splash screen.