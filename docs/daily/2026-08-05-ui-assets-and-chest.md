# 신규 UI 자산 적용 + 방치 보상 상자

> 작업일: 2026-08-05

## PixelLab 자산

`create_image_pixen`, `low detail`, `single color black outline`, `side`,
`flat muted colors, plain retro game pixel art` — 기존 UI 규칙 그대로.
사장님이 A/B 시트에서 **전부 B**를 선택했다.

| 파일 | 원본 크기 | job id | 비고 |
|---|---:|---|---|
| `assets/ui/pill.png` | 96×32 | `b226beef-17ba-487a-ab6e-d7218c75197f` | 철판 + 양끝 핏빛 보석 |
| `assets/ui/widget_bar.png` | 160×44 → **80×44** | `cb248c64-b510-4f17-b686-94fc4ae9ae7a` | 진홍 가죽 띠 + 리벳 |
| `assets/ui/round_btn.png` | 40×40 | `65b5865e-583d-4fef-a3dc-41aa082ac71f` | 흑요석 + 핏빛 장식 테 |
| `assets/ui/chest.png` | 40×40 | 사장님이 PixelLab 에서 직접 고른 zip | 고딕 보물상자 |

떨어진 후보(미채택): `ca41263f`(알약 금테), `2ad2545c`(석재 바), `a67e9eb4`(원형 금테).

### widget_bar 를 잘라 쓴 이유

원본 160px 가운데(x 60~74)에 **리벳 기둥**이 있다. 9-slice 는 가운데를 늘리므로
무늬가 있는 기둥이 그 안에 있으면 늘어나 뭉개진다. 찢어진 왼쪽(0~60)과 오른쪽
기둥(140~160)만 남겨 80×44 로 잘랐다. 가죽 무늬는 균일해서 가로로 많이 늘려도 산다.

### 9-slice 여백 (실측)

| 자산 | 좌우 | 상하 |
|---|---:|---:|
| `pill` | 30 | 6 |
| `widget_bar` | 16 | 8 |

`pill` 의 30 은 양끝 붉은 보석이 끝나는 지점이다 — 눈대중이 아니라 확대 렌더에
4px 눈금을 그려 읽었다(`scratchpad/uisheet/slice_check.png` 방식).

## 방치 보상 상자

**예전**: 접속하면 피가 지갑에 바로 들어가고 배너만 6초 떴다 — 받은 느낌이 없다.
**지금**: 계산은 접속할 때 하되 `chest_gold` 에 담아 두고, 눌러야 지갑에 들어간다.

- 자리는 **전투 띠 위쪽 하늘**. 처음엔 레퍼런스처럼 화면 가운데 아래에 뒀는데
  거기는 지면이라 몹 몸통과 겹쳤다(렌더로 확인). 그 다음 `VIEW_TOP+26` 은 HP 라벨과
  겹쳐서 `VIEW_TOP+44` 로 내렸다.
- `round_btn` 을 뒤에 깔았다. 상자만 있으면 배경 소품처럼 보이고 누를 것으로 안 읽힌다.
- 저장: `chest.gold` / `chest.minutes`. 옛 저장본은 0 으로 시작한다.
- 단계 전진 알림은 그대로 배너로 둔다(상자와 별개 정보다).

개발 플래그 `--chest` 추가.

## 검증

- 다섯 테스트 모두 Assertion 없이 통과
- 격리 렌더(`$env:APPDATA` 임시)로 알약·가이드 띠·상자 확인
