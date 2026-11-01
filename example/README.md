# 실제 윤곽·병렬·Windows 표시 실험

정식 viewer API가 아닌 독립 실행 실험이다. [결과와 한계](../docs/outline-experiment.md)를 먼저 읽는다.
측정은 DirectWrite, 표시는 **같은 확정 cubic 경로**를 Flutter Canvas로 수행한다.
TextPainter로 시험 문구를 다시 배치하지 않는다. 화면 안내용 Text 위젯은 별도다.

- native/probe.cpp: 실제 face0·script 분석·glyph 배치/윤곽의 Windows SDK C ABI.
- lib/src/native_font.dart: worker 전용 FFI 자원 수명.
- lib/src/outline_geometry.dart: Flutter 없는 배율·회전·곡선 극점·외곽 중심 정렬.
- lib/src/worker_pool.dart: 1~4 isolate, 32개 묶음, 제한된 cache와 취소.
- lib/src/display_paths.dart: 확정 윤곽→Path·보조선·clip 제외.
- lib/main.dart: 실제 창, 확대/이동, 준비·profile 계측·PNG 기록.
- bin/benchmark.dart: Flutter 없는 AOT 정확성·72개 성능 관찰.
- test/: 독립 곡선 기대값 / 실제 face·worker / 화면 변환.

## 재현

viewer 루트에서 SDK를 준비한 후 아래 명령을 실행한다.
루트 tool/fvm.ps1은 루트로 이동하므로 example에서는 고정 SDK를 직접 호출한다.
Windows C++ 개발 도구는 기존 설치를 사용하며 전역 설정을 바꾸지 않는다.

    $env:PUB_CACHE = Join-Path (Get-Location) '.tooling/pub-cache'
    Push-Location example
    & ../.fvm/flutter_sdk/bin/flutter.bat pub get
    & ../.fvm/flutter_sdk/bin/dart.bat format --output=none --set-exit-if-changed lib bin test
    & ../.fvm/flutter_sdk/bin/flutter.bat analyze --fatal-infos
    $cmake = 'C:/Program Files/Microsoft Visual Studio/18/Insiders/Common7/IDE/CommonExtensions/Microsoft/CMake/CMake/bin/cmake.exe'
    & $cmake -S native -B build/native -G 'Visual Studio 18 2026' -A x64
    & $cmake --build build/native --config Release
    & ../.fvm/flutter_sdk/bin/flutter.bat test
    & ../.fvm/flutter_sdk/bin/dart.bat compile exe bin/benchmark.dart -o build/cpu_benchmark.exe
    & ./build/cpu_benchmark.exe
    # CPU 비교가 끝난 다음 화면 시험을 따로 실행한다.
    & ../.fvm/flutter_sdk/bin/flutter.bat build windows --profile --dart-define=PROBE_AUTORUN=true
    & ./build/windows/x64/runner/Profile/outline_probe.exe
    Pop-Location

자동 성능 측정 없는 수동 실행은 --dart-define=PROBE_AUTORUN=true를 빼고 빌드한다.
실행의 현재 디렉터리는 example로 둔다. 다른 디렉터리에서 실행하면 기록 루트도 달라질 수 있다.
DLL은 CMake install로 실행 파일 옆에 포함된다. 별도 native 빌드가 있으면 그 DLL을 우선 사용한다.
실험 앱이 열려 있으면 DLL/실행 파일이 잠겨 재빌드가 실패할 수 있으므로 창을 먼저 닫는다.

처음에는 C:\Windows\Fonts\H2GTRE.TTF를 읽는다. UI에서 허가된 단독 TrueType face 파일 경로를 지정할 수 있다.
실측 기준은 이 파일의 해시/face0/em 3mm이며 다른 파일 결과를 같은 시험으로 간주하지 않는다.
TTC/CFF/variable/합성 스타일·결합 문자·RTL·fallback은 이번 지원 범위가 아니다.
원문은 LTR ASCII와 완성형 한글, 1~128 UTF-16 코드 단위로 제한한다. 지원 밖 입력은 실패 단계로 거부한다.

창에는 기본/0.8자폭·45°를 나란히 보여 준다. 두 패널의 모델 목표점은 각각 (40,25)mm이며,
오른쪽에는 비교용 표시 이동 +50mm만 추가한다. 줌/이동은 viewer 행렬만 바꾼다.
마우스 휠 확대·드래그 이동, 정확성 준비, 성능, 취소를 사용할 수 있다.
진행 중 경로 입력은 잠그며 취소/종료 후의 옛 결과를 게시하지 않는다.

출력은 ../.tooling/outline-results/새_타임스탬프/에 생긴다.
JSON에는 **합성 시험 문구의 실제 윤곽**이 들어가므로 로컬·Git 제외 자료로 유지한다.
원본 font를 복사하거나 배포하지 않는다. 화면 결과·메트릭의 로컬 시험과 글꼴 임베딩/상용 배포 허가는 별개다.
'외곽 없음'은 정상 공백 입력이며, font/기능 실패와 구분한다.
'취소'는 실행 중 native 호출을 강제 중단하지 않고 최대 한 묶음의 완료를 기다린다.

실험에만 ffi 2.2.0, crypto 3.0.7, flutter_test, flutter_lints 6.0.0을 선언했다.
앞 두 패키지의 실제 배포 LICENSE는 BSD-3-Clause를 확인했다. Flutter/분석 패키지도 BSD 계열이며
기존 SDK와 실제 의존성 해결을 확인했다. 루트 패키지 의존성과 공개 API에는 추가하지 않았다.
분석은 flutter_lints+strict 타입 3종이다. 루트의 very_good_analysis 공개 API 기준을 대체하지 않는다.
이 example은 앱이므로 pubspec.lock을 보존한다. font/DLL/build/측정 원본은 Git 제외다.