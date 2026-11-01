import 'dart:async';

import 'dart:isolate';
import 'dart:math' as math;

import 'native_font.dart';
import 'outline_geometry.dart';

/// 실험 전용: 최대 4개, worker당 한 묶음(최대32), 별도 대기 큐 없이 순서대로 공급한다.
class ProbePool {
  ProbePool._();
  final _ports = <SendPort>[];
  final _responses = <StreamIterator<dynamic>>[];
  final _isolates = <Isolate>[];
  bool _busy = false, _closed = false;
  int epoch = 0;
  double initMs = 0;
  static Future<ProbePool> open(int count, String dll, String font) async {
    if (count < 1 || count > 4) {
      throw ArgumentError.value(count, 'count', '1..4');
    }
    final result = ProbePool._();
    final timer = Stopwatch()..start();
    try {
      await Future.wait(
        List.generate(count, (_) async {
          final replies = ReceivePort();
          final stream = StreamIterator<dynamic>(replies);
          final isolate = await Isolate.spawn(_worker, [
            replies.sendPort,
            dll,
            font,
          ]);
          result._isolates.add(isolate);
          if (!await stream.moveNext()) throw StateError('worker init closed');
          final message = stream.current as List;
          if (message[0] != 'ready') {
            await stream.cancel();
            throw ProbeFault(message[1] as String, message[2] as int);
          }
          result._ports.add(message[1] as SendPort);
          result._responses.add(stream);
        }),
      );
    } catch (_) {
      await result.close();
      rethrow;
    }
    result.initMs = timer.elapsedMicroseconds / 1000;
    return result;
  }

  void cancel() {
    epoch++;
  }

