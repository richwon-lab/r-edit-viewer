> 후속 상태(2026-11-02): 아래는 연결 계약의 설계 기록이다. 12절의 최소 실험은 [실제 실행 결과](outline-experiment.md)에서 수행했다. 정식 표시 API·공통 패키지 채택은 아직 없다.

# 글자 표시와 공통 글꼴 외곽 측정 연결 계약 — 설계

2026-11-01. **문서 설계이며 표시/측정 API·타입·인터페이스·새 패키지는 구현하지 않았다.**
[책임 계약](package-contract.md)과 [개발 기준](development-foundation.md)을 따른다.
확정 요구는 최신 사용자 결정, 아래 실행 방식은 추천안이며 미정 사항은 마지막에 모았다.
이미 확인한 DXF → CAD/TypeEdit 경로를 유지한다. TypeEdit 직접 입력·크기 대응 재시험을 선행 조건으로 요구하지 않는다.
이 문서의 예시는 설계용 합성이며 TypeEdit 실측/정밀 일치 결과가 아니다.

## 1. 확인한 실제 자료와 현재 차이

형제 파일은 읽기 전용으로 대조했다. 아래 경로는 각 형제 저장소 루트 기준이다.

| 기준 저장소/파일 | 실제 확인과 이번 해석 |
|---|---|
| r_edit_viewer의 AGENTS·책임/개발 기준·lib/r_edit_viewer.dart | 초기 기반만 있고 표시 API/모델 없음 |
| r_edit_workflow의 lib/r_edit_workflow.dart, lib/src/geometry/{point2,coordinate_space,path_segments,geometry_path,closed_boundary,drawing_geometry}.dart | Point2, mm/inch 문맥, 시작점+LineTo/ArcTo 경로, 원/닫힌 경계. Bézier/글꼴 fill 의미는 없음 |
| r_edit_workflow의 docs/font-measurement-contract.md | 명목/em/메트릭/잉크/advance·실제 자원·공통 측정 경계 구분. 과거 advance 정렬 추천은 최신 외곽 정렬 요구로 대체 |
| r_edit의 docs/dxf-flutter-render-probe.md | 합성 DXF의 실제 Windows 표시와 한계 기록. 외부 정밀 일치/실제 잉크 정렬 완료 기록이 아님 |
| r_edit의 tool/experiments/dxf_flutter_probe/lib/probe_scene.dart | TextPainter가 문자열을 배치하고 width로 좌/중/우 정렬. logicalBox는 advance×명목 높이 상자이며 ink 경계가 아님 |
| 같은 실험 lib/font_evidence.dart | glyf 헤더의 제어점 포함 bbox/cmap 검사. 실제 곡선 극점 측정/윤곽 경로 추출은 없음. HY cap 환산은 해당 실험 규약 |

참고한 HEAD: workflow `5a703f3809f056ecb5f9296524055509697a1faa`,
앱 `7788b33a0dccea4d36430434fa1b3b292fed98dc`, viewer 기반 `ec0136700bcc7ea4fda78c6bd05aa378654c2c9a`.
실제 작업 트리 파일을 읽었으며 위 커밋만으로 미커밋 내용을 읽었다고 대체하지 않는다.
기존 실험의 기본 글꼴/고정 cap-height/kerning off/논리 폭 정렬은 공통 규약으로 승격하지 않는다.

## 2. 두 방식 비교와 추천

| 판단 항목 | ① viewer가 문자열/글꼴 조건을 받아 측정 호출 | ② 공통 처리에서 선택·배치·외곽을 완료하고 viewer가 표시 |
|---|---|---|
| 소비 편의 | 초기 호출은 짧지만 비동기 font 접근·취소·실패·해제를 위젯 수명과 조정해야 함 | 준비 단계가 필요. 앱이 공통 준비를 한 번 호출하고 동일 결과를 화면/엔진에 전달하는 흐름으로 단순화 가능 |
| 측정 일관성 | 엔진과 viewer의 옵션/기본값/백엔드 차이로 다른 glyph·외곽이 나올 위험 | 동일 불변 배치/외곽을 소비. viewer가 다시 shaping하지 않는 것이 필수 |
| 자원 수명 | 화면 관찰/위젯 재생성과 실제 font face/캐시의 수명이 섞이기 쉬움 | 앱/공통 런타임이 font 수명, 결과가 사용 윤곽 수명, viewer가 화면 캐시를 소유하도록 분리 |
| 엔진 재사용 | 별도 공통 계층으로 분리하지 않으면 Flutter/viewer 의존이 엔진으로 전파 | viewer와 독립된 공통 출력이 엔진에도 사용 가능 |
| 성능/갱신 | 화면 build/zoom마다 재측정하지 않도록 별도 규칙 필요 | 입력 조건 변경 시에만 새 결과 준비. zoom/pan은 이미 준비된 기하의 화면 변환만 수행 |
| 주요 비용 | 편의 API가 사실상 자원/측정 orchestration 계층이 될 수 있음 | 윤곽 전달량·캐시/지원 표현·라이선스 및 준비 완료 대기가 필요 |

