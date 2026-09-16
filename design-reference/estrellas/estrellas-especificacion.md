# Especificación: Mis Estrellas (Rewards Program)

**Referencia Visual:** `screenshot.png`  
**Estado:** Completado — Especificación técnica para implementación en Flutter  
**Fecha:** Septiembre 2026

---

## 1. Layout General

### Estructura Principal
```
┌─────────────────────────────────┐
│ PROGRAMA DE LEALTAD             │
│ Mis Estrellas              ¡Gracias por ser parte!
│ Cada compra te acerca a más beneficios
│
│ ┌─────────────────────────────┐ │
│ │ ⭐ ⭐ ⭐ ⭐ ⭐              │ │
│ │ ⭐ ⭐ ⭐ ⭐ ⭐              │ │
│ │ ⭐ ⭐ ⭐ ⭐ ⭐*              │ │ (* = Especial dorada)
│ └─────────────────────────────┘ │
│
│ ESTRELLA ACTUAL
│ ◯ (1/15)      Especial
│                Te faltan 6 estrellas para desbloquear
│                tu próximo premio
│
│ 🎁 Más estrellas, más premios
│    Canjea tus estrellas por increíbles beneficios.
│
└─────────────────────────────────┘
```

### Padding y Márgenes
- **Top margin:** 12px
- **Horizontal padding (contenedor):** 16px
- **Bottom spacing (antes de botón):** 24px
- **Gap entre estrellas (grid):** 12px (horizontal y vertical)

---

## 2. Colores

### Paleta Principal
| Elemento | Hex | RGB | Uso |
|----------|-----|-----|-----|
| Fondo | #0d0d0d | 13, 13, 13 | Fondo de pantalla |
| Border contenedor | #8B7355 | 139, 115, 85 | Border dorado del grid |
| Estrella inactiva (outline) | #444444 | 68, 68, 68 | Estrellas sin desbloquear |
| Estrella activa | #FFD700 | 255, 215, 0 | Estrella Especial (llena) |
| Glow/Brillo | #FFC107 | 255, 193, 7 | Efecto alrededor de estrella activa |
| Texto principal | #FFFFFF | 255, 255, 255 | Títulos, "Mis Estrellas" |
| Texto secundario | #999999 | 153, 153, 153 | Subtítulos, descripciones |
| Dorado accento | #D4AF37 | 212, 175, 55 | "PROGRAMA DE LEALTAD", "¡Gracias..." |
| Texto botón | #FFFFFF | 255, 255, 255 | Texto en botón CTA |
| Fondo circular progreso | #1a1a1a | 26, 26, 26 | Círculo de progreso (fondo) |
| Borde circular progreso | #FFD700 | 255, 215, 0 | Arco de progreso (1/15) |

---

## 3. Tipografía

### Fuentes
- **Display/Títulos:** Cinzel Bold (ya en proyecto Celtas)
- **Cuerpo:** Manrope Regular (ya en proyecto Celtas)

### Estilos de Texto

| Sección | Texto | Peso | Tamaño | Color | Altura línea |
|---------|-------|------|--------|-------|--------------|
| Header pequeño | PROGRAMA DE LEALTAD | Regular | 10px | #D4AF37 | 1.2 |
| Título principal | Mis Estrellas | Bold | 32px | #FFFFFF | 1.2 |
| Subtítulo | Cada compra te acerca... | Regular | 14px | #999999 | 1.5 |
| Agradecimiento derecha | ¡Gracias por ser parte! | Regular | 12px | #D4AF37 | 1.4 |
| Label Premio | Premio 1 / Premio 2 | Regular | 12px | #999999 | 1.2 |
| Label Especial | Especial | Medium | 14px | #FFD700 | 1.2 |
| Sección título | ESTRELLA ACTUAL | Regular | 12px | #D4AF37 | 1.2 |
| Estrella actual nombre | Especial | Bold | 28px | #FFFFFF | 1.2 |
| Texto faltante | Te faltan 6 estrellas... | Regular | 14px | #999999 | 1.5 |
| Botón texto | Más estrellas, más premios | Medium | 16px | #FFFFFF | 1.4 |
| Botón descripción | Canjea tus estrellas... | Regular | 13px | #999999 | 1.4 |
| Progreso circular | 1/15 | Regular | 18px | #FFD700 | 1.2 |

