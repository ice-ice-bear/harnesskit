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

### 1.5 외부 위임 전략 — "Curate, Don't Reinvent"

HarnessKit의 핵심 원칙: **이미 검증된 marketplace plugin이 있으면 그것을 사용한다.** HarnessKit은 바퀴를 재발명하지 않고, repo에 맞는 최적의 도구를 **선택 → 구성 → 관찰 → 개선**하는 오케스트레이터 역할에 집중한다.

이 원칙은 모든 영역에 적용된다:

| 영역 | 기존 강력 plugin 있음 | 없거나 부족함 |
|------|---------------------|-------------|
| **Skills** | marketplace skill 설치 → 사용 패턴 기반 커스터마이즈 (`/skill-builder`) | marketplace에 없는 영역만 `/skill-builder`로 생성 |
| **Code Review** | `/simplify`, `/review`, `/security-review` 등 추천 | 자체 생성하지 않음 (v2에서 내재화 검토) |
| **Hooks** | marketplace hook plugin 있으면 추천 | 자체 hook 제공 (session, guardrails) |
| **Agents** | marketplace agent 설치 → 사용 패턴 기반 커스터마이즈 | marketplace에 없는 영역만 `/skill-builder`로 생성 (v2) |
| **Commands** | marketplace 명령어 있으면 추천 | 자체 dev command 제공 |

`/harnesskit:insights`가 사용 패턴을 관찰하며:
- 기존 plugin이 프로젝트에 맞지 않으면 → 설정 조정 또는 대안 plugin 추천
- marketplace에 적합한 plugin이 없는 영역만 → 자체 생성/내재화 검토

### 1.6 버전 로드맵

**v1 — Adaptive Harness Foundation**:
- Repo 감지 → 프리셋 → Harness 인프라 생성 (CLAUDE.md, feature_list, progress, failures)
- Harness Toolkit 구성: marketplace plugin 탐색/설치 + dev hooks + 추천 (skills/agents는 marketplace 우선, 부족 시 `/skill-builder`)
- 세션 관리 hooks (브리핑, 가드레일, 로그)
- Insights 관찰 + 개선 루프 (harness 인프라 + toolkit 모두 대상)

**v2 — Intelligent Harness Evolution**:

| 기능 | 설명 | 선행 조건 |
|------|------|----------|
| **Insights 기반 agent 자동 생성** | 세션 데이터 분석 → "API 조사에 시간이 많이 걸립니다, researcher agent를 생성할까요?" → Claude가 프로젝트 맞춤 agent.md 생성 | v1 insights 데이터 10세션+ 축적 |
| **Insights 기반 skill 자동 생성** | 반복 패턴 감지 → `/skill-builder`로 새 skill 생성 + eval + variance analysis → "이 에러 핸들링 패턴을 skill로 추출할까요?" | v1 failures + session-logs 분석 |
| **Insights 기반 hook 자동 생성** | 반복 수동 작업 감지 → hook 자동 제안 → "파일 저장 후 매번 타입체크를 실행하고 있습니다, PostToolUse hook으로 자동화할까요?" | v1 session-logs 행동 패턴 분석 |
| **Marketplace plugin 자동 추천** | 사용 패턴 분석 → "코드 리뷰를 자주 요청합니다, /review 플러그인을 설치할까요?" | v1 session-logs |
| **PRD → GitHub 이슈 분해** | `/harnesskit:prd` 명령어로 PRD를 기능 단위로 분해, GitHub 이슈 자동 생성 | GitHub MCP 연동 |
| **git worktree 세션 격리** | 병렬 개발 시 물리적 디렉터리 격리 | 병렬 세션 지원 |
| **코드 리뷰 내재화** | marketplace 위임 → 프로젝트 맞춤 리뷰 skill로 전환 | v1 리뷰 패턴 데이터 축적 |
| **A/B 테스트** | `/skill-builder`의 eval + variance analysis로 skill/hook 변형 성능 비교 → 최적 변형 자동 선택 | v1에서 이미 `/skill-builder` 연동 |
| **바이블 가이드라인** | 블로그 + 관련 영상 + 추가 자료 취합 → 통합 가이드라인 문서 | 리서치 자료 수집 |