**②를 첫 추천으로 한다.** 공통 처리의 결과는 선택한 font와 확정 glyph 배치의 외곽·치수까지 포함한다.
viewer는 그 결과에 표현되지 않은 원문을 별도 TextPainter/시스템 font로 다시 그리지 않는다.
소비 앱은 자원 확보 → 공통 준비 → 표시의 한 흐름을 소유한다. 편의 래퍼가 필요해져도 공통 계층에서 검토하고
viewer 내부에 두 번째 측정 규약을 넣지 않는다. 이번에는 래퍼/서비스 인터페이스도 구현하지 않는다.

첫 표시 방식으로 **그 측정에 사용한 vector outline을 그대로 채우는 방식**을 우선 추천한다.
화면에서는 공통 경로를 Flutter Path로 변환해 그리되, 원문을 재shaping하지 않는다.
향후 glyph ID 기반 native 렌더링을 검토한다면 동일 face/instance·ID·위치/변환을 그대로 사용함을 입증해야 한다.
문자열만 넘기는 font 렌더링으로 교체해도 같은 결과라고 가정하지 않는다.
윤곽 표시의 작은 화면 raster 품질은 별도 평가 대상이며 글꼴 이용 조건 검토도 필요하다.

## 3. 데이터 흐름과 책임

1. 앱/상위 호출자가 원문 그대로, 실제 font 자원/face 선택, 지원할 언어/script/방향/features,
   명목 크기의 의미와 이미 해석한 em 길이·도면 단위를 공통 처리에 전달한다.
   자동/직접 줄바꿈과 줄 선택은 상위 배치/입력 책임이다. viewer가 재줄바꿈하지 않는다.
2. 공통 처리에서 실제 face/instance를 확정하고 shaping으로 glyph ID·원문 연결·advance/offset을 결정한다.
   한 문자=한 glyph 또는 glyph 순서=원문 순서라고 가정하지 않는다. 첫 지원 문자/기능 범위는 별도 확인한다.
3. **같은 실제 face/instance와 glyph ID**로 외곽을 취득한다. 합성 bold/italic·variation 등이 있다면
   glyph 형상/배치/측정 모두에 동일한 실제 설정을 적용하거나 미지원으로 거부한다.
4. 공통 처리에서 font units→도면 길이, 자폭을 적용해 객체 자체 좌표의 경로와 실제 경계를 준비한다.
   원래 font-unit 윤곽은 공유하고 최종 glyph별 변환으로 배치할 수 있다. 중복 경로 복사는 필수가 아니다.
5. 앱/배치 측은 이 불변 결과와 명시적인 객체 회전/위치를 도면에 배치한다. 외곽 정렬 명령은 그 기하로 이동량을 구한다.
6. viewer는 확정 기하/배치·단위와 표시 상태를 받아 화면 변환·fill·선택/보조 표시를 수행한다.
   배치 엔진은 동일 공통 근거를 독립 소비한다. workflow·엔진·DXF가 viewer 또는 Flutter 위젯을 필요로 하지 않는다.

공통 글꼴 처리는 **viewer와 나란히 소비되는 별도 공통 책임 패키지**에 두는 안을 추천한다.
viewer lib/src나 workflow의 업무 모델 안에 플랫폼 글꼴 처리를 넣지 않는다.
구체 패키지명·기존 글꼴 코드 재사용·네이티브 binding의 실제 위치는 후속 실험 후 결정한다.
이번에 저장소/패키지·공통 geometry·범용 adapter/plugin 체계는 만들지 않는다.

### 결과에 필요한 개념 — 필드/API 확정 아님

