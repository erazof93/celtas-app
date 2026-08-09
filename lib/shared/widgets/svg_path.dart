import 'dart:math' as math;
import 'dart:ui';

/// Parser de paths SVG para los logos del mockup (llama de Celtas y "G" de
/// Google). Flutter no expone `Path.parse`, así que este helper traduce el `d`
/// del SVG a un [Path] de dart:ui.
///
/// Soporta la gramática completa de paths SVG: comandos `M L H V C S Q T A Z`
/// y sus variantes relativas en minúscula, notación compacta (`M4 20` sin
/// espacio entre comando y coordenada) y repetición implícita de parámetros
/// (pares extra tras `M`/`L`/etc. sin repetir el comando).
Path parseSvgPath(String d) {
  final path = Path();
  final tokens = _tokenize(d);
  var i = 0;

  double? x, y; // cursor actual
  double? subpathStartX, subpathStartY;
  double? lastCubicControlX, lastCubicControlY;
  double? lastQuadControlX, lastQuadControlY;

  double? readNumber() {
    if (i >= tokens.length) return null;
    final token = tokens[i];
    if (_isCommand(token)) return null;
    i++;
    return double.parse(token);
  }

  String? readCommand() {
    if (i >= tokens.length) return null;
    final token = tokens[i];
    if (!_isCommand(token)) return null;
    i++;
    return token;
  }

  void moveTo(double nx, double ny, {required bool relative}) {
    if (relative) {
      nx += x ?? 0;
      ny += y ?? 0;
    }
    path.moveTo(nx, ny);
    x = nx;
    y = ny;
    subpathStartX = nx;
    subpathStartY = ny;
    lastCubicControlX = null;
    lastCubicControlY = null;
    lastQuadControlX = null;
    lastQuadControlY = null;
  }

  void lineTo(double nx, double ny, {required bool relative}) {
    if (relative) {
      nx += x ?? 0;
      ny += y ?? 0;
    }
    path.lineTo(nx, ny);
    x = nx;
    y = ny;
    lastCubicControlX = null;
    lastCubicControlY = null;
    lastQuadControlX = null;
    lastQuadControlY = null;
  }

  void horizontalTo(double nx, {required bool relative}) {
    if (relative) nx += x ?? 0;
    path.lineTo(nx, y!);
    x = nx;
    lastCubicControlX = null;
    lastCubicControlY = null;
    lastQuadControlX = null;
    lastQuadControlY = null;
  }

  void verticalTo(double ny, {required bool relative}) {
    if (relative) ny += y ?? 0;
    path.lineTo(x!, ny);
    y = ny;
    lastCubicControlX = null;
    lastCubicControlY = null;
    lastQuadControlX = null;
    lastQuadControlY = null;
  }

  void cubicTo(
    double c1x,
    double c1y,
    double c2x,
    double c2y,
    double nx,
    double ny, {
    required bool relative,
  }) {
    if (relative) {
      c1x += x ?? 0;
      c1y += y ?? 0;
      c2x += x ?? 0;
      c2y += y ?? 0;
      nx += x ?? 0;
      ny += y ?? 0;
    }
    path.cubicTo(c1x, c1y, c2x, c2y, nx, ny);
    lastCubicControlX = c2x;
    lastCubicControlY = c2y;
    lastQuadControlX = null;
    lastQuadControlY = null;
    x = nx;
    y = ny;
  }

  void smoothCubicTo(
    double c2x,
    double c2y,
    double nx,
    double ny, {
    required bool relative,
  }) {
    final c1x = lastCubicControlX != null ? 2 * x! - lastCubicControlX! : x!;
    final c1y = lastCubicControlY != null ? 2 * y! - lastCubicControlY! : y!;
    cubicTo(c1x, c1y, c2x, c2y, nx, ny, relative: relative);
  }

  void quadTo(
    double cx,
    double cy,
    double nx,
    double ny, {
    required bool relative,
  }) {
    if (relative) {
      cx += x ?? 0;
      cy += y ?? 0;
      nx += x ?? 0;
      ny += y ?? 0;
    }
    path.quadraticBezierTo(cx, cy, nx, ny);
    lastQuadControlX = cx;
    lastQuadControlY = cy;
    lastCubicControlX = null;
    lastCubicControlY = null;
    x = nx;
    y = ny;
  }

  void smoothQuadTo(double nx, double ny, {required bool relative}) {
    final cx = lastQuadControlX != null ? 2 * x! - lastQuadControlX! : x!;
    final cy = lastQuadControlY != null ? 2 * y! - lastQuadControlY! : y!;
    quadTo(cx, cy, nx, ny, relative: relative);
  }

  void arcTo(
    double rx,
    double ry,
    double rotation,
    bool largeArc,
    bool sweep,
    double nx,
    double ny, {
    required bool relative,
  }) {
    if (relative) {
      nx += x ?? 0;
      ny += y ?? 0;
    }
    _appendArc(path, x!, y!, rx, ry, rotation, largeArc, sweep, nx, ny);
    x = nx;
    y = ny;
    lastCubicControlX = null;
    lastCubicControlY = null;
    lastQuadControlX = null;
    lastQuadControlY = null;
  }

  void closePath() {
    path.close();
    x = subpathStartX;
    y = subpathStartY;
    lastCubicControlX = null;
    lastCubicControlY = null;
    lastQuadControlX = null;
    lastQuadControlY = null;
  }

  // El path SVG debe empezar con un comando M/m.
  var command = readCommand();
  if (command == null || (command != 'M' && command != 'm')) {
    throw ArgumentError('El path SVG debe empezar con un comando M/m: $d');
  }

  while (i < tokens.length) {
    // Si el siguiente token es un comando, lo leemos; si no, repetimos el
    // comando anterior (repetición implícita de parámetros).
    final next = readCommand();
    if (next != null) command = next;

    switch (command) {
      case 'M':
      case 'm':
        final nx = readNumber();
        final ny = readNumber();
        if (nx == null || ny == null) {
          throw ArgumentError('Comando $command requiere 2 coordenadas: $d');
        }
        moveTo(nx, ny, relative: command == 'm');
        // Pares adicionales tras M se tratan como L.
        while (i < tokens.length && !_isCommand(tokens[i])) {
          final lx = readNumber();
          final ly = readNumber();
          if (lx == null || ly == null) break;
          lineTo(lx, ly, relative: command == 'm');
        }
        break;
      case 'L':
      case 'l':
        while (i < tokens.length && !_isCommand(tokens[i])) {
          final nx = readNumber();
          final ny = readNumber();
          if (nx == null || ny == null) break;
          lineTo(nx, ny, relative: command == 'l');
        }
        break;
      case 'H':
      case 'h':
        while (i < tokens.length && !_isCommand(tokens[i])) {
          final nx = readNumber();
          if (nx == null) break;
          horizontalTo(nx, relative: command == 'h');
        }
        break;
      case 'V':
      case 'v':
        while (i < tokens.length && !_isCommand(tokens[i])) {
          final ny = readNumber();
          if (ny == null) break;
          verticalTo(ny, relative: command == 'v');
        }
        break;
      case 'C':
      case 'c':
        while (i < tokens.length && !_isCommand(tokens[i])) {
          final c1x = readNumber();
          final c1y = readNumber();
          final c2x = readNumber();
          final c2y = readNumber();
          final nx = readNumber();
          final ny = readNumber();
          if (c1x == null ||
              c1y == null ||
              c2x == null ||
              c2y == null ||
              nx == null ||
              ny == null) {
            break;
          }
          cubicTo(c1x, c1y, c2x, c2y, nx, ny, relative: command == 'c');
        }
        break;
      case 'S':
      case 's':
        while (i < tokens.length && !_isCommand(tokens[i])) {
          final c2x = readNumber();
          final c2y = readNumber();
          final nx = readNumber();
          final ny = readNumber();
          if (c2x == null || c2y == null || nx == null || ny == null) break;
          smoothCubicTo(c2x, c2y, nx, ny, relative: command == 's');
        }
        break;
      case 'Q':
      case 'q':
        while (i < tokens.length && !_isCommand(tokens[i])) {
          final cx = readNumber();
          final cy = readNumber();
          final nx = readNumber();
          final ny = readNumber();
          if (cx == null || cy == null || nx == null || ny == null) break;
          quadTo(cx, cy, nx, ny, relative: command == 'q');
        }
        break;
      case 'T':
      case 't':
        while (i < tokens.length && !_isCommand(tokens[i])) {
          final nx = readNumber();
          final ny = readNumber();
          if (nx == null || ny == null) break;
          smoothQuadTo(nx, ny, relative: command == 't');
        }
        break;
      case 'A':
      case 'a':
        while (i < tokens.length && !_isCommand(tokens[i])) {
          final rx = readNumber();
          final ry = readNumber();
          final rot = readNumber();
          final laf = readNumber();
          final sf = readNumber();
          final nx = readNumber();
          final ny = readNumber();
          if (rx == null ||
              ry == null ||
              rot == null ||
              laf == null ||
              sf == null ||
              nx == null ||
              ny == null) {
            break;
          }
          arcTo(rx, ry, rot, laf != 0, sf != 0, nx, ny,
              relative: command == 'a');
        }
        break;
      case 'Z':
      case 'z':
        closePath();
        break;
      default:
        throw ArgumentError('Comando SVG no soportado: $command');
    }
  }

  return path;
}

