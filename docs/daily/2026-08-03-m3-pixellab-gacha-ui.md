# M3 PixelLab 장비 소환 UI

> 작업일: 2026-08-03

## 완료

- 장비 보관함 카드를 화면 `112×128`로 확대했다.
- 카드 상단에는 `Lv.`, 중앙에는 장비 아이콘과 등급색, 하단에는 등급과 조각 수를 분리했다.
- 1회 소환 결과에 큰 카드 프레임, 10연 결과에 `80×96` 소형 카드 프레임을 적용했다.
- 소환 화면 왼쪽에 밤의 소환 제단을 배치하고 재화·천장·확률·보유 정보를 오른쪽에 정리했다.
- 장비 소환 화면에는 보관 장비 수와 보유 효과 적용 여부를 표시한다.

## PixelLab 자산

모두 `create_image_pixen`, `low detail`, `single color black outline`, `side`,
`flat muted colors, plain retro game pixel art` 규칙으로 생성했다.

| 파일 | 원본 크기 | job id |
|---|---:|---|
| `assets/ui/gear_card.png` | 56×64 | `aa3d8585-113d-468b-8292-f1c5e6da251d` |
| `assets/ui/gear_card_small.png` | 40×48 | `994cdb0f-1b62-462f-a352-cff86062d29a` |
| `assets/ui/summon_altar.png` | 64×64 | `cc80a0ba-03c9-4ba9-8f3a-7fe915c06045` |

## 검증

- `GearTest`, `CombatRulesTest`, `BalanceTest` 통과
- `576×896` 실제 렌더에서 소환 메인, 1회 결과, 10연 결과, 4열 보관함 확인
- 신규 PNG 세 장 Godot import 완료

개발 캡처 플래그: `--tab=summon`, `--pull=gear:1|10`,
`--tab=gear --gear-mode=inventory`.