| 개념 | 의미·관계·단위 |
|---|---|
| 원문/줄·run 연결 | 원문/공백을 보존. 원문 범위와 glyph cluster 관계는 다대다일 수 있음. glyph 순서와 논리 문자열 범위를 구분 |
| 요청 font와 실제 face | 파일 경로/이름은 탐색 정보. 실제 bytes, face index, variation axes/합성 설정을 확정. glyph ID는 이 face/instance 안에서만 유효 |
| 자원 식별 근거 | 이름/버전/hash는 탐색·대조 보조. 실제 자원/내용 대응 검증을 대체하지 않음. 결과마다 전체 font를 복제하지 않음 |
| resolved shaping 조건 | 실제 direction/script/language/features·측정기/버전·측정 모드. 숨은 기본값 변경으로 같은 근거를 재사용하지 않음 |
| glyph 배치 | 각 실제 glyph ID, pen advance 벡터와 offset 벡터, cluster 연결. 전달용 배치 값은 em/자폭 적용이 완료된 객체 길이 단위를 사용하고 원래 font-unit 값은 구분된 근거로만 보존 |
| 윤곽 묶음 | face/instance+glyph에 연결된 contour·선/곡선·닫힘·fill 의미. 복합 glyph의 component 변환/구멍을 해결한 동등 형상이어야 함 |
| glyph→객체 변환 | em 길이/unitsPerEm·advance/offset·자폭으로 확정된 변환. viewer가 다시 font metric을 추정하지 않음 |
| 객체 외곽과 경계 | 최종 glyph 윤곽들의 실제 기여 형상과 그 객체 좌표 경계. 경계의 계산 방식/지원/오차 정보를 구분 |
| 객체→도면 변환 | 회전·이동. 객체 자체 경계와 도면 축 경계는 별도 파생값 |

배치의 정본은 advance/offset과 명시 변환이다. glyph origin은 pen+offset에서 파생한다.
계산해 둔 origin/합쳐진 경로/bounds는 불변 파생 캐시로 둘 수 있지만 별도 수정 가능한 두 정본으로 노출하지 않는다.
viewer용 Flutter Path/TextPainter/native face 핸들을 공통 값이나 저장 JSON의 정본으로 전달하지 않는다.
이 문서는 저장 형식/전체 배치 입력/저장 결과·확인 모델을 확정하지 않는다.

## 4. 크기·단위·변환 순서

- **명목 크기**는 사용자/외부 형식에서 지정한 값과 그 해석 근거다.
- **em 길이**는 도면 길이 단위에서 1 em의 길이다. UPEM은 face의 font units 수다.
  명목→em 대응 근거가 없으면 미확인으로 남긴다. 임의 HY 계수나 특정 glyph의 높이를 공통 상수로 쓰지 않는다.
- **baseline/pen**은 배치 좌표 기준, advance는 다음 pen까지의 벡터다. 문구의 실제 외곽과 다른 값이다.
- cap/ascent/descent/행 간격은 기준 메트릭이다. 실제 H/x/g/한글의 잉크 높이와 같다고 가정하지 않는다.
  원문이 바뀌어도 동일 크기 해석의 em 배율을 유지한다. 실제 외곽 높이에 맞춘 재스케일은 금지한다.

공통 객체 길이는 부모 도면 문맥의 mm 또는 inch를 따른다. X 오른쪽/Y 위쪽, 객체 원점은 첫 pen의 baseline 기준을 추천한다.
원점을 도형 왼쪽 아래나 ink min으로 강제하지 않는다. font 좌표가 다른 방향/단위라면 공통 처리 입구에서 명시 변환한다.
다른 단위의 객체를 같은 도면에 놓기 전 관련 경로/advance/offset/em 길이를 모두 환산한다. 단위 태그만 바꾸지 않는다.
backend가 26.6 pixel 같은 고정소수 표현을 반환할 수 있으므로 값의 원래 단위·분모·loading/hinting 설정을 기록해야 한다. 이를 font units라고 가정하거나 현재 화면 DPI로 제작 외곽을 역산하지 않는다.

첫 추천 변환 순서(가로쓰기·양수 자폭, 전단/반전/추가 tracking은 별도 미정):

1. shaping 결과 font-unit pen을 advance의 순서 있는 합으로 구하고 offset을 더한다.
2. 각 glyph의 윤곽/advance/offset에 동일한 `s=emLength/unitsPerEm`을 적용한다.
3. 객체 baseline 축에서 `W=diag(horizontalScale,1)`을 적용한다. glyph X offset/진행량/외곽에 함께 적용하고 Y는 바꾸지 않는다.
4. 필요하면 **실제 외곽**을 구하고 명시한 정렬 의미에 따라 객체의 이동을 결정한다.
5. 객체 회전 R(도면 Y 위에서 반시계 양수), 이동 t를 적용한다. viewport의 Y 반전/확대/이동과 DPI는 마지막 표시 단계다.

