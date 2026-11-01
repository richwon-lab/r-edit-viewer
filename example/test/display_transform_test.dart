import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outline_probe/src/display_paths.dart';
import 'package:outline_probe/src/outline_geometry.dart';

void main() {
  testWidgets('확대·이동과 1배/2배 픽셀 출력은 도면 윤곽과 중심을 바꾸지 않는다', (tester) async {
    final commands = Float64List.fromList([
      0,
      38,
      24,
      1,
      42,
      24,
      1,
      42,
      26,
      1,
      38,
      26,
      3,
    ]);
    final original = commands.toList();
    final controller = TransformationController();
    final path = displayPath(commands, 1);
    final result = <String, Object?>{
      'commands': commands,
      'bounds': <double>[38, 24, 42, 26],
      'origin': <double>[38, 24],
      'angle': 0.0,
    };
    final painter = OutlinePainter([DisplayItem(result, path, Offset.zero)]);
    await tester.pumpWidget(
      MaterialApp(
        home: InteractiveViewer(
          transformationController: controller,
          constrained: false,
          child: SizedBox(
            width: 2600,
            height: 1600,
            child: CustomPaint(painter: painter),
          ),
        ),
      ),
    );
    await tester.drag(find.byType(InteractiveViewer), const Offset(-80, -40));
    await tester.pumpAndSettle();
    expect(controller.value, isNot(Matrix4.identity()));
    controller.value = Matrix4.identity()..scaleByDouble(2, 2, 1, 1);
    await tester.pump();
    for (final pixelRatio in [1.0, 2.0]) {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder)..scale(pixelRatio);
      painter.paint(canvas, const Size(800, 600));
      final picture = recorder.endRecording();
      final image = await picture.toImage(
        (800 * pixelRatio).toInt(),
        (600 * pixelRatio).toInt(),
      );
      image.dispose();
      picture.dispose();
      expect(commands, original);
      expect(exactBounds(commands), [38, 24, 42, 26]);
    }
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
}
