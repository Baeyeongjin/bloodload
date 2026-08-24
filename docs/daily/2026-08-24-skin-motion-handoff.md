# 2026-08-24 — 스킨 모션 정렬 마무리 · 내일 이어갈 작업

## 오늘 확정된 것

- **가로 순간이동 원인**: install_motion 의 "오른쪽으로 뻗으면 좌우 반전"이
  캔버스 중심 기준 미러라, 왼쪽으로 15~17px 치우친 생성물이 반전 후
  반대쪽으로 튀었다. → 도구에 **가로 중심 정렬 단계 추가**(반전 뒤에 실행,
  f0 잉크 중심 → 캔버스 중심, 전 프레임 같은 dx, 잘리면 양쪽 확장).
- 뒤돌아보는 프레임 12모션 중 11개 재생성·재설치 완료(중심 정렬 적용).
  dragon attack·sweep / grim attack·cast / pink attack·heavy·sweep /
  abyss attack3 / hawaii attack·heavy·sweep.
- dragon·grim death 가 지면 아래로 8~12px 가라앉던 것 클램프.
- 8스킨 × 전 모션 전수 감사 통과(발 기준선 h/2+16, 가로 중심 w/2,
  프레임 간 밑단 점프). 헤드리스 임포트까지 완료.

## 내일 1순위 — hawaii attack2 (파라솔 휘두르기)

유일하게 남은 모션. 1차 잡 실패 → 재발주해 둔 잡:
`47a2006b-52a6-4344-9b73-db3ef7df872a`

```
python tools/install_motion.py --no-span --no-flip hawaii attack2=47a2006b-52a6-4344-9b73-db3ef7df872a
```

- HTTP 423 = 아직 처리 중(대기 후 재시도), 410 = 잡 만료 → 아래 인자로 재발주.
- 재발주 인자(animate_image): frame_count 8, no_background true,
  first_frame_url `https://api.pixellab.ai/mcp/images/640aedbf-cc74-4f5e-b228-de5da65c8e2c/download`,
  action: "swinging the beach parasol horizontally from right to left with the
  arms only, legs completely frozen in place, both feet glued to the same spot
  on the ground in every frame, the character NEVER turns around and his face
  points LEFT in EVERY single frame, plain motion, absolutely no visual
  effects, STRICT SIDE VIEW, character stays centered"
- 두 번 더 실패하면 종결: attack2 폴더가 없으면 콤보가 조용히 축소되므로
  현재 설치본(뒤돌아봄 있는 구판) 유지 여부만 사장님께 확인.
- 설치 후 `--editor --quit` 임포트 1회 + 커밋.

## 그다음 (사장님 픽 대기)

- 펫 원정 / 고스트 랭킹 / 보스 러시 / 이름 변경 기능
- 스킨 폴백 모션 보충: dragon attack2, grim hurt, hawaii attack3·hurt,
  pink attack3·dash
- 외부 대기: 광고 SDK, 결제 SDK(DEV_FREE 끄기)

## 인게임 확인 루틴 (새 모션 깔면 항상)

8스킨 갈아입고 공격·이동·사망 — 순간이동·반대 공격·뒤돌아봄 없는지.
사장님께 보내는 미리보기는 **오른쪽 보기로 반전**해서.