준비 과정의 단일 run 수식에서 u/o/p는 모두 같은 face의 font units다. glyph 점 u, glyph offset o, 누적 pen p이면 `qObject = W · s · (u+p+o)`,
`qDrawing = R · qObject + t`다. 여러 face/run은 각자의 UPEM/em 변환을 거쳐 같은 객체 길이 문맥에 놓인다. 자폭 전 공통 길이의 run 원점 b가 있으면 `qObject=W·(b+s·(u+p+o))`다. 서로 다른 UPEM의 pen을 직접 더하지 않는다.
결과의 advance/offset·glyph→객체 변환은 이 준비를 끝낸 값이다. viewer는 font-unit 수식을 다시 실행하지 않는다. 명목/em/자폭 정보를 provenance로 보존해도 이미 확정한 배치에 또 적용하지 않는다.
회전 중심이 객체 원점과 다르면 `R(q−pivot)+pivot+t`로 명시하고 어느 좌표의 pivot인지 구분한다.
화면 배율/DPI·pixel snapping·AA·hinting에 따라 제작 좌표의 외곽/bounds를 다시 측정하지 않는다.

## 5. 실제 외곽·제어점·경계 계산

경계는 같은 glyph 배치와 fill 의미로 실제 그리는 vector 형상에서 파생해야 한다.
contour의 방향/닫힘, 내부 counter, 겹침과 fill rule을 보존한다. contour마다 임의 홀로 바꾸거나 모든 면을 합쳐 채우지 않는다.
bitmap/color/SVG/지원하지 않는 variation 등 해당 경로 방식으로 동일 외곽을 제공할 수 없는 자원은 별도 미지원이다.
outline 없는 정상 공백과 달리 미지원 형상을 빈 윤곽으로 수락하지 않는다.

| 경계 종류 | 의미/사용 |
|---|---|
| 실제 vector 외곽의 축 경계 | 지원 곡선의 실제 극점과 fill 형상으로 구한 경계. 선택/외곽 정렬의 근거 |
| control-point bounds | on/off-curve 제어점의 min/max. 외곽을 포함해도 실제 선이 도달하지 않는 곳까지 클 수 있음. 캐시/빠른 제외의 보수적 보조일 뿐 |
| advance/행 상자 | 진행량/행 메트릭. 원문 공간 설명·caret 등의 별도 보조에 사용하며 실제 외곽 선택 경계라고 부르지 않음 |
| raster 경계 | 특정 배율/DPI/AA에서 색칠된 pixel 범위. 제작 외곽의 정본으로 사용하지 않음 |

TrueType glyf 헤더 bbox도 제어점을 포함하므로 그대로 실제 ink bounds로 사용하지 않는다.
Flutter Path.getBounds도 보수적/부정확한 경우가 명시되어 있어 그 반환값을 공통 정밀 측정 정본으로 삼지 않는다.
viewer가 동일 contour를 Path로 그릴 수 있다는 사실과 정확한 기하 경계 계산 가능성은 별개다.

선분은 양끝점, 2차/3차 Bézier는 각 축 도함수의 [0,1] 내부 근과 양끝점을 검토하는 방식이 첫 추천이다.
회전 후에는 변환한 곡선의 극점을 다시 구한다. 지원 backend가 검증된 tight bounds를 제공한다면 같은 의미를 입증해 사용할 수 있다.
수학적 극점 계산과 double 수치 오차/퇴화 곡선/overflow·fill 상쇄의 지원을 구분한다. '해석적'이라는 말만으로 무오차를 보장하지 않는다.
보이는 fill에 기여하지 않는 퇴화/상쇄 contour의 처리도 지원 계약에 포함해야 한다. 이해하지 못한 fill은 임의 경계로 정상화하지 않는다.

곡선을 polyline으로 근사한다면 길이 단위의 편차 한계·좌표/변환 단계·알고리즘·지원 곡선과 수치 실패를 함께 기록해야 한다.
샘플 수만 지정하거나 화면 pixel 오차만으로 제작 경계를 인증하지 않는다. 자폭 등 선형 변환 후 편차 상한도 다시 설명한다.
보수적 외접 경계는 보수적이라고 표시하고, 근사 경계는 오차 범위와 함께 제공한다. 미확정 허용오차로 정밀 정렬 성공을 선언하지 않는다.
첫 추천은 지원하는 Bézier의 vector 극점 계산이며, 공통 근사 상수·허용오차는 이번에 정하지 않는다.
글리프/텍스트 외곽의 bbox가 정확해도 글자-홀 충돌/제작 가능성 검사가 완료된 것은 아니다.

## 6. 객체 자체 경계와 회전 후 도면 축 경계·정렬

`G`는 크기/자폭까지 적용한 객체 자체 외곽이다. `BLocal=bounds(G)`와
`BDrawing=bounds(R·G+t)`를 구분한다. `bounds(R·BLocal+t)`는 보통 보수적인 사각형이며 BDrawing의 대체물이 아니다.
공통 좌표 기하 연산이 도면 축 경계의 수치 계산을 맡고 viewer는 그것을 표시한다. viewer만 가능한 측정으로 엔진을 묶지 않는다.
정렬 명령 소유 앱/편집 경계는 그 파생값을 사용해 이동을 요청한다. 캐시에는 회전/자폭/곡선 근거가 함께 맞아야 한다.

