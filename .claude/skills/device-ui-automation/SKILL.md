---
name: device-ui-automation
description: Automatiza pruebas de flujo completo en el dispositivo Android real conectado (celtas-mobile), controlando la app vía adb (capturas + toques simulados) en vez de pedirle al usuario que interactúe manualmente. Usar cuando el usuario pida probar un flujo end-to-end "sin que yo toque el celular", "de forma automática", o pida explícitamente esta skill.
license: MIT
metadata:
  project: celtas-mobile
  audience: claude-code
---

## Cuándo usar esta skill

Solo cuando el usuario pida explícitamente automatizar la prueba (no es el modo por defecto).
El modo por defecto para probar en dispositivo sigue siendo: `flutter run` + Monitor Tool
observando el log, mientras el usuario toca la pantalla — es más barato en tokens/cuota y más
confiable. Esta skill es para cuando el usuario prioriza no tener que interactuar él mismo.

⚠️ Costo: cada captura de pantalla analizada consume una cantidad significativa de tokens
(aprox. 1,000-1,600 por imagen según resolución). Un flujo de 4-5 pasos puede generar 8-12
capturas (una antes y después de cada acción, para verificar). Avisa al usuario si el flujo va
a ser largo y esto va a consumir bastante cuota.

## Prerrequisitos

```bash
adb devices
```
Confirma que el dispositivo aparece como `device` (no `unauthorized` ni `offline`). Si no
aparece, avisa al usuario — no sigas adivinando.

```bash
adb shell wm size
```
Saca la resolución REAL de pantalla del dispositivo — nunca asumas coordenadas de memoria ni
las copies de otro dispositivo. Las coordenadas de toque dependen de esto.

## Flujo de trabajo

1. **Captura el estado actual**:
   ```bash
   adb exec-out screencap -p > /tmp/screen_N.png
   ```
   Lee la imagen para entender qué pantalla es y dónde están los elementos interactuables.

2. **Simula el toque** en la coordenada correspondiente al elemento identificado:
   ```bash
   adb shell input tap X Y
   ```
   Espera un breve momento (`sleep 1` o `sleep 2`) tras el toque para que la UI reaccione
   (animaciones, llamadas a la API) antes de la siguiente captura.

3. **Para campos de texto**, primero toca el campo para enfocarlo, luego:
   ```bash
   adb shell input text "texto%ssin%sespacios%sreales"
   ```
   `adb input text` no maneja espacios directos de forma confiable — usa `%s` como separador,
   o encierra el texto de forma que el shell no lo rompa. Verifica con una captura que el texto
   se escribió correctamente antes de continuar (es un punto común de fallo silencioso).

4. **Vuelve a capturar y verifica** que el toque/texto tuvo el efecto esperado ANTES de asumir
   que puedes seguir al siguiente paso. No encadenes varios toques a ciegas sin confirmar cada
   uno — un toque que falló (coordenada errónea, UI no había terminado de renderizar) invalida
   todos los pasos siguientes sin que te des cuenta.

5. **Repite** hasta completar el flujo pedido.

6. **Al terminar**, reporta: qué pasos se hicieron, qué se vio en cada captura relevante (en
   texto, no reproduzcas las imágenes), y el resultado final — mismo estándar de evidencia que
   el resto del proyecto (cruza contra el log de `flutter run`/Monitor cuando sea posible, no
   confíes solo en la interpretación visual).

## Limitaciones a tener presentes

- No es 100% confiable — una coordenada mal calculada o una animación no terminada puede hacer
  fallar un toque sin que sea evidente en la imagen resultante. Si algo no cuadra, dilo
  explícitamente en vez de asumir que funcionó.
- El teclado del sistema (para inputs de texto) a veces tapa parte de la pantalla en la captura
  — considéralo al calcular dónde está un botón "Guardar"/"Continuar" que puede haber quedado
  detrás del teclado.
- Combina esto con el Monitor Tool sobre el log de `flutter run` cuando sea posible — la
  combinación de "lo que se ve en pantalla" + "lo que realmente pasó en la red" da mucha más
  certeza que cualquiera de los dos por separado.
