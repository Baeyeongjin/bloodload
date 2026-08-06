---
name: godot-verify
description: bloodlord를 검증하거나 화면을 캡처할 때 쓴다. 파싱 검사, 테스트 5종 실행, 격리 렌더 절차. "테스트 돌려줘 / 확인해줘 / 화면 보여줘 / 스크린샷 / 잘 되나 봐줘" 같은 요청, 그리고 .gd 를 고친 뒤에 사용.
---

# 검증과 렌더

Godot 콘솔 바이너리:
```
C:\Users\kpo02\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe
```

**Bash는 한글 경로에서 실패한다.** Godot 실행은 PowerShell로. 단 PowerShell에는
heredoc이 없다(`<<'EOF'`는 파서 에러) — 커밋 메시지 같은 여러 줄 문자열은 Write 툴로
파일에 쓰고 `git commit -F`.

## 1. 파싱

```powershell
& $g --headless --path $p --check-only --script Main.gd
& $g --headless --path $p --import        # 자산을 새로 넣었을 때
```

## 2. 테스트 5종

```powershell
Get-ChildItem "$p\tests\*.gd" | ForEach-Object {
  $o = & $g --headless --path $p --script "tests/$($_.Name)" 2>&1 | Out-String
  if ($o -match "Assertion") { "FAIL $($_.Name)" } else { "OK $($_.Name)" }
}
```

**exit 0 을 믿지 말 것.** `assert` 가 실패해도 실행이 이어져서 아래 `print("... OK")`
와 `quit()` 가 그대로 돌고 종료 코드가 0 으로 나온다. 반드시 출력에서 `Assertion` 을
걸러 봐야 한다. 각 테스트 앞에 20초 watchdog 이 있어 멈춰도 끝난다.

| 파일 | 무엇을 지키는가 |
|---|---|
| `CombatRulesTest` | 배경 규격 3종, 보스 특수 패턴 주기·예고, **서는 자리·휘두름·피해 3판정 일치**, 칸 좌표, 모션 사거리 |
| `BalanceTest` | 구간 통과 시간(보스는 한 마리당 비교), `clear < TIME_NORMAL` |
| `GearTest` | 실제 폰트 칸 폭, `Ui.icon` 크기 회귀 |
| `GoalTest` | 가이드가 한 바퀴에 트랙 전부 한 번씩 |
| `SkillTest` | 스킬 표, 이펙트 프레임 무결성 |

`CombatRulesTest`의 "3판정 일치"는 이번에 세 번 난 버그를 막는다 — 영웅이 설 자리 /
휘두를 조건 / 피해가 닿을 조건이 서로 다른 값을 보면 만족하는 거리가 없어진다.
셋 중 하나를 고칠 때는 **반드시 나머지 둘을 같이 본다.**

## 3. 렌더 — 반드시 격리한다

```powershell
$iso = "<scratchpad>\iso"
$env:APPDATA = $iso
Remove-Item -Recurse -Force -Path "$iso\Godot" -ErrorAction SilentlyContinue
& $g --path $p --rendering-method gl_compatibility --resolution 576x896 -- --autoshot --wait=N
Copy-Item "$iso\Godot\app_userdata\Bloodlord\autoshot.png" out.png -Force
```

**`$env:APPDATA` 를 임시 폴더로 바꾸지 않으면 사장님 저장본으로 돌아간다.**
창이 뜬 사이 버튼이 눌려 **실제로 장비가 분해된 사고**가 있었다. 예외 없다.

`Remove-Item` 에 `-Path` 를 명시할 것. 변수가 비면 `/` 를 지우려 해서 차단된다.

`--rendering-method gl_compatibility` 도 필수다 — Forward+ 는 Intel Vulkan TDR 로 멈춘다.

## 4. 개발 플래그

| 플래그 | 하는 일 |
|---|---|
| `--wait=N` | N초 뒤 캡처 |
| `--gaps` | 영웅과 몹의 거리가 어긋나는 순간을 찍는다 (아래) |
| `--stage=3-1` | 그 구간에서 시작 |
| `--tab=growth\|gear\|summon\|codex` | 그 창을 연 채로 |
| `--reward` / `--chest` | 보상 창 / 방치 상자 |
| `--skills[=N]` / `--skillfx[=형태]` / `--skill-detail` | 스킬 화면 |
| `--pull=gear:10` / `--gacha=` | 소환 |
| `--rates` | 소환 레벨별 확률표 |
| `--equip` / `--gear-detail` / `--gear-mode=` / `--bulk=` | 장비 화면 |
| `--status` | 도감 능력치 창 |
| `--tell` | 보스·중간보스가 **매 스윙 특수 패턴**을 쓴다 (예고판 캡처용) |
| `--walk` / `--dialog=` | 기타 |