| 정렬 의미 | 이동 계산/추천 |
|---|---|
| 도면 축의 실제 외곽 경계 중심을 목표 q에 맞춤 | cD=center(BDrawing), Δ=q−cD, tNew=t+Δ. **첫 객체 중심 정렬의 추천** |
| 객체 자체 경계 중심을 회전해 목표에 맞춤 | cL=center(BLocal), tNew=q−R·cL(원점 pivot 기준). 회전 후 도면 AABB 중심과 다를 수 있어 별도 명령 의미 |
| DXF 원래 좌/중/우 삽입/정렬점 해석 | 형식 규약의 advance/baseline/STYLE·원래 group10/11 의미를 외부 해석기가 적용. 위 외곽 정렬 명령으로 자동 교체하지 않음 |

여기서 외곽 중심은 **해당 축 경계 사각형의 중심**이지 면적 무게중심이나 최소면적 회전 상자 중심이 아니다.
사용자 UI 명칭은 어느 기준인지 알려야 하며 TypeEdit의 모든 정렬 동작을 실측해 동일하다고 확정한 것은 아니다.
X/Y 중 하나만 맞추는 경우 선택 축의 Δ만 적용한다. 정렬은 크기·원문·glyph 배치·자폭을 바꾸지 않는다.
화면 확대/이동은 q/Δ의 도면 값을 바꾸지 않는다. 회전 pivot을 바꾸는 명령도 외곽 정렬과 별도다.

### 합성 곡선 반례 — 실제 font/TypeEdit 시험 아님

객체 길이 단위를 mm로 둔 가상 폐윤곽: 2차 Bézier P0=(0,0), P1=(10,20), P2=(20,0),
마지막은 P2→P0 직선이다. `B(t)=(20t,40t(1−t))`.
제어점 상자는 [0,20]×[0,20]이나 실제 경계는 [0,20]×[0,10]이다. 중간 제어점 y=20은 곡선 위 점이 아니다.
45° 반시계 회전 후 실제 축 경계는 `x=[−2.5/√2,20/√2]`, `y=[0,22.5/√2]`다.
그 중심은 `(8.75/√2,11.25/√2)`이고 R·center(BLocal)는 `(5/√2,15/√2)`여서 다르다.
회전한 local 사각형을 다시 둘러싼 상자는 `x=[−10/√2,20/√2]`, `y=[0,30/√2]`로 더 크다.
이 반례로 제어점/실제 곡선/회전 상자와 두 정렬 의미를 구분할 수 있다. 이 수치를 글꼴 보정값으로 쓰지 않는다.

## 7. 원문과 glyph/외곽 예시

다음은 필요한 동작의 설계 예시이며 실제 font 측정 결과가 아니다.

| 입력/변경 | 공통 처리→표시·정렬 의미 |
|---|---|
| H / x / g, 같은 해석된 em | 동일 face/크기 정책을 사용해 각각 glyph와 실제 외곽을 준비. x의 낮은 높이·g의 내려오는 획을 남김. 외곽 높이를 같게 재스케일하지 않음 |
| H 한글 g | 전체 run 조건에 맞춰 glyph 선택/위치를 확정. 문자별 advance 합이 shaping과 같다고 가정하지 않음. 누락/fallback은 실제 자원별로 판단 |
| `  H  g ` | 앞/반복/끝 공백을 보존한 pen/advance. ink는 보이는 glyph들에서 계산. 외곽 정렬로 이동하면 공백의 원문/진행량은 유지하되 논리 폭 중심을 맞추지는 않음 |
| 공백만 `   ` | 글꼴에서 정상 처리되고 잉크가 없으면 **성공·외곽 없음**. advance/원문/기준선 정보는 유지. 실패/unsupported와 다른 상태 |
| 자폭 1→0.8 | 준비된 외곽과 glyph X 위치/offset/advance를 동일하게 0.8 변환, Y 유지. 새 실제 경계로 정렬 이동을 구함. 자동 크기 변경 없음 |
| 자폭 적용 후 45° 회전 | 자폭은 객체 baseline 축에 먼저 적용. 회전한 실제 윤곽으로 도면 축 경계 재계산. 회전 후 화면 X 방향으로 자폭을 적용하지 않음 |

공백만 있는 객체에는 외곽 중심이 정의되지 않는다. 외곽 정렬은 '외곽 없음으로 적용할 수 없음'을 반환하는 안을 추천한다.
기준점/caret·목록 선택은 별도 UX로 허용할 수 있으나 advance 상자를 실제 외곽 선택 경계로 둔갑시키지 않는다.
아직 선택 UX를 구현하지 않았다. 명시적인 baseline 이동 명령은 외곽 정렬과 구분해 후속 검토한다.
빈 문자열의 허용 정책은 별도이며 이번에 workflow TextAreaInput의 빈 원문/CRLF 제한을 바꾸지 않는다.