bool _isCommand(String token) =>
    token.length == 1 && RegExp(r'^[a-zA-Z]$').hasMatch(token);

/// Tokeniza el `d` en comandos (letras) y números (enteros, decimales y
/// notación científica), ignorando espacios y comas.
List<String> _tokenize(String d) {
  final tokens = <String>[];
  final re = RegExp(r'[a-zA-Z]|-?\d*\.?\d+(?:[eE][+-]?\d+)?');
  for (final match in re.allMatches(d)) {
    tokens.add(match.group(0)!);
  }
  return tokens;
}

/// Convierte un arco SVG (parámetros del comando A/a) a curvas de Bézier
/// cúbicas y las agrega al [path]. Implementa el algoritmo de parametrización
/// por punto final de la especificación SVG (F.6.5).
void _appendArc(
  Path path,
  double x1,
  double y1,
  double rx,
  double ry,
  double phiDeg,
  bool largeArc,
  bool sweep,
  double x2,
  double y2,
) {
  rx = rx.abs();
  ry = ry.abs();
  if (rx == 0 || ry == 0 || (x1 == x2 && y1 == y2)) {
    path.lineTo(x2, y2);
    return;
  }

  final phi = phiDeg * math.pi / 180;
  final cosPhi = math.cos(phi);
  final sinPhi = math.sin(phi);

  // Paso 1: coordenadas del punto medio en el sistema rotado.
  final dx2 = (x1 - x2) / 2;
  final dy2 = (y1 - y2) / 2;
  final x1p = cosPhi * dx2 + sinPhi * dy2;
  final y1p = -sinPhi * dx2 + cosPhi * dy2;

  // Paso 2: corrección de radios si el arco es demasiado grande.
  final lambda = (x1p * x1p) / (rx * rx) + (y1p * y1p) / (ry * ry);
  if (lambda > 1) {
    final scale = math.sqrt(lambda);
    rx *= scale;
    ry *= scale;
  }

  // Paso 3: centro del arco en el sistema rotado.
  final sign = largeArc == sweep ? -1.0 : 1.0;
  final num = rx * rx * ry * ry - rx * rx * y1p * y1p - ry * ry * x1p * x1p;
  final den = rx * rx * y1p * y1p + ry * ry * x1p * x1p;
  final coef = sign * math.sqrt((num / den).clamp(0.0, double.infinity));
  final cxp = coef * (rx * y1p / ry);
  final cyp = coef * (-ry * x1p / rx);

  final cx = cosPhi * cxp - sinPhi * cyp + (x1 + x2) / 2;
  final cy = sinPhi * cxp + cosPhi * cyp + (y1 + y2) / 2;

  // Paso 4: ángulos inicial y de barrido.
  final ux = (x1p - cxp) / rx;
  final uy = (y1p - cyp) / ry;
  final vx = (-x1p - cxp) / rx;
  final vy = (-y1p - cyp) / ry;
  final theta1 = _angle(1, 0, ux, uy);
  var dTheta = _angle(ux, uy, vx, vy);
  if (!sweep && dTheta > 0) dTheta -= 2 * math.pi;
  if (sweep && dTheta < 0) dTheta += 2 * math.pi;

  // Paso 5: aproximar el arco con curvas de Bézier cúbicas (~45° por tramo).
  final segments = (dTheta.abs() / (math.pi / 4)).ceil().clamp(1, 12);
  final dt = dTheta / segments;
  var t = theta1;
  var p = _ellipsePoint(cx, cy, rx, ry, cosPhi, sinPhi, t);
  for (var s = 0; s < segments; s++) {
    final t2 = t + dt;
    final p2 = _ellipsePoint(cx, cy, rx, ry, cosPhi, sinPhi, t2);
    final k = 4 / 3 * math.tan(dt / 4);
    final d1 = _ellipseDerivative(rx, ry, cosPhi, sinPhi, t);
    final d2 = _ellipseDerivative(rx, ry, cosPhi, sinPhi, t2);
    path.cubicTo(
      p.dx + k * d1.dx,
      p.dy + k * d1.dy,
      p2.dx - k * d2.dx,
      p2.dy - k * d2.dy,
      p2.dx,
      p2.dy,
    );
    p = p2;
    t = t2;
  }
}

double _angle(double ux, double uy, double vx, double vy) {
  final dot = ux * vx + uy * vy;
  final len = math.sqrt((ux * ux + uy * uy) * (vx * vx + vy * vy));
  var ang = math.acos((dot / len).clamp(-1.0, 1.0));
  if (ux * vy - uy * vx < 0) ang = -ang;
  return ang;
}

Offset _ellipsePoint(
  double cx,
  double cy,
  double rx,
  double ry,
  double cosPhi,
  double sinPhi,
  double t,
) {
  final cosT = math.cos(t);
  final sinT = math.sin(t);
  return Offset(
    cx + rx * cosT * cosPhi - ry * sinT * sinPhi,
    cy + rx * cosT * sinPhi + ry * sinT * cosPhi,
  );
}

Offset _ellipseDerivative(
  double rx,
  double ry,
  double cosPhi,
  double sinPhi,
  double t,
) {
  final cosT = math.cos(t);
  final sinT = math.sin(t);
  return Offset(
    -rx * sinT * cosPhi - ry * cosT * sinPhi,
    -rx * sinT * sinPhi + ry * cosT * cosPhi,
  );
}