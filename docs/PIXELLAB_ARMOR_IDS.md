# PixelLab 방어구 생성 기록

방어구 20종은 **2026-08-04에 재생성**했다. 1차(`pixen`)는 결이 안 맞아 폐기.
새 아이템을 뽑을 때는 **2차 방식**을 따른다.

---

## 왜 1차가 실패했나 (다시 하지 말 것)

| | 1차 (폐기) | 2차 (채택) |
|---|---|---|
> **몹 object id 표는 이 파일 맨 아래에 있다.** 보스 5종은 `HANDOFF.md` 4장.
> 둘 다 다시 찾기 제일 어려운 정보다 — PixelLab 쪽 이름이 게임 이름과 전혀 다르다.

| 도구 | `create_image_pixen` | **`create_1_direction_object`** |
| 스타일 지정 | 프롬프트로 **설명만** | **`style_images` 로 레퍼런스 직접 물림** |
| 디테일 | `highly detailed` | 레퍼런스가 결정 |
| 외곽선 | `selective outline` | 레퍼런스가 결정 |
| 호출 | 20종 = 20회 | **1회에 20종** |

**스타일은 글로 설명해서 못 맞춘다.** "동일한 팔레트, 동일한 외곽선 굵기"를 아무리
길게 써도 `pixen` 은 자기 기본값으로 그린다. 기존 자산을 `style_images` 로 넣는 것이
유일하게 통하는 방법이다.

한 번에 뽑는 이유: **같은 배치 안에서는 서로 결이 안 갈린다.** 20회 따로 부르면
같은 프롬프트라도 20가지 톤이 나온다.

---

## 2차 생성 (채택)

- object_id: **`88f357ff-ffc7-4a42-9405-94c1823a6dbb`**
- 도구: `create_1_direction_object`, `view: sidescroller`
- 비용: **20 generations** (64칸 후보 시트 → 사장님이 20개 선택)
- 스타일 레퍼런스 (기존 자산에서 고른 것):
  - `23d983ad-bb65-4a89-a2e8-64feb36277d5` — 어두운 로브/망토
  - `3a76e9fb-036b-430a-b02a-bfd3ef1ff2ea` — 어두운 판금 상반신

```
description: dark gothic vampire fantasy armor inventory icon,
             single garment only, no character or body
style_images: [위 두 장의 base64]
item_descriptions: [20종 각각의 영문 한 줄]
```

`style_images` 를 주면 **size 를 따로 못 준다** — 가장 큰 레퍼런스가 크기를 정한다
(32×32 레퍼런스 → 32×32 결과). 크기가 ≤42 면 후보가 64칸으로 나온다.

### 20종 목록

| 등급 | 게임 표시명 | 파일명 |
|---|---|---|
| 커먼 | 낡은 가죽 조끼 | `ga_leather_vest_worn.png` |
| 커먼 | 녹슨 사슬 갑옷 | `ga_chainmail_rusted.png` |
| 커먼 | 경비병 흉갑 | `ga_guard_cuirass.png` |
| 커먼 | 수습생 로브 | `ga_apprentice_robe.png` |
| 언커먼 | 사냥꾼 코트 | `ga_hunter_coat.png` |
| 언커먼 | 묘지 경비갑 | `ga_graveguard_mail.png` |
| 언커먼 | 흡혈귀 가죽옷 | `ga_vampire_leathers.png` |
| 언커먼 | 뼈 견갑옷 | `ga_bone_pauldrons.png` |
| 레어 | 서리 기사 갑옷 | `ga_frost_plate.png` |
| 레어 | 핏빛 흉갑 | `ga_blood_cuirass.png` |
| 에픽 | 망령 갑옷 | `ga_spectral_armor.png` |
| 에픽 | 타락 성기사 갑옷 | `ga_fallen_paladin.png` |
| 레전더리 | 용비늘 갑주 | `ga_dragon_scale.png` |
| 레전더리 | 심연의 예복 | `ga_abyss_raiment.png` |
| 레전더리 | 지옥불 갑주 | `ga_inferno_plate.png` |
| 레전더리 | 월식 망토 | `ga_eclipse_mantle.png` |
| 신화 | 시조 흡혈귀 갑주 | `ga_primordial_vampire.png` |
| 신화 | 공허 군주 판금 | `ga_void_lord_plate.png` |
| 신화 | 종말의 용갑 | `ga_apocalypse_dragon.png` |
| 신화 | 불멸자의 장례복 | `ga_immortal_shroud.png` |

### 이름 매칭 주의

내려받은 폴더 이름은 **`item_descriptions` 에서 따온다.** 그런데 일부는 그게 안 남고
전부 `dark_gothic_vampire_fantasy_ar*` 로 떨어진다(이번엔 20종 중 **7종**).
그 7종은 그림을 보고 배정해야 한다.

> **다음부터**: `item_descriptions` 의 첫 단어를 서로 다르게 쓰면 폴더 이름이
> 안 겹친다. 이번엔 `dark gothic...` 이 공통 접두어라 뭉쳤다.

## PixelLab ID가 없는 기존 재사용 4종