## 8. 결과·font·캐시의 소유와 수명

| 대상 | 소유/수명 추천 |
|---|---|
| 원본 파일/실제 font 자원 접근 | 앱/상위 자원 경계. 로컬 파일/권한·face를 명시 확보. viewer가 경로를 보고 다른 font를 자동 탐색하지 않음 |
| native font face·shaper 런타임 | 공통 처리 런타임 소유. 사용 중 연산은 자원이 유효해야 하며 해제/실패를 진단. viewer 위젯 dispose가 공유 런타임을 종료하지 않음 |
| glyph 윤곽/불변 준비 결과 | 사용하는 contour/배치에 대한 강한 소유/참조 유지. 네이티브 포인터만 반환하지 않는 값 표현을 첫 추천 |
| 공통 캐시 | 실제 자원/face/instance·glyph/조건에 따라 재사용. 크기/개수 한도를 두고 활성 결과의 기하를 무효화하지 않는 정책 필요 |
| viewer Path/GPU/보조선 캐시 | 표시 수명에 따라 해제. 공통 측정의 정본 아님. 캐시 제거/zoom 변경이 원래 기하 측정을 바꾸지 않음 |

공통 런타임/cache의 원래 face가 닫히거나 캐시에서 빠져도, 이미 독립된 불변 윤곽을 가진 결과는 같은 형상을 계속 표시할 수 있는 안을 추천한다.
새 문구 재측정은 실제 자원이 다시 필요하다. 이름/hash만 남은 결과나 native 핸들만 빌린 결과로 같은 보장을 주장하지 않는다.
결과마다 font 전체/모든 glyph를 복제하지 않는다. 사용 glyph 윤곽을 불변 풀로 공유하며 자원 소유 경계의 메모리 한도/해제를 설계한다.
font bytes·윤곽 추출/부분 배포/임베딩의 권리는 별도 확인하며 로컬 읽기 성공만으로 허가를 단정하지 않는다.
새 원문/face/feature/크기 해석은 새 측정 근거를 요구한다. viewer가 과거 결과를 새 문자열에 자동 재사용하지 않는다.
캐시 키는 실제 font 내용/face/axes·glyph·shaping 조건·모드/변환을 구분해야 하며, hashCode/파일명만으로 근거 동일성을 확정하지 않는다.
내부 캐시/결과를 JSON 저장 API로 노출하는 설계는 이번 범위 밖이다.

## 9. 진단 책임

공통 처리의 예상 실패와 viewer가 받은 손상된 입력/API 오용을 구분한다. 아래는 코드 이름/enum 확정이 아니라 진단 범주다.

| 상황 | 발생/진단 경계와 필요한 상세 |
|---|---|
| 글꼴 없음/접근 실패 | 앱 자원 경계: 요청 자원/face·발생 연산·접근 오류 코드·원인/최초 스택. 민감한 절대 경로를 무조건 로그에 남기지 않음 |
| glyph 없음/미확정 fallback | 공통 선택 단계: 실제 face/instance·누락 코드 포인트/cluster 범위·요청 기능. 요청 font와 실제 대체 font를 혼동하지 않음. 첫 지원은 자동 fallback 비허용 추천 |
| 미지원 기능/형상 | 공통 처리: 요청/지원 범위·실제 glyph/윤곽 종류·연산·run/glyph 위치. 색 glyph/미지원 곡선을 사각형/빈 외곽으로 바꾸지 않음 |
| 측정/수치 실패 | 공통 측정: 실제 face·run/glyph·경계 계산 연산·문제 수치/표현 불가·하위 원인. 정상 폭 0/외곽 없음과 구분 |
| 근거/자원 불일치 | 공통 검증/소비 경계: 기대/실제 자원·face/조건과 불일치 항목. font 전체/원문을 진단에 복제하지 않음 |
| 표시 backend 미지원/자원 해제 | viewer/공통 런타임의 해당 경계: 필요한 경로 기능/실제 backend·연산·참조 자원의 상태. 재shaping/대체로 성공 처리하지 않음 |
| 외곽 없는 정상 결과의 외곽 정렬 요청 | 명령 경계: 대상 객체 식별·요청 정렬 기준·외곽 없음. font 측정 실패로 오진하지 않음 |
| 손상된 배치/경로 연결·API 오용/내부 결함 | 실제 경계의 인자 검증/예외. 코드 결함을 일반 '미지원' 또는 공백 성공으로 숨기지 않음 |

