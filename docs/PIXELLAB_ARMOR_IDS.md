# PixelLab 방어구 생성 기록

방어구 20종은 **2026-08-04에 재생성**했다. 1차(`pixen`)는 결이 안 맞아 폐기.
새 아이템을 뽑을 때는 **2차 방식**을 따른다.

---

## 왜 1차가 실패했나 (다시 하지 말 것)

| | 1차 (폐기) | 2차 (채택) |
|---|---|---|
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
