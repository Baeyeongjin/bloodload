# 공격 이펙트 — 만드는 법

출처: AdamCYounis "Pixel Art Class - Attack Effects!"(64분, `Gi8Vncrd_uY`)를
자막 전문 + 화면 프레임으로 뜯었다. **우리 게임에 쓸 것만** 남겼다.

## 1. 히트박스가 먼저다. 그림은 그걸 덮는 것이다

> "You need to know where is this attack going to hit... we want to cover as
> much of this hit box as makes sense to do."

그림을 먼저 그리고 판정을 맞추는 게 아니라, **판정을 그려 놓고 그 위에
그림을 얹는다.** 이 저장소가 두 번 고친 "그림과 결과가 갈린다"가 정확히
이 순서를 뒤집었을 때 난다.

**지금 어긋나 있는 곳:** `Main._slam_wave(at_x, r, key)` 의 `r` 이 **죽은
인자다** — 서명에만 있고 본문에서 안 쓴다. 보스 특수는 사거리 배수가
1.7 ~ 3.2 배로 갈리는데(`FoeTiers.SPECIAL_KIND` 셋째 축) 그림 크기는 전부
같다. 촉수(2.8)와 음파(3.2)는 그림보다 훨씬 멀리까지 때린다.

**고칠 때 주의**: 3.2배로 그냥 키우면 화면을 가린다(우리 원칙 위반).
사거리는 **가로로 뻗어서** 읽혀야지 덩치로 읽히면 안 된다 — 레시피의
X 오프셋(`e[1]`)을 사거리에 걸어 몇 개 늘어놓는 쪽이 맞다.

## 2. 프레임은 뒤쪽에 몰아 준다

> "A few frames of lead-up, a very great amount of motion over a very small
> amount of time, and then lots of frames where things are winding down."

7프레임이면 **예비 1~2 · 실제 타격 1~2 · 잔여 3~4** 다. 타격 자체는 거의
프레임을 안 쓴다. 우리 `예고 초`(0.45~1.30)가 예비에 해당하고, 잔여가
지금 제일 얇다.

## 3. 이중 타원 — 초승달을 그리는 지름길

1. 흰 타원을 채워 그린다
2. 다른 색으로 **살짝 밀어** 두 번째 타원을 그린다
3. 두 번째 것을 지운다

남는 초승달은 두께가 1 → 5 → 1 픽셀로 **매끄럽게** 변한다. 손으로 그리면
잘 안 나오는 부분이 공짜로 나온다. (33:30 화면에서 그대로 보인다.)

단, 강사 본인이 "초보용 지름길"이라고 한다 — 익으면 **히트박스 모양에
맞춰** 직접 그린다(타원은 위아래가 대칭이라 실제 궤적과 안 맞는다).

## 4. 부피는 두 톤으로 낸다

53:00 화면에서 스미어가 **청록 몸 + 흰 심**으로 바뀌는 순간 부피가 생긴다.
한 색이면 종잇장이고 두 톤이면 두께가 읽힌다.

**우리는 이미 절반 갖고 있다** — `FoeTiers.SLAM_THEME` 이 보스마다
`[스타일, 심 색, 테두리 색]` 을 들고 있다. 그런데 `_slam_fx_one` 은
`e[5]` 하나로 통째로 tint 만 한다. 두 톤을 실제로 쓰는 건
`_crystal_wave`(수호자) 하나뿐이다.

## 5. **퍼지되 날아가지 않는다** — 제일 쓸모 있는 규칙

> "Seeing the blast extend out, but not travel. The head is traveling out,
> but the entire thing is thinning. It feels more like light and less like
> a particle... lightning is the same — it's better to dissipate than to travel."

타격 에너지는 밖으로 **이동**하면 입자로 보이고, 제자리에서 **얇아지며
흩어지면** 빛으로 보인다. 번개·섬광은 거의 안 움직이고 번쩍이기만 해야 한다.

우리 `_crystal_wave` 는 앞면을 `r * min(1, p*1.15)` 로 **전진**시킨다.
지면 충격파는 전진이 맞지만, 칼빛·번개 계열(arc·soul·sonic)은 이 규칙대로
제자리에서 얇아지는 쪽이 맞다.

## 6. 스미어는 무기의 성격을 말한다

> "Is it a flame attack? Is it a whip? Is it really sharp and quick? Or is it
> more heavy? Does it cut through the air efficiently or is it cumbersome?"

같은 초승달이라도 얇고 긴 것 / 두껍고 뭉툭한 것이 무기를 가른다. 우리는
`SLAM_THEME` 스타일 이름(lash·spray·cross·arc·sonic·debris…)에 이미 성격을
적어 놨으므로, 그림이 그 이름대로 갈리는지 보면 된다.

## 안 가져온 것

- 실루엣 겹침 처리 · 구도 균형 — 우리는 옆보기 고정에 이펙트가 화면을
  가리면 안 되는 제약이 있어서 강의의 구도 논의가 그대로 안 온다.
- 검 궤적 전용 기법(air trails) — 영웅 평타는 이미 `fx_cleave` 로 서 있다.