진단의 문자 위치는 UTF-16 코드 단위의 반열림 범위를 추천하며 glyph index/cluster index와 구분한다.
원문과 연결을 유지하고 surrogate pair 중간과 grapheme 내부 경계는 다른 문제로 설명한다.
결합 문자/ZWJ의 지원·분할 정책은 미정이며 현재 원문 허용 조건을 바꾸지 않는다.
shaper의 UTF-8 byte cluster를 그대로 Dart 문자열 index라고 전달하지 않는다.
오류 위치는 원래 입력·run·glyph/contour 중 실제 있는 범위를 가리키고, 목록 위치 기준을 명시해야 한다.
하위 진단/원인/스택을 보존하고 UI 문구·정상 거부 처리·로그 기록은 앱 경계가 소유한다.
원문 전체/font bytes/전체 윤곽/상태를 로그로 덤프하거나 메시지 파싱으로 오류를 복구하지 않는다.

## 10. workflow 실제 기하와의 연결 한계

| 현재 타입/검증 | 글꼴 외곽과 대조한 결과 |
|---|---|
| Point2 / DrawingCoordinateSpace | 유한 2D 좌표·mm/inch·X 오른쪽/Y 위 의미는 맞출 수 있음. 소유 패키지/공유 API가 정해졌다는 의미는 아님 |
| PathSegment sealed / LineTo / ArcTo | 선분과 원호 bulge만 지원. quadratic/cubic Bézier의 제어점을 손실 없이 담을 수 없음. sealed 타입을 외부 패키지에서 임의 확장할 수도 없음 |
| GeometryPath | 시작점+순서 있는 구간. 같은 시작/끝 퇴화 구간 거부·원호 파생 수치 검증. 글꼴 contour의 퇴화/복합/암묵 곡선 규약을 해결하는 검증이 아님 |
| CircleBoundary / PathBoundary | 원/명시 닫힌 경로. glyph 전체의 여러 contour·counter/방향/fill 규칙·component 변환을 담는 계약은 없음 |
| DrawingGeometry / DesignGeometry | 도면/업무 형상의 묶음·단위/역할 책임. font/glyph 배치·실제 외곽 측정 결과의 대체 타입이 아님 |

TrueType은 2차 곡선·off-curve 점/복합 glyph, CFF 계열은 3차 곡선 표현이 필요하다.
폰트의 반복 contour/구멍·component 변환을 해결해 같은 선분+quadratic/cubic Bézier·닫힘/fill 의미로 전달하는 방향을 추천한다.
원호로의 근사는 일반적으로 동일 곡선이 아니며, 오차 정책 없이 ArcTo나 다각형으로 대체하지 않는다.
확대율에 따라 재근사한 도형을 도면 측정 정본으로 쓰지도 않는다.

필요한 추가 표현은 **2차/3차 Bézier, 여러 닫힌 contour와 fill 의미, glyph별 변환/배치, 실제 경계와 품질/오차 근거**다.
기존 업무 geometry enum을 이번에 늘리거나 viewer에 복제하지 않는다. 글꼴 공통 결과의 표현을 정한 뒤
도안 선/원호와 어떤 부분을 공유/변환할지 검토한다. 소비는 공개 API만 사용하며 내부 src를 가져오지 않는다.

## 11. 확정 요구·추천·미정

**확정 요구:** 외곽 기반 선택/정렬, 동일 실제 font/glyph 배치로 표시와 측정, 화면과 제작 좌표 분리,
원문/공백 보존, 문구별 높이 재조정 금지, DXF 삽입점과 외곽 정렬 구분, 공통 측정의 엔진 재사용,
미지원/누락을 정상으로 숨기지 않음. 기존 CAD/TypeEdit 검증 경로 재시험은 이번 설계의 선행 조건이 아니다.

**추천:** 공통 처리 완료 후 불변 glyph/윤곽 결과를 viewer와 엔진이 소비하는 ②안,
동일 contour의 경로 표시, font-unit 근거+도면 길이의 최종 배치/변환,
선·2차·3차 곡선을 보존한 실제 vector 경계, 도면 축 AABB 중심 정렬을 첫 명시적 외곽 중심 정렬로 사용,
외곽 없음은 정상 값으로 구분하고 외곽 정렬은 별도 적용 불가로 처리,
사용 윤곽을 보유하는 결과와 앱/공통 런타임/font 캐시·viewer 화면 캐시의 수명 분리.

