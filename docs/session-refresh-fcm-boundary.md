# Refresh silencioso y frontera FCM/logout

El refresh silencioso comparte un intento por puente de sesión y revisión, desde
la lectura de Secure Storage. Un plazo global de 20 segundos cubre lectura,
HTTP y publicación/persistencia. Al vencer, se liberan las solicitudes que
esperaban, se cancela HTTP y se invalida la condición de las escrituras en cola.
Los fallos de almacenamiento y timeout no se convierten en un 401 ni borran
credenciales. Solo un 401 HTTP confirmado de refresh invalida la sesión; su
borrado se conserva en la cola existente sin bloquear las solicitudes.

Una operación nativa de escritura ya iniciada no puede cancelarse. Logout
mantiene su borrado detrás de ella, y una cuenta nueva mantiene su escritura
detrás del borrado. Las escrituras todavía en cola comprueban identidad, revisión
y vigencia del refresh antes de comenzar; no hay una segunda cola de credenciales.

## Reproducción FCM sin backend real

`fcm_session_race_test.dart` utiliza AuthController real y un servidor simulado
que captura la identidad al despachar una petición e ignora cancelaciones de
peticiones ya aceptadas:

1. La cuenta A inicia PATCH de FCM; el servidor lo retiene.
2. A inicia logout. Se cancela PATCH localmente antes de enviar DELETE.
3. DELETE termina y deja el token de A en null.
4. El servidor termina el PATCH aceptado anteriormente: vuelve a guardar el token.

La reproducción previa a la corrección confirmó que la cancelación local además
ocurría después de iniciar DELETE. La corrección la adelanta y evita nuevos PATCH
durante logout/login, resultados de getToken obsoletos y duplicados por refresh.
La reproducción conserva deliberadamente el paso 4 para documentar el límite.
No demuestra que el backend vigente siempre ejecute ese orden, sino que el
contrato actual no ofrece al cliente una garantía contra ese orden permitido.

## Garantía que necesita cooperación del servidor

No puede garantizarse que un PATCH aceptado no sobreviva a logout solo mediante
CancelToken, revisión local o espera del Future HTTP. Un timeout/cancelación no
acredita que el servidor haya terminado o abortado la transacción.

Se propone evaluar, en una tarea transversal autorizada, un registro por
instalación con una generación/lease validada por el servidor. Logout revoca esa
generación; PATCH de generaciones revocadas se rechaza también al confirmar la
transacción. DELETE debe estar condicionado al registro/generación esperado para
no borrar un registro posterior. La generación debe ser válida entre procesos y
dispositivos, no simplemente el contador en memoria del cliente.

Eso requiere coordinar modelo y contratos de backend/cliente y tests de órdenes
inversos, cambio de cuenta, misma cuenta tras nuevo login y varios dispositivos.
No se implementó ni se modificó backend o contrato HTTP en esta fase. Un DELETE
compensatorio incondicional después de un PATCH tardío podría borrar un registro
nuevo; tampoco sería una solución segura sin esa identificación.
