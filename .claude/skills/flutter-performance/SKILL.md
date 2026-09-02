---
name: flutter-performance
description: Convenciones y comandos reales para auditar rendimiento, tamaño de build y código muerto en la app Flutter de Celtas. Usar junto con el subagente performance-agent, o cuando cualquier sesión necesite verificar el impacto de rendimiento de un cambio (ej. agregar una dependencia pesada, una imagen grande, una lista larga).
license: MIT
metadata:
  project: celtas-mobile
  audience: claude-code
---

## Cuándo usar esta skill

Al auditar o mejorar rendimiento/tamaño de la app, o al evaluar si un cambio nuevo (dependencia,
asset, pantalla con listas largas) tiene impacto de rendimiento que valga la pena revisar antes
de mergear.

## Regla de oro (heredada de todo el proyecto)

Ningún hallazgo de "esto no se usa" o "esto es lento" se acepta sin evidencia real —
comando + salida real, nunca una suposición. Ya nos mordió varias veces en este proyecto asumir
sin verificar (el `api.d.ts` fabricado, el bug de `merge()`, el desfase de `daysOfWeek`).
Rendimiento no es diferente: un "debería ser más rápido" sin medir es la misma clase de error.

## Comandos reales para cada tipo de auditoría

### Dependencias declaradas pero sin uso real
```bash
# Para cada dependencia en pubspec.yaml, confirma su import real:
grep -rn "package:NOMBRE_PAQUETE" lib/ test/
```
Si no hay ningún resultado, es candidata a eliminar de `pubspec.yaml` — pero confirma también
que no se usa de forma indirecta (ej. un plugin nativo referenciado solo desde
`android/app/build.gradle.kts` o `ios/Podfile`, sin import Dart directo).

### Tamaño real del build
```bash
flutter build apk --analyze-size --target-platform=android-arm64
```
Genera un reporte real de qué ocupa espacio — úsalo antes de asumir qué es "lo pesado".

### Assets sin referenciar
```bash
# Lista todos los assets declarados en pubspec.yaml, luego confirma cada uno:
grep -rn "assets/branding/NOMBRE_ARCHIVO" lib/
```
Ojo: algunos assets se referencian solo desde `pubspec.yaml` (ej. la config de
`flutter_launcher_icons`/`flutter_native_splash`, ver Sección 4 del manual del proyecto) — esos
NO están "sin usar" aunque no aparezcan en ningún `.dart`.

### Análisis estático general
```bash
flutter analyze
dart fix --dry-run   # sugerencias automáticas de limpieza, revisar antes de aplicar
```

### Tests completos después de cualquier cambio
```bash
flutter test
```
No se considera "seguro" ningún cambio de limpieza/rendimiento sin esto en verde.

## Convenciones específicas del proyecto a respetar

- El parser SVG propio (`lib/shared/widgets/svg_path.dart`) es zona de riesgo conocida (2 bugs
  de clase reales encontrados aquí) — cualquier "optimización" de ese archivo necesita
  verificación visual en dispositivo real, no solo que los tests pasen.
- `cached_network_image` ya está en uso para imágenes de red (productos, banners) — no lo
  reemplaces por otra librería sin justificación real y medida.
- El interceptor de `dio` (cola de pendientes durante refresh) ya fue optimizado y endurecido a
  fondo (ver el módulo 1 del `ROADMAP.md`) — no lo toques buscando rendimiento sin una razón
  medida y concreta, es código sensible con historial de bugs sutiles ya resueltos.
- Las fuentes (Cinzel, Manrope) vienen de `google_fonts`, no empaquetadas — confirma qué pesos
  específicos se usan realmente (`grep -rn "GoogleFonts.cinzel\|GoogleFonts.manrope" lib/`)
  antes de asumir cuáles se pueden recortar.

## Formato de reporte esperado

Todo hallazgo de "código muerto" o "dependencia sin usar" debe presentarse como una lista para
confirmar, no como una acción ya hecha — ver el formato completo en `performance-agent.md`.
