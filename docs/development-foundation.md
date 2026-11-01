# 개발 기준

## SDK·도구와 설치

형제 r_edit/r_edit_workflow의 AGENTS·현행 개발 기준·pubspec·분석 설정·FVM 구성을 대조했다.
기준은 **Flutter 3.47.7 / Dart 3.13.5 / FVM 4.3.2**다. 최신 버전이라는 이유로 업데이트하지 않는다.
.fvmrc는 프로젝트 SDK 버전, .fvm/flutter_sdk는 로컬 SDK 연결이다. SDK·캐시·IDE 설정은 Git 제외한다.
tool/fvm.ps1은 형제와 같은 방식으로 이 저장소의 .tooling/pub-cache·.tooling/fvm을 사용하고 프로세스 환경을 복구한다.
공유 SDK의 git/파일을 패치·upgrade하거나 전역 PATH/형제 설정을 변경하지 않는다.

최초 준비(다른 저장소 없이 설치 가능):

```powershell
# BootstrapDart에는 설치된 호환 Dart 실행 파일을 지정한다.
./tool/fvm.ps1 -BootstrapDart 'C:/path/to/dart-sdk/bin/dart.exe' install 3.47.7
./tool/fvm.ps1 -BootstrapDart 'C:/path/to/dart-sdk/bin/dart.exe' use 3.47.7 --force --skip-pub-get
./tool/fvm.ps1 flutter --version
./tool/fvm.ps1 dart --version
./tool/fvm.ps1 dart tool/verify.dart
```

이 기계에서는 이미 설치된 동일 SDK를 프로젝트 전용 FVM 캐시의 로컬 junction으로 참조해 중복 다운로드를 피했다.
이는 Git 제외 로컬 설정이며 형제 프로젝트를 필수 의존성으로 선언하거나 그 설정을 수정한 것이 아니다.
새 clone은 위 명령으로 자체 FVM 캐시를 준비한다. 로컬 캐시 재사용 경로를 소스/스크립트의 기본값으로 박아 넣지 않는다.
IntelliJ Flutter SDK는 이 저장소 .fvm/flutter_sdk, Dart SDK는 그 아래 bin/cache/dart-sdk다.

## 의존성과 분석

- 현재 runtime은 Flutter SDK만 사용한다. 개발 의존성은 very_good_analysis 11.0.0(MIT)이다.
  Flutter SDK의 라이선스는 BSD-3-Clause다. 설치된 형제의 공식 배포 pubspec/라이선스와 SDK 제약을 대조했다.
- very_good_analysis는 형제와 같은 버전을 사용한다. strict-casts/strict-inference/strict-raw-types를 적용한다.
  public_member_api_docs는 켜고 한국어 설명의 줄 길이 규칙만 예외로 둔다. 사용하지 않는 flutter_lints를 중복 포함하지 않는다.
- SDK 선언은 Dart ^3.13.5, Flutter >=3.47.7이다. 실제 실행 버전은 FVM으로 고정한다.
- 패키지 설명은 Windows의 Git 의존성 소비 문제를 고려해 ASCII 영문으로 유지한다. UTF-8/LF로 저장한다.
- pubspec.lock은 라이브러리의 로컬 해결 결과이므로 Git 제외한다. 원격/브랜치/기존 커밋은 바꾸지 않는다.
- 현재 테스트가 없어 flutter_test도 선행 선언하지 않았다. 첫 실제 테스트를 추가할 때 SDK 테스트 의존성과 사례를 함께 추가한다.
- Riverpod/라우터/DXF/글꼴 처리/코드 생성/workflow·공통 geometry 의존성과 native plugin은 사용처 없이 추가하지 않는다.
  Freezed 등 형제의 기술은 실제 반복 값/API가 생길 때 검토하며 이번에는 설치하지 않는다.
- 의존성 도입/교체는 공식 유지·라이선스·Windows/고정 SDK·역할 중복·대안·실제 해결/검증 근거를 기록한다. overrides로 충돌을 숨기지 않는다.

