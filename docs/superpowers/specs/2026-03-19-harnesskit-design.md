# HarnessKit — Adaptive Harness for Vibe Coders

> **Date**: 2026-03-19
> **Status**: Design approved, pending implementation
> **Approach**: Layered Architecture (Approach B)

---

## 1. Overview

HarnessKit은 vibe coder를 위한 Claude Code Plugin이다. 기존 Harness Engineering 구현체들의 장점을 수용하고 단점을 개선하여, **감지 → 설정 → 관찰 → 개선** 사이클을 자동화한다.

### 1.1 핵심 차별점

- **Repo 속성 자동 감지** → 프레임워크에 맞는 harness 자동 구성
- **경험 수준별 적응** → beginner/intermediate/advanced 프리셋 + 사용 패턴 기반 자동 조정 제안
- **자기 개선 루프** → 세션 로그 축적 → 반복 패턴 감지(토큰 0) → `/harnesskit:insights`로 심층 분석 → 설정 개선 diff 제안
- **내장 `/insights` 연동** → Claude Code 내장 insights가 진단, HarnessKit insights가 처방

### 1.2 설계 근거

- **Anthropic 공식 아티클**: "Effective harnesses for long-running agents" (2025-11-26)
- **기존 구현체 분석**: autonomous-coding, panayiotism/claude-harness, Chachamaru127/claude-code-harness, GantisStorm/autonomous-coding-harness
- **블로그 가이드라인**: ice-ice-bear.github.io Claude Code 실전 가이드 — Second Brain 구조, Lazy Loading, "Context is milk", WAT Framework

### 1.3 타겟 사용자

- **(A) 비감독형 vibe coder**: 프롬프트만 던지고 결과만 확인 → 강한 가드레일 + 상세 브리핑 필요
- **(B) 협업형 vibe coder**: Claude와 대화하며 점진적 개발 → 적절한 가이드 + 자율성 필요
- 경험 수준에 따라 harness가 적응 (프리셋 시작 → insights가 조정 제안)

### 1.4 배포 형태

Claude Code Plugin 공식 형태 — `claude plugin install harnesskit`으로 설치

### 1.5 외부 위임 전략

코드 리뷰는 초기에 marketplace의 검증된 플러그인에 위임 (`/simplify`, `/review`, `/security-review` 등). `/harnesskit:insights`가 사용 패턴을 관찰하며 점진적으로 내재화.

### 1.6 후순위 기능 (v2+)

- PRD → GitHub 이슈 분해
- git worktree 세션 격리
- 코드 리뷰 내재화
- A/B 테스트 (`/skill-builder` 연동)

---

## 2. Plugin 구조

### 2.1 전체 파일 트리

```
harnesskit/
│
├── plugin.json                         # 플러그인 매니페스트
│
├── agents/
│   └── orchestrator.md                 # setup, insights 흐름 조율
│
├── skills/
│   ├── setup.md                        # repo 감지 + 프리셋 선택 + init 호출
│   ├── init.md                         # 템플릿 기반 파일 생성
│   ├── insights.md                     # 세션 로그 분석 + diff 제안
│   ├── apply.md                        # 승인된 변경 적용
│   └── status.md                       # 현재 harness 상태 조회
│
├── hooks/
│   ├── session-start.sh                # SessionStart: 브리핑 주입
│   ├── guardrails.sh                   # PreToolUse: 위험 행동 차단
│   └── session-end.sh                  # Stop: 로그 저장 + 넛지 감지
│
├── templates/
│   ├── claude-md/
│   │   ├── base.md                     # 공통 세션 프로토콜
│   │   ├── nextjs.md                   # Next.js 특화
│   │   ├── python-django.md            # Django 특화
│   │   ├── python-fastapi.md           # FastAPI 특화
│   │   ├── react-vite.md               # React + Vite 특화
│   │   └── generic.md                  # 범용
│   ├── claudeignore/
│   │   ├── nextjs.txt
│   │   ├── python.txt
│   │   └── generic.txt
│   ├── feature-list/
│   │   └── starter.json                # 빈 골격
│   └── presets/
│       ├── beginner.json               # 가드레일 강, 브리핑 상세
│       ├── intermediate.json           # 균형
│       └── advanced.json               # 최소 개입
│
├── scripts/
│   ├── detect-repo.sh                  # repo 속성 감지
│   ├── scan-session-logs.sh            # 반복 패턴 감지
│   └── compile-briefing.sh             # 브리핑 조합
│
└── README.md                           # 설치 및 사용 가이드
```