v2의 핵심 원칙: **모든 자동 생성은 사용자 승인 후 적용**. insights가 제안 → 사용자가 y/n → apply가 실행.

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
│   ├── setup.md                        # repo 감지 + 프리셋 선택 + toolkit 생성
│   ├── init.md                         # 템플릿 기반 파일 생성
│   ├── insights.md                     # 세션 로그 분석 + diff 제안
│   ├── apply.md                        # 승인된 변경 적용
│   ├── status.md                       # 현재 harness 상태 조회
│   ├── test.md                         # /harnesskit:test — 테스트 실행 + failures 연동
│   ├── lint.md                         # /harnesskit:lint — 린터 + 포맷터
│   ├── typecheck.md                    # /harnesskit:typecheck — 타입 체크
│   └── dev.md                          # /harnesskit:dev — 개발 서버 시작
│
├── hooks/
│   ├── session-start.sh                # SessionStart: 브리핑 주입
│   ├── guardrails.sh                   # PreToolUse: 위험 행동 차단
│   ├── session-end.sh                  # Stop: 로그 저장 + 넛지 감지
│   ├── post-edit-lint.sh               # PostToolUse: 자동 lint
│   ├── post-edit-typecheck.sh          # PostToolUse: 자동 typecheck
│   └── pre-commit-test.sh             # PreToolUse: 커밋 전 테스트
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
│   ├── presets/
│   │   ├── beginner.json               # 가드레일 강, 브리핑 상세
│   │   ├── intermediate.json           # 균형
│   │   └── advanced.json               # 최소 개입
│   └── (no skill/agent templates — marketplace-first approach)
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

**Harness 관리 명령어:**

| 명령어 | 역할 | 매핑 |
|--------|------|------|
| `/harnesskit:setup` | 최초 1회 — repo 감지 + 프리셋 + 인프라 + toolkit 생성 | setup.md → orchestrator → init.md |
| `/harnesskit:insights` | 세션 로그 분석 → harness + toolkit 개선 diff 제안 | orchestrator → insights.md |
| `/harnesskit:apply` | insights 제안을 승인 후 적용 | apply.md |
| `/harnesskit:status` | 현재 harness 상태 + toolkit 현황 조회 | status.md |
| `/harnesskit:reset` | harness 초기화 (프리셋 재선택) | setup.md (reset mode) — 아래 2.5 참조 |

**Dev 워크플로우 명령어 (setup이 repo에 맞게 구성):**

| 명령어 | 역할 | HarnessKit 연동 |
|--------|------|-----------------|
| `/harnesskit:test` | 테스트 실행 (vitest, pytest 등) | 실패 시 failures.json에 자동 기록 |
| `/harnesskit:lint` | 린터 + 포맷터 (eslint, ruff 등) | 반복 에러 → insights가 skill 규칙 추가 제안 |
| `/harnesskit:typecheck` | 타입 체크 (tsc 등) | 에러 → current-session.jsonl에 기록 |
| `/harnesskit:dev` | 개발 서버 시작 (next dev, uvicorn 등) | 감지된 프레임워크에 맞게 자동 구성 |

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
├── CLAUDE.md                           # 프리셋 + 프레임워크별 생성 (skill 참조 포함)
├── .claudeignore                       # 토큰 절약용
├── .claude/
│   └── settings.json                   # hooks 등록 (harness + dev hooks)
├── docs/
│   └── feature_list.json               # passes: false 패턴
├── progress/
│   └── claude-progress.txt             # 세션 간 핸드오프
└── .harnesskit/
    ├── config.json                     # 프리셋 + 설정 + 설치된 플러그인 목록
    ├── detected.json                   # repo 감지 스냅샷
    ├── failures.json                   # 실패 학습 (append-only)
    ├── insights-history.json           # 제안 승인/거절 이력
    ├── skills/                         # insights가 /skill-builder로 생성한 커스텀 skill (marketplace 커스터마이즈 또는 신규)
    │   └── (초기에는 비어 있음 — marketplace plugin 사용 후 필요 시 생성)
    ├── agents/                         # insights가 추천/생성한 커스텀 agent
    │   └── (초기에는 비어 있음 — marketplace agent 사용 후 필요 시 생성)
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

