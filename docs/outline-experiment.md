# 동일 glyph 윤곽의 정확성·병렬·Windows 표시 실험

2026-11-02. [연결 계약](text-outline-binding.md)의 최소 가정을 실제 실행으로 확인했다.
정식 backend 선정이나 viewer 공개 API 구현은 아니다. 운영 lib와 루트 pubspec은 유지했다.
코드는 [example 실행 안내](../example/README.md)에 있으며 별도 pubspec/lock과 Windows runner를 갖는다.

## 1. 선택과 실제 확인 범위

| 후보 | 같은 face의 배치·윤곽 / 실제 경계 | 운영·배포·수명 | 이번 판단 |
| --- | --- | --- | --- |
| Windows DirectWrite | GetGlyphs→GetGlyphPlacements의 ID/advance/offset을 같은 face의 GetGlyphRunOutline에 전달. batch sink의 cubic을 독립 값으로 복사하고 도함수 극점으로 경계 계산 | Windows OS API, OS/SDK 이용 조건 적용. 별도 vendor DLL 재배포 없이 직접 작성한 작은 C ABI DLL을 빌드. Flutter 없는 Windows Dart AOT에서 실행 가능. 다른 OS 지원 없음 | **실험용 선택**. 실제 Windows/고정 SDK 실행 확인 |
| FreeType + HarfBuzz | 같은 font bytes/face의 shaping 결과로 FT glyph outline을 얻는 후보. FT의 bbox 기능과 곡선 분해 API 검토 | FT는 FTL 또는 GPLv2, HB는 Old MIT. 공식 저장소/문서가 유지됨. Windows 빌드·바이너리·FFI 배포 필요. FT library/face를 무근거로 공유하지 않고 worker별 소유 필요 | 이 실험에 설치/빌드하지 않음. cross-platform 정식 공통 처리 후보로 유지 |
| Flutter Paragraph/TextPainter | 표시·shaping은 가능하나 현재 공개 Dart API에서 동일 glyph ID/배치/윤곽을 함께 추출하는 경로를 확보하지 못함. 논리 bounds는 실제 ink bounds가 아님 | SDK 유지/BSD-3-Clause. UI 자원과 수명 결합, Flutter 없는 엔진의 정본으로 부적합 | 시험 문구에는 사용하지 않음. 안내 UI Text만 사용 |

Microsoft의 일반 shared factory 권장과 달리 이번에는 자원/캐시 소유 범위를 분리하려고 worker마다 isolated factory를 생성했다.
이는 OS persistent cache까지 전혀 사용하지 않는다는 보장이 아니다. DirectWrite 자체 내부 스레드/캐시는 이 브리지가 제어하지 않는다.
하나의 context에는 한 번에 한 batch만 실행하고 native mutex도 둔다. factory/face/포인터를 isolate 사이에 보내지 않는다.
구조상 동시 호출을 피하며, 이것을 모든 DirectWrite 인터페이스의 무제한 thread safety 검증으로 확대하지 않는다.

실제 사용: Flutter 3.47.7 / Dart 3.13.5, engine deb287481e3ce9468f3434937ced4240a70539ca.
Windows dwrite.dll 10.0.26100.8875, SDK 10.0.26100.0, MSVC 19.51.36260.0, Visual Studio 18 Insiders.
기존 설치를 사용했으며 SDK/PATH/형제 프로젝트는 변경하지 않았다.
example에만 ffi 2.2.0(BSD-3-Clause), crypto 3.0.7(BSD-3-Clause), Flutter SDK,
flutter_test, flutter_lints 6.0.0을 선언/해결했다. 정식 공통 패키지/의존성 채택은 후속 결정이다.
직접 작성한 프로젝트 소스의 배포 라이선스도 기존 미정 상태를 유지한다.

### 확인한 공식 자료와 실제 소스

확인일 2026-11-02. 문서/소스 검토와 실기 성공은 구분한다.