**미정:** 공통 패키지의 이름/기존 코드 재사용/언어·backend·라이선스, 실제 glyph/contour 출력 형식,
shaping 기능/언어/문자 범위·variation/color 지원, 명목→em 해석 책임의 구체 API,
오차/수치 한계·fill/퇴화 처리·곡선 근사 허용 여부, 캐시 한도/결과 보관 비용,
공백 선택 UX·추가 tracking/다중 줄/반전·전단·정렬 UI 이름, 공개 타입/오류/공유 geometry의 소유권.
미정은 구현자의 임의 기술 선택 허가가 아니다. 계약 검토 전 표시 API를 먼저 만들지 않는다.

## 12. 가장 위험한 가정과 다음 최소 실험 한 가지

위험한 가정은 **실제 사용할 공통 backend가 같은 face/instance의 확정 glyph 배치와 그 Bézier 윤곽을 함께 제공하고,
viewer가 문자열 재배치 없이 그것을 그려 실제 경계로 선택/정렬할 수 있다**는 것이다.
현재 TextPainter 논리 폭+별도 glyf bbox 조합으로는 이 가정을 입증하지 못했다.

다음 한 가지는 이 **동일 glyph 배치/윤곽의 끝까지 전달 실험**으로 추천한다. 구현은 이번에 하지 않는다.
기존 고정 SDK와 허가된 로컬 TrueType font 한 face, 해석된 em 길이 하나를 고정한다.
` Hxg 한글  ` run 하나와 공백만인 run 하나를 준비하고, 기본 배치와 자폭 0.8+45° 회전의 두 상태를 한 작은 화면에서 비교한다.
실제 곡선 극점과 제어점 상자가 다른 위 합성 2차 곡선은 경계 계산의 독립 수치 반례로 곁들인다.
특정 HY 계수/고정 cap-height는 사용하지 않는다. 이 첫 실험 성공은 CFF/3차·전체 문자·배포 backend 지원의 검증이 아니다.

성공 판단: 요청/실제 face·glyph ID/cluster/advance/offset/윤곽 연결을 기록하고,
동일 경로로 표시/경계/정렬함을 확인한다. resource/cache 해제 후 보유 윤곽의 유효성,
공백 성공과 glyph/기능 실패 구분, zoom/DPI 변경 전후 도면 경계 불변을 검사한다.
좌표·도함수 극점의 독립 기대값을 사용하고, 화면 픽셀·동일 함수의 왕복만으로 정확성을 인증하지 않는다.
각 수치 오차와 backend 한계를 기록하며 미달 시 표시 API 구현으로 넘어가지 않고 실패한 능력/필요한 대안을 보고한다.
CAD/TypeEdit 재시험·DXF 재출력·회사 파일/생성 코드를 요구하지 않는다. 새 범용 측정 프레임워크/별도 저장소를 만드는 실험도 아니다.

### 공식 사실 확인 위치

2026-11-01 확인. 이 자료는 형식/API의 의미 근거이며 도구 도입·실기 성공 근거가 아니다.

- [OpenType glyf](https://learn.microsoft.com/en-us/typography/opentype/spec/glyf): on/off-curve·복합 glyph, 제어점 bbox의 한계.
- [OpenType CFF](https://learn.microsoft.com/en-us/typography/opentype/spec/cff), [FreeType outline 설명](https://freetype.org/freetype2/docs/glyphs/glyphs-6.html): TrueType conic과 PostScript cubic·contour/제어점 의미.
- [Flutter Path.getBounds](https://api.flutter.dev/flutter/dart-ui/Path/getBounds.html): 보수적/부정확한 bounds 사례.
- [HarfBuzz shaping 출력](https://harfbuzz.github.io/shaping-and-shape-plans.html): glyph ID/cluster·advance/offset과 원문 문자의 구분. 채택 결정 아님.

### 이번 문서 작업의 확인 범위

- 위 실제 소스/공개 export에서 선분·원호와 font curve/윤곽의 차이, 과거 실험의 advance 정렬/논리 상자를 확인했다.
- 고정 SDK의 `bin/cache/pkg/sky_engine/lib/ui/painting.dart`에서도 Path.getBounds의 보수적/부정확한 경계 설명을 대조했다.
- 합성 2차 곡선의 도함수 극점과 끝점을 산술 대조했다. 45° 후 중심은 약 (6.1871843354,7.9549512883),
  회전한 local 경계 중심은 약 (3.5355339059,10.6066017178)로 다르다. 소수 표시는 설명용이며 반올림/공차 정책이 아니다.
- viewer 문서 링크·실제 파일 경로와 단위/변환/정렬 의미를 확인했다. staged index의 초기 해시는 유지됐다.
- 변경은 이 문서·책임 계약·next-step 및 README의 현재 상태 연결뿐이다. 운영 코드/의존성/형제 파일은 변경하지 않았다.
- 글꼴 로딩·glyph shaping/추출·실제 외곽 측정·TypeEdit 시험·Dart/Flutter 생성/분석/테스트는 실행하지 않았다.
