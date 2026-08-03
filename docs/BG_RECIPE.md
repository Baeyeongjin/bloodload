# 배경 생성 레시피

> 마지막 업데이트: 2026-08-03

**추가 맵을 만들 때 이 파일만 보고 그대로 따라 하면 된다.** 톤·크기·지면 위치가
어긋나면 코드를 고쳐야 하므로, 새 배경도 반드시 이 규격으로 뽑는다.

---

## 규격 (바꾸면 코드도 바꿔야 함)

| 항목 | 값 | 왜 |
|---|---|---|
| 도구 | `create_image_pixen` | 1 generation. pixflux는 400px 상한이라 못 씀 |
| 크기 | **768 × 160** | 세로 160×2 = 320 = 전투 띠 높이에 딱 맞는다. 가로 768×2 = 1536 = 화면 폭의 2.6배라 같은 그림이 금방 안 돌아온다 |
| `detail` | `low detail` | |
| `outline` | `lineless` | 배경에 검은 외곽선이 들어가면 캐릭터가 안 떠 보인다 |
| `view` | `side` | |
| `no_background` | `false` | 장면이지 스프라이트가 아니다 |
| 지면 행 | 원본 **132**행 근처 | 코드가 `ground = 132` 고정으로 맞춘다. 바닥 띠를 그보다 아래에 깔리게 그려야 발이 닿는다 |

PixelLab 한계: 변당 16~768, 각 변 4의 배수, 총 면적 ≤ 512×512(=262144).
768×160 = 122880 → 통과.

---

## 프롬프트 틀

```
wide horizontal side-scrolling game background,
{장소},
flat walkable {바닥 재질} running along the whole bottom edge,
one tall dark {세로 기둥} at the far left edge and
one identical tall dark {세로 기둥} at the far right edge,
{작은 소품들} standing on the ground,
distant {원경} behind,
{팔레트} palette, flat muted colors, plain retro game pixel art
```

**세 문구는 반드시 넣는다:**

1. `wide horizontal side-scrolling game background` — 없으면 세로 구도로 그린다
2. `flat walkable ... running along the whole bottom edge` — 없으면 바닥이 안 생겨
   캐릭터가 허공에 선다
3. `one tall dark {기둥} at the far left edge and one identical ... at the far right edge`
   — **이음매를 숨기는 핵심.** 좌우 끝에 같은 기둥이 있으면 옆으로 이어 붙였을 때
   둘이 만나 굵은 기둥 하나로 읽힌다

**넣으면 안 되는 것:** `banner`, `flag`, `cloth drape`, `sign`, `tapestry` 등
**글자가 적힐 수 있는 물건.** 반드시 깨진 가짜 글자를 그려 넣는다 —
핏빛 성소 1차 생성이 이것 때문에 폐기됐다(붉은 천에 "Ж-Ж" 같은 글자가 박혔다).
대신 `iron brazier with crimson flame`, `bare stone altar` 처럼 글자가 안 붙는 물건을 쓴다.

---

## 실제 사용한 프롬프트와 job id

### 1막 깨어난 무덤 — `wide_graveyard.png`
`91508cde-06a7-46c1-b804-8834fd4154c6`
```
wide horizontal side-scrolling game background, dead graveyard forest, flat walkable
dirt ground running along the whole bottom edge, one tall dark bare tree trunk at the
far left edge and one identical tall dark bare tree trunk at the far right edge, a few
small gravestones and stone crosses standing on the ground, distant grey-green fog
hills behind, cold desaturated grey green palette, flat muted colors, plain retro game
pixel art
```

### 2막 화형의 언덕 — `wide_hell.png`
`3a927756-85fb-4c43-9035-31d8593a7660`
```
wide horizontal side-scrolling game background, burning hillside, flat walkable
scorched ground running along the whole bottom edge, one tall charred blackened dead
tree at the far left edge and one identical tall charred blackened dead tree at the far
right edge, small campfires and burnt stakes standing on the ground, distant smoking
orange-red hills behind, dark orange and ash grey palette, flat muted colors, plain
retro game pixel art
```

### 3막 서리 봉인지 — `wide_glacier.png`
`968f7be9-528e-41bb-b897-68579d323ed5`
```
wide horizontal side-scrolling game background, frozen glacier field, flat walkable
snow ground running along the whole bottom edge, one tall dark blue ice pillar at the
far left edge and one identical tall dark blue ice pillar at the far right edge, small
ice shards and frozen rocks standing on the ground, distant pale blue glacier ridges
and fog behind, cold pale blue and white palette, flat muted colors, plain retro game
pixel art
```

### 4막 핏빛 성소 — `wide_sanctum.png`
`f95d7ce2-a54a-4c11-bb43-c9e2d3223997` (재생성)
```
wide horizontal side-scrolling game background, dark blood sanctum stone crypt
interior, flat walkable dark stone floor strip running along the whole bottom edge, one
tall dark stone column at the far left edge and one identical tall dark stone column at
the far right edge, low bare stone altars and iron braziers with crimson flame standing
on the floor, distant deep red stone arches fading into shadow behind, dark crimson and
black stone palette, flat muted colors, plain retro game pixel art
```
> 폐기된 1차: `a9cfc90f-05cb-4e9f-b017-0c5d9048a8e8` — `crimson cloth drapes`를 넣었더니
> 붉은 천에 깨진 글자를 그렸다. 천 장식을 화로로 바꿔 해결.

### 5막 빼앗긴 본성 — `wide_castle.png`
`76746174-9572-41f9-8a0e-a1b32a705020`
```
wide horizontal side-scrolling game background, ruined dark castle great hall interior,
flat walkable cracked stone floor running along the whole bottom edge, one tall dark
purple stone column at the far left edge and one identical tall dark purple stone
column at the far right edge, rubble piles and a broken throne standing on the floor,
distant tall arched windows glowing violet behind, dark violet and black stone palette,
flat muted colors, plain retro game pixel art
```

---

## 받은 다음 — **반드시 이음매 처리**

좌우 끝에 같은 기둥을 그리게 해도 **하늘·산·지면 높이가 정확히는 안 맞아
이음매가 선으로 보인다.** 프롬프트로는 못 없앤다. 코드로 잇는다.

```bash
python tools/make_seamless.py
```

오른쪽 끝 48px 을 왼쪽 끝에 램프로 겹쳐 섞고 그만큼 잘라낸다(768 → **720**).
새 오른쪽 끝과 새 왼쪽 끝은 원본에서 원래 이웃이던 열이라 자연히 이어진다.
원본은 `*.orig.png` 로 남으므로 여러 번 돌려도 계속 좁아지지 않는다.

> 새 배경을 넣었으면 이 스크립트를 돌리고 `Grid.BG_SRC` 의 가로를 맞춘다.
> 안 돌리면 걷는 동안 몇 초마다 세로 줄이 지나간다.

## 받는 법

```bash
python tools/fetch_art.py <job_id> assets/bg/wide_<이름>.png
```

이미 있으면 건너뛴다. 그다음 `StageDefs.ACTS` 의 `bg` 경로에 추가한다.

## 폐기된 접근 (다시 하지 말 것)

| 시도 | 왜 버렸나 |
|---|---|
| 288×512 세로 배경 + 좌우 반전 사본 | 픽셀은 이어지지만 대칭 구도라 이음매가 **나비**처럼 보였다 |
| 지나가는 소품 레이어 | 배경이 흐르면 충분한데 화면만 복잡해졌다 |
| 짧은 배경(화면 폭)으로 감기 | 몇 초마다 같은 나무가 지나가 걷는 느낌이 죽는다 |
