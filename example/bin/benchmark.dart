import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:outline_probe/src/worker_pool.dart';
import 'package:outline_probe/src/native_font.dart';
import 'package:outline_probe/src/outline_geometry.dart';

List<String> samples(int n, bool unique) => List.generate(
  n,
  (i) => unique ? ' Hxg 한글 ${i.toString().padLeft(4, "0")}  ' : ' Hxg 한글  ',
);
Map<String, Object?> canonical(Map<String, Object?> value) => Map.fromEntries(
  value.entries
      .where((e) => !['shapeMs', 'outlineMs', 'boundsMs'].contains(e.key))
      .map(
        (e) => MapEntry(
          e.key,
          e.value is TypedData ? (e.value as List).toList() : e.value,
        ),
      ),
);
Future<void> main() async {
  const dll = 'build/native/Release/outline_probe_native.dll',
      font = r'C:\Windows\Fonts\H2GTRE.TTF';
  final report = <Map<String, Object?>>[];
  // AOT 실행: single/4-worker 동일 값·완료 순서와 취소/재사용을 독립 검사한다.
  final p1 = await ProbePool.open(1, dll, font),
      p4 = await ProbePool.open(4, dll, font);
  final a = await p1.run(samples(100, true), reuse: false),
      b = await p4.run(samples(100, true), reuse: false);
  final ar = (a['results'] as List).cast<Map<String, Object?>>(),
      br = (b['results'] as List).cast<Map<String, Object?>>();
  for (var i = 0; i < ar.length; i++) {
    if (jsonEncode(canonical(ar[i])) != jsonEncode(canonical(br[i]))) {
      throw StateError('parallel mismatch $i');
    }
    final error = (ar[i]['error'] as List).cast<double>();
    if (error.any((e) => e.abs() > 1e-9)) {
      throw StateError('alignment error $i');
    }
  }
  final cancelled = p4.run(samples(1000, true), reuse: false);
  p4.cancel();
  if ((await cancelled)['cancelled'] != true) {
    throw StateError('cancel did not reject stale result');
  }
  await p1.close();
  await p4.close();
  for (final workers in [1, 4]) {
    for (final unique in [false, true]) {
      for (final n in [1, 100, 1000]) {
        for (final reuse in [false, true]) {
          ProbePool? warm;
          if (reuse) {
            warm = await ProbePool.open(workers, dll, font);
            await warm.run(samples(n, unique));
          }
          for (var repeat = 0; repeat < 3; repeat++) {
            final pool = warm ?? await ProbePool.open(workers, dll, font);
            final all = Stopwatch()..start();
            final before = ProcessInfo.currentRss;
            final value = await pool.run(samples(n, unique), reuse: reuse);
            final result = (value['results'] as List)
                .cast<Map<String, Object?>>();
            report.add({
              'workers': workers,
              'unique': unique,
              'n': n,
              'reuse': reuse,
              'repeat': repeat,
              'initMs': reuse ? 0 : pool.initMs,
              'wallMs': value['wallMs'],
              'computeSumMs': value['workerSumMs'],
              for (final phase in [
                'shapeMs',
                'outlineMs',
                'boundsMs',
                'nativeBatchMs',
              ])
                phase: value[phase],
              'envelopeSumMs': value['envelopeSumMs'],
              'hits': value['hits'],
              'misses': value['misses'],
              'cachePayloadPerWorkerMax': value['cachePayloadPerWorkerMax'],
              'rssBefore': before,
              'rssAfter': ProcessInfo.currentRss,
              'peakRss': ProcessInfo.maxRss,
              'resultPayloadBytes': result.fold<int>(
                0,
                (sum, r) => sum + payloadBytes(r),
              ),
              'receiveToCheckMs': all.elapsedMicroseconds / 1000,
            });
            if (warm == null) await pool.close();
          }
          await warm?.close();
        }
      }
    }
  }
  // 객체마다 font context를 열고 닫는 대안 비용: worker 재생성 없이 별도로 분리해 측정한다.
  final fresh = <Map<String, Object?>>[];
  for (final n in [1, 100, 1000]) {
    for (var repeat = 0; repeat < 3; repeat++) {
      final time = Stopwatch()..start();
      var init = 0.0;
      for (var i = 0; i < n; i++) {
        final watch = Stopwatch()..start();
        final fontContext = NativeFont(dll, font);
        init += watch.elapsedMicroseconds / 1000;
        try {
          final value = fontContext.batch([' Hxg 한글  ']);
          prepareRun(
            (value['runs'] as List).single as Map<String, dynamic>,
            value['upem'] as int,
            ' Hxg 한글  ',
            1,
            0,
          );
        } finally {
          fontContext.close();
        }
      }
      fresh.add({
        'n': n,
        'repeat': repeat,
        'wallMs': time.elapsedMicroseconds / 1000,
        'fontInitSumMs': init,
      });
    }
  }
  final folder = Directory(
    '../.tooling/outline-results/${DateTime.now().microsecondsSinceEpoch}',
  );
  await folder.create(recursive: true);
  await File('${folder.path}/cpu-benchmark.json').writeAsString(
    const JsonEncoder.withIndent('  ').convert({
      'mode': 'Dart AOT release exe',
      'pid': pid,
      'processors': Platform.numberOfProcessors,
      'repeats': 3,
      'cases': report,
      'freshFontPerObject': fresh,
      'accuracy': '100 unique objects single/4 workers identical; target error<=1e-9mm; cancellation passed',
    }),
  );
  stdout.writeln(
    'AOT accuracy passed; ${report.length} cases; ${folder.absolute.path}',
  );
}
