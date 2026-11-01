import 'dart:typed_data';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// UI 전용 변환. 측정/worker에는 Flutter Path를 전달하지 않는다.
Path displayPath(Float64List commands, int fill) {
  final path = Path()
    ..fillType = fill == 0 ? PathFillType.evenOdd : PathFillType.nonZero;
  for (var i = 0; i < commands.length;) {
    final op = commands[i++].toInt();
    switch (op) {
      case 0:
        path.moveTo(commands[i++], commands[i++]);
      case 1:
        path.lineTo(commands[i++], commands[i++]);
      case 2:
        path.cubicTo(
          commands[i++],
          commands[i++],
          commands[i++],
          commands[i++],
          commands[i++],
          commands[i++],
        );
      case 3:
        path.close();
      default:
        throw StateError('unsupported outline command');
    }
  }
  return path;
}

class DisplayItem {
  DisplayItem(this.result, this.path, this.shift);
  final Map<String, Object?> result;
  final Path path;
  final Offset shift;
  Rect? get box {
    final b = result['bounds'] as List<double>?;
    return b == null
        ? null
        : Rect.fromLTRB(
            b[0] + shift.dx,
            b[1] + shift.dy,
            b[2] + shift.dx,
            b[3] + shift.dy,
          );
  }
}

class OutlinePainter extends CustomPainter {
  OutlinePainter(this.items, {this.cull = true});
  final List<DisplayItem> items;
  final bool cull;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(Colors.white, BlendMode.src);
    canvas.translate(30, 310);
    canvas.scale(4, -4);
    final clip = canvas.getLocalClipBounds();
    for (final item in items) {
      final box = item.box;
      if (cull && box != null && !clip.overlaps(box.inflate(2))) continue;
      canvas.save();
      canvas.translate(item.shift.dx, item.shift.dy);
      canvas.drawPath(item.path, Paint()..color = const Color(0xff193d5d));
      final b = item.result['bounds'] as List<double>?;
      if (b != null) {
        canvas.drawRect(
          Rect.fromLTRB(b[0], b[1], b[2], b[3]),
          Paint()
            ..color = Colors.teal
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.12,
        );
        canvas.drawCircle(
          Offset((b[0] + b[2]) / 2, (b[1] + b[3]) / 2),
          0.45,
          Paint()..color = Colors.red,
        );
      }
      canvas.drawLine(
        const Offset(38, 25),
        const Offset(42, 25),
        Paint()
          ..color = Colors.orange
          ..strokeWidth = 0.12,
      );
      canvas.drawLine(
        const Offset(40, 23),
        const Offset(40, 27),
        Paint()
          ..color = Colors.orange
          ..strokeWidth = 0.12,
      );
      final origin = item.result['origin'] as List<double>;
      canvas.drawLine(
        Offset(origin[0], origin[1]),
        Offset(
          origin[0] + 4 * math.cos(item.result['angle'] as double),
          origin[1] + 4 * math.sin(item.result['angle'] as double),
        ),
        Paint()
          ..color = Colors.purple
          ..strokeWidth = 0.15,
      );
      canvas.drawCircle(
        Offset(origin[0], origin[1]),
        0.35,
        Paint()..color = Colors.purple,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(OutlinePainter old) =>
      old.items != items || old.cull != cull;
}
