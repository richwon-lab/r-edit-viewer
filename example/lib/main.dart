import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'src/native_font.dart';

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:crypto/crypto.dart';

import 'src/worker_pool.dart';
import 'src/display_paths.dart';

void main() => runApp(const ProbePage());

class ProbePage extends StatefulWidget {
  const ProbePage({super.key});
  @override
  State<ProbePage> createState() => _ProbePageState();
}

class _ProbePageState extends State<ProbePage>
    with SingleTickerProviderStateMixin {
  final boundary = GlobalKey(), transform = TransformationController();
  final fontPath = TextEditingController(text: r'C:\Windows\Fonts\H2GTRE.TTF');
  ProbePool? active;
  List<DisplayItem> items = [];
  String status = '초기화 중', errorText = '';
  Map<String, Object?>? accuracy;
  bool busy = false, animate = false;
  int generation = 0;
  late final Ticker ticker;
  final frames = <List<double>>[];
  final reports = <Map<String, Object?>>[];
  final pathCache = <String, Path>{};
  int pathPayload = 0;
  bool cull = true;
  late Directory output;
  String get dll =>
      File('build/native/Release/outline_probe_native.dll').existsSync()
      ? File('build/native/Release/outline_probe_native.dll').absolute.path
      : '${File(Platform.resolvedExecutable).parent.path}/outline_probe_native.dll';
  @override
  void initState() {
    super.initState();
    output = Directory(
      '${Directory.current.parent.path}/.tooling/outline-results/${DateTime.now().microsecondsSinceEpoch}',
    );
    ticker = createTicker((elapsed) {
      if (!animate) return;
      final phase = elapsed.inMicroseconds / 1e6;
      final scale = 0.8 + 0.12 * math.sin(phase * 1.7);
      transform.value = Matrix4.identity()
        ..translateByDouble(50 * math.sin(phase), 25 * math.cos(phase), 0, 1)
        ..scaleByDouble(scale, scale, 1, 1);
    })..start();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await loadAccuracy();
      if (const bool.fromEnvironment('PROBE_AUTORUN')) await benchmark();
    });
  }

  Future<List<DisplayItem>> display(
    List<Map<String, Object?>> results, {
    bool grid = false,
  }) async {
    final prepared = <DisplayItem>[];
    for (var i = 0; i < results.length; i++) {
      final result = results[i];
      final commands = result['commands'] as Float64List;
      final key = '${result['text']}|${result['width']}|${result['angle']}';
      var path = pathCache[key];
      if (path == null) {
        path = displayPath(commands, result['fill'] as int);
        if (pathCache.length >= 64 ||
            pathPayload + commands.lengthInBytes > 4 * 1024 * 1024) {
          pathCache.clear();
          pathPayload = 0;
        }
        if (commands.lengthInBytes <= 4 * 1024 * 1024) {
          pathCache[key] = path;
          pathPayload += commands.lengthInBytes;
        }
      }
      prepared.add(
        DisplayItem(
          result,
          path,
          grid
              ? Offset((i % 20) * 30.0, -(i ~/ 20) * 18.0)
              : Offset(i * 50.0, 0),
        ),
      );
      if (i % 8 == 7) await Future<void>.delayed(Duration.zero);
    }
    return prepared;
  }

  Future<void> loadAccuracy() async {
    pathCache.clear();
    pathPayload = 0;
    final current = ++generation;
    active?.cancel();
    setState(() => busy = true);
    ProbePool? pool;
    try {
      pool = await ProbePool.open(1, dll, fontPath.text);
      active = pool;
      final basic = await pool.run(
        [' Hxg 한글  ', '   '],
        width: 1,
        angle: 0,
        reuse: false,
      );
      final rotated = await pool.run([' Hxg 한글  '], reuse: false);
      final a = (basic['results'] as List).cast<Map<String, Object?>>();
      final b = (rotated['results'] as List).cast<Map<String, Object?>>();
      final prepared = await display([a[0], b[0]]);
      if (!mounted || current != generation) return;
      accuracy = {
        'basic': a[0],
        'rotated': b[0],
        'space': a[1],
        'fontSha256': sha256
            .convert(await File(fontPath.text).readAsBytes())
            .toString(),
      };
      setState(() {
        transform.value = Matrix4.identity()
          ..translateByDouble(-220, -360, 0, 1)
          ..scaleByDouble(3, 3, 1, 1);
        items = prepared;
        status = '실제 외곽 준비 완료 · em 3mm · face0 · 공백: 외곽 없음';
        errorText = '';
      });
      await capture('accuracy');
    } on ProbeFault catch (error) {
      if (mounted && current == generation) {
        setState(() => errorText = '새 준비 실패(이전 표시 유지): $error');
      }
      // 예상한 backend 실패만 표시한다. 코드 결함은 잡아 정상 상태로 바꾸지 않는다.
    } finally {
      await pool?.close();
      if (identical(active, pool)) active = null;
      if (mounted && current == generation) setState(() => busy = false);
    }
  }

  void onTimings(List<ui.FrameTiming> timings) {
    for (final t in timings) {
      frames.add([
        t.buildDuration.inMicroseconds / 1000,
        t.rasterDuration.inMicroseconds / 1000,
        t.totalSpan.inMicroseconds / 1000,
      ]);
    }
  }

  List<double> quantiles(List<double> values) {
    if (values.isEmpty) return [];
    values.sort();
    return [
      for (final q in [0.5, 0.95, 0.99, 1.0])
        values[((values.length - 1) * q).round()],
    ];
  }

  Future<void> benchmark() async {
    if (busy) return;
    pathCache.clear();
    pathPayload = 0;
    final current = ++generation;
    setState(() => busy = true);
    try {
      transform.value = Matrix4.identity();
      for (final testCase in [(1, true), (4, true), (4, false)]) {
        final workerCount = testCase.$1;
        cull = testCase.$2;
        if (!mounted || current != generation) break;
        final pool = await ProbePool.open(workerCount, dll, fontPath.text);
        active = pool;
        try {
          final first = Stopwatch()..start();
          final value = await pool.run(
            List.generate(1000, (i) => ' Hxg 한글 $i  '),
            reuse: false,
          );
          if (current != generation) break;
          final pathWatch = Stopwatch()..start();
          final prepared = await display(
            (value['results'] as List).cast<Map<String, Object?>>(),
            grid: true,
          );
          if (current != generation || !mounted) break;
          setState(() {
            items = prepared;
            status = '$workerCount worker · 1,000 윤곽 표시 + 계산 중 자동 확대/이동';
          });
          await WidgetsBinding.instance.endOfFrame;
          final firstDisplayMs = first.elapsedMicroseconds / 1000,
              displayMs = pathWatch.elapsedMicroseconds / 1000;
          frames.clear();
          SchedulerBinding.instance.addTimingsCallback(onTimings);
          animate = true;
          final duration = Stopwatch()..start();
          var jobs = 0;
          final cpuSamples = <double>[];
          while (duration.elapsedMilliseconds < 8000 && current == generation) {
            final result = await pool.run(
              List.generate(1000, (i) => ' Hxg 한글 $i  '),
              reuse: false,
            );
            if (result['cancelled'] == true) break;
            cpuSamples.add(result['wallMs'] as double);
            jobs++;
          }
          animate = false;
          SchedulerBinding.instance.removeTimingsCallback(onTimings);
          await Future<void>.delayed(const Duration(milliseconds: 100));
          reports.add({
            'workers': workerCount,
            'sceneObjects': 1000,
            'culling': cull,
            'jobs': jobs,
            'windowMs': duration.elapsedMicroseconds / 1000,
            'initMs': pool.initMs,
            'pathPreparationMs': displayMs,
            'firstDisplayMs': firstDisplayMs,
            'firstIncludingInitMs': firstDisplayMs + pool.initMs,
            'frameCount': frames.length,
            'uiMs': quantiles(frames.map((e) => e[0]).toList()),
            'rasterMs': quantiles(frames.map((e) => e[1]).toList()),
            'totalSpanMs': quantiles(frames.map((e) => e[2]).toList()),
            'cpuRequestMs': quantiles(cpuSamples),
            'rss': ProcessInfo.currentRss,
            'peakRss': ProcessInfo.maxRss,
            'pathCacheCommandBytes': pathPayload,
            'frames': frames.toList(),
            'note': 'UI/raster timings are not GPU execution times',
          });
          await capture('workers-$workerCount-cull-$cull');
        } finally {
          animate = false;
          SchedulerBinding.instance.removeTimingsCallback(onTimings);
          await pool.close();
          if (identical(active, pool)) active = null;
        }
      }
      if (mounted && current == generation) {
        await output.create(recursive: true);
        await File('${output.path}/profile.json').writeAsString(
          const JsonEncoder.withIndent('  ').convert({
            'mode': kProfileMode
                ? 'profile'
                : (kReleaseMode ? 'release' : 'debug'),
            'pid': pid,
            'refreshHz': 60,
            'font': r'H2GTRE.TTF face0',
            'reports': reports,
          }),
        );
        setState(() => status = '성능 측정 완료: ${output.path}');
        // 기준 두 객체를 다시 보여 주며 별도 저장 폴더의 최종 화면을 남긴다.
        busy = false;
        await loadAccuracy();
      }
    } finally {
      animate = false;
      SchedulerBinding.instance.removeTimingsCallback(onTimings);
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> capture(String name) async {
    if (!mounted) return;
    await output.create(recursive: true);
    await WidgetsBinding.instance.endOfFrame;
    final image =
        await (boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary)
            .toImage(pixelRatio: 1.5);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final file = File(
      '${output.path}/$name-${DateTime.now().microsecondsSinceEpoch}.png',
    );
    await file.create(exclusive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    if (accuracy != null) {
      await File('${output.path}/accuracy.json')
          .writeAsString(jsonEncode(accuracy));
    }
  }

  void cancel() {
    generation++;
    active?.cancel();
    setState(() => status = '취소 요청: 이전 표시 유지, 실행 중 묶음 종료 후 자원 정리');
  }

  @override
  void dispose() {
    generation++;
    active?.cancel();
    unawaited(active?.close());
    ticker.dispose();
    SchedulerBinding.instance.removeTimingsCallback(onTimings);
    pathCache.clear();
    fontPath.dispose();
    transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: RepaintBoundary(
      key: boundary,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('실제 glyph 윤곽 · 정확성 / worker / 프레임 실험'),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: fontPath,
                      enabled: !busy,
                      decoration: const InputDecoration(
                        labelText: '허가된 실제 font 경로 (단독 TrueType face0)',
                      ),
                    ),
                  ),
                  FilledButton(
                    onPressed: busy ? null : loadAccuracy,
                    child: const Text('정확성 준비'),
                  ),
                  TextButton(
                    onPressed: busy ? null : benchmark,
                    child: const Text('1/4 worker 성능'),
                  ),
                  TextButton(onPressed: cancel, child: const Text('취소')),
                ],
              ),
            ),
            Text(status),
            if (errorText.isNotEmpty)
              Text(errorText, style: const TextStyle(color: Colors.red)),
            const Text(
              '왼쪽: 기본 / 오른쪽: 자폭 0.8·45° · 초록: 실제 curve bounds · 빨강 중심=주황 목표 (40,25) · 보라: 원점/기준선',
            ),
            if (accuracy != null)
              Text(
                '정렬 오차(mm): ${(accuracy!['basic'] as Map)['error']} / ${(accuracy!['rotated'] as Map)['error']} · 원문 공백 보존 · 공백은 외곽 없음',
              ),
            Expanded(
              child: RepaintBoundary(
                child: InteractiveViewer(
                  transformationController: transform,
                  constrained: false,
                  minScale: 0.03,
                  maxScale: 20,
                  boundaryMargin: const EdgeInsets.all(10000),
                  child: SizedBox(
                    width: 2600,
                    height: 1600,
                    child: CustomPaint(
                      painter: OutlinePainter(items, cull: cull),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