공식 기준: [분석 11.0.0](https://pub.dev/packages/very_good_analysis/versions/11.0.0),
[FVM 프로젝트 설정](https://fvm.app/documentation/getting-started/configuration),
[Flutter package/plugin 구분](https://docs.flutter.dev/packages-and-plugins/developing-packages).
형제의 실제 버전/설정이 이번 선택 기준이며 웹의 최신 버전을 채택했다는 의미가 아니다.

## 소스·오류·검증 규칙

- 영어 식별자와 Dart 표기 규칙, 한국어 중심 API 주석·문서·테스트 설명을 사용한다.
- lib/r_edit_viewer.dart를 공개 진입점으로 둔다. 실제 구현이 생기면 책임이 드러나는 lib/src 파일에 둔다.
  빈 계층·폴더·인터페이스·샘플 위젯을 미래 확장 명목으로 만들지 않는다.
- 공개 API는 의미·도면 단위·좌표 기준·불변식·실패 조건·검사하지 않는 범위를 설명한다. 이름을 풀어 쓴 주석으로 대체하지 않는다.
- 오류는 발생 이유·실제 위치·필요한 기대/실제 정보·관련 자원/연산과 대응을 설명해야 한다.
  오류 메시지 파싱·임의 Map·거대한 nullable 진단형을 공통 규약으로 만들지 않는다.
  정상 미지원과 결함을 구분하고 원인/스택을 보존한다. 미지원 표시/외곽은 기본 글꼴/0/임의 사각형으로 정상화하지 않는다.
- 원문/전체 객체/글꼴 bytes를 진단에 무조건 보관하거나 로그로 출력하지 않는다. 로깅 수명·출력 대상은 소비 앱의 책임이다.
- 테스트는 책임별 파일, 조건과 기대 결과가 드러나는 한국어 이름을 사용한다. 의미 없는 통과 테스트를 만들지 않는다.
  존재하는 테스트의 단독 실행과 전체 실행을 확인한다. 동작이 없으면 테스트 없음으로 보고한다.
- 완료 전 `./tool/fvm.ps1 dart tool/verify.dart`로 pub get·format 검사·strict 분석·존재하는 테스트를 수행한다.
  문서만 바뀌면 링크/용어를 검사한다. 향후 실제 example/네이티브 연결은 그 변경에 맞춰 실행/플랫폼 검사를 추가한다.
- 실제 검사·합성 사례·과거 실험·미실행을 구분한다. API/렌더링·외곽 측정·제작 가능성을 구현 완료처럼 쓰지 않는다.

초기 기반 시점에는 생성 도구·생성 소스·CI·example 앱이 없었다. 아래 초기 실행 기록은 당시 사실이다.
배포 라이선스는 미정이며 자동 생성된 LICENSE 자리표시자는 삭제했다. 새 라이선스를 임의로 선택하지 않았다.

## 초기 기반의 실제 확인 (2026-11-01)

- 기존 root Git·master·origin https://github.com/richwon-lab/r-edit-viewer.git을 유지했다.
  이미 생성된 Flutter package 골격을 정리했으며 새 프로젝트/.git이나 example 앱을 만들지 않았다. .metadata는 도구 관리 원본을 유지했다.
- viewer의 FVM 명령으로 Flutter 3.47.7(revision abaf9c5237), Dart 3.13.5, FVM 4.3.2를 실제 확인했다.
- flutter pub get 성공. runtime은 Flutter SDK, dev는 very_good_analysis 11.0.0만 직접 선언했다.
  기존 flutter_lints·flutter_test와 더 이상 필요한 곳이 없는 테스트 전이 의존성이 해결 결과에서 제거됐다.
- dart format lib tool과 tool/verify.dart의 재포맷 검사·flutter analyze --fatal-infos 성공(No issues found).
- 테스트 없음. flutter test/생성/AOT/Windows 실행/렌더링·외곽 측정은 수행하지 않았다.
- 기본 샘플 참조·문서 링크·pubspec ASCII/UTF-8/LF·Git 제외/줄바꿈·PowerShell 구문·기존 스테이징과 형제 Git 상태를 확인했다. 실제 프로젝트 Git 디렉터리는 루트 .git 하나이며, 형제 Git 상태는 변경되지 않았다.

## 격리 윤곽 실험 (2026-11-02)

최신 사용자 요청으로 example/에 독립 Windows 실행을 만들었다.
[실험 실행·의존성](../example/README.md)과 [실제 결과/한계](outline-experiment.md)를 따른다.
루트 운영 API/의존성/SDK는 유지한다. example은 Flutter 없는 AOT 계산 부분과 Flutter 표시 부분을 구분한다.
별도 pubspec/lock·flutter_lints와 strict 타입3종을 사용하고 자체 분석/책임별 테스트/Windows profile 검사를 실행한다.
루트 분석은 example/**를 제외한다. 종속 패키지의 pub get 여부가 루트 분석 결과를 바꾸지 않게 하며,
example의 검증을 루트 verify가 대신 수행했다고 보고하지 않는다.
추가한 .cpp/.h/CMakeLists.txt도 LF 관리하며 font·build·측정 원본은 Git 제외다.
정식 패키지 채택은 의존성·라이선스·정확성/성능 자료 검토 뒤 결정한다.