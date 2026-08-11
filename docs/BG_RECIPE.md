# 배경 생성 레시피

> 마지막 업데이트: 2026-08-03

**추가 맵을 만들 때 이 파일만 보고 그대로 따라 하면 된다.** 톤·크기·지면 위치가
어긋나면 코드를 고쳐야 하므로, 새 배경도 반드시 이 규격으로 뽑는다.

---

## 규격 (바꾸면 코드도 바꿔야 함)

| 항목 | 값 | 왜 |
|---|---|---|
| 도구 | `create_image_pixen` | 1 generation. pixflux는 400px 상한이라 못 씀 |
| 크기 | **768 × 320** 으로 생성 → **744 × 208** 로 가공 | 세로 208×2 = 416 = **전투 띠 전체**. 그림 하나가 띠를 통째로 덮는다. 320 으로 넉넉히 뽑는 건 지면 행을 맞춰 잘라 내기 위한 여유다 |
| `detail` | `low detail` | |
| `outline` | `lineless` | 배경에 검은 외곽선이 들어가면 캐릭터가 안 떠 보인다 |
| `view` | `side` | |
| `no_background` | `false` | 장면이지 스프라이트가 아니다 |
| 지면 행 | 가공 후 **145행 고정** | 지면선은 막이 바뀌어도 같은 높이여야 한다. `tools/fit_ground.py` 가 실측해서 [지면-145, 지면+63) 창을 떠내므로 **생성 단계에서 맞출 필요가 없다** — 320줄 중 45~80% 사이에만 오면 된다 |

PixelLab 한계: 변당 16~768, 각 변 4의 배수, 총 면적 ≤ 512×512(=262144).
768×320 = 245760 → 통과 (상한 262144 바로 아래).

> **왜 160 에서 320(→208) 으로 갔나** (2026-08-05)
> 160 은 지면 위만 겨우 덮어서, 화면 위쪽 8~94px 과 지면 아래 88px 을 코드가
> 가짜로 메우고 있었다(하늘 그라데이션 · 담을 뒤집어 잇기 · 검정 페이드).
> 그래도 위쪽에 판때기 같은 띠가 남았다 — 사장님: "그 위에도 배경이 채워져
> 있어야 하지 않니". 208 로 다시 뽑으니 보정 세 가지가 전부 필요 없어졌다.
>
> 그런데 208 로 딱 맞게 뽑으면 **지면 행이 그림마다 101~160 으로 흩어진다.**
> 그러면 막이 바뀔 때마다 캐릭터 발밑 높이가 달라진다 — 사장님: "지면 높이가
> 막마다 동일해야 하는데". 코드로 배경을 밀어 맞추면 반대쪽에 빈 자리가 생겨
> 방금 지운 보정이 되살아난다. **320 으로 넉넉히 뽑아 그림을 자르는 쪽**이 답이었다.

---

## 프롬프트 틀

```
wide horizontal side-scrolling game background,
{장소},
flat walkable {바닥 재질} running along the whole width
  with the ground line about three quarters down the image,
below the ground line a deep vertical bank of {지면 아래 재질}
  filling the entire bottom quarter,
one tall dark {세로 기둥} at the far left edge and
one identical tall dark {세로 기둥} at the far right edge,
{작은 소품들} standing on the ground,
distant {원경} behind,
{팔레트} palette, flat muted colors, plain retro game pixel art
```

**세 문구는 반드시 넣는다:**

1. `wide horizontal side-scrolling game background` — 없으면 세로 구도로 그린다
2. `flat walkable ... running along the whole width` — 없으면 바닥이 안 생겨
   캐릭터가 허공에 선다
2-1. `below the ground line a deep vertical bank of ... filling the entire bottom
   quarter` — **지면 아래를 그림으로 채우는 절.** 없으면 지면이 그림 맨 아래에
   붙어서 위젯(보물상자·가이드)이 앉을 자리가 통째로 빈다
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
`2b9ab524-9d16-4b59-a688-894b47dc2817` (2026-08-05, 320줄)
```
wide horizontal side-scrolling game background, dead graveyard forest, flat walkable
dirt ground running along the whole bottom edge, one tall dark bare tree trunk at the
far left edge and one identical tall dark bare tree trunk at the far right edge, a few
small gravestones and stone crosses standing on the ground, distant grey-green fog
hills behind, cold desaturated grey green palette, flat muted colors, plain retro game
pixel art
```

### 2막 화형의 언덕 — `wide_hell.png`
`158c07b3-ec15-40ac-9763-37d9e3876902` (2026-08-05, 320줄)
```
wide horizontal side-scrolling game background, burning hillside, flat walkable
scorched ground running along the whole bottom edge, one tall charred blackened dead
tree at the far left edge and one identical tall charred blackened dead tree at the far
right edge, small campfires and burnt stakes standing on the ground, distant smoking
orange-red hills behind, dark orange and ash grey palette, flat muted colors, plain
retro game pixel art
```

### 3막 서리 봉인지 — `wide_glacier.png`
`d5a866fc-8ca2-447e-824c-9f99f9fec944` (2026-08-05, 320줄)
```
wide horizontal side-scrolling game background, frozen glacier field, flat walkable
snow ground running along the whole bottom edge, one tall dark blue ice pillar at the
far left edge and one identical tall dark blue ice pillar at the far right edge, small
ice shards and frozen rocks standing on the ground, distant pale blue glacier ridges
and fog behind, cold pale blue and white palette, flat muted colors, plain retro game
pixel art
```