  Future<Map<String, Object?>> run(
    List<String> texts, {
    bool reuse = true,
    double width = 0.8,
    double angle = 0.7853981633974483,
  }) async {
    if (_busy || _closed) throw StateError('pool busy/closed');
    if (texts.isEmpty || texts.length > 1000) {
      throw ArgumentError('1..1000 objects');
    }
    if (!width.isFinite || width <= 0) {
      throw ArgumentError.value(width, 'width', '유한 양수');
    }
    if (!angle.isFinite) throw ArgumentError.value(angle, 'angle', '유한 라디안');
    final source = List<String>.of(texts, growable: false);
    _busy = true;
    final generation = epoch;
    final timer = Stopwatch()..start();
    final output = List<Map<String, Object?>?>.filled(source.length, null);
    var next = 0;
    double envelope = 0, compute = 0;
    final phases = <String, double>{
      'shapeMs': 0,
      'outlineMs': 0,
      'boundsMs': 0,
      'nativeBatchMs': 0,
    };
    var hits = 0, misses = 0, payload = 0;
    try {
      await Future.wait(
        List.generate(_ports.length, (worker) async {
          while (next < source.length && !_closed && generation == epoch) {
            final start = next;
            final end = math.min(start + 32, source.length);
            next = end;
            final transfer = Stopwatch()..start();
            _ports[worker].send([
              'batch',
              source.sublist(start, end),
              reuse,
              width,
              angle,
            ]);
            if (!await _responses[worker].moveNext()) {
              throw StateError('worker unexpectedly closed');
            }
            final reply = _responses[worker].current as Map;
            if (reply['fault'] != null) {
              final fault = reply['fault'] as List;
              throw ProbeFault(fault[0] as String, fault[1] as int);
            }
            final workerMs = reply['workerMs'] as double;
            envelope += math.max(
              0,
              transfer.elapsedMicroseconds / 1000 - workerMs,
            );
            compute += workerMs;
            for (final name in phases.keys) {
              phases[name] = phases[name]! + (reply[name] as double);
            }
            hits += reply['hits'] as int;
            misses += reply['misses'] as int;
            payload = math.max(payload, reply['cacheBytes'] as int);
            final values = (reply['results'] as List)
                .cast<Map<String, Object?>>();
            for (var i = 0; i < values.length; i++) {
              output[start + i] = values[i];
            }
          }
        }),
      );
      if (generation != epoch || _closed) return {'cancelled': true};
      return {
        'cancelled': false,
        'results': output.cast<Map<String, Object?>>(),
        'wallMs': timer.elapsedMicroseconds / 1000,
        'workerSumMs': compute,
        ...phases,
        'envelopeSumMs': envelope,
        'hits': hits,
        'misses': misses,
        'cachePayloadPerWorkerMax': payload,
      };
    } finally {
      _busy = false;
    }
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    epoch++;
    while (_busy) {
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
    for (var i = 0; i < _ports.length; i++) {
      _ports[i].send(['close']);
      await _responses[i].moveNext();
      await _responses[i].cancel();
    }
  }
}

void _worker(List<Object> setup) async {
  final parent = setup[0] as SendPort;
  final port = ReceivePort();
  NativeFont? font;
  final cache = <String, Map<String, Object?>>{};
  var retained = 0;
  try {
    font = NativeFont(setup[1] as String, setup[2] as String);
    parent.send(['ready', port.sendPort]);
    await for (final raw in port) {
      final message = raw as List;
      if (message[0] == 'close') break;
      final watch = Stopwatch()..start();
      final strings = (message[1] as List).cast<String>();
      final reuse = message[2] as bool;
      final width = message[3] as double, angle = message[4] as double;
      String key(String text) => "$width|$angle|$text";
      if (!reuse) {
        cache.clear();
        retained = 0;
      }
      var hits = 0, misses = 0;
      var shapeMs = 0.0, outlineMs = 0.0, boundsMs = 0.0, nativeBatchMs = 0.0;
      final results = <Map<String, Object?>>[];
      try {
        // 한 native 호출에 필요한 miss를 모으고 캐시 hit와 원래 순서를 복원한다.
        final missing = <String>[];
        for (final text in strings) {
          if (!reuse || !cache.containsKey(key(text))) {
            if (!reuse || !missing.contains(text)) missing.add(text);
          }
        }
        final prepared = <String, Map<String, Object?>>{};
        if (missing.isNotEmpty) {
          final nativeWatch = Stopwatch()..start();
          final native = font.batch(missing);
          nativeBatchMs = nativeWatch.elapsedMicroseconds / 1000;
          final runs = (native['runs'] as List).cast<Map<String, dynamic>>();
          for (var i = 0; i < missing.length; i++) {
            shapeMs += (runs[i]['shapeMs'] as num).toDouble();
            outlineMs += (runs[i]['outlineMs'] as num).toDouble();
            prepared[missing[i]] = prepareRun(
              runs[i],
              native['upem'] as int,
              missing[i],
              width,
              angle,
            );
            boundsMs += prepared[missing[i]]!['boundsMs'] as double;
          }
        }
        for (final text in strings) {
          var value = reuse ? cache.remove(key(text)) : null;
          if (value != null) {
            hits++;
            cache[key(text)] = value;
          } else {
            misses++;
            value = prepared[text]!;
            final bytes = payloadBytes(value);
            if (reuse && bytes <= 16 * 1024 * 1024) {
              while (cache.isNotEmpty &&
                  (cache.length >= 64 || retained + bytes > 16 * 1024 * 1024)) {
                retained -= payloadBytes(cache.remove(cache.keys.first)!);
              }
              cache[key(text)] = value;
              retained += bytes;
            }
          }
          results.add(value);
        }
        parent.send({
          'results': results,
          'workerMs': watch.elapsedMicroseconds / 1000,
          'shapeMs': shapeMs,
          'outlineMs': outlineMs,
          'boundsMs': boundsMs,
          'nativeBatchMs': nativeBatchMs,
          'hits': hits,
          'misses': misses,
          'cacheBytes': retained,
        });
      } on ProbeFault catch (fault) {
        parent.send({
          'fault': [fault.stage, fault.code],
        });
      }
    }
  } on ProbeFault catch (fault) {
    parent.send(['fault', fault.stage, fault.code]);
  } finally {
    font?.close();
    cache.clear();
    port.close();
    parent.send(['closed']);
  }
}
