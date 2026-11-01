import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:outline_probe/src/native_font.dart';
import 'package:outline_probe/src/outline_geometry.dart';
import 'package:outline_probe/src/worker_pool.dart';

const dll = 'build/native/Release/outline_probe_native.dll';
const font = r'C:\Windows\Fonts\H2GTRE.TTF';

Map<String, Object?> comparable(Map<String, Object?> value) => {
  for (final e in value.entries)
    if (!['shapeMs', 'outlineMs', 'boundsMs'].contains(e.key)) e.key: e.value,
};
void main() {
  if (!Platform.isWindows) return;
  group('실제 face와 worker 수명', () {
    test('공백과 원문을 보존하며 해제 후에도 윤곽과 정렬값을 사용한다', () {
      final context = NativeFont(dll, font);
      final value = context.batch([' Hxg 한글  ', '   ']);
      context.close();
      context.close();
      expect(value['upem'], 1024);
      final runs = value['runs'] as List;
      final ink = prepareRun(
        runs[0] as Map<String, dynamic>,
        1024,
        ' Hxg 한글  ',
        .8,
        math.pi / 4,
      );
      final space = prepareRun(
        runs[1] as Map<String, dynamic>,
        1024,
        '   ',
        1,
        0,
      );
      expect(ink['text'], ' Hxg 한글  ');
      expect((ink['glyphs'] as List).length, 9);
      expect((ink['glyphs'] as List).contains(0), isFalse);
      expect(ink['error'], everyElement(closeTo(0, 1e-9)));
      expect(
        exactBounds((ink['commands'] as List).cast<double>()),
        ink['bounds'],
      );
      expect(space['bounds'], isNull);
      expect(
        (space['advances'] as List).fold<num>(0, (a, b) => a + (b as num)),
        greaterThan(0),
      );
    });
    test('누락 파일을 다른 글꼴이나 빈 윤곽으로 대체하지 않는다', () {
      expect(
        () => NativeFont(dll, r'C:\missing-outline-probe-font.ttf'),
        throwsA(
          isA<ProbeFault>().having((e) => e.stage, '실패 단계', 'openFontFile'),
        ),
      );
    });
    test('지원하지 않는 결합 문자를 명시적으로 거부한다', () {
      final context = NativeFont(dll, font);
      try {
        expect(
          () => context.batch(['a\u0301']),
          throwsA(
            isA<ProbeFault>().having(
              (e) => e.stage,
              '실패 단계',
              'unsupportedCharacter',
            ),
          ),
        );
      } finally {
        context.close();
      }
    });
    test('1개와 4개 isolate가 순서와 실제 glyph 배치·윤곽을 동일하게 반환한다', () async {
      final a = await ProbePool.open(1, dll, font),
          b = await ProbePool.open(4, dll, font);
      try {
        final texts = List.generate(100, (i) => ' Hxg 한글 $i  ');
        final x = await a.run(texts, reuse: false),
            y = await b.run(texts, reuse: false);
        final first = (x['results'] as List).cast<Map<String, Object?>>();
        final second = (y['results'] as List).cast<Map<String, Object?>>();
        for (var i = 0; i < texts.length; i++) {
          expect(first[i]['text'], texts[i]);
          expect(
            jsonEncode(comparable(first[i])),
            jsonEncode(comparable(second[i])),
          );
        }
      } finally {
        await a.close();
        await b.close();
      }
    });
    test('취소한 결과를 최신 결과로 반환하지 않고 다음 작업은 독립 수행한다', () async {
      final pool = await ProbePool.open(4, dll, font);
      try {
        final pending = pool.run(
          List.generate(1000, (i) => ' Hxg $i '),
          reuse: false,
        );
        pool.cancel();
        expect((await pending)['cancelled'], isTrue);
        final value = await pool.run([' Hxg 한글  ']);
        expect((value['results'] as List).single['text'], ' Hxg 한글  ');
      } finally {
        await pool.close();
      }
    });
    test('실행 중 닫기는 자원을 정리하고 재실행을 거부한다', () async {
      final pool = await ProbePool.open(1, dll, font);
      final pending = pool.run(
        List.generate(1000, (i) => ' Hxg $i '),
        reuse: false,
      );
      await pool.close();
      expect((await pending)['cancelled'], isTrue);
      expect(() => pool.run(['H']), throwsStateError);
      await pool.close();
    });
    test('호출 후 입력 목록을 바꿔도 캡처한 문구가 유지된다', () async {
      final pool = await ProbePool.open(1, dll, font);
      try {
        final texts = [' Hxg 한글  '];
        final pending = pool.run(texts);
        texts[0] = 'CHANGED';
        expect(
          ((await pending)['results'] as List).single['text'],
          ' Hxg 한글  ',
        );
      } finally {
        await pool.close();
      }
    });
    test('캐시는 같은 윤곽을 재사용하고 실제 재계산 시간을 중복 집계하지 않는다', () async {
      final pool = await ProbePool.open(1, dll, font);
      try {
        final first = await pool.run([' Hxg 한글  ']);
        final second = await pool.run([' Hxg 한글  ']);
        expect(second['hits'], 1);
        expect(second['shapeMs'], 0);
        expect(second['outlineMs'], 0);
        expect(second['boundsMs'], 0);
        expect(
          jsonEncode(
            comparable(
              (first['results'] as List).single as Map<String, Object?>,
            ),
          ),
          jsonEncode(
            comparable(
              (second['results'] as List).single as Map<String, Object?>,
            ),
          ),
        );
      } finally {
        await pool.close();
      }
    });
    test('worker 수 상한을 벗어나면 시작 전에 거부한다', () {
      expect(() => ProbePool.open(5, dll, font), throwsArgumentError);
    });
  });
}