---

## 4. Grid de Estrellas

### Especificaciones
- **Columnas:** 5
- **Filas:** 3
- **Total:** 15 estrellas
- **Tamaño por estrella (círculo):** 48px × 48px
- **Stroke width (outline):** 2px
- **Gap horizontal:** 12px
- **Gap vertical:** 12px
- **Border radius del contenedor:** 12px

### Estados de Estrella

#### Inactiva (Desacreditada)
```
Apariencia:
- Círculo gris: #444444
- Outline: 2px #666666
- Icono: ☆ (outline, gris)
- Sin efecto
```

#### Activa/Especial (Desbloqueada - Dorada)
```
Apariencia:
- Círculo: #FFD700
- Icono: ★ (llena, amarillo)
- Glow/Brillo: shadow radial #FFC107, blur 16px, spread 2px
- Posición: esquina inferior derecha (última estrella)
- Label: "Especial" (badge debajo)
```

#### Descripción bajo Estrellas
- "Premio 1" bajo fila 1, columna 2
- "Premio 2" bajo fila 1, columna 4

---

## 5. Sección "Estrella Actual"

### Circular Progreso

#### Especificaciones
- **Diámetro total:** 80px
- **Ancho del arco:** 6px
- **Fondo del arco:** #333333 (gris oscuro)
- **Arco de progreso:** #FFD700 (dorado)
- **Progreso:** 1/15 = 6.67% (arco muy pequeño)
- **Texto dentro:** "1/15" (18px, bold, dorado)
- **Posición:** Izquierda, alineado con la sección de texto

### Información Textual

```
ESTRELLA ACTUAL
Especial
Te faltan 6 estrellas para desbloquear
tu próximo premio

Tipografía:
- "ESTRELLA ACTUAL": 12px, regular, #D4AF37
- "Especial": 28px, bold, #FFFFFF
- "Te faltan...": 14px, regular, #999999
```

### Layout de la Sección
```
┌─ Sección "ESTRELLA ACTUAL" ─┐
│  [Circular: 1/15]  Especial │
│                    Te faltan 6 estrellas...
└────────────────────────────┘

- Espacio entre circular y texto: 16px
- Circular: 80px × 80px
- Texto apilado verticalmente a la derecha
```

---

## 6. Botón CTA

### "Más Estrellas, Más Premios"

