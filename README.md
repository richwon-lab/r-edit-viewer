# r_edit_viewer

R-edit의 독립 Flutter viewer 패키지다. 공개 진입점은 lib/r_edit_viewer.dart이며 아직 표시 API/위젯은 없다.
도형·글자 표시, 도면↔화면 변환, 확대/이동, 선택·기준점/경계 보조선이 책임이다.
업무 규칙·배치 탐색·제작 판정·저장/동기화·DXF 해석/생성은 포함하지 않는다.

- [개발 기준과 SDK 준비](docs/development-foundation.md)
- [패키지 책임](docs/package-contract.md)
- [글자 외곽 연결 계약](docs/text-outline-binding.md)
- [실행 실험 결과·정확성/성능·한계](docs/outline-experiment.md)
- [Windows example 실행](example/README.md)
- [다음 한 가지 작업](docs/next-step.md)

Flutter 3.47.7 / Dart 3.13.5, FVM 4.3.2를 유지한다.

    ./tool/fvm.ps1 flutter pub get
    ./tool/fvm.ps1 dart tool/verify.dart

루트 runtime 의존성은 Flutter SDK뿐이다. 정식 renderer·공통 font 패키지·workflow 의존성·앱 연결은 없다.
별도 example에는 DirectWrite+동일 glyph 윤곽·외곽 정렬과 bounded isolate의 실제 Windows 실험을 구현했다.
루트에는 동작 테스트가 없고 example에 책임별 테스트가 있다. example은 자체 의존성 해결/분석/테스트를 실행한다.
루트 분석에서 독립 example을 제외한 것은 중첩 의존성이 없는 checkout을 잘못 분석하지 않기 위해서다.
example의 strict 타입 분석과 실제 실행은 별도로 확인한다.

측정 원본·실제 font·DLL/build는 Git에 넣지 않는다. publish_to:none과 미정 배포 라이선스를 유지한다.
공식 채택·전체 문자/폰트 지원·항상 매끄러운 프레임을 이번 실험 완료로 간주하지 않는다.