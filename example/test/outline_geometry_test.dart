import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:outline_probe/src/outline_geometry.dart';

void main() {
  group('실제 곡선 경계', () {
    const arch = <double>[0, 0, 0, 2, 20 / 3, 40 / 3, 40 / 3, 40 / 3, 20, 0, 3];
    test('2차 포물선의 높이 10은 제어점 높이와 다르다', () {
      final box = exactBounds(arch)!;
      for (var i = 0; i < 4; i++) {
        expect(box[i], closeTo([0, 0, 20, 10][i], 1e-12));
      }
    });
    test('45도 회전 뒤 극점을 다시 구해 사각형 회전과 구분한다', () {
      final box = exactBounds(transformOutline(arch, 1, 1, math.pi / 4))!;
      final expected = [
        -2.5 / math.sqrt2,
        0,
        20 / math.sqrt2,
        22.5 / math.sqrt2,
      ];
      for (var i = 0; i < 4; i++) {
        expect(box[i], closeTo(expected[i], 1e-12));
      }
    });
    test('3차 곡선의 내부 극점 높이는 독립 계산값 9다', () {
      expect(exactBounds([0, 0, 0, 2, 0, 12, 12, 12, 12, 0, 3]), [0, 0, 12, 9]);
    });
    test('선분도 없으면 외곽 없음이며 0 크기 사각형이 아니다', () {
      expect(exactBounds([]), isNull);
    });
    test('비유한 곡선 좌표는 정상 외곽으로 바꾸지 않는다', () {
      expect(
        () => exactBounds([0, 0, 0, 1, double.infinity, 1]),
        throwsStateError,
      );
    });
  });
}
