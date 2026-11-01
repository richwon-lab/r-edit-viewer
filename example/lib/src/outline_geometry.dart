import 'dart:math' as math;
import 'dart:typed_data';

typedef Box = List<double>;

/// 실험의 독립 수치 경계. control box/Flutter Path.getBounds를 사용하지 않는다.
Box? exactBounds(List<double> commands) {
  double minX = double.infinity,
      minY = double.infinity,
      maxX = double.negativeInfinity,
      maxY = double.negativeInfinity;
  var x = 0.0, y = 0.0, sx = 0.0, sy = 0.0;
  var hasInk = false;
  void add(double x, double y) {
    if (!x.isFinite || !y.isFinite) throw StateError('nonFiniteOutline');
    minX = math.min(minX, x);
    maxX = math.max(maxX, x);
    minY = math.min(minY, y);
    maxY = math.max(maxY, y);
  }

  List<double> extrema(double p0, double p1, double p2, double p3) {
    final a = 3 * (-p0 + 3 * p1 - 3 * p2 + p3),
        b = 2 * (3 * p0 - 6 * p1 + 3 * p2),
        c = -3 * p0 + 3 * p1;
    if (a == 0) return b == 0 ? <double>[] : [-c / b];
    final d = b * b - 4 * a * c;
    if (d < 0) return [];
    final q = -0.5 * (b + (b >= 0 ? 1 : -1) * math.sqrt(d));
    return q == 0 ? [-b / (2 * a)] : [q / a, c / q];
  }

  double cubic(double a, double b, double c, double d, double t) {
    final u = 1 - t;
    return u * u * u * a +
        3 * u * u * t * b +
        3 * u * t * t * c +
        t * t * t * d;
  }

  for (var i = 0; i < commands.length;) {
    final op = commands[i++].toInt();
    if (op == 0) {
      x = commands[i++];
      y = commands[i++];
      sx = x;
      sy = y;
    } else if (op == 1) {
      hasInk = true;
      add(x, y);
      x = commands[i++];
      y = commands[i++];
      add(x, y);
    } else if (op == 2) {
      hasInk = true;
      final x1 = commands[i++],
          y1 = commands[i++],
          x2 = commands[i++],
          y2 = commands[i++],
          x3 = commands[i++],
          y3 = commands[i++];
      add(x, y);
      add(x3, y3);
      for (final t in {...extrema(x, x1, x2, x3), ...extrema(y, y1, y2, y3)}) {
        if (t > 0 && t < 1) {
          add(cubic(x, x1, x2, x3, t), cubic(y, y1, y2, y3, t));
        }
      }
      x = x3;
      y = y3;
    } else if (op == 3) {
      if (x != sx || y != sy) {
        add(x, y);
        add(sx, sy);
      }
      x = sx;
      y = sy;
    } else {
      throw StateError('unknownOutlineCommand $op');
    }
  }
  return hasInk ? [minX, minY, maxX, maxY] : null;
}

Float64List transformOutline(
  List<double> commands,
  double sx,
  double sy,
  double angle, {
  double dx = 0,
  double dy = 0,
}) {
  final out = Float64List(commands.length),
      c = math.cos(angle),
      s = math.sin(angle);
  for (var i = 0; i < commands.length;) {
    final op = commands[i].toInt();
    out[i] = commands[i];
    i++;
    final count = switch (op) {
      0 || 1 => 1,
      2 => 3,
      3 => 0,
      _ => throw StateError('unknown command'),
    };
    for (var j = 0; j < count; j++) {
      final x = commands[i] * sx, y = commands[i + 1] * sy;
      out[i] = c * x - s * y + dx;
      out[i + 1] = s * x + c * y + dy;
      i += 2;
    }
  }
  return out;
}

Map<String, Object?> prepareRun(
  Map<String, dynamic> native,
  int upem,
  String text,
  double width,
  double angle,
) {
  final timer = Stopwatch()..start();
  final raw = (native['commands'] as List)
      .cast<num>()
      .map((n) => n.toDouble())
      .toList();
  final local = transformOutline(raw, 3 / upem * width, 3 / upem, 0);
  final rotated = transformOutline(local, 1, 1, angle);
  final before = exactBounds(rotated); // 실제 회전 곡선의 극점을 다시 계산한다.
  final dx = before == null ? 0.0 : 40 - (before[0] + before[2]) / 2;
  final dy = before == null ? 0.0 : 25 - (before[1] + before[3]) / 2;
  final aligned = transformOutline(rotated, 1, 1, 0, dx: dx, dy: dy);
  final after = exactBounds(aligned);
  return {
    'text': text,
    'glyphs': Uint32List.fromList((native['glyphs'] as List).cast<int>()),
    'clusters': Uint32List.fromList((native['clusters'] as List).cast<int>()),
    'advances': Float64List.fromList(
      (native['advances'] as List)
          .cast<num>()
          .map((n) => n.toDouble())
          .toList(),
    ),
    'offsetX': Float64List.fromList(
      (native['offsetX'] as List).cast<num>().map((n) => n.toDouble()).toList(),
    ),
    'offsetY': Float64List.fromList(
      (native['offsetY'] as List).cast<num>().map((n) => n.toDouble()).toList(),
    ),
    'commands': aligned,
    'fill': native['fill'],
    'localBounds': exactBounds(local),
    'beforeBounds': before,
    'bounds': after,
    'translation': [dx, dy],
    'origin': [dx, dy],
    'width': width,
    'angle': angle,
    'emMm': 3.0,
    'shapeMs': native['shapeMs'],
    'outlineMs': native['outlineMs'],
    'boundsMs': timer.elapsedMicroseconds / 1000,
    'error': after == null
        ? null
        : [(after[0] + after[2]) / 2 - 40, (after[1] + after[3]) / 2 - 25],
  };
}

int payloadBytes(Map<String, Object?> result) {
  var n = 512 + (result['text'] as String).length * 2;
  for (final value in result.values) {
    if (value is TypedData) n += value.lengthInBytes;
  }
  return n;
}
