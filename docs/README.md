# Bloodlord 문서

> 마지막 업데이트: 2026-08-04

## 기준 문서 (계속 갱신한다)

- [HANDOFF.md](HANDOFF.md) — **여기부터 읽는다.** 현재 상태와 바로 다음 작업
- [PLAN.md](PLAN.md) — v1 범위
- [DESIGN.md](DESIGN.md) — 장기 설계와 마일스톤
- [STATS.md](STATS.md) — 성장 공식과 해금
- [UI_RULES.md](UI_RULES.md) — UI 배치 규칙

## 자산 생성 규격 (한 번 정하고 그대로 따른다)

- [BG_RECIPE.md](BG_RECIPE.md) — 배경 768×160, 이음매 숨기는 법, job id
- [PIXELLAB_ARMOR_IDS.md](PIXELLAB_ARMOR_IDS.md) — `style_images` 배치 생성법, 방어구 24종 매핑
- [SKILL_VFX_RECIPE.md](SKILL_VFX_RECIPE.md) — 스킬 이펙트 20종. 아이콘·이름·프롬프트 대응표
- [CREDITS.md](CREDITS.md) — 배포 시 포함할 저작자 표시

## 날짜별 기록

완료한 작업은 [daily/](daily/) 아래 `YYYY-MM-DD-<주제>.md`에 기록한다.
새 작업을 시작할 때는 `HANDOFF.md`를 먼저 읽고, 끝나면 날짜와 상태를 갱신한다.

**살아 있는 문서는 늘리지 않는다.** 승인용·계획용 문서는 결정이 확정되면 기준 문서에
접고 지운다 — 남겨 두면 코드가 바뀐 뒤에도 그대로 남아 다음 작업자를 잘못 이끈다.
실제로 `SKILL_PLAN.md`(원소 상성 24종 안)가 그렇게 되어 2026-08-04에 지웠다.