### 4막 핏빛 성소 — `wide_sanctum.png`
`daeae78b-b009-4061-ad01-8ee7014ef302` (2026-08-05, 320줄)
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
`6aadcb90-7e5d-46b8-b0b9-6684e17d29b1` (2026-08-05, 320줄)
```
wide horizontal side-scrolling game background, ruined dark castle great hall interior,
flat walkable cracked stone floor running along the whole bottom edge, one tall dark
purple stone column at the far left edge and one identical tall dark purple stone
column at the far right edge, rubble piles and a broken throne standing on the floor,
distant tall arched windows glowing violet behind, dark violet and black stone palette,
flat muted colors, plain retro game pixel art
```

### 핏빛 미궁(던전) — `wide_maze.png`
`0049c514-04e1-4947-a2fc-62734ad3cc66` (2026-08-11, 320줄 · 지면 202행)
막이 아니라 **던전 전용**이다: `StageDefs.ACTS` 에 안 들어가고 `Main._apply_stage_bg`
가 미궁 모드에서 직접 이 이름을 집는다. 틈 바탕색도 BACKDROP 배열이 아니라
같은 자리의 미궁 분기(33,33,29 실측)다. 후보 셋 중 사장님이 A(철창 미궁)를 골랐다
(심연 회랑 `57fda9d1`, 혈정 동굴 `db65a75b` 은 폐기).
```
wide horizontal side-scrolling game background, dark underground blood labyrinth
dungeon interior, flat walkable dark flagstone floor running along the whole width
with the ground line about three quarters down the image, below the ground line a deep
vertical bank of stacked dark stone blocks filling the entire bottom quarter, one tall
dark iron-banded pillar at the far left edge and one identical tall dark iron-banded
pillar at the far right edge, rusty iron cage gates and hanging chains and iron
braziers with crimson flame standing on the ground, distant dark maze corridors fading
into black shadow behind, dark crimson and charcoal black palette, flat muted colors,
plain retro game pixel art
```

---

## 받은 다음 — **반드시 이음매 처리**

좌우 끝에 같은 기둥을 그리게 해도 **하늘·산·지면 높이가 정확히는 안 맞아
이음매가 선으로 보인다.** 프롬프트로는 못 없앤다. 코드로 잇는다.

```bash
python tools/fit_ground.py       # 지면 145행 기준으로 320 -> 208 줄 잘라내기
python tools/make_seamless.py    # 가로 이음매: 768 -> 744
```

**순서가 중요하다.** `make_seamless.py` 는 `*.orig.png` 스냅샷에서 다시 만들므로,
이음매 처리를 먼저 하면 그 스냅샷이 320줄로 굳어 세로 자르기가 되돌려진다.

오른쪽 끝 24px 을 왼쪽 끝에 램프로 겹쳐 섞고 그만큼 잘라낸다(768 → **744**).
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

## 폐기된 후보 (2026-08-05)

| job id | 왜 버렸나 |
|---|---|
| `96ea6d7d-6a96-4899-97d3-6d8c54e2f105` | 3막 160줄판. 윗부분에 가짜 간판(깨진 글자) |
| `6aed22d0-5033-4012-8066-918a5f12a342` | 3막 160줄판. 위아래가 다 밝아 위젯이 묻힌다 |
| `1e6150b1-27b5-407f-a821-e1888437da5b` | 3막 208줄판. 산 위에 가짜 글자 |
| `a71591c8-4e99-413f-8755-1d08d1153dba` | 3막 208줄판. 지면이 160행이라 위젯 띠가 96px 로 얕다 |

3막에서만 가짜 글자가 두 번 나왔다. `distant ... ridges` 처럼 **먼 산**을 시키면
그 위에 표지판을 그려 넣는 것으로 보인다 — `distant smooth pale blue snow slopes
low on the horizon, plain empty pale sky above with nothing in it` 으로 바꾸니 멈췄다.

### 208줄 세대 (지면이 막마다 달라 폐기)

`e9785e76`(무덤) · `26470583`(언덕) · `01cf62a2`(빙하) · `585d93a5`(성소) ·
`6c3768e9`(본성). 그림 자체는 멀쩡했지만 지면 행이 101~152 로 흩어졌다.

### 단이 두 개면 지면을 못 고른다

빼앗긴 본성 1차(`f85a85f7`)는 바닥이 위아래 두 단이었다. 검출기가 아래 단을 골라
캐릭터가 그 단에 서고, 왕좌·잔해가 있는 진짜 바닥이 머리 위로 갔다(사장님:
"빼앗긴 본성은 살짝 이상한데"). 실내 배경에는 **단이 하나뿐임을 명시**한다:
`one single unbroken flat walkable ... floor line ..., no steps and no terraces
and no second ledge`.

### fit_ground 가 지면을 잘못 잡았던 경우

화형의 언덕은 **맨 아래 불꽃 줄**이 지면보다 대비가 커서 313행으로 잡혔다.
찾는 범위를 잘라 낼 창(`[145, 높이-63]`)으로 묶어 해결했다 — 어차피 그 밖에
지면이 있으면 자를 수가 없다.