| 등급 | 게임 표시명 | 파일명 |
|---|---|---|
| 레어 | 흑철 판금 | `gear_plate.png` |
| 레어 | 자수정 비늘갑 | `gear_scale.png` |
| 에픽 | 진홍 망토 | `gear_cloak.png` |
| 에픽 | 심연 로브 | `gear_robe.png` |

---

실제 매핑은 `GearDefs.gd` 의 `CATALOG["armor"]`. 파일명만 맞으면 코드 변경은 없다.

---

# 몹 object id (2026-08-06)

**게임 키 ↔ PixelLab object id.** 이름이 전혀 달라서 눈으로 찾으면 반드시 틀린다 —
08-05 에 `list_characters` 의 "Wraith Knight Monster"(파란 해골)를 게임의 망령 기사로
잘못 고른 적이 있다. 새 모션을 뽑을 때는 **이 표에서만** 가져온다.

| 게임 키 | 이름 | object id | PixelLab 쪽 이름 |
|---|---|---|---|
| `slime` | 슬라임 | `a17c6ea3-6a86-4bfd-8da0-985202228404` | green gelatinous slime blob |
| `goblin` | 고블린 | `a4ec3cea-cf74-4788-8433-47a6f69de03c` | small green goblin |
| `bat` | 박쥐 | `d63cdc18-6c56-4cea-a37b-d65591e6bca0` | small flying vampire bat |
| `zombie` | 좀비 | `35ade55a-2ea0-420f-9931-bdaf7b7948c6` | shambling rotting zombie |
| `skeleton` | 해골 | `0b4141fa-149b-4dec-b944-24062e2c4142` | walking skeleton warrior |
| `ghoul` | 구울 | `960720af-b349-493b-9622-dd14c3914c7a` | hunched ghoul flesh-eater |
| `mushroom` | 독버섯 | `a0b549df-6bfa-4b71-a0cb-203b7e974137` | walking purple mushroom monster |
| `fire_imp` | 파이어 임프 | `a6ddcefb-7ad6-47ed-8627-9f5b3fc96269` | small red fire imp demon |
| `orc` | 오크 | `01d54ed3-6e88-4987-b8de-62713e4ea4d7` | brutish green orc warrior |
| `lava_toad` | 용암 두꺼비 | `728fcd42-e023-444d-82e0-333aae915c42` | bloated lava toad monster |
| `hellhound` | 헬하운드 | `27048113-1212-4f02-9982-414a7a10a1cb` | fiery black hellhound beast |
| `gargoyle` | 가고일 | `74adb306-755b-43f3-b357-4c1fbd674fb2` | stone gargoyle |
| `demon` | 데몬 | `4df9d477-6bbc-4dff-9de5-0bca2b939def` | large red demon (48px) |
| `frost_spider` | 서리 거미 | `44857c5e-7692-42a5-b09b-b0bcc5c4133e` | frost spider monster |
| `ice_wisp` | 아이스 위습 | `40be0d9f-7f11-4087-9930-ae1f324f2419` | floating pale blue ice wisp |
| `frost_golem` | 프로스트 골렘 | `928bb529-325e-4178-994b-e187b46f8e0e` | hulking ice golem (48px) |
| `eye_mass` | 눈알 덩어리 | `9a9b3e8b-994a-4770-ad30-fd6c975d0976` | floating mass of eyeballs |
| `void_wraith` | 보이드 레이스 | `fd148336-f225-4fb9-8d66-c5d2ca1f1116` | dark purple hooded void wraith |
| `wraith_knight` | 망령 기사 | `dc87b329-6670-467c-b820-14876f09d4e0` | tall spectral wraith knight (48px) |
| `cultist` | 뿔 광신도 | `51aece64-9c76-4f64-954e-69be1d9c6340` | horned demon cultist monster |
| `dark_knight` | 다크 나이트 | `ac30feaa-c641-4f87-8b6a-338fc53dedcd` | imposing dark knight (48px) |

> **`spider`(거미)는 object 가 없다.** `FoeTiers` 에는 있는데 PixelLab 쪽에 대응하는
> 것이 `frost_spider` 뿐이다. 그래서 로스터 21종 중 내려찍기가 **20종**이고 거미만
> 빠져 있다. 거미에 모션을 붙이려면 object 부터 새로 만들어야 한다.
>
> **`gargoyle` 은 이 표에 있지만 내려찍기가 필요 없다.** 어느 막 로스터에도 없어
> 보스로만 나오고, 그때는 `boss_2_special` 을 쓴다. 08-10 에 모르고 한 번 뽑아
> 생성 1회를 버렸다 — **후보는 `ACTS[].roster` 에서만** 뽑는다.

**주의**: 이 표의 object 는 **보스용과 별개다.** 보스 5종(`boss_1`~`boss_5`)은 같은
몹의 큰 버전이 아니라 아예 다른 object 다(`HANDOFF.md` 4장). `wraith_knight` ·
`dark_knight` · `frost_golem` · `eye_mass` 는 잡몹으로도 보스로도 나오는데,
**쓰는 그림이 서로 다르다.**