### 예고판(특수 패턴)을 찍으려면 `--tell` 을 쓴다

예고는 0.85초인데 주기가 세 스윙마다라, 그냥 찍으면 **거의 안 잡힌다** —
2026-08-06 에 0.7초 간격으로 6장을 흩뿌려 찍고 한 장도 못 잡았다(잡힌 건 영웅 스킬
이펙트였다). `--tell` 이 매 스윙을 특수로 만들어 예고를 화면에 고정한다.

```powershell
& $g --path $p --rendering-method gl_compatibility --resolution 576x896 `
    -- "--stage=1-5" --tell --autoshot --wait=7.6
```

`1-5` 는 중간보스 구간이다(`MIDBOSS_STEP`). 보스는 `--stage=1-10`.

### `--gaps` 읽는 법

지표가 **양쪽으로 열려 있다.** 자가 한쪽만 보면 반대쪽 고장은 아무리 돌려도 안 잡힌다 —
실제로 겹침을 없앤 뒤 "멀리서 싸운다"가 남았는데 지표에 안 보였다.

```
겹침   -6.0  영웅  288.0 정지    해골  344.0  몹도착 true
뜸     12.0  영웅  288.0 대시중  고블린 232.0  몹도착 true
```

- **잉크로 잰다** (`f.body_half()`). 상자로 재면 한쪽당 6px 과장돼서, 그 수치로 칸을
  옮기면 과보정된다. 예전 판이 그래서 12px 과장했다 — 지금은 고쳐져 있다
- **`정지`/`대시중`을 같이 본다.** 큰 겹침은 대부분 지나가는 중이다. 구분 없이 보면
  못 고칠 값을 고치려 든다
- **겹침은 아무 몹이나, 뜸은 지금 상대하는 몹만** 찍는다. 다른 칸 몹과는 원래 멀어서
  같이 찍으면 진짜 문제가 잡음에 묻힌다

## 5. 런타임 에러·계측은 이미 읽을 수 있다

**유료 MCP 를 살 필요가 없다.** 실행 중인 게임의 출력이 콘솔 바이너리의 stdout/stderr
로 그대로 온다. 2026-08-06 에 양방향 다 실측했다:

- **게임의 `print()`** → 온다. `--gaps` 프로브가 `_process` 에서 찍는 줄이 그대로 잡혔다
- **`SCRIPT ERROR`** → 온다. `_lane_x` 시그니처를 깼을 때
  `SCRIPT ERROR: Invalid call to function '_lane_x' in base 'Node2D (Main.gd)'` 가 올라왔다

그래서 "고친다 → 돌린다 → 에러 읽는다 → 화면으로 확인한다" 루프가 이미 완결이다:

```powershell
$out = & $g --path $p --rendering-method gl_compatibility --resolution 576x896 `
        -- --autoshot --wait=N 2>&1 | Out-String
$out -split "`n" | Where-Object { $_ -match "SCRIPT ERROR|ERROR|WARNING" }
```

**새 현상을 조사할 때는 프로브를 심는 쪽이 맞다.** `--gaps` 가 그 사례다 — 눈으로는
"겹쳐 보이네"까지밖에 못 갔지만, 매 0.25초 거리·도착·모션을 찍게 하자 원인이 셋으로
갈렸다. 조사가 끝나면 프로브는 남겨 둔다(플래그로 꺼져 있으니 비용이 없다).

## 6. 하지 말 것

- **Godot 에디터를 열어 둔 채 외부에서 `.gd` 수정** — 에디터가 되돌린다
- PowerShell 로 한글 문서 치환 (인코딩이 깨진다) — 문서는 Edit 툴로
- `.ps1` 안에 한글 경로·식별자
- 게임을 직접 실행해서 플레이 검증 — 사장님이 직접 돌린다. headless 검증과 `--autoshot` 만 쓴다