**Harness 인프라 개선:**

| 대상 파일 | 제안 유형 | 예시 |
|-----------|----------|------|
| CLAUDE.md | 규칙 추가/수정 | null check 규칙 추가 |
| CLAUDE.md | Lazy Loading 참조 추가 | 에러 핸들링 → docs/error-patterns.md |
| .claudeignore | 제외 패턴 추가 | coverage/, dist/ |
| failures.json | rootCause + prevention 보강 | 반복 에러의 원인 분석 결과 |
| config.json | 프리셋 조정 | beginner → intermediate 승급 |
| config.json | 넛지 임계값 조정 | 에러 감지 3→2 |
| feature_list.json | 기능 분할 제안 | "feat-007이 너무 큽니다" |

**Toolkit 개선 (Section 9.7 상세):**

| 대상 | 제안 유형 | 예시 |
|------|----------|------|
| .harnesskit/skills/*.md | 내용 수정/추가 | "nextjs-conventions.md에 Image 최적화 규칙 추가" |
| .harnesskit/skills/ | 새 skill 생성 제안 | "에러 핸들링 패턴이 반복됩니다, skill로 추출 권장" |
| .claude/settings.json | dev hook 활성화/비활성화 | "typecheck hook 비활성화 권장 (매번 무시됨)" |
| .claude/settings.json | dev hook 옵션 조정 | "lint hook에 --cache 옵션 추가" |
| marketplace | 추가 플러그인 추천 | "코드 리뷰를 자주 요청합니다, /review 설치 권장" |
| .harnesskit/agents/ | 추가 agent 추천 | "API 조사에 시간 소요, researcher agent 설치 권장" |

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

## 9. Harness Toolkit Generation (v1 핵심)

Harness Engineering의 본체는 인프라(feature_list, progress, failures)가 아니라 **실제 코딩을 돕는 skills, hooks, agents, commands**다. HarnessKit은 repo 감지 결과에 따라 이 toolkit을 자동 생성한다.

### 9.1 Setup 시 Toolkit 구성 — "Marketplace First, Customize Later"

모든 영역에서 **marketplace에 검증된 plugin을 먼저 탐색/설치**한다. 자체 생성은 하지 않는다. 커스터마이즈는 insights가 사용 패턴을 분석한 후 `/skill-builder`를 통해 수행한다:

```
/harnesskit:setup (Next.js + TypeScript + Vitest 감지)
  │
  ├── [A] Skills
  │     ├─ marketplace에서 프레임워크 매칭 skill plugin 탐색
  │     │    ├─ 있음 → 설치 추천 (사용자 선택)
  │     │    └─ 없음 → 기록만 (insights가 나중에 /skill-builder로 생성 제안)
  │     └─ 초기에는 marketplace plugin만 사용, 커스텀 skill 생성 안함
  │
  ├── [B] Dev Hooks
  │     ├─ harness 전용 hooks (session-start, guardrails, session-end)는 항상 자체
  │     └─ dev hooks (lint, typecheck, pre-commit-test)도 자체 제공
  │
  ├── [C] Dev Commands
  │     └─ 자체 skill로 제공 (/harnesskit:test, :lint, :typecheck, :dev)
  │        HarnessKit 생태계(failures.json 등)와 연동
  │
  ├── [D] Code Review / Security
  │     └─ 항상 marketplace 추천 (/simplify, /review, /security-review 등)
  │        자체 구현하지 않음
  │
  └── [E] Agents
        ├─ marketplace에서 매칭 agent plugin 탐색
        │    ├─ 있음 → 설치 추천 (사용자 선택)
        │    └─ 없음 → 기록만 (v2에서 insights 기반 자동 생성)
        └─ 초기에는 marketplace agent만 사용, 자체 생성 안함
```

**커스터마이즈 타이밍**: setup 시점이 아닌 `/harnesskit:insights` 실행 후. 사용 패턴과 에러율을 기반으로 marketplace plugin을 프로젝트에 맞게 fork/수정하거나, marketplace에 없는 영역에 대해 새 skill을 생성한다.

### 9.2 [A] Skills — Marketplace First, Customize Later

Skills는 자체 생성하지 않고, **marketplace에서 검증된 plugin을 먼저 탐색/설치**한다. 커스터마이즈는 사용 패턴 데이터가 축적된 후 `/skill-builder`를 통해 수행한다.

#### Setup 시 Skill 구성 흐름

```
/harnesskit:setup → repo 감지 완료
  │
  ├── 감지 결과 (nextjs + typescript + vitest)를 기반으로
  │   marketplace에서 매칭 skill plugin 탐색
  │
  ├── 발견된 plugin:
  │   ① 사용자에게 추천 목록 표시
  │   ② 사용자 선택 시 설치
  │   ③ .harnesskit/config.json의 installedPlugins에 기록
  │
  ├── 매칭 plugin 없는 영역:
  │   ① gap으로 기록 (.harnesskit/config.json의 uncoveredAreas)
  │   ② insights가 나중에 사용 패턴 기반으로 /skill-builder 생성 제안
  │
  └── 초기에는 .harnesskit/skills/ 비어 있음
```

#### 커스터마이즈 흐름 (Insights 연동)

```
/harnesskit:insights 분석 결과:
  "Next.js Image 최적화 실수가 5세션 연속 반복됩니다.
   설치된 conventions plugin이 이를 커버하지 않습니다."
  → 제안: skill_customization — marketplace plugin 기반 커스텀 skill 생성
  → /harnesskit:apply 승인 시:
    → /skill-builder에 전달: 설치된 plugin + detected.json + 에러 패턴 데이터
    → /skill-builder가 프로젝트 맞춤 skill 생성 + eval 검증
    → .harnesskit/skills/에 저장
    → CLAUDE.md에 참조 추가
```

```
/harnesskit:insights 분석 결과:
  "에러 핸들링 패턴이 반복됩니다. marketplace에 적합한 plugin이 없습니다."
  → 제안: skill_creation — 새 skill 생성
  → /harnesskit:apply 승인 시:
    → /skill-builder에 전달: detected.json + 에러 패턴 + 사용 데이터
    → .harnesskit/skills/error-handling.md 생성
```

#### Marketplace vs 자체 생성 비교

| Marketplace plugin 그대로 | Insights 후 /skill-builder 커스터마이즈 |
|--------------------------|---------------------------------------|
| 범용, 검증됨 | 프로젝트 에러 패턴 반영 |
| 즉시 사용 가능 | 데이터 축적 후 생성 |
| 업데이트는 marketplace 관리 | insights → /skill-builder로 점진 개선 |
| 모든 프로젝트에 동일 | 사용자의 실수 패턴에 맞춤 |

**CLAUDE.md에서의 참조 (Lazy Loading)** — 커스텀 skill 생성 후:
```markdown
## Skills 참조
- 에러 핸들링 패턴 → .harnesskit/skills/error-handling.md
- Image 최적화 규칙 → .harnesskit/skills/nextjs-image-rules.md
```

Claude는 관련 작업 시에만 해당 skill 파일을 읽는다 (매 세션 전체 로드 아님).

### 9.3 [B] Dev Hooks 자동 구성

harness 관리용 hooks (Section 5)에 더해, **실제 개발을 돕는 hooks**도 구성한다:

| Hook | 트리거 | 동작 | 프레임워크 |
|------|--------|------|-----------|
| `post-edit-lint.sh` | PostToolUse (Edit/Write) | 변경된 파일에 린터 자동 실행 | ESLint, ruff 등 감지된 린터 |
| `post-edit-typecheck.sh` | PostToolUse (Edit/Write) | .ts/.tsx 변경 시 `tsc --noEmit` 실행 | TypeScript 감지 시 |
| `pre-commit-test.sh` | PreToolUse (Bash: git commit) | 커밋 전 관련 테스트 자동 실행 | vitest, pytest 등 |

프리셋별 차이:
- **Beginner**: 모든 dev hooks 활성화 (실수 방지 최대)
- **Intermediate**: lint + typecheck만 (테스트는 수동)
- **Advanced**: 없음 (사용자 재량)

`.claude/settings.json`에 harness hooks와 함께 등록:
```json
{
  "hooks": {
    "SessionStart": [/* harness hooks */],
    "PreToolUse": [/* guardrails + pre-commit-test */],
    "PostToolUse": [
      {
        "type": "command",
        "command": "bash $(claude plugin path harnesskit)/hooks/post-edit-lint.sh"
      },
      {
        "type": "command",
        "command": "bash $(claude plugin path harnesskit)/hooks/post-edit-typecheck.sh"
      }
    ],
    "Stop": [/* session-end */]
  }
}
```

### 9.4 [C] Dev Commands (Skill 기반)

repo에 맞는 개발 워크플로우 명령어를 skill로 등록한다:

| 명령어 | 동작 | 프레임워크 |
|--------|------|-----------|
| `/harnesskit:test` | 테스트 실행 + 실패 시 failures.json 기록 + 재시도 안내 | vitest, pytest, jest 등 |
| `/harnesskit:lint` | 린터 + 포맷터 실행 + 자동 수정 | eslint+prettier, ruff 등 |
| `/harnesskit:typecheck` | 타입 체크 실행 + 에러 요약 | TypeScript |
| `/harnesskit:dev` | 개발 서버 시작 (프레임워크별) | next dev, vite, uvicorn 등 |

이 명령어들은 단순 래핑이 아니라, **HarnessKit 생태계와 연동**된다:
- `/harnesskit:test` 실패 시 → `current-session.jsonl`에 에러 자동 기록
- `/harnesskit:lint` 반복 에러 → insights가 CLAUDE.md 규칙 추가 제안

### 9.5 [D] Marketplace 플러그인 추천

setup 완료 시 repo에 맞는 marketplace 플러그인을 추천한다:

```
📦 추천 Marketplace 플러그인:

  [1] /simplify — 코드 리뷰 + 리팩토링 (모든 프로젝트)
  [2] /review — PR 리뷰 자동화 (git remote 감지 시)
  [3] /security-review — 보안 취약점 검사 (API 프로젝트)

  설치할 플러그인을 선택하세요 (1,2,3 또는 all/none):
