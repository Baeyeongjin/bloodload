---
name: bg-pipeline
description: bloodlord 배경(막/스테이지 그림)을 새로 만들거나 교체할 때 쓴다. PixelLab 생성 규격, 지면 행 고정, 이음매 처리의 순서를 강제한다. "배경 만들어줘 / 새 막 추가 / N막 배경 다시 뽑아줘 / 배경이 이상해" 같은 요청에서 사용.
---

# 배경 파이프라인

세 단계다. **순서를 바꾸면 조용히 되돌아간다.**

```
1. PixelLab create_image_pixen  768 × 320  →  assets/bg/{name}.orig.png
2. python tools/fit_ground.py     지면 실측 후 208줄 창을 떠낸다 (768 × 208)
3. python tools/make_seamless.py  좌우를 섞어 잇는다        (744 × 208)
```

## 지뢰 1 — 순서

`make_seamless.py`는 **`.orig.png`에서 다시 만든다.** 먼저 돌리면 `fit_ground`의
세로 자르기가 통째로 되돌려진다. 항상 `fit_ground` → `make_seamless`.

## 지뢰 2 — 지면 행은 생성 단계에서 맞추지 않는다

`fit_ground.py`가 실측해서 `[지면-145, 지면+63)` 창을 떠내므로, 생성물은 지면이
**320줄 중 45~80% 사이에만 오면 된다.** 가공 후 전 배경의 지면이 145행으로
고정된다 → `StageDefs.GROUND_ROW` 하나로 끝난다. 막마다 값을 적지 않는다.

`fit_ground`가 지면을 오검출한 사례: 화형의 언덕이 맨 아래 불꽃 때문에 313행으로
잡혔다. 탐색 범위를 잘라낼 창으로 제한해서 고쳤다 — 새 배경에서 또 나오면
`ground_row()`가 보는 범위부터 확인한다.

## 지뢰 3 — 생성물에 가짜 글자·간판이 섞인다

3막에서 두 번 나왔다. `distant ... ridges` 같은 **먼 산 지시가 원인**이다.
`plain empty pale sky above with nothing in it`으로 바꿔야 재발하지 않는다.
이미 섞였으면 해당 행을 아래 줄로 덮는다.

## 규격 (바꾸면 코드도 바꿔야 함)

| 항목 | 값 |
|---|---|
| 도구 | `create_image_pixen` (pixflux는 400px 상한이라 못 씀) |
| 생성 크기 | **768 × 320** |
| 최종 | **744 × 208** (`Grid.BG_SRC`) |
| 지면 행 | 가공 후 **145** (`StageDefs.GROUND_ROW`) |
| detail / outline / view | `low detail` / `lineless` / `side` |
| `no_background` | `false` — 장면이지 스프라이트가 아니다 |

PixelLab 한계: 변당 16~768, 각 변 4의 배수, **총 면적 ≤ 262144**.
768×320 = 245760 → 통과 (상한 바로 아래).

프롬프트 틀 전문과 필수 3문구는 `docs/BG_RECIPE.md`에 있다. 새로 뽑을 때 그 파일을 읽는다.

## 새 배경을 추가할 때 손댈 곳

1. `tools/make_seamless.py`의 `NAMES` 배열에 이름 추가
2. `Main.gd`의 `BACKDROP` 배열 (fit_ground 후 실측값)
3. `StageDefs.ACTS`

## 끝나면 검증

```bash
python3 -c "from PIL import Image; im=Image.open('assets/bg/{name}.png'); print(im.size)"
```
`(744, 208)`이 아니면 파이프라인이 안 돌았다.

그리고 `CombatRulesTest`가 배경 규격 3종(원본 크기·지면 행·막별 일치)을 검사한다.
`godot-verify` 스킬 참고.

## 안 고쳐도 되는 것

`make_seamless`의 이음매 블렌드(24열)는 팔레트를 10~15배 늘린다(18색 → 320색).
실측했다: RGB 거리 중앙 2.4~7.7, 오염 픽셀은 전부 `x=1~23`, 전체의 1.5%.
**지각 불가라 그냥 둔다.** 이음매가 안 보이는 대가다. 숫자가 커 보여도 손대지 말 것.
