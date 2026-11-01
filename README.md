# r_edit_viewer

R-edit의 독립 Flutter viewer 패키지다. 현재는 **Flutter package 개발 기반과 책임 계약만 준비**했다.
렌더러·표시 입력 모델·DXF 파서·글꼴 처리·앱 연결은 구현하지 않았다.
공개 진입점은 `lib/r_edit_viewer.dart`이며 아직 사용 가능한 표시 API/위젯은 없다.

책임은 도형/글자 표시, 도면↔화면 좌표 변환, 확대/이동, 선택 표시와 기준점/경계 보조선이다.
업무 규칙·자동 줄바꿈/배치 탐색·제작 판정·저장/동기화·DXF 해석/생성은 포함하지 않는다.
계산 결과와 외부 파일에서 얻은 도안 모두를 표시하는 방향이며 DXF 전용 입력 구조로 고정하지 않는다.

- [개발 기준과 SDK 준비](docs/development-foundation.md)
- [패키지 책임·글자 외곽 원칙](docs/package-contract.md)
- [다음 한 가지 작업](docs/next-step.md)
- [작업 지침](AGENTS.md)

Flutter 3.47.7 / Dart 3.13.5, FVM 4.3.2를 사용한다. 최초 SDK 준비는 개발 기준을 따른다.

```powershell
./tool/fvm.ps1 flutter pub get
./tool/fvm.ps1 dart tool/verify.dart
```

기본 Calculator와 전용 테스트를 제거했다. 현재 테스트는 없으며 통과용 테스트를 추가하지 않는다.
`example/`은 나중에 독립 실행·검증 화면이 실제 필요할 때 만들 위치다. 이번에는 폴더나 데모 앱을 만들지 않았다.
현재 runtime 의존성은 Flutter SDK뿐이며 workflow 의존성이나 네이티브 plugin은 없다.
발행은 `publish_to: none`으로 막았다. 배포 라이선스는 미정이며 생성기의 LICENSE 자리표시자는 제거했다.

다음 작업은 **viewer 표시 입력과 공통 글꼴 외곽 측정의 연결 계약 설계**다.