### 2.2 plugin.json

```json
{
  "name": "harnesskit",
  "version": "0.1.0",
  "description": "Adaptive harness for vibe coders — detect, configure, observe, improve",
  "skills": [
    "skills/setup.md",
    "skills/init.md",
    "skills/insights.md",
    "skills/apply.md",
    "skills/status.md"
  ],
  "agents": [
    "agents/orchestrator.md"
  ]
}
```

### 2.2.1 Hook 등록 방식

Claude Code Plugin 매니페스트(`plugin.json`)는 skills와 agents만 등록 가능하다. Hooks는 프로젝트의 `.claude/settings.json`에 등록해야 한다.

따라서 `/harnesskit:setup` 실행 시 init skill이 프로젝트의 `.claude/settings.json`에 hook 항목을 자동으로 기록한다:

```json
// .claude/settings.json (setup이 생성/병합)
{
  "hooks": {
    "SessionStart": [
      {
        "type": "command",
        "command": "bash $(claude plugin path harnesskit)/hooks/session-start.sh"
      }
    ],
    "PreToolUse": [
      {
        "type": "command",
        "command": "bash $(claude plugin path harnesskit)/hooks/guardrails.sh"
      }
    ],
    "Stop": [
      {
        "type": "command",
        "command": "bash $(claude plugin path harnesskit)/hooks/session-end.sh"
      }
    ]
  }
}
```

**기존 hooks 보존**: settings.json에 이미 hooks가 있으면 배열에 append한다 (기존 hook 유지).

**제거**: 플러그인 제거 시 또는 `/harnesskit:reset --full` 시 settings.json에서 harnesskit 관련 hook 항목만 제거한다.

### 2.3 사용자 슬래시 명령어

| 명령어 | 역할 | 매핑 |
|--------|------|------|
| `/harnesskit:setup` | 최초 1회 — repo 감지 + 프리셋 선택 + 파일 생성 | setup.md → orchestrator → init.md |
| `/harnesskit:insights` | 세션 로그 분석 → 설정 개선 diff 제안 | orchestrator → insights.md |
| `/harnesskit:apply` | insights 제안을 승인 후 적용 | apply.md |
| `/harnesskit:status` | 현재 harness 상태 조회 | status.md |
| `/harnesskit:reset` | harness 초기화 (프리셋 재선택) | setup.md (reset mode) — 아래 2.5 참조 |

### 2.5 `/harnesskit:reset` 동작 정의

reset은 setup.md가 "reset mode"로 실행되는 것이다:

```
/harnesskit:reset 실행:
① 현재 프리셋 확인 → 사용자에게 표시
② 새 프리셋 선택 (또는 동일 프리셋으로 재생성)
③ 보존되는 파일:
   ├ .harnesskit/failures.json (실패 학습 — 절대 삭제하지 않음)
   ├ .harnesskit/session-logs/ (이력 보존)
   ├ .harnesskit/insights-history.json (제안 이력 보존)
   └ docs/feature_list.json (기능 목록 보존)
④ 재생성되는 파일:
   ├ .harnesskit/config.json (새 프리셋 반영)
   ├ .harnesskit/detected.json (재감지)
   ├ CLAUDE.md (새 프리셋 + 재감지 결과로 재생성)
   └ .claudeignore (재감지 결과로 재생성)
⑤ 기존 CLAUDE.md → .harnesskit/backup/에 백업
```