#### Especificaciones
- **Tipo:** Button con icono + texto
- **Icono:** 🎁 (regalo, 20px)
- **Texto principal:** "Más estrellas, más premios" (16px, medium)
- **Texto secundario:** "Canjea tus estrellas por increíbles beneficios." (13px, regular, gris)
- **Altura:** 64px
- **Padding:** 12px (vertical), 16px (horizontal)
- **Border radius:** 8px
- **Fondo:** #1a1a1a (ligeramente más claro que fondo)
- **Border:** 1px #666666 (gris oscuro)
- **Icono chevron derecha:** > (12px, #999999, extremo derecho)
- **Alignment:** Text a la izquierda, chevron a la derecha

#### Estados
- **Normal:** Border gris oscuro, fondo oscuro
- **Hover:** Border más claro (#888888), fondo ligeramente más claro
- **Press:** Escala 0.98, feedback háptico

---

## 7. Contenedor Principal

### Tarjeta/Container
- **Border:** 1px sólido #8B7355 (dorado oscuro)
- **Border radius:** 12px
- **Background:** Gradient sutil (fondo oscuro a ligeramente más oscuro)
- **Padding interno:** 16px (todos lados)
- **Margin:** 0px top, 16px horizontal, 16px bottom
- **Shadow:** elevation 1 (sombra muy sutil)

---

## 8. Header Superior

### Encabezado Dorado
```
PROGRAMA DE LEALTAD                   ¡Gracias por ser parte! ❤️
```

- **Posición:** Top del contenedor
- **Estilo izquierda:** 10px, regular, #D4AF37
- **Estilo derecha:** 12px, regular, #D4AF37, italic
- **Corazón:** ❤️ emoji, 12px, dorado
- **Justificado:** space-between

---

## 9. Variantes / Edge Cases

### Usuario con 0 Estrellas
```
ESTRELLA ACTUAL
Ninguna
Te faltan 15 estrellas para desbloquear
tu primer premio

- Progreso: 0/15 (sin arco visible)
- Todas las 15 estrellas: inactivas (grises)
- Botón: activo e invitador
```

### Usuario con 15 Estrellas (Todo Desbloqueado)
```
ESTRELLA ACTUAL
¡Todas las estrellas desbloqueadas!
Tienes disponibles 3 premios especiales

- Progreso: 15/15 (arco completo)
- Todas las 15 estrellas: activas (doradas)
- Botón: llevar a pantalla de canje
```

### Usuario en Progreso (5/15)
```
ESTRELLA ACTUAL
Dorado
Te faltan 10 estrellas para desbloquear
tu próximo premio

- Progreso: 5/15 (33.3% del arco)
- 5 primeras estrellas: doradas, resto: grises
- Botón: activo
```

---

## 10. Responsividad

### Breakpoints
- **Mobile (default):** <600px
  - Grid 5 columnas × 3 filas (como en foto)
  - Padding: 16px
  - Texto: tamaños base

- **Tablet (futuro):** >600px
  - Grid 6 columnas × 3 filas (opcional)
  - Padding: 24px
  - Texto: +2px

---

## 11. Animaciones

### Transiciones
- **Hover en estrella:** Escala 1.1, 200ms ease-out
- **Hover en botón:** Background +5% brillo, 200ms ease-out
- **Progress circular:** Animación del arco al cambiar progreso: 600ms ease-out

### Efectos Especiales
- **Estrella activa (Especial):** Glow continuo (pulse sutil, 2s infinito)
- **Entrada de pantalla:** Fade-in suave de 400ms

---

## 12. Integración con Bottom Nav

La pantalla es accesible desde:
- **Bottom nav tab:** "Estrellas" (icono ⭐, dorado cuando activo)
- **Position:** Tab 4 de 5
- **Label:** "Estrellas"

---

## 13. Notas de Implementación Flutter

### Widgets Recomendados
```dart
Scaffold(
  body: SingleChildScrollView(
    child: Column(
      children: [
        // Header dorado
        // Grid de estrellas (GridView)
        // Sección "Estrella Actual" (Row con CircularProgressIndicator)
        // Botón CTA (GestureDetector o Button)
      ],
    ),
  ),
  bottomNavigationBar: // BottomNavBar existente
)
```

### Variables a Extraer
```dart
// Colores
const celtas_dark = Color(0xFF0d0d0d);
const celtas_gold = Color(0xFFFFD700);
const celtas_gold_glow = Color(0xFFFFC107);
const celtas_gray_text = Color(0xFF999999);

// Tamaños
const star_size = 48.0;
const grid_gap = 12.0;
const circular_size = 80.0;
const border_radius = 12.0;
```

### Data Needed
```dart
// Modelo Reward
class RewardState {
  int totalStars;           // Ej: 15
  int currentStars;         // Ej: 1
  String currentMilestone;  // Ej: "Especial"
  int starsNeeded;          // Ej: 6
  List<String> unlockedPrizes;
}
```

---

## 14. Checklist de Implementación

- [ ] Grid de 5×3 estrellas renderizado correctamente
- [ ] Estrella Especial (última) con efecto glow
- [ ] Circular progreso con arco dinámico (1/15)
- [ ] Colores exactos de la paleta
- [ ] Tipografía Cinzel/Manrope con tamaños correctos
- [ ] Botón CTA con icono y chevron
- [ ] Responsive: se ve bien en phones pequeños
- [ ] Animaciones suaves (hover, glow, entrada)
- [ ] Bottom nav tab funciona correctamente
- [ ] Edge cases probados (0 estrellas, 15 estrellas)

---

**Generado:** Septiembre 16, 2026  
**Basado en:** Foto exacta compartida por el usuario  
**Listo para:** Implementación en Flutter