```

추천 로직은 `detected.json` 기반:
- git remote 있음 → `/review` 추천
- API 엔드포인트 감지 → `/security-review` 추천
- 모든 프로젝트 → `/simplify` 추천

설치된 플러그인 목록은 `.harnesskit/config.json`의 `installedPlugins` 필드에 기록. 이후 insights가 사용 빈도를 관찰.

### 9.6 [E] Agent — Marketplace First

v1에서는 **marketplace agent plugin을 탐색/추천**. 자체 템플릿을 제공하지 않는다.

```
🤖 Marketplace Agent 추천:

  감지 결과 기반으로 marketplace에서 매칭 agent plugin을 탐색합니다.

  [1] {marketplace-planner-plugin} — 구현 전 세부 계획 수립
  [2] {marketplace-reviewer-plugin} — 코드 리뷰 (또는 /review 추천)
  [3] {marketplace-researcher-plugin} — API 문서/라이브러리 조사

  설치할 agent를 선택하세요 (번호 또는 all/none):
```

매칭 agent가 marketplace에 없는 경우 → gap으로 기록. v2에서 insights 기반 `/skill-builder`를 통해 프로젝트 맞춤 agent 자동 생성.

초기에는 `.harnesskit/agents/` 비어 있음. 커스텀 agent는 insights 분석 후 필요 시 생성.

### 9.7 Insights의 Toolkit 개선 범위 (v1)

insights는 harness 인프라뿐 아니라 **toolkit도 개선 대상**이다. Skill 관련 개선은 `/skill-builder`를 통해 실행된다:

| 대상 | 제안 유형 | 실행 방법 | 예시 |
|------|----------|----------|------|
| **Skills** | marketplace plugin 커스터마이즈 | `/skill-builder`로 marketplace plugin 기반 커스텀 skill 생성 + eval 검증 | "설치된 conventions plugin이 Image 최적화를 커버하지 않습니다, 커스텀 skill 생성 권장" |
| **Skills** | 새 skill 생성 (marketplace 부재 시) | `/skill-builder`로 사용 데이터 기반 생성 + eval 검증 | "에러 핸들링 패턴이 반복됩니다, error-handling.md skill 생성 권장" |
| **Dev Hooks** | 활성화/비활성화 | settings.json 직접 수정 | "typecheck hook이 매번 실패 후 무시됩니다, 비활성화할까요?" |
| **Dev Hooks** | 설정 조정 | settings.json 직접 수정 | "lint hook이 너무 느립니다, --cache 옵션 추가 권장" |
| **Dev Commands** | 옵션 조정 | skill 파일 수정 | "/harnesskit:test에 --watch 모드 추가 권장" |
| **Marketplace** | 추가 추천 | 사용자에게 안내 | "코드 리뷰를 자주 요청합니다, /review 플러그인 설치 권장" |
| **Agents** | 추가 추천 | marketplace agent 추천 (v2: `/skill-builder`로 커스텀 생성) | "API 조사에 시간이 많이 걸립니다, marketplace researcher agent 설치 권장" |

---

## 10. 파일 영향 매트릭스

### 10.1 생성되는 모든 파일과 영향

| 파일 | 생성 시점 | 업데이트 주체 | 레포 영향 |
|------|----------|-------------|----------|
| **CLAUDE.md** | setup | insights→apply | Claude의 행동 규칙 정의. 세션 프로토콜, 코딩 컨벤션, skill 참조 포함. 이 파일이 Claude를 "범용 AI"에서 "프로젝트 전문가"로 전환하는 핵심 |
| **.claudeignore** | setup | insights→apply | Claude가 읽지 않을 파일/폴더 정의. 토큰 절약 직접 영향 (Next.js에서 .next/ 제외 시 30~40% 절감) |
| **docs/feature_list.json** | setup (빈 골격) | 사용자/Claude | 프로젝트의 기능 목록과 완료 상태. passes:false→true 전환이 진행 추적의 핵심. 에이전트의 "할 일 목록" |
| **progress/claude-progress.txt** | setup | Claude (매 세션 종료) | 세션 간 핸드오프 노트. 다음 세션의 Claude가 "어디까지 왔는가"를 즉시 파악. 인수인계 문서 |
| **.claude/settings.json** | setup (hooks 등록) | insights→apply (hook 추가/제거) | Claude Code의 동작 제어. 가드레일, dev hooks, 세션 관리 hooks 등록. 프로젝트의 "자동화 설정" |
| **.harnesskit/skills/*.md** | insights→apply (`/skill-builder` 생성) | insights→apply (내용 수정) | 프로젝트 맞춤 커스텀 skill. 초기에는 비어 있음 — marketplace plugin 사용 후 사용 패턴 기반으로 생성. 출력 품질과 일관성에 직접 영향 |
| **.harnesskit/agents/*.md** | v2에서 insights 자동 생성 | v2에서 insights 자동 생성 | 역할 특화 AI 인스턴스. 초기에는 비어 있음 — marketplace agent 사용 후 필요 시 생성 |
| **.harnesskit/config.json** | setup | insights→apply, reset | 프리셋, 감지 결과, 설치된 플러그인 목록. 모든 hook과 skill의 동작을 결정하는 중앙 설정 |
| **.harnesskit/detected.json** | setup | reset (재감지) | repo 속성 스냅샷. 템플릿 선택, 추천 로직의 입력 데이터 |
| **.harnesskit/failures.json** | Stop hook (자동) | insights→apply (rootCause 보강) | 실패 학습 저장소. 같은 실수 반복 방지. 세션 시작 시 관련 실패 경고 제공 |
| **.harnesskit/insights-history.json** | apply | apply | 제안 승인/거절 이력. 거절된 제안 재제안 방지. insights 품질 개선의 피드백 루프 |
| **.harnesskit/current-session.jsonl** | Claude (세션 중) | Stop hook (읽기 후 삭제) | 세션 중 에러/feature 이벤트 기록. Stop hook의 데이터 소스. 임시 파일 |
| **.harnesskit/current-feature.txt** | Claude (세션 시작) | Claude (변경 시) | 현재 작업 중인 feature ID. Stop hook이 failure와 feature를 연결하는 데 사용 |
| **.harnesskit/session-start-time.txt** | SessionStart hook | Stop hook (읽기) | 세션 시작 시각. 세션 로그의 duration 계산용 |
| **.harnesskit/session-logs/*.json** | Stop hook | - (읽기 전용) | 세션별 실행 이력 아카이브. insights 분석의 핵심 데이터 소스 |
| **.harnesskit/backup/** | setup/reset (덮어쓰기 시) | - | 기존 파일 백업. 안전망 |

### 10.2 Vibe Coder가 체감하는 변화

| 시점 | 변화 | 원인 파일 |
|------|------|----------|
| **setup 직후** | Claude가 프로젝트 컨벤션을 이미 알고 있음 | CLAUDE.md + skills/*.md |
| **setup 직후** | 위험한 명령어가 차단됨 | settings.json (guardrails hook) |
| **setup 직후** | `/harnesskit:test`, `/harnesskit:lint` 등 사용 가능 | skill 파일들 |
| **setup 직후** | 파일 수정 후 자동 lint/typecheck | settings.json (dev hooks) |
| **세션 시작 시** | 이전 작업 상태 브리핑이 자동 표시 | progress.txt + feature_list.json |
| **세션 시작 시** | 관련 실패 이력 경고 | failures.json |
| **세션 종료 시** | 에러/진행 상태 자동 기록 | current-session.jsonl → session-logs |
| **반복 에러 시** | "insights 실행 권장" 넛지 | session-logs 패턴 매칭 |
| **insights 실행 후** | CLAUDE.md 규칙 추가, skill 개선, hook 조정 | insights → apply |
| **시간이 지남에 따라** | harness가 점점 프로젝트에 최적화 | 전체 관찰→개선 루프 |

---

## 11. 데이터 흐름 종합

```
/harnesskit:setup
  │
  ├── [감지] ──→ [프리셋 선택]
  │
  ├── [인프라 생성] ──→ CLAUDE.md, feature_list, progress, failures, .claudeignore
  │
  ├── [Toolkit 생성] ──→ skills/*.md, dev hooks, dev commands
  │
  ├── [추천] ──→ marketplace 플러그인 (사용자 선택 설치)
  │
  └── [추천] ──→ agents (사용자 선택 설치)
       │
       ▼
  ┌── SessionStart hook ──→ 브리핑 주입 (토큰 0)
  │
  ├── 작업 중 ──→ PreToolUse hook ──→ 가드레일 (토큰 0)
  │           ──→ PostToolUse hook ──→ 자동 lint/typecheck (토큰 0)
  │           ──→ /harnesskit:test, :lint, :dev 등 사용
  │           ──→ skills/*.md 참조하여 프로젝트 컨벤션 준수
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
            ├─ 인프라 개선: CLAUDE.md 규칙 추가, .claudeignore 수정
            ├─ Skill 개선: nextjs-conventions.md에 규칙 추가
            ├─ Hook 개선: dev hook 옵션 조정, 활성화/비활성화
            ├─ 추가 추천: marketplace 플러그인, agent 추가
            └─ 프리셋 조정: beginner → intermediate 승급
                              │
                              ▼
          /harnesskit:apply ──→ 승인 후 적용
                              │
                              ▼
          다음 세션부터 개선된 harness + toolkit
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

- 새 프레임워크 지원 = marketplace plugin 탐색 로직 확장
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