- [DirectWrite 개요](https://learn.microsoft.com/en-us/windows/win32/directwrite/direct-write-portal),
  [factory 상태·소유](https://learn.microsoft.com/en-us/windows/win32/api/dwrite/nn-dwrite-idwritefactory).
- [GetGlyphs](https://learn.microsoft.com/en-us/windows/win32/api/dwrite/nf-dwrite-idwritetextanalyzer-getglyphs),
  [GetGlyphPlacements](https://learn.microsoft.com/en-us/windows/win32/api/dwrite/nf-dwrite-idwritetextanalyzer-getglyphplacements),
  [GetGlyphRunOutline](https://learn.microsoft.com/en-us/windows/win32/api/dwrite/nf-dwrite-idwritefontface-getglyphrunoutline).
- [FreeType face 수명](https://freetype.org/freetype2/docs/reference/ft2-face_creation.html),
  [library/thread 수명](https://freetype.org/freetype2/docs/reference/ft2-library_setup.html),
  [라이선스](https://freetype.org/license.html).
- [HarfBuzz 공식 문서](https://harfbuzz.github.io/),
  [FT 연동 thread 제약](https://harfbuzz.github.io/harfbuzz-hb-ft.html),
  [공식 소스·유지 현황](https://github.com/harfbuzz/harfbuzz),
  [라이선스](https://github.com/harfbuzz/harfbuzz/blob/main/COPYING).
- [Dart ffi 소스](https://github.com/dart-lang/native/tree/main/pkgs/ffi),
  [crypto 소스](https://github.com/dart-lang/core/tree/main/pkgs/crypto).
  실제 해결 버전의 pubspec/LICENSE와 SDK 제약도 로컬 cache에서 대조했다.
- 설치된 Windows SDK dwrite.h/d2d1.h와 고정 Flutter 소스의 dart:ui text.dart/painting.dart,
  engine/src/flutter/shell/platform/windows/egl/manager.cc를 대조했다.
  임의 master 소스를 실제 고정 실행 버전의 증거로 대체하지 않았다.

## 2. 한 실제 face와 입력

C:\Windows\Fonts\H2GTRE.TTF, 3,485,364 bytes,
SHA-256 820d3212f688b546a327ea43a7202e3379cdbbd767ebac9753997e3f3d285171.
형제 workflow의 기존 font-size-probe 기록에 있는 내부 HY견고딕/HYGothic-Extra, Regular,
Version 1.00/1.0을 참고하고 이번 실제 읽기 해시와 UPEM 1024를 확인했다.
파일명 유사성으로 선택하지 않았다. face index 0, 합성 스타일 없음, **em 길이 3mm**다.
이는 CAD/TypeEdit의 명목 크기 3과 같다는 검증이 아니다. HY cap-height 보정은 없다.

시험 원문은 앞 공백 1개·뒤 공백 2개를 포함하는 ' Hxg 한글  '과 공백 3개다.
ASCII/완성형 한글의 LTR, 한 줄, 1~128 UTF-16 코드 단위만 지원한다.
결합 문자/ZWJ/RTL/collection/CFF/variable/color glyph·기능 선택은 이번 브리지 지원 밖이다.
원문 변경·fallback·기본 글꼴 대체는 하지 않는다. font 원본을 복사·수정·Git 등록하지 않았다.

GetGlyphs와 placements에 사용한 바로 그 face/ID/advance/offset을 outline API에 넘긴다.
run별 윤곽과 누적 advance는 font-unit 정규화 좌표에서 결합한다. JSON/typed 값으로 복사한 뒤 font를 해제할 수 있다.
native는 double JSON을 출력하지만 원 API의 좌표/advance는 FLOAT다. double 후처리가 원 API 정밀도를 높이지 않는다.
화면은 이 확정 경로만 Path로 옮겨 그린다. 화면 문자열 재배치/재측정, curve flattening은 하지 않는다.

변환 순서: Y 위쪽 정규화 → 3/UPEM의 균일 배율 → X 자폭 → 기준선 원점 주위 회전 →
회전한 **실제 curve**의 axis-aligned bounds 계산 → 중심을 (40,25)mm로 평행이동.
로컬 ink box와 회전 후 도면 box를 구분한다. 화면 패널 이동/줌/DPI는 이 값 밖의 표시 변환이다.
오른쪽 예시 패널에는 비교용 표시 이동 +50mm가 있으므로 화면에서 두 모델 목표점이 겹치지 않는다.
advance/offset 메타데이터는 reference font units이며 emMm/width/angle과 구분한다.

## 3. 정확성 관찰

| 상태 | 정렬 전 실제 bounds (mm) | 정렬 이동 (mm) | 정렬 후 중심 오차 (mm) |
| --- | --- | --- | --- |
| 기본 | [1.271484375, -0.4072265625, 14.150390625, 2.4814453125] | [32.2890625, 23.962890625] | [0,0] |
| 자폭0.8·45° | [-0.9069473109476675, 0.721331780886199, 8.07966172260871, 9.543869944120386] | [36.413642794169476, 19.867399137496708] | [0,0] |
| 공백3개 | 외곽 없음 | [0,0], 중심 정렬 불가 | 오차 없음이 아니라 정의 대상 없음 |

실제 관찰 glyph ID는 [35,75,123,106,35,14918,4842,35,35]이며 .notdef 0은 없었다.
공백 glyph와 advance는 남는다. 기본 로컬 ink 높이는 2.888671875mm로 em 3mm와 다르며,
이 높이를 3mm로 맞추는 재배율은 하지 않는다. 정렬은 이동만 하므로 크기/자폭/간격을 바꾸지 않는다.

별도 생성한 100개 서로 다른 run의 single/4-isolate 결과에서 시간 필드를 제외한 glyph·cluster·advance·offset·경로·경계·정렬이 일치했다.
AOT에서도 검사했다. 1e-9mm는 이 시험의 중심 잔차 확인 기준일 뿐 제작 공차나 모든 font의 절대 정확도 보장이 아니다.

독립 기대값:
- 2차 arch (0,0)–control(10,20)–(20,0)를 동등 cubic으로 전달: 실제 box [0,0,20,10].
- 45° 후 실제 box [-2.5/√2,0,20/√2,22.5/√2]. 기존 box를 회전한 결과와 다르다.
- cubic (0,0), (0,12), (12,12), (12,0): 최대 Y=9.
도함수 극점을 검사했고 control box/Flutter Path.getBounds로 대체하지 않았다. 극한 double 범위 전체의 일반 CAD 검증은 아니다.

native face 해제 후 보유 윤곽/경계 사용, 정상 공백/미지원 결합 문자/없는 font 실패 구분,
취소 후 다음 작업·실행 중 close·반복 close·worker 상한을 테스트했다.
Flutter gesture 시험의 드래그/확대와 1배·2배 offscreen 출력에서도 원본 좌표/중심이 유지됐다.
다른 실제 모니터/DPI로 창을 이동한 시험은 하지 않았다.

## 4. 실행 방식과 상한

| 방식 | 비교 | 구현 |
| --- | --- | --- |
| 계산 isolate 1개 | UI와 계산 분리, 가장 작은 시작 비용 | 기준값 |
| Dart isolate 최대4개 | **한 OS 프로세스의 병렬 실행**. worker별 factory/face·cache, ID 대신 순번으로 결과 슬롯 복원 | 실제 선택·비교 |
| native 자체 thread pool | nested 과잉 thread/작업 취소/자원 제어 필요. 이번 DirectWrite 호출은 동기이며 내부 thread는 OS 책임 | 별도 pool 추가하지 않음 |
| OS worker 프로세스 | Windows AOT/C ABI 부분은 UI 없이 독립 실행 가능. stdin/stdout framing 또는 binary IPC, 프로세스 시작/복사 비용·실패 복구·배포 필요. native crash를 UI에서 격리하는 장점 | IPC worker는 미구현. 이번 범위는 isolate로 충분하며 프로세스 장애 격리는 보장하지 않음 |

최대4 worker, 각 최대32문구 한 batch, 전체 요청1개/최대1,000객체, 별도 무제한 대기 큐 없음.
1객체는 한 worker만 계산하므로 4개를 미리 열 이유가 없다. 필요 시 큰 묶음에서만 제한 병렬화를 검토한다.
한 문자열의 glyph별 FFI 왕복 대신 여러 문자열을 한 native 호출로 전달한다.
worker 입력은 strings/폭/각도, 결과는 독립 typed 좌표/glyph와 작은 값이다. Widget/Context/Path/포인터는 보내지 않는다.

epoch를 올리면 후속 묶음 공급/옛 결과 게시를 중단한다. UI도 generation·mounted로 옛 화면 반영을 차단한다.
완료 순서는 원래 입력 슬롯으로 복원한다. 진행 중 font 경로 변경은 막는다.
취소/close는 현재 native 묶음을 마친 뒤 face/receive port/cache를 해제한다. native hang/crash 강제 복구는 지원하지 않는다.
worker 하나가 응답하지 않는 내부 결함의 timeout/재시작은 미구현이다. OS 강제 종료에서 Dart 비동기 cleanup 완료까지 보장하지 않는다. 정상 font 실패는 단계+HRESULT 예외로 전달하며 빈 경로로 바꾸지 않는다.

worker LRU는 64개 또는 추정 payload 16MiB 중 먼저 도달한 한도, UI Path cache는 64개/command payload 4MiB 한도다.
UI는 상한 도달 시 cache를 비우고 너무 큰 단일 경로를 보관하지 않는다. font 재준비 때 Path cache도 폐기한다.
활성 scene 결과/Path·Map 오버헤드·DirectWrite·Flutter/GPU 메모리까지 이 payload 한도로 제한한다는 뜻은 아니다.
close/dispose에서 cache/worker를 정리한다. native glyph cache와 GPU 메모리의 정확한 상한은 미확인이다.

## 5. CPU AOT 성능

측정 PC: Ryzen5 3600(물리6/논리12), RAM 34,305,093,632 bytes, RTX3060,
driver32.0.16.1088, 화면60Hz. 기존 IDE 등 일반 실행 환경이며 전용 성능 시험실 조건은 아니다.
고정 Dart의 compile exe(AOT release), 각 조건3회. screen 시험과 CPU 시험은 최종 측정을 겹치지 않았다.
규모1/100/1,000은 실험값이며 업무 부하/제품 기본값이 아니다.
cold는 새 pool/context와 자체 cache 없음이다. OS disk/font cache를 강제 비운 cold boot 측정은 아니다.

아래는 request wall ms 중앙값 [최소,최대], pool 초기화 별도다. 3회뿐이므로 정밀한 p99 추정은 하지 않는다.

| 문구/규모, 자체 cache 없음 | 1 worker | 4 workers |
| --- | ---: | ---: |
| 반복1 | 1.05 [0.98,1.34] | 1.29 [1.08,1.42] |
| 반복100 | 64.75 [64.43,76.36] | 45.04 [42.36,46.18] |
| 반복1,000 | 680.77 [667.34,705.16] | 392.03 [386.84,392.70] |
| 서로 다름1 | 1.40 [1.33,1.41] | 1.61 [1.58,1.69] |
| 서로 다름100 | 119.05 [116.06,119.21] | 74.23 [69.29,75.38] |
| 서로 다름1,000 | 1493.98 [1424.14,1519.89] | 704.82 [672.65,713.06] |

| 재사용 wall ms 중앙값 | 1 worker | 4 workers |
| --- | ---: | ---: |
| 반복1 / 100 / 1,000 | 0.03 / 0.27 / 1.57 | 0.04 / 0.11 / 0.71 |
| 서로 다름1 / 100 / 1,000 | 0.04 / 156.91 / 1403.24 | 0.03 / 0.30 / 678.40 |

64-entry LRU보다 큰 working set은 재사용 효과가 없다. 서로 다른100개는 1 worker에서 thrash,
4 worker에서는 약32개씩 배분돼 hit가 가능했다. cache 배치/완료 timing에 따라 hit율이 달라지는 효과를 병렬 속도 향상과 혼동하지 않는다.
서로 다른1,000은 양쪽 모두 miss다. 1 worker/100개 warm가 cold보다 느린 관찰도 숨기지 않는다.

새 pool+font 초기화 중앙값은 해당 조건 약0.94~1.56ms(1),1.98~2.44ms(4).
객체마다 font context를 다시 열면 1/100/1,000개 wall 중앙값2.73/215.93/1984.24ms,
이 중 초기화 합1.00/76.49/703.80ms였다. worker도 매번 새로 만드는 방식은 위 cold init으로 구분했다.
재사용 pool의 초기 생성 비용은 warm 측정 밖이며 무료라는 뜻이 아니다.

1,000 unique·1 worker의 단계별 중앙값: native batch+JSON 왕복1265.12ms,
그 안의 shaping27.11ms·outline20.18ms, Dart 배율/회전/극점·정렬216.61ms.
따라서 **현재 큰 병목은 native JSON 직렬화·Dart 해석/복사**다. nativeBatch는 순수 FFI latency가 아니다.
parent roundtrip-worker 경과 차이는 전송/수신+스케줄링/복사를 포함한 envelope이며 순수 IPC 계측이 아니다.
4개 worker의 단계 합은 동시 실행 합계이므로 wall보다 클 수 있다. cache hit에 과거 계산 시간을 다시 합산하지 않게 계측했다.

AOT peak RSS 약88.3MiB, case 종료 RSS 최대78.1MiB.
논리 결과 payload 합 최대10,134,400bytes, worker cache 추정 payload 최대707,408bytes/worker였다.
중복 참조/Map/allocator/native 메모리를 정확히 더한 값이 아니므로 RSS와 구분한다.

## 6. GPU·화면 계측

실제 Windows **profile** 실행 PID68692. auto 확대/이동 중 1,000객체 계산 요청을 반복했다.
조건별 한 번의 약8~9초 구간, frame 샘플507/492/489개다. 숫자 순서는 p50 / p95 / p99 / max (ms).

| worker / clip 제외 | UI | raster | totalSpan |
| --- | --- | --- | --- |
| 1 / 켬 | 1.325 / 2.173 / 2.515 / 18.726 | 7.995 / 13.341 / 20.288 / 333.490 | 10.392 / 17.679 / 47.806 / 335.697 |
| 4 / 켬 | 1.482 / 2.943 / 4.336 / 11.622 | 8.911 / 13.334 / 15.973 / 25.601 | 11.578 / 16.446 / 20.925 / 30.561 |
| 4 / 끔 | 7.982 / 13.119 / 14.532 / 15.706 | 8.635 / 12.207 / 13.865 / 14.523 | 18.333 / 23.641 / 26.982 / 28.855 |

60Hz 예산16.67ms에 대해 4-worker/clip 켬의 p95는 이내, p99는 초과했다.
1-worker에는 335.7ms 긴 지연도 관찰됐다. 원인을 특정하지 못했고 삭제/평균으로 숨기지 않았다.
**항상 매끄러운 표시를 달성했다는 판정은 하지 않는다.** 객체 수가 장면에1,000개라는 뜻이며 모든 객체가 viewport에 보인 것은 아니다.

clip 제외는 실제 canvas local clip과 준비된 도면 box로 검사하며 실험 on/off의 UI p95가2.943/13.119ms로 달랐다.
변환 중 font 재로딩·재측정·전체 경로 재생성은 하지 않는다. RepaintBoundary와 고정 Path를 재사용한다.
이것은 임의 대형 도면용 spatial index 검증이 아니다. clip 밖 보조선/scene 크기 제한도 실험 범위다.

init 포함 첫 UI frame 준비까지1522.69/1113.44/648.43ms,
그중 Path 준비+상태 게시/endOfFrame48.95/60.86/43.35ms였다.
실제 모니터 present 완료/GPU fence 시간을 측정한 것이 아니다. 초기화·shader/OS 조건과 긴 지연을 포함할 수 있다.
화면 profile peak RSS208.7MiB, 활성 결과/Path/GPU 보관량 전체의 엄밀한 예산은 후속이다.

런타임 stderr가 Impeller(OpenGLESSDF)를 보고했다.
고정 engine의 Windows egl/manager.cc는 ANGLE D3D11 우선 경로와 WARP fallback을 갖는다.
실제 프로세스에 d3d11.dll/dwrite.dll이 로드됐으며 해당 PID의 GPU 3D 엔진 counter는 양수23샘플, 최대4%였다.
이를 합쳐 이번 실행에서 하드웨어 GPU 활동을 확인했다. adapter는 시스템의 RTX3060이다.
정확한 GPU command별 시간/VRAM peak/CPU와 GPU 작업 분해는 측정하지 않았다.
**raster 시간은 GPU 실행 시간이 아니다.** 외곽 측정을 GPU로 옮기거나 별도 shader/렌더러를 도입하지 않았다.

프로세스 관찰43.46초 동안 CPU time99.02초(평균 약2.28개 코어), thread 최대67개였다.
UI/raster/VM/OS thread도 포함하므로 이 값을 계산 worker 수로 해석하지 않는다.
isolate 최대4 외에 별도 native thread pool은 만들지 않았고 oversubscription 조합 실험은 하지 않았다.

## 7. 기록·실패·재현

로컬 원본(모두 Git 제외):
- .tooling/outline-results/1793546943834617/cpu-benchmark.json: 최종 단독 AOT72관찰+fresh context9관찰.
- .tooling/outline-results/1793547213416806/profile.json, accuracy.json, PNG: 최종 profile.
- .tooling/outline-measured-window.err 및 .gpu.json: renderer·PID GPU/CPU 관찰.
- [실제 Windows 렌더링 화면](../.tooling/outline-results/1793547213416806/accuracy-1793547243513276.png).

스크린샷은 실제 profile 앱의 RepaintBoundary PNG를 읽어 확인했다.
H/x/g와 한글의 방향·외곽·회전·목표점·회전 기준선을 확인했으며 잘림/재줄바꿈은 보이지 않았다.
Computer Use는 창을 발견했지만 앱 승인 timeout으로 OS screenshot/실제 마우스 입력 검사는 완료하지 못했다.
자동 viewport 변환은 실제 profile에서 실행했고 드래그는 Flutter widget 시험으로 검사했다.
다른 모니터 DPI/TypeEdit 정밀 중첩/새 CAD 재시험은 하지 않았다. GPU counter 조회와 화면 capture 도구의 계측 부하도 포함된 환경이다. 기존 DXF 검증을 무효화하거나 재시험을 요구하지 않는다.

정상 오류 예: openFontFile + HRESULT -2003283965(없는 파일),
unsupportedCharacter + E_NOTIMPL(이번 지원 밖 결합 문자).
글꼴 전체/원문 전체를 오류로 덤프하지 않는다. native error buffer는 같은 FFI 호출에서 복사해 thread-local 조회 순서에 의존하지 않는다.
native 내부 결함/응답 정지 복구·glyphMissing 강제 font 사례는 미검증이다. 운영 수준 진단 모델은 후속 계약이다.

실제 검사: pub get, format, strict 분석, 책임별 단독 테스트와 전체15테스트,
native Release 빌드, Dart AOT 정확성/취소 검사·성능, Windows profile 빌드/실행,
루트 표준 verify와 Git 제외/스테이징·형제 상태/문서 링크 확인.
초기 시험의 없는 파일 기대 단계(analyzeFont→실제 openFontFile)와 양의 드래그가 viewport 경계에서 제한된 시험 준비를 수정한 뒤 재검사했다.
재빌드 중 실행 DLL 잠금 실패도 발생했고 이전 시험 프로세스 정리 후 빌드를 재실행해 성공했다.
예비 측정은 남겨 두되 위 최종 기록과 섞지 않았다. 원격 CI/다른 PC/배포/전체 Unicode 지원은 미실행이다.

## 8. 정식 구현으로 넘길 판단

가져갈 책임: 동일 face·glyph run/윤곽 연결, Flutter 없는 curve bounds/변환,
원본을 변경하지 않는 외곽 정렬, bounded worker와 자원 소유권, 실패/공백 구분.
실험에 남길 것: 문자열 키 Map/JSON C ABI·하드코딩된3mm/목표점·합성 workload·자동 benchmark UI·로컬 font 기본 경로.
정식 모델·viewer API·새 공통 패키지·engine·DXF·앱 연결·3D는 구현하지 않았다.

다음 한 가지는 **동일 glyph/윤곽 정확성을 유지하는 묶음 binary 전달 실험**이다.
지금 병목으로 관찰한 JSON만 대체하고 동일 단일/4-worker 기대값·초기/재사용·frame 긴 지연을 재측정한다.
backend 정식 채택과 공통 패키지 위치는 이 비용/지원범위 검토 뒤 결정한다.