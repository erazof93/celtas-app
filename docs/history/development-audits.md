# HISTÓRICO — SIN AUTORIDAD OPERATIVA

Síntesis de antecedentes técnicos rescatados el 2026-10-05.
No establece reglas vigentes, pendientes ni resultados actuales de tests.
Para comportamiento actual consulta [arquitectura](../architecture.md),
[negocio](../business-rules.md), [contratos](../backend-integration.md)
y [roadmap](../../ROADMAP.md). Fechas/relatos originales no se reejecutaron aquí.

## Sesión y navegación

- La cola de refresh tuvo un deadlock cuando una request encolada reintentaba
  sin marcar retry y volvía a esperar una cola que no se liberaría.
  Se incorporaron guards y tests de regresión. Investigar allí si aparecen
  requests colgadas; esto no demuestra ausencia de otras carreras.
- Recrear router por cada cambio auth devolvía al Splash. Se adoptó instancia
  estable y refresh del redirect. Un bootstrap sin scope pasó inadvertido en
  widget tests que agregaban su propio scope.
- Providers de perfil/listas de pedidos/cupones/estrellas retuvieron usuario
  anterior. Se incorporó escucha de identidad desde cada feature para evitar
  dependencia auth hacia todas ellas. No asumir que cubre otros providers.

## Renderizado y UX

- Parser SVG propio requirió gramática completa y correcciones de curvas suaves
  y geometría de iconos. Compilar/unit tests no bastó para detectar todas las
  diferencias visuales: bounds y dispositivo aportaron evidencia adicional.
- SafeArea, tipografía y CTA de checkout tuvieron diferencias visibles en
  Android real. La fidelidad a un mockup no garantiza usabilidad con insets.
- Snackbar/pop tuvo carreras durante navegación desde detalle a carrito.
- Selección obligatoria evolucionó a dropdown/dialog con validación y señal
  “Listo”; no recuperar diseños previos como comportamiento requerido.
- Rewards pasó de grid fijo a hitos configurables y varias iteraciones visuales.
  Loops de animación innecesarios bloquearon pumpAndSettle; se condicionaron
  a los estados que requieren animación.

## Contratos y dominio

- PATCH de direcciones perdió campos por Object.assign de undefined en backend.
  Servidor adoptó merge; Mobile mantiene refetch tras actualización.
  No extrapolar el incidente a prohibir toda respuesta de mutación.
- Opciones evolucionaron de salsas a bebidas/extras/papas, con snapshots,
  required/max y Sin X explícito. Null/[]/omitido dejaron de ser intercambiables.
- Delivery por distancia motivó coordenadas obligatorias en formularios Mobile;
  datos históricos permanecieron nullable.
- Teléfono de checkout pasó de guardar inmediatamente a revisión en dos pasos.
- Rewards evolucionó desde intervalos fijos y vigencia antigua a hitos,
  catálogo especial y fin de mes de Lima. Valores de ejemplos no son constantes.

## FCM, Google y actualización

- Historial local perdió inserciones por carreras de carga/add y add/add;
  se introdujo cola serializada y límite también en memoria.
- Cambio de horario pasó a push de invalidación y timer por nextChangeAt,
  evitando polling. Datos previos durante refresh causaron timers espurios.
- Fallo Google en builds de Play se diagnosticó en asociaciones OAuth de
  package/certificados de firma, incluidas claves anteriores de distribución.
  Se retiraron parches de síntomas y se mantuvo API Google Sign-In 7.
  No se conservan huellas ni identificadores privados en esta síntesis.
- Gate de actualización falló al usar contexto ancestro del Navigator;
  rootNavigatorKey permitió montar diálogo y probar barrera/back.

## Calidad de la evidencia antigua

Las auditorías originales mezclaban conteos de tests, resultados de formato,
observaciones superadas y cambios todavía locales. Algunos tests con fechas
fijas envejecieron; explicaciones de matchers de mocks se corrigieron después.
No transportar esos veredictos a un cierre actual.

Se omitieron claves de proveedor reproducidas históricamente, referencias a
credenciales de E2E, datos de cuentas/pedidos, material de firma y transcripciones.
No se conservaron prompts, instrucciones de herramientas anteriores ni relatos
duplicados. El respaldo externo del desarrollador conserva los originales;
este documento solo retiene antecedentes útiles para investigar regresiones.
