import 'dart:io';

/// 고정 SDK로 이 패키지의 의존성·포맷·분석과 존재하는 테스트를 검사한다.
Future<void> main() async {
  final root = File.fromUri(Platform.script).parent.parent;
  Directory.current = root.path;
  final sdk = Directory('.fvm/flutter_sdk');
  if (!sdk.existsSync()) {
    throw StateError('개발 기준에 따라 FVM SDK를 먼저 준비하세요.');
  }
  final dart =
      '${sdk.absolute.path}/bin/cache/dart-sdk/bin/'
      'dart${Platform.isWindows ? '.exe' : ''}';
  final flutter =
      '${sdk.absolute.path}/bin/'
      'flutter${Platform.isWindows ? '.bat' : ''}';
  Future<void> run(String executable, List<String> arguments) async {
    stdout.writeln('> $executable ${arguments.join(' ')}');
    final process = await Process.start(
      executable,
      arguments,
      workingDirectory: root.path,
      runInShell: Platform.isWindows && executable.endsWith('.bat'),
      mode: ProcessStartMode.inheritStdio,
    );
    final code = await process.exitCode;
    if (code != 0) throw StateError('검증 실패(exit=$code): $arguments');
  }

  await run(flutter, ['pub', 'get']);
  await run(dart, [
    'format',
    '--output=none',
    '--set-exit-if-changed',
    'lib',
    'tool',
    if (Directory('test').existsSync()) 'test',
  ]);
  await run(flutter, ['analyze', '--fatal-infos']);
  final tests = Directory('test');
  final hasTests =
      tests.existsSync() &&
      tests
          .listSync(recursive: true, followLinks: false)
          .whereType<File>()
          .any((file) => file.path.endsWith('_test.dart'));
  if (hasTests) {
    await run(flutter, ['test']);
  } else {
    stdout.writeln('테스트 없음: 동작 구현 전이므로 flutter test는 실행하지 않았습니다.');
  }
  stdout.writeln('로컬 기반 검증 완료. 렌더링·측정·앱 연결 검증은 아닙니다.');
}