`/harnesskit:reset --full`: `.harnesskit/` 전체 삭제 + `.claude/settings.json`에서 harnesskit hooks 제거. 사용자 확인 필수.

### 2.6 자동 Hooks

| Hook | 트리거 | 동작 | 토큰 소비 |
|------|--------|------|----------|
| session-start.sh | SessionStart | progress 읽기 → feature 스캔 → 실패 이력 → 브리핑 주입 | 0 |
| guardrails.sh | PreToolUse | 위험 행동 패턴 매칭 → BLOCK/WARN/PASS | 0 |
| session-end.sh | Stop | 세션 로그 저장 → failures 기록 → 반복 패턴 감지 → 넛지(조건부) | 0 |

---

## 3. Repo 감지 + 프리셋 시스템

### 3.1 감지 항목

| 항목 | 감지 방법 |
|------|----------|
| 언어/런타임 | package.json, requirements.txt, go.mod, Cargo.toml 등 |
| 프레임워크 | next.config.*, vite.config.*, django/settings.py 등 |
| 패키지 매니저 | npm/yarn/pnpm lock 파일, poetry.lock 등 |
| 테스트 프레임워크 | jest.config.*, pytest.ini, vitest.config.* 등 |
| 린터/포맷터 | .eslintrc.*, .prettierrc, ruff.toml 등 |
| 모노레포 여부 | packages/*, apps/*, turborepo.json, nx.json |
| git 상태 | .git 존재 여부, 브랜치, 리모트 |
| 기존 harness 파일 | CLAUDE.md, .claude/, feature_list.json 유무 |

감지 결과는 `.harnesskit/detected.json`에 저장.

### 3.2 프리셋별 차이

| 설정 항목 | Beginner | Intermediate | Advanced |
|-----------|----------|--------------|----------|
| 가드레일 범위 | R01~R09 전체 + 추가 보호 | R01~R04 핵심만 | R01~R03 최소 |
| 세션 브리핑 | 상세 (progress + feature + 다음 할 일 안내) | 요약 (progress + feature 목록) | 최소 (progress 한 줄) |
| feature_list 단위 | 작은 단위 (steps 포함) | 중간 단위 | 큰 단위 (description만) |
| 세션 종료 시 | progress 업데이트 강제 알림 | 알림 | 자동 저장만 |
| insights 넛지 임계값 | 같은 에러 2회 | 같은 에러 3회 | 같은 에러 5회 |
| CLAUDE.md 상세도 | 세션 프로토콜 전문 포함 | 핵심 규칙만 | 최소 컨벤션만 |

프리셋은 `.harnesskit/config.json`에 저장. 프리셋 변경은 `/harnesskit:insights`가 제안하거나 `/harnesskit:reset`으로 수동 변경.

### 3.3 기존 파일 존재 시

이미 CLAUDE.md 등이 있는 프로젝트에서는 3가지 옵션 제시:
- **병합**: 기존 파일 유지, 빠진 파일만 생성
- **덮어쓰기**: 전부 새로 생성 (기존은 `.harnesskit/backup/`에 백업)
- **취소**

---

## 4. 파일 생성 시스템

### 4.1 사용자 프로젝트에 생성되는 파일

```
user-project/
├── CLAUDE.md                           # 프리셋 + 프레임워크별 생성
├── .claudeignore                       # 토큰 절약용
├── docs/
│   └── feature_list.json               # passes: false 패턴
├── progress/
│   └── claude-progress.txt             # 세션 간 핸드오프
└── .harnesskit/
    ├── config.json                     # 프리셋 + 설정
    ├── detected.json                   # repo 감지 스냅샷
    ├── failures.json                   # 실패 학습 (append-only)
    ├── insights-history.json           # 제안 승인/거절 이력
    ├── session-logs/                   # 세션별 로그 (.gitignore)
    └── backup/                         # 덮어쓰기 백업 (.gitignore)
```

### 4.2 CLAUDE.md 생성 로직

`base.md` + 프레임워크 템플릿 + 프리셋 필터를 조합:
- **base.md**: 세션 시작/종료 프로토콜, 절대 규칙 (항상 포함)
- **프레임워크 템플릿**: 해당 프레임워크 컨벤션, 테스트 명령어
- **프리셋 필터**: beginner=전문, intermediate=핵심, advanced=최소

Lazy Loading 원칙: 루트 CLAUDE.md는 60줄 이하, 상세 내용은 참조 파일로 분리.

### 4.3 feature_list.json

init은 빈 골격만 생성. 사용자가 채우거나 Claude와 대화하며 작성:

```json
{
  "version": "1.0.0",
  "features": [
    {
      "id": "feat-001",
      "category": "functional",
      "description": "",
      "steps": [],
      "passes": false
    }
  ]
}
```

절대 규칙: `passes` 필드 외 에이전트가 수정 불가.

### 4.4 .gitignore 권장

git에 포함 (팀 공유):
- `.harnesskit/config.json`, `detected.json`, `failures.json`, `insights-history.json`
- `docs/feature_list.json`, `progress/claude-progress.txt`, `CLAUDE.md`

git에서 제외 (개인 로컬):
- `.harnesskit/session-logs/`, `.harnesskit/backup/`

failures.json을 git에 포함하면 팀원 간 실패 학습 공유 가능.

---

## 5. Hooks 시스템

### 5.1 session-start.sh (SessionStart)

```
실행 흐름:
① .harnesskit/config.json → 프리셋 확인
② progress/claude-progress.txt 읽기
③ docs/feature_list.json → passes:false 카운트
④ .harnesskit/failures.json → 최근 실패 + 현재 feature 관련 실패 추출
⑤ git log --oneline -5
⑥ 프리셋에 따라 브리핑 조합 → stdout (Claude에 주입)
```

프리셋별 브리핑 상세도:
- **Beginner**: progress + feature 상태 + 실패 이력 + 다음 단계 안내
- **Intermediate**: progress + feature 목록 + 실패 경고
- **Advanced**: 한 줄 요약

### 5.2 guardrails.sh (PreToolUse)

패턴 매칭으로 위험 행동 차단. Claude 호출 없음.

#### Hook 입력 형식

PreToolUse hook은 stdin으로 JSON을 받는다:

```json
// Bash 도구 호출 시
{"tool_name": "Bash", "tool_input": {"command": "git push --force origin main"}}

// Write 도구 호출 시
{"tool_name": "Write", "tool_input": {"file_path": "/project/.env", "content": "..."}}

// Edit 도구 호출 시
{"tool_name": "Edit", "tool_input": {"file_path": "/project/test.ts", "old_string": "...", "new_string": "it.skip(...)"}}
```

#### 검사 로직

```bash
#!/bin/bash
# guardrails.sh — PreToolUse hook
INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name')
PRESET=$(jq -r '.preset' .harnesskit/config.json 2>/dev/null || echo "intermediate")

case "$TOOL" in
  Bash)
    CMD=$(echo "$INPUT" | jq -r '.tool_input.command')
    # 패턴 매칭: sudo, rm -rf /, git push --force 등
    ;;
  Write|Edit)
    FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path')
    # 보호 파일 검사: .env, .git/*, secrets*
    # Edit의 경우 new_string에서 it.skip/test.skip 검사
    ;;
esac
```

#### 프리셋별 가드레일 매트릭스

| 패턴 | Beginner | Intermediate | Advanced |
|------|----------|--------------|----------|
| `sudo` | BLOCK | BLOCK | BLOCK |
| `rm -rf /`, `rm -rf ~` | BLOCK | BLOCK | BLOCK |
| `.env` 쓰기 | BLOCK | BLOCK | WARN |
| `git push --force` | BLOCK | BLOCK | WARN |
| `git reset --hard` | BLOCK | WARN | PASS |
| `npm publish` | BLOCK | WARN | PASS |
| `it.skip`, `test.skip` (Edit의 new_string) | WARN | PASS | PASS |

BLOCK = 실행 차단, WARN = 경고 후 진행, PASS = 통과.

### 5.3 session-end.sh (Stop)

두 가지 역할:

#### 에러 데이터 소스: Scratch 파일 방식

Stop hook이 세션 중 에러를 알기 위해, CLAUDE.md의 세션 프로토콜에 다음 규칙을 포함한다:

```markdown
## 세션 중 에러 기록 (자동)
- 에러 발생 시 `.harnesskit/current-session.jsonl`에 한 줄씩 append:
  {"type":"error","pattern":"에러 메시지","file":"파일 경로"}
- 기능 완료 시:
  {"type":"feature_done","id":"feat-XXX"}
- 기능 실패 시:
  {"type":"feature_fail","id":"feat-XXX"}
```

이 scratch 파일은 Claude가 세션 중 작성하고, Stop hook이 읽은 뒤 삭제한다. JSONL(줄 단위 JSON) 형식이므로 shell에서 `jq` 없이도 `grep`으로 파싱 가능하다.

#### 현재 Feature 추적

CLAUDE.md의 세션 시작 프로토콜에 다음 규칙을 포함한다:

```markdown
## 세션 시작 시
- feature_list.json에서 작업할 feature를 선택한 뒤
  `.harnesskit/current-feature.txt`에 feature ID를 기록 (예: feat-006)
```

session-start hook이 이전 세션의 feature를 기본값으로 제안하고, Claude가 변경 시 파일을 업데이트한다.

#### 역할 1 — 상태 저장 (매번)

```
Stop hook 실행:
① git diff --name-only로 변경 파일 수집
② .harnesskit/current-session.jsonl 읽기
③ .harnesskit/current-feature.txt 읽기
④ 위 데이터를 조합하여 세션 로그 생성
⑤ .harnesskit/current-session.jsonl 삭제 (다음 세션을 위해)
⑥ 세션 시작 시간은 .harnesskit/session-start-time.txt에서 읽기
   (session-start.sh가 기록)
```

세션 로그 구조:
```json
{
  "sessionId": "2026-03-19-1430",
  "startedAt": "2026-03-19T14:30:00Z",
  "endedAt": "2026-03-19T16:45:00Z",
  "currentFeature": "feat-006",
  "filesChanged": ["src/auth/login.tsx"],
  "featuresCompleted": ["feat-004"],
  "featuresFailed": [],
  "errors": [
    {
      "pattern": "TypeError: Cannot read property 'id' of undefined",
      "file": "src/auth/login.tsx",
      "count": 2
    }
  ]
}
```

#### 역할 2 — 반복 패턴 감지 (토큰 0)

- 최근 N개 세션 로그 스캔 (N = 프리셋별 임계값: beginner=2, intermediate=3, advanced=5)
- 같은 에러 `pattern` 반복 → 넛지: `/harnesskit:insights 실행 권장`
- 같은 feature 재시도 (current-feature가 이전 세션과 동일 + featuresFailed에 포함) → 넛지: `failures.json 이전 기록 확인`
- 패턴 없으면 → 조용히 종료

---

## 6. Insights 시스템

### 6.1 2단계 구조: 내장 insights + HarnessKit insights

| | Claude Code 내장 `/insights` | `/harnesskit:insights` |
|---|---|---|
| 역할 | 진단 (범용 사용 패턴 분석) | 처방 (harness 설정 변경 diff 제안) |
| 분석 대상 | 토큰 사용량, 도구 호출 빈도 등 | failures, feature 진행률, 세션 로그 |
| 출력 | 일반적 개선 제안 | 구체적 파일 변경 diff |

내장 insights가 관찰, HarnessKit insights가 그 결과를 참고하여 harness를 개선.

### 6.2 `/harnesskit:insights` 흐름

```
① 데이터 수집
  ├ .harnesskit/session-logs/*.json (최근 N개)
  ├ .harnesskit/failures.json
  ├ .harnesskit/config.json
  ├ docs/feature_list.json
  └ CLAUDE.md

② Claude 분석
  ├ 반복 에러 패턴
  ├ 세션당 완료 기능 수 추이
  ├ 가드레일 차단/경고 빈도
  ├ 컨텍스트 소진 빈도
  └ 프리셋과 실제 사용 패턴의 괴리

③ 리포트 출력

④ 개선 제안 (diff 형태)

⑤ 사용자 승인 대기 → /harnesskit:apply
```

### 6.3 제안 가능한 변경 범위

| 대상 파일 | 제안 유형 | 예시 |
|-----------|----------|------|
| CLAUDE.md | 규칙 추가/수정 | null check 규칙 추가 |
| CLAUDE.md | Lazy Loading 참조 추가 | 에러 핸들링 → docs/error-patterns.md |
| .claudeignore | 제외 패턴 추가 | coverage/, dist/ |
| failures.json | rootCause + prevention 보강 | 반복 에러의 원인 분석 결과 |
| config.json | 프리셋 조정 | beginner → intermediate 승급 |
| config.json | 넛지 임계값 조정 | 에러 감지 3→2 |
| feature_list.json | 기능 분할 제안 | "feat-007이 너무 큽니다" |

### 6.4 `/harnesskit:apply` — 승인 후 적용

- 각 제안을 diff로 표시 → y/n/수정 선택
- 승인된 변경 적용
- insights-history.json에 승인/거절 기록
- 거절된 제안의 재제안 규칙: 동일 category + target file 조합을 10세션간 억제. 10세션 후 새로운 데이터가 뒷받침하면 재제안 허용

### 6.5 프리셋 자동 조정 제안

충분한 데이터(10세션+) 축적 후 프리셋 변경 제안 가능:

**승급 조건 (beginner → intermediate, intermediate → advanced)**:
- 최근 10세션 동안 가드레일 BLOCK 0회 AND
- 세션당 평균 완료 feature > 1개 AND
- 반복 에러(동일 pattern 3회+) 0건

**강등 조건 (advanced → intermediate, intermediate → beginner)**:
- 동일 에러 pattern이 최근 5세션 중 3세션 이상에서 반복 OR
- feature 실패율 > 50% (featuresFailed / 전체 시도) OR
- 가드레일 WARN 빈도가 세션당 평균 3회 이상

---

## 7. Failures 시스템

### 7.1 데이터 구조

```json
{
  "failures": [
    {
      "id": "fail-001",
      "firstSeen": "2026-03-16",
      "lastSeen": "2026-03-19",
      "occurrences": 4,
      "feature": "feat-006",
      "pattern": "Cannot read property 'id' of undefined",
      "files": ["src/api/user.ts", "src/api/auth.ts"],
      "rootCause": null,
      "prevention": null,
      "status": "open"
    }
  ]
}
```

### 7.2 필드 생명주기

| 필드 | 기록 시점 | 기록 주체 |
|------|----------|----------|
| id, firstSeen, pattern, files | 최초 감지 | Stop hook (자동) |
| occurrences, lastSeen | 반복 발생 | Stop hook (자동) |
| feature | 감지 시 `.harnesskit/current-feature.txt`에서 읽음 | Stop hook (자동) |
| rootCause, prevention | insights 분석 시 | Claude (insights) → apply 승인 |
| status: open → resolved | 해당 에러 미발생 3세션 후 | Stop hook (자동) |

### 7.3 세션 시작 시 활용

session-start hook이 현재 작업할 feature와 관련된 failure를 자동 경고. resolved된 failure의 prevention은 "이렇게 하면 됩니다" 가이드로 제공.

---

## 8. Status 조회

### 8.1 `/harnesskit:status`

Shell 스크립트로 파일 읽기만 수행 (토큰 최소):

```
═══ HarnessKit Status ═══
⚙️  Preset: intermediate (since 2026-03-15)
📂  Project: Next.js + TypeScript + Vitest
📋  Features: 5/12 (42%)
📝  Last Session: feat-005 완료
⚠️  Active Failures: 2건
💡  Pending Insights: 없음
══════════════════════════
```

---

## 9. 데이터 흐름 종합

```
/harnesskit:setup ──→ [감지] ──→ [프리셋 선택] ──→ [파일 생성]
                                                        │
                   ┌────────────────────────────────────┘
                   ▼
    ┌── SessionStart hook ──→ 브리핑 주입 (토큰 0)
    │
    ├── 작업 중 ──→ PreToolUse hook ──→ 가드레일 (토큰 0)
    │
    └── Stop hook ──→ 로그 저장 + failures 기록 (토큰 0)
                        │
                        ├─ 반복 패턴? → 넛지 출력
                        └─ 패턴 없음 → 조용히 종료
                                │
                    (사용자 또는 넛지 트리거)
                                │
                                ▼
            내장 /insights ──→ 범용 진단
                                │
                                ▼
            /harnesskit:insights ──→ 심층 분석 ──→ diff 제안
                                                      │
                                                      ▼
                                    /harnesskit:apply ──→ 승인 후 적용
                                                              │
                                                              ▼
                                            다음 세션부터 개선된 harness
```

---

## 10. 비기능 요구사항

### 10.1 토큰 효율

- 모든 hook은 shell 스크립트로 실행 (토큰 소비 0)
- CLAUDE.md는 60줄 이하 유지
- insights만 Claude를 호출 (사용자 수동 트리거)
- 블로그 가이드라인의 Lazy Loading 원칙 준수

### 10.2 안전성

- 가드레일은 패턴 매칭 기반 (프롬프트 의존 아님)
- 모든 설정 변경은 사용자 승인 후 적용 (제안 + 승인 방식)
- 기존 파일 덮어쓰기 시 자동 백업
- failures.json은 append-only (삭제 불가, resolved만 가능)

### 10.3 확장성

- 새 프레임워크 지원 = 템플릿 파일 추가
- 프리셋 커스터마이징 = config.json의 overrides 필드
- 바이블 가이드라인은 추후 별도 문서로 취합 (블로그 + 관련 영상 + 추가 자료)
- A/B 테스트는 `/skill-builder` 연동으로 후순위 구현

### 10.4 Graceful Degradation

모든 hook은 데이터 파일 누락/손상에 대해 안전하게 동작해야 한다:

| 상황 | 동작 |
|------|------|
| `.harnesskit/config.json` 누락 | 기본값 `intermediate` 프리셋 사용 |
| `feature_list.json` 누락 | 브리핑에서 feature 섹션 생략 |
| `failures.json` 누락 또는 JSON 파싱 실패 | 빈 failures로 처리, 경고 없음 |
| `progress/claude-progress.txt` 누락 | "No previous progress" 표시 |
| `current-session.jsonl` 누락 | 에러/feature 데이터 없이 세션 로그 생성 (filesChanged만) |
| `current-feature.txt` 누락 | feature 필드를 null로 기록 |
| 모든 파일 누락 | session-start: 최소 브리핑 ("HarnessKit: run /harnesskit:setup"), 나머지 hook: 조용히 종료 |

각 hook은 파일 읽기 전 존재 확인 (`[ -f file ]`), JSON 파싱 시 `jq` 에러를 `/dev/null`로 리다이렉트. 어떤 파일 오류도 hook 자체를 크래시시키지 않는다.

### 10.5 제거 및 마이그레이션

**제거**: 생성된 파일(CLAUDE.md, .claudeignore 등)은 사용자 소유. 플러그인 제거 시 프로젝트 파일은 그대로 남는다. `/harnesskit:reset --full`로 `.harnesskit/` 및 hooks 설정을 정리할 수 있다.

**마이그레이션**: `.harnesskit/config.json`에 `schemaVersion` 필드를 포함. 플러그인 업데이트 시 session-start hook이 버전 불일치를 감지하면 "HarnessKit이 업데이트되었습니다. `/harnesskit:setup`으로 마이그레이션하세요" 안내.
