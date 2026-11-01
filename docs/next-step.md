# 다음 작업

공개 viewer 패키지는 아직 개발 기반과 [책임 계약](package-contract.md) 상태다.
[글자 외곽 연결 계약](text-outline-binding.md)의 동일 face·glyph·윤곽 가정은
[Windows 격리 실행 실험](outline-experiment.md)에서 실제 경로 표시·외곽 중심 정렬·1/4-isolate로 검증했다.
정식 backend/표시 API/공통 패키지는 아직 선택·구현하지 않았다.

다음 한 가지는 **정확한 동일 glyph/윤곽을 보존하는 묶음 binary 전달 실험**이다.
실제로 큰 비용을 차지한 native JSON 직렬화·Dart 해석만 대체하여,
동일 독립 기대값·단일/병렬 일치·수명/취소와 cold/warm 성능·frame 긴 지연을 비교한다.
정식 데이터 모델·backend 채택이나 새 패키지 분리는 이 전달 비용/지원 범위 검토 후 결정한다.

기존 DXF→CAD/TypeEdit 재시험은 선행 조건이 아니다.
전체 Unicode/font/제작 공차·GPU 계산·항상60fps·native crash 격리는 이번 실험에서 보장하지 않는다.
앱/workflow/SDK/CI/기존 스테이징은 변경하지 않는다.