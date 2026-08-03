# M3 장비 UI 가독성·희귀도 연출

> 작업일: 2026-08-03

## 완료

- 보관함 기본 정렬을 낮은 희귀도부터 보이도록 `일반→고급→희귀→영웅→전설`로 변경했다.
- 소환 화면의 보석·마일·조각 문구와 10연 결과 요약을 작은 글자로 바꿔 큰 수치도 잘리지 않게 했다.
- 장비 상세 팝업을 왼쪽 장비 전시, 오른쪽 장착/보유 효과, 아래쪽 `3×2` 정보칸과
  다섯 행동 버튼으로 재구성했다.
- 상세 팝업 버튼은 비용을 정보칸에서 보여 주고 `장착/Lv업/합성/분해/닫기`로 짧게 표시한다.
- 소환 결과에서만 희귀 장비는 반짝임 1개, 영웅은 2개, 전설은 4개와 등급색 점멸을 표시한다.
- 보관함과 상세 화면은 등급별 배경·테두리색만 사용하고 반복 반짝임을 표시하지 않는다.

## PixelLab 자산

`create_image_pixen`, `low detail`, `single color black outline`, `side`,
`flat muted colors, plain retro game pixel art` 규칙을 사용했다.

| 파일 | 원본 크기 | job id |
|---|---:|---|
| `assets/ui/gear_detail_panel.png` | 288×160 | `918adebc-382b-4e2c-bbac-01936ff16c2d` |
| `assets/ui/rarity_sparkle.png` | 16×16 | `1130722e-7ddd-4e7b-af58-1f203a05129a` |

## 검증

- `CombatRulesTest`, `GearTest` 통과
- `576×896`에서 10연 희귀/영웅 연출과 반짝임 없는 상세 팝업 확인
- 누적 140회, 조각 83개 상태에서 소환 화면 문구 잘림 없음
- 보관함 첫 화면이 일반 등급부터 채워지는 것 확인

개발 캡처 플래그: `--pull=gear:10`, `--tab=gear --gear-mode=inventory`,
`--gear-detail=first`.
