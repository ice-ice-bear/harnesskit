# Claude Code Harness Engineering 완전 가이드
> **작성일**: 2026년 3월 19일  
> **범위**: Harness Engineering 개념 정의 · 공식 구현체 · 주요 플러그인 심층 분석 · 비교 · 실전 선택 가이드

---

## 목차

1. [Harness Engineering이란 무엇인가](#1-harness-engineering이란-무엇인가)
2. [Anthropic 공식 구현체: autonomous-coding](#2-anthropic-공식-구현체-autonomous-coding)
3. [panayiotism/claude-harness](#3-panayiotismclaude-harness)
4. [Chachamaru127/claude-code-harness](#4-chachamaru127claude-code-harness)
5. [두 플러그인 면밀 비교](#5-두-플러그인-면밀-비교)
6. [GantisStorm/autonomous-coding-harness](#6-gantisstormautonomous-coding-harness)
7. [공통 생태계 이슈](#7-공통-생태계-이슈)
8. [실전 선택 가이드](#8-실전-선택-가이드)
9. [용어 정리](#9-용어-정리)

---

## 1. Harness Engineering이란 무엇인가

### 1.1 탄생 배경: 컨텍스트 창의 근본적 한계

AI 에이전트가 단순한 질의응답을 넘어 수 시간, 수 일에 걸친 장기 작업을 수행하게 되면서 하나의 치명적인 문제가 수면 위로 떠올랐다. **컨텍스트 창의 세션 경계 문제**다.

Claude Code(혹은 어떤 LLM 기반 에이전트든)는 새 세션을 시작할 때마다 이전 세션의 기억이 전혀 없다. 교대 근무자가 아무런 인수인계 없이 출근하는 것과 같다. 이 상황에서 에이전트는 두 가지 전형적인 실패 패턴을 보인다.

- **One-shot 시도**: 전체 작업을 한 번에 끝내려다 컨텍스트 중간에 소진, 절반이 구현된 미완성 코드를 남긴다.
- **조기 완료 선언**: 이미 일부 기능이 구현된 것을 보고 작업이 끝났다고 잘못 판단한다.

이 문제를 해결하기 위해 Anthropic은 2025년 11월 26일 엔지니어링 블로그에 *"Effective harnesses for long-running agents"*를 발표했다. 이것이 **Harness Engineering**의 공식 정의를 제시한 최초의 문서다.

### 1.2 Harness Engineering의 정의

> **Harness Engineering**은 AI 에이전트가 여러 컨텍스트 창(세션)에 걸쳐 일관된 진행을 유지할 수 있도록 에이전트 외부에 구축하는 구조적 인프라를 설계하고 운영하는 공학 분야다.

단순한 프롬프트 엔지니어링과 근본적으로 다르다. 프롬프트 엔지니어링이 "모델에게 무엇을 말할 것인가"를 다룬다면, Harness Engineering은 "모델이 다음 세션에서도 지금의 상태를 이어받아 일할 수 있는 환경을 어떻게 구축할 것인가"를 다룬다.

### 1.3 Harness Engineering의 3개 레이어

실무 관점에서 Harness는 소유 주체에 따라 3개 레이어로 분류된다.

| 레이어 | 소유자 | 구성 요소 | 예시 |
|--------|--------|-----------|------|
| **Tool-owned Harness** | 도구 제작사 | 기본 컨텍스트 관리, compaction, 기본 도구 | Claude Code의 내장 기능 |
| **Project-owned Harness** | 개발자/팀 | CLAUDE.md, feature_list.json, progress 파일, init.sh | 레포지토리 내 커스텀 구조 |
| **Org-owned Harness** | 조직 | 평가 게이트, 권한 관리, 감사 로그, CI/CD 연동 | 팀 단위 정책, CODEOWNERS |

가장 큰 차이는 중간 레이어, 즉 **레포지토리에 직접 놓는 구조**에서 만들어진다.

### 1.4 Harness Engineering의 4대 핵심 구성요소

Anthropic이 정의한 진정한 Harness Engineering은 다음 4가지를 모두 포함해야 한다.

#### (1) Feature List — 완료 기준의 외부화

```json
{
  "category": "functional",
  "description": "새 채팅 버튼을 클릭하면 새 대화가 생성된다",
  "steps": [
    "메인 인터페이스로 이동",
    "New Chat 버튼 클릭",
    "새 대화 생성 확인",
    "채팅 영역이 welcome 상태 표시 확인"
  ],
  "passes": false
}
```

모든 기능이 `passes: false`로 시작한다. 이것이 핵심이다. 에이전트가 "이미 완성됐다"고 잘못 판단하는 것을 구조적으로 막는다. Markdown 파일이 아닌 JSON을 사용하는 이유는, 모델이 Markdown 파일은 임의로 수정하는 경향이 있지만 JSON 파일은 그렇지 않기 때문이다.

#### (2) Progress File — 세션 간 핸드오프

`claude-progress.txt`는 인간 엔지니어의 일일 업무 일지에 해당한다. 각 세션 종료 시 에이전트가 다음 내용을 기록한다.

- 이번 세션에서 구현한 것
- 현재 깨져 있는 것
- 다음 세션에서 집중해야 할 것
- 주의사항

이 파일 덕분에 다음 세션의 에이전트는 "어디까지 왔는가"를 재구성하는 데 시간을 낭비하지 않는다.

#### (3) init.sh — 재현 가능한 환경

매 세션 시작 시 개발 서버를 실행하고 기본 E2E 테스트를 통과시키는 스크립트다. 이것의 목적은 "이전 에이전트가 남긴 코드가 현재 정상 작동하는가"를 확인하는 것이다. 새 기능을 구현하기 전에 기존 상태가 건강한지 먼저 검증하지 않으면, 이미 깨진 시스템 위에 새 기능을 쌓는 최악의 상황이 발생한다.

#### (4) Git 기반 증분 커밋 — 상태 복구의 최후 수단

각 세션 종료 시 작업 내용을 git에 커밋한다. 이것은 단순한 버전 관리가 아니다. 에이전트가 잘못된 구현으로 시스템을 망가뜨렸을 때 `git revert`로 깨끗한 상태로 돌아갈 수 있는 복구 메커니즘이다.

### 1.5 매 세션 시작 프로토콜 (의례적 스타트업)

Anthropic이 제안한 세션 시작 순서는 인간 소프트웨어 엔지니어의 일상에서 직접 영감을 받았다.

```
① pwd 실행     → 현재 작업 디렉터리 확인 (기본이지만 놓치면 치명적)
② progress 읽기 → claude-progress.txt + git log --oneline -20
③ 기능 선택    → feature_list.json에서 passes:false인 최우선 기능 선택
④ init.sh 실행 → 개발 서버 기동 + 기본 E2E 테스트 (구현 전에 반드시)
⑤ 작업 시작   → 선택한 단일 기능만 구현
```

④번 단계가 가장 자주 건너뛰어지는 단계다. 에이전트는 즉시 일을 시작하고 싶어하지만, 기존 코드가 이미 깨져있는 상태에서 새 기능을 구현하면 문제가 더 악화될 뿐이다.

### 1.6 Harness라는 단어의 3가지 용법과 혼란

이 문서에서 다루는 플러그인들이 모두 "harness"라는 단어를 쓰지만, 실제로는 세 가지 전혀 다른 의미로 사용되고 있다.

| 용법 | 의미 | 대표 사례 |
|------|------|-----------|
| **Anthropic 정의 (원본)** | 세션 간 컨텍스트 지속성 문제를 해결하는 Initializer + Coding Agent 이중 구조 | autonomous-coding, claude-harness |
| **일반적 의미** | AI 에이전트를 제어하고 안내하는 모든 외부 구조 (가드레일, 워크플로우 포함) | claude-code-harness |
| **마케팅적 용법** | AI를 더 잘 다루는 도구라면 무엇이든 | 시장의 다수 플러그인 |

이 혼란이 이 문서의 출발점이다.

---

## 2. Anthropic 공식 구현체: autonomous-coding

**레포지토리**: `anthropics/claude-quickstarts/autonomous-coding`  
**유형**: Python SDK 기반 데모  
**라이선스**: MIT  
**출처**: [Anthropic Engineering Blog, Nov 26 2025](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents)

### 2.1 개요

Anthropic이 *Effective harnesses for long-running agents* 아티클과 함께 공개한 공식 구현체다. Harness Engineering의 모든 개념이 코드로 구현되어 있어, 이론과 구현이 1:1로 대응한다. "Internal Anthropic use"라는 주석이 코드 내에 존재할 정도로 내부 실험적 성격이 강하다.

### 2.2 아키텍처

```
autonomous-coding/
├── autonomous_agent_demo.py   # 메인 진입점 (Initializer + Coding Agent 루프)
├── prompts/
│   ├── initializer_prompt.md  # 첫 번째 세션 전용 프롬프트
│   └── coding_prompt.md       # 이후 모든 세션 프롬프트
├── app_spec.txt               # 사용자가 작성하는 앱 명세
└── requirements.txt
```

**두 에이전트의 역할 분리**:

| 에이전트 | 실행 횟수 | 역할 |
|----------|-----------|------|
| **Initializer Agent** | 최초 1회 | `feature_list.json` 생성 (200개), `claude-progress.txt` 초기화, `init.sh` 작성, git init |
| **Coding Agent** | 이후 매 세션 | progress 읽기 → 기능 선택 → 구현 → E2E 테스트 → git commit → progress 업데이트 |

### 2.3 feature_list.json 설계 원칙

```json
// 좋은 예 (사용자 행동 + 검증 단계 포함)
{
  "description": "사용자가 메시지를 전송하고 AI 응답을 받을 수 있다",
  "steps": [
    "메인 인터페이스로 이동",
    "입력창에 텍스트 입력",
    "Enter 키 또는 전송 버튼 클릭",
    "AI 응답이 채팅창에 표시되는지 확인"
  ],
  "passes": false
}

// 나쁜 예 (검증 불가능)
{
  "description": "채팅 기능 구현",
  "passes": false
}
```

핵심 규칙:
- 모든 기능은 `passes: false`로 시작
- 에이전트는 `passes` 필드의 값만 변경 가능 (기능 설명, 단계 수정 불가)
- 이 규칙이 강한 경고 문구로 명시됨: *"It is unacceptable to remove or edit tests"*

### 2.4 실제 세션 흐름 예시

```
[Assistant] I'll start by getting my bearings.
[Tool Use]  <bash - pwd>
[Tool Use]  <read - claude-progress.txt>
[Tool Use]  <read - feature_list.json>
[Assistant] Let me check the git log to see recent work.
[Tool Use]  <bash - git log --oneline -20>
[Assistant] Now let me start the development server.
<Starts the development server via init.sh>
[Assistant] Let me verify basic functionality is still working.
<Runs E2E test with Puppeteer>
[Assistant] Core functionality confirmed working. Starting on feature #42: user authentication...
```

### 2.5 장점

- **이론-구현 완전 일치**: Anthropic 아티클의 모든 개념이 코드로 구현됨
- **Puppeteer MCP**: 실제 브라우저 자동화로 E2E 테스트 수행, 사람처럼 테스트
- **투명성**: MIT 오픈소스, 내부 로직 완전 공개
- **학습 가치 최고**: Harness Engineering 개념 학습의 최적 교재

### 2.6 한계점

- **Python SDK 필수**: Claude Code plugin 형태가 아님, 별도 Python 환경 필요
- **웹앱 특화**: Puppeteer 기반 테스트는 비웹 프로젝트에 적용 어려움
- **데모 수준**: 실제 프로덕션 적용을 위해서는 상당한 커스터마이징 필요
- **속도와 비용**: 200개 기능 완성까지 수십 시간, API 비용 $50~200 예상
- **팀 협업 미지원**: 단일 개발자 시나리오만 커버

### 2.7 유저 반응

> "공식 아티클 읽고 바로 실행해봤는데, 200개 feature가 passes:false로 생성되는 거 보고 충격받음. 개념 이해에 최고."

> "이게 데모인 건 알겠는데, 내 Next.js 프로젝트에 붙이려면 절반을 다시 써야 함."

> README 경고: *"Warning: This demo takes a long time to run! First session may appear to hang — this is normal."* (실제 사용자 혼란 원인)

### 2.8 종합 평가

| 항목 | 점수 (100점 기준) | 비고 |
|------|-------------------|------|
| Harness 적합도 | 98 | 공식 정의와 완전 일치 |
| 설치 용이성 | 45 | Python 환경, 수동 설정 필요 |
| 프로덕션 준비도 | 40 | 명시적 데모, 직접 커스터마이징 필요 |
| 학습 자료 | 88 | 아티클과 코드 1:1 대응 |
| 커뮤니티 활성도 | 55 | quickstarts 레포 내 일부 |

---

## 3. panayiotism/claude-harness

**레포지토리**: `panayiotism/claude-harness`  
**유형**: Claude Code Plugin (Shell + Batchfile)  
**GitHub**: ⭐ 70 · 7 forks · 149 commits  
**현재 버전**: 2026-02-28 (semver와 날짜 혼용)  
**라이선스**: MIT

### 3.1 개요

Anthropic 아티클을 README에 직접 출처로 명시한 가장 투명한 Claude Code Plugin이다. `claude-harness`는 Anthropic의 2에이전트 패턴을 Claude Code Plugin 생태계에 녹여낸 것으로, 4레이어 메모리 아키텍처가 `claude-progress.txt`의 고도화 버전에 해당한다.

출처 명시: *"Based on Anthropic's engineering article and enhanced with patterns from Context-Engine, Agent-Foreman, Autonomous-Coding."*

### 3.2 아키텍처

```
.claude-harness/
├── memory/
│   ├── episodic/
│   │   └── decisions.json      # 최근 50개 결정의 롤링 윈도우
│   ├── semantic/
│   │   ├── architecture.json   # 프로젝트 구조 (영구 보존)
│   │   ├── entities.json       # 핵심 컴포넌트
│   │   └── constraints.json    # 규칙 & 컨벤션
│   ├── procedural/
│   │   ├── failures.json       # 실패 접근법 Append-only 로그 ★
│   │   ├── successes.json      # 성공 접근법 로그
│   │   └── patterns.json       # 학습된 패턴
│   └── learned/
│       └── rules.json          # 사용자 교정으로 학습한 규칙
├── features/
│   ├── active.json             # 현재 진행 중인 기능 목록
│   ├── archive.json            # 완료된 기능 아카이브
│   └── tests/
│       └── {feature-id}.json   # 기능별 테스트 케이스
├── sessions/                   # 세션별 격리 상태 (gitignore)
│   └── {uuid}/                 # 각 Claude 인스턴스 독립 루프 상태
└── config.json
```

### 3.3 4레이어 메모리 시스템

| 레이어 | 목적 | 생명주기 |
|--------|------|---------|
| **Working** | 현재 작업 전용 컨텍스트 | 매 세션 재생성 |
| **Episodic** | 최근 결정 사항 (최대 50개) | 롤링 윈도우 |
| **Semantic** | 프로젝트 아키텍처, 패턴 | 영구 보존 |
| **Procedural** | 성공/실패 접근법 | Append-only |

매 세션 시작 시 4개 레이어에서 관련 정보를 병렬로 읽어 **Working Context**를 새로 컴파일한다. 이 방식은 컨텍스트 누적 없이 항상 신선하고 관련성 높은 컨텍스트를 제공한다.

### 3.4 failures.json — 핵심 킬러 피처

```json
{
  "entries": [
    {
      "id": "uuid",
      "timestamp": "2025-01-20T10:30:00Z",
      "feature": "feature-001",
      "approach": "DOM 직접 조작으로 상태 관리 시도",
      "files": ["src/components/Auth.tsx"],
      "errors": ["React hydration mismatch"],
      "rootCause": "SSR 환경에서 직접 DOM 접근 불가",
      "prevention": "useState와 useEffect 사용 권장"
    }
  ]
}
```

`/flow` 명령 실행 전 자동으로 `failures.json`을 검색한다. 유사한 접근법이 과거에 실패했다면 다음과 같이 경고한다.

```
⚠️  SIMILAR APPROACH FAILED BEFORE

Failure: DOM 직접 조작으로 상태 관리 시도
When: 2025-01-20
Error: React hydration mismatch
Root Cause: SSR 환경에서 직접 DOM 접근 불가
Prevention Tip: useState와 useEffect 사용 권장

✅ SUCCESSFUL ALTERNATIVE
Approach: React hooks + conditional rendering
```

### 3.5 주요 명령어 체계

#### 핵심 5개 명령어

| 명령어 | 역할 | Harness 연관 |
|--------|------|-------------|
| `/claude-harness:setup` | 메모리 아키텍처 초기화 | Initializer Agent |
| `/claude-harness:start` | 4레이어 컨텍스트 컴파일 | 세션 스타트업 프로토콜 |
| `/claude-harness:flow` | 전체 생애주기 자동화 | Coding Agent 루프 |
| `/claude-harness:checkpoint` | 수동 커밋 + PR 생성 | Git 증분 커밋 |
| `/claude-harness:merge` | 모든 PR 머지 + 이슈 닫기 | 릴리스 |

#### `/flow` 플래그 옵션

| 플래그 | 동작 |
|--------|------|
| `(기본값)` | TDD 전체 사이클 → checkpoint → merge |
| `--no-merge` | checkpoint까지만 (PR 생성, merge 않음) |
| `--plan-only` | 계획 수립까지만 |
| `--quick` | 계획 단계 스킵 |
| `--fix feature-001 "Bug"` | 기능에 연결된 버그픽스 |
| `--autonomous` | 전체 백로그 비감독 배치 처리 |
| `--team` | Tester + Implementer + Reviewer 3에이전트 팀 |

### 3.6 TDD 사이클 강제 (ATDD Always-On)

v9.3.0부터 모든 `/flow` 실행에 ATDD(Acceptance Test-Driven Development)가 강제된다.

```
RED    → Gherkin 기준에서 인수 테스트 먼저 작성 (실패 상태)
GREEN  → 인수 테스트를 통과하는 최소 코드 작성
REFACTOR → 코드 품질, 타입 체크, 린트
ACCEPT → Playwright/Cypress 등 E2E 실제 수락 테스트
```

### 3.7 PRD 분해 기능

```bash
# PRD 파일에서 자동으로 GitHub 이슈 생성
/claude-harness:prd-breakdown @./docs/prd.md

# 결과:
# - 원자적 기능으로 분해
# - 의존성 위상 정렬 (토폴로지 정렬)
# - MVP 우선순위 자동 설정
# - Gherkin 인수 기준 자동 생성 (Given/When/Then)
# - GitHub 이슈 양방향 의존성 링크 (Depends on #X / Blocks #Y)
```

### 3.8 세션 격리 (git worktree)

```bash
# 기능 시작 → 자동으로 격리된 worktree 생성
/claude-harness:flow "Add authentication"
# → ../project-feature-XXX/ 에 독립 디렉터리 생성

# 병렬 개발: 각 Claude 인스턴스가 독립 worktree에서 동작
```

각 세션은 UUID 기반 독립 디렉터리를 가지며 gitignore된다. PID 기반 스테일 세션 감지로 종료된 세션의 디렉터리를 자동 정리한다.

### 3.9 장점

- Anthropic 아티클을 직접 출처로 명시한 가장 투명한 구현
- 4레이어 메모리로 `claude-progress.txt` 개념을 구조적으로 확장
- failures.json을 통한 실패 학습 — 같은 실수 반복 방지
- git worktree 기반 물리적 격리로 병렬 개발 안전
- PRD → 기능 분해 → GitHub 이슈 생성까지 자동화
- SessionStart 후크로 세션 시작 시 자동 컨텍스트 주입

### 3.10 한계점

- **잦은 구조 변경**: v6→v7→v8→v9→v10 급격한 마이그레이션, 기존 사용자 부담
- **Shell 98%**: TypeScript 없이 복잡한 로직 유지보수 난이도 높음
- **GitHub MCP 필수**: 없으면 이슈/PR 자동화 전부 불가
- **plugin update 버그**: Claude Code 자체 버그(#29071, #17361)로 업데이트 불안정
- **v6.5.0 40분 hang 버그**: 대규모 테스트 스위트에서 발생, v6.5.1 hotfix 필요
- **커뮤니티 소규모**: ⭐70 — 외부 사용 사례, 버그 트래킹 부족

### 3.11 유저 반응 (CHANGELOG 기록 기반)

> *"SessionEnd hook [session-end.sh] failed: not found"* — 세션 종료 시 후크 오류 (v6.0.4에서 수정)

> *"ENAMETOOLONG on plugin update"* — 플러그인 캐시 재귀 중첩으로 경로 길이 초과 (v10.0.2 workaround)

> *"Agent hang 40+ minutes in v6.5.0"* — 테스트 스위트 실행 시 무한 대기 (v6.5.1 CRITICAL FIX)

긍정적 반응: *"failures.json이 진짜 킬러 피처. 같은 SSR 실수를 3번 반복하다가 이걸 쓰고 처음으로 1번에 통과."*

### 3.12 종합 평가

| 항목 | 점수 | 비고 |
|------|------|------|
| Harness 적합도 | 88 | Anthropic 정의에 가장 충실한 Plugin |
| 설치 용이성 | 68 | plugin 설치는 쉽지만 GitHub MCP 별도 설정 |
| 프로덕션 준비도 | 62 | 구조 변경 잦아 장기 운영 불안 |
| 메모리 시스템 | 90 | 4레이어 아키텍처로 claude-progress.txt 고도화 |
| 업데이트 안정성 | 48 | plugin update 버그 + 잦은 breaking change |

---

## 4. Chachamaru127/claude-code-harness

**레포지토리**: `Chachamaru127/claude-code-harness`  
**유형**: Claude Code Plugin (TypeScript + Shell + JavaScript)  
**GitHub**: ⭐ 252 · 24 forks · 617 commits  
**현재 버전**: v3.10.2 (2026-03-12)  
**라이선스**: MIT

### 4.1 개요

이 플러그인은 "harness"라는 이름을 달았지만 Anthropic의 Harness Engineering 정의(세션 간 컨텍스트 지속성 문제 해결)와 목적이 **근본적으로 다르다**. 이 플러그인은 **런타임에서 AI의 행동을 강제하고 코드 품질을 자동화하는 워크플로우 규율 도구**다. 커뮤니티 최다 스타(⭐252)를 보유하고 있으며 일본어 README를 제공하는 것으로 보아 일본 개발자 커뮤니티를 주 기반으로 한다.

### 4.2 핵심 철학

> **"Skill packs can teach a prompt. Harness also enforces behavior at runtime."**

프롬프트만으로 AI에게 좋은 행동을 가르치는 것의 한계를 인식하고, 실행 경로 자체에서 행동을 강제한다.

### 4.3 5개 동사(Verb) 워크플로우

```
/harness-setup   → 프로젝트 초기화 (파일, 규칙, 명령어 등록)
/harness-plan    → 아이디어 → Plans.md (명확한 인수 기준 포함)
/harness-work    → 병렬 구현
/harness-review  → 4관점 코드 리뷰 자동화
/harness-release → CHANGELOG, 태그, GitHub Release
```

한 줄 완전 자동화:
```bash
/harness-work all
# 플랜 승인 → 병렬 구현 → 리뷰 → 커밋 자동 실행
# ⚠️ Experimental: 프로덕션 사용 전 docs/evidence/work-all.md 검토 필요
```

### 4.4 TypeScript 가드레일 엔진 (R01~R09)

`core/` 디렉터리에 TypeScript로 컴파일된 선언적 규칙 엔진이 있다. 9개 규칙이 실행 경로에서 AI의 위험한 행동을 차단한다.

| 규칙 | 보호 대상 | 처리 방식 |
|------|-----------|-----------|
| R01 | `sudo` 명령어 | **즉각 차단** |
| R02 | `.git/`, `.env`, 시크릿 파일 쓰기 | **즉각 차단** |
| R03 | `rm -rf /`, `rm -rf ~` 등 파괴적 경로 | **즉각 차단** |
| R04 | `git push --force` | **즉각 차단** |
| R05~R09 | 모드별 컨텍스트 인식 가드 | 상황별 처리 |
| Post | `it.skip`, assertion 변조 | **경고** |
| Perm | `git status`, `npm test` | **자동 허용** |

프롬프트 엔지니어링과의 차이: 가드레일은 AI가 "하지 않겠다"고 약속하는 것이 아니라, **물리적으로 실행할 수 없게** 만든다.

### 4.5 4관점 코드 리뷰 (`/harness-review`)

| 관점 | 검토 항목 |
|------|-----------|
| **Security** | 취약점, SQL injection, auth 우회, 시크릿 노출 |
| **Performance** | 병목, 메모리 누수, N+1 쿼리, 확장성 |
| **Quality** | 패턴, 네이밍, 유지보수성, 중복 |
| **Accessibility** | WCAG 준수, 스크린 리더 호환 |

### 4.6 고급 기능들

#### Breezing (에이전트 팀)

```bash
/harness-work breezing all                   # Planner + Critic 팀 기반 병렬 구현
/harness-work breezing --no-discuss all      # 플랜 검토 스킵, 바로 코딩
/harness-work breezing --codex all           # OpenAI Codex에 위임
```

Phase 0 (계획 토론): Planner가 작업 품질 분석, Critic이 계획에 이의 제기, 승인 후 코딩 시작.
- 기본값: 토큰 5.5x 소비
- `--no-discuss`: 토큰 4x 소비

#### Codex 엔진 통합

```bash
/harness-work --codex "5개 API 엔드포인트 구현"
# → Codex가 구현 → 자기 리뷰 → 보고서 제출
# → Claude Code 워커와 병렬 동작
```

OpenAI Codex CLI 설치 및 API 키 필요.

#### 2-에이전트 모드 (Cursor 연동)

```bash
/harness-release handoff  # Cursor PM에게 보고서 전달
# Plans.md가 두 환경 간 공유 SSOT
```

#### 비코드 산출물 생성

```bash
/generate-slide   # 3개 시각 패턴 (Minimalist/Infographic/Hero)
                  # GOOGLE_AI_API_KEY 필요
/generate-video   # Remotion 기반 비디오 생성
                  # ffmpeg + Remotion 셋업 필요
```

### 4.7 아키텍처

```
claude-code-harness/
├── core/           # TypeScript 가드레일 엔진 (strict ESM, NodeNext)
│   └── src/        # guardrails/ state/ engine/
├── skills-v3/      # 5개 동사 스킬 (현재 버전)
├── agents-v3/      # 3개 에이전트 (worker/reviewer/scaffolder)
├── hooks/          # core/ 엔진 연결 레이어 (thin shims)
├── skills/         # 41개 레거시 스킬 (호환성 유지)
├── agents/         # 11개 레거시 에이전트
├── scripts/        # v2 후크 스크립트
└── templates/      # 생성 템플릿
```

v3에서 42개 스킬을 5개 동사로 통합했다. 레거시 명령어들은 deprecated되었지만 호환성을 위해 유지된다.

### 4.8 Claude Code 최신 기능 활용

| 기능 | 활용 스킬 | 목적 |
|------|-----------|------|
| Agent Memory | harness-work, harness-review | 세션 간 학습 지속 |
| Worktree isolation | breezing | 동일 파일에 대한 안전한 병렬 쓰기 |
| HTTP hooks | hooks | JSON POST로 Slack, 대시보드 연동 |
| ultrathink | harness-work | 복잡한 작업에 자동 ultrathink 주입 |
| modelOverrides | harness-setup | Bedrock, Vertex 등 커스텀 모델 ID 매핑 |

### 4.9 장점

- TypeScript 컴파일 엔진으로 가드레일이 "선언적 규칙"으로 명문화됨
- 보안/성능/품질/접근성 4관점 리뷰 자동화 — 코드 리뷰 자동화 최강
- OpenAI Codex, Cursor 등 생태계 연동으로 범용성 최고
- 617 commits — 가장 활발한 개발 이력
- 벤치마크 자체 제공으로 투명한 비교 가능

### 4.10 한계점

- 세션 간 컨텍스트 지속성 없음 — Harness Engineering 핵심 문제 미해결
- feature_list.json, claude-progress.txt 패턴 없음
- `/harness-work all`: "Experimental" 경고 — 프로덕션 미적합
- Breezing 기본값: 토큰 5.5x 소비 (고비용)
- 슬라이드 생성: GOOGLE_AI_API_KEY 별도 필요
- 비디오 생성: Remotion + ffmpeg 별도 셋업 필요
- Windows symlink 문제 (core.symlinks=false 이슈)

### 4.11 유저 반응

긍정적:
> *"TypeScript 가드레일이 실제로 git push --force 막아줌. 이거 하나만으로도 설치 가치 있음."*

부정적:
> *"Breezing으로 Planner + Critic 돌렸더니 토큰이 5.5배 나옴. 계획 단계가 rework 줄여주긴 하는데 비용 상쇄되는지 모르겠음."*

중립적:
> *"⭐252인데 이게 harness라고? 써보니까 리뷰/릴리스 자동화 도구임. 그냥 그걸로 쓰면 좋음."*

### 4.12 종합 평가

| 항목 | 점수 | 비고 |
|------|------|------|
| Harness 적합도 | 35 | Anthropic 정의와 목적이 다름 |
| 설치 용이성 | 82 | plugin marketplace를 통한 간편 설치 |
| 코드 품질 관리 | 92 | 4관점 리뷰 + TypeScript 가드레일 |
| 가드레일 견고성 | 88 | 9개 규칙, 실행 경로에서 강제 |
| 생태계 확장성 | 78 | Codex, Cursor 등 연동 |

---

## 5. 두 플러그인 면밀 비교

이전 섹션의 두 주요 플러그인(`panayiotism/claude-harness` vs `Chachamaru127/claude-code-harness`)을 다차원으로 비교한다.

### 5.1 기본 정보 비교

| 항목 | panayiotism/claude-harness | Chachamaru127/claude-code-harness |
|------|----------------------------|-----------------------------------|
| 슬로건 | Long-running agent harness with memory & TDD | Plan. Work. Review. Ship. |
| ⭐ | 70 | 252 |
| Forks | 7 | 24 |
| Commits | 149 | 617 |
| 버전 | 날짜 기반 (2026-02-28) | Semantic (v3.10.2) |
| 핵심 언어 | Shell 98%, Batchfile 1.5% | TypeScript 25.7%, JS 32.5%, Shell 38.9% |
| 출처 | Anthropic 아티클 직접 인용 | 독자적 설계 |

### 5.2 설계 철학 비교

| 차원 | panayiotism/claude-harness | Chachamaru127/claude-code-harness |
|------|----------------------------|-----------------------------------|
| **핵심 목표** | 세션 간 컨텍스트 지속 + 실패 학습 | 런타임 행동 강제 + 코드 품질 자동화 |
| **문제 해석** | "에이전트가 기억을 잃는다" | "에이전트가 나쁜 행동을 한다" |
| **해결 방식** | 메모리 시스템 + 핸드오프 구조 | 가드레일 엔진 + 워크플로우 규율 |
| **TDD** | RED→GREEN→REFACTOR→ACCEPT 강제 | 별도 언급 없음 (리뷰 중심) |
| **인간 개입** | 기능 승인 시 + 컨텍스트 리뷰 시 | 플랜 승인 시 (선택) |

### 5.3 가드레일 방식 비교

| 항목 | panayiotism/claude-harness | Chachamaru127/claude-code-harness |
|------|----------------------------|-----------------------------------|
| **방식** | Shell hooks + 허용/차단 목록 | TypeScript 컴파일 엔진 + 선언적 규칙 |
| **차단 방법** | 목록 매칭 (정적) | 규칙 엔진 평가 (동적) |
| **sudo** | deny 목록 | R01 규칙 즉각 차단 |
| **.env 쓰기** | deny 목록 | R02 규칙 차단 |
| **git push --force** | PreToolUse hook 차단 | R04 규칙 차단 |
| **확장성** | 목록에 패턴 추가 | TypeScript 규칙 추가 |
| **투명성** | 목록 직접 편집 가능 | 컴파일 필요, 더 복잡 |

### 5.4 병렬 개발 방식 비교

| 항목 | panayiotism/claude-harness | Chachamaru127/claude-code-harness |
|------|----------------------------|-----------------------------------|
| **병렬화 단위** | git worktree (물리적 디렉터리) | 병렬 워커 (동일 디렉터리) |
| **격리 강도** | 완전 격리 (별도 파일시스템) | 논리적 격리 |
| **충돌 위험** | 없음 (물리적 분리) | 잠재적 파일 충돌 가능 |
| **병렬 모드** | `--autonomous` | `--parallel N` |
| **컨텍스트 격리** | 각 worktree = 독립 Claude 세션 | 멀티 에이전트 동일 컨텍스트 공유 |

### 5.5 GitHub 연동 비교

| 항목 | panayiotism/claude-harness | Chachamaru127/claude-code-harness |
|------|----------------------------|-----------------------------------|
| **이슈 자동 생성** | 기능 시작 시 자동 생성 | 없음 |
| **PR 자동 생성** | `/checkpoint` 시 자동 | `/harness-release` 단계 |
| **PRD 분해** | `/prd-breakdown` — Gherkin + 이슈 | 없음 |
| **이슈 의존성 링크** | Depends on #X / Blocks #Y | 없음 |
| **릴리스 자동화** | 기본 버전 bump | CHANGELOG, 태그, GitHub Release |

### 5.6 비용 비교

| 사용 시나리오 | panayiotism/claude-harness | Chachamaru127/claude-code-harness |
|---------------|----------------------------|-----------------------------------|
| 단순 기능 구현 | 1x (기준) | 1x |
| TDD 전체 사이클 | ~1.5x | N/A |
| 팀 에이전트 (`--team`) | ~3x | N/A |
| Breezing 기본 | N/A | ~5.5x |
| Breezing `--no-discuss` | N/A | ~4x |

### 5.7 적합한 사용 상황

**panayiotism/claude-harness가 적합한 경우**:
- 며칠~몇 주에 걸친 장기 프로젝트
- 같은 실수를 반복하는 패턴을 끊고 싶을 때
- TDD를 엄격히 따르고 싶은 경우
- PRD → 기능 분해 → GitHub 이슈 자동화가 필요한 경우
- 세션이 끊겨도 자동으로 이어서 작업하게 만들고 싶은 경우

**Chachamaru127/claude-code-harness가 적합한 경우**:
- 코드 품질과 보안 리뷰가 핵심인 팀
- 릴리스 자동화(CHANGELOG, 태그)가 필요한 경우
- OpenAI Codex, Cursor 등과 혼용하는 경우
- 클라이언트에게 리뷰 리포트를 제출해야 하는 프리랜서
- 팀 단위 일관된 개발 표준을 강제하고 싶은 경우

### 5.8 한 줄 핵심 차이

> **panayiotism/claude-harness** = "과거를 기억하고 학습하는 장기 에이전트 세션 관리자"

> **Chachamaru127/claude-code-harness** = "개발 행동을 런타임에 강제하는 규율 엔진"

두 플러그인은 경쟁 관계가 아니라 **서로 다른 문제를 풀고 있다**. "무엇을 더 믿느냐"의 문제다. AI가 항상 좋은 판단을 내리기 어렵다고 보고 런타임에서 강제하고 싶다면 `claude-code-harness`, AI가 경험에서 배우도록 기억과 컨텍스트를 체계적으로 관리하고 싶다면 `claude-harness`가 맞다.

---

## 6. GantisStorm/autonomous-coding-harness

**레포지토리**: `GantisStorm/autonomous-coding-harness`  
**유형**: Python 기반 독립 실행형 시스템  
**특화**: GitLab + Docker 환경  
**인용**: *"2026 is the year of agent harnesses"* (Cole Medin)

### 6.1 개요

GitLab + Docker 환경을 위한 프로덕션 지향 Harness 구현체다. Anthropic의 2에이전트 패턴을 Agent Daemon 아키텍처로 확장했다. 커뮤니티 규모는 작지만, 팀 환경에서의 실제 적용에 가장 준비된 플러그인이다.

### 6.2 Agent Daemon 아키텍처

```
Docker Container
└── Agent Daemon (python -m agent.daemon)
    ├── Agent CLI 1 (subprocess)
    │   └── Orchestrator Session: Init Phase
    ├── Agent CLI 2 (subprocess)
    │   └── Orchestrator Session: Coding Phase
    └── Agent CLI 3 (subprocess)
        └── (idle/done)
```

데몬 프로세스가 상시 실행되며 여러 에이전트 서브프로세스를 동적으로 생성·관리·모니터링한다. 각 에이전트의 로그를 독립 파일로 라우팅하고 상태를 `.data/daemon_state.json`에 지속 저장한다.

### 6.3 핵심 기능

| 기능 | 설명 |
|------|------|
| **Atomic State Persistence** | 중간 상태를 체크포인트로 저장, 크래시 후 재개 가능 |
| **Multi-Session Handoff** | commit SHA 포함 핸드오프 코멘트로 세션 연속성 보장 |
| **Test Repair Loop** | 실패 테스트 자동 수정 후 다음 작업 진행 |
| **Regression Gate** | 새 기능 구현 전 기존 테스트 전체 실행 (구현 전에) |
| **File Tracking** | 에이전트 생성 변경만 push, 사용자 미커밋 작업 보호 |
| **Quality Gate** | 린트, 포맷, 타입 체크 강제 (이슈 닫기 전) |

### 6.4 테스트 프레임워크 지원

pytest, Jest, Vitest, Go test, Rust cargo test

### 6.5 장점

- Docker 컨테이너 완전 격리 — 보안상 가장 강력
- Agent Daemon으로 멀티 에이전트 생명주기 체계적 관리
- Human-in-the-Loop 체크포인트 명시적 설계
- Regression Gate로 "깨진 시스템 위에 새 기능 쌓기" 방지

### 6.6 한계점

- GitLab 전용 (GitHub 사용자는 포크 후 수정 필요)
- Docker 필수 — 로컬 개발 오버헤드 큼
- Windows 미지원 (명시적 제한)
- 커뮤니티 규모 극소 — 버그 지원 거의 없음
- Python 데몬 운영을 위한 DevOps 지식 필요

### 6.7 종합 평가

| 항목 | 점수 | 비고 |
|------|------|------|
| Harness 적합도 | 85 | Anthropic 패턴 GitLab/Docker에 충실히 적용 |
| 설치 용이성 | 30 | Docker + GitLab CI + Python 동시 셋업 |
| 프로덕션 준비도 | 72 | 팀 환경에서 실제 사용 가능 |
| 엔터프라이즈 적합 | 78 | 거버넌스, 격리, 테스트 게이트 내장 |
| 커뮤니티 규모 | 20 | 매우 소규모, 지원 부재 |

---

## 7. 공통 생태계 이슈

모든 플러그인이 공유하는 구조적 문제들이다.

### 7.1 토큰 비용 문제

**기본 지표** (2026년 초 기준):
- 평균 개발자 비용: $6/일
- 90% 사용자: $12/일 이하
- 팀 API 사용: 월 $100~200/개발자 (Sonnet 4.6 기준, 큰 분산)

**플러그인 활성화 시 추가 비용 원인**:

1. **시스템 프롬프트 오버헤드**: 활성 플러그인의 모든 도구 정의가 매 메시지마다 시스템 프롬프트에 로딩됨. 5개 MCP 서버 = 5배 오버헤드.

2. **확장 사고 비용**: 기본값으로 요청당 31,999 thinking 토큰 사용. 사용자 대부분이 이를 모름.

3. **에이전트 팀 비용**: 각 팀원이 독립 컨텍스트 창 = 팀원 수 × 기본 비용.

4. **Opus vs Haiku**: Opus 출력 토큰은 Haiku의 약 19배 비용. 같은 작업, 다른 비용.

**비용 절감 전략**:
- `.claudeignore` 설정 (예: `.next/` 제외로 Next.js 프로젝트 30~40% 절감)
- 플러그인 선택적 활성화 (사용 안 하는 MCP 서버 비활성화)
- Plan mode (`Shift+Tab`) — 시행착오 반복 없이 계획 후 실행
- 모델 선택: Sonnet(기본) → Opus(복잡한 아키텍처 결정만)
- CLAUDE.md 60줄 이하 유지 (매 프롬프트마다 로딩됨)
- `/compact` 컨텍스트 60~80% 이전에 실행

### 7.2 Context Rot 문제

1M 토큰 컨텍스트 창이 GA(2026-03-13)되었지만, **컨텍스트 창이 크다고 context rot이 해결되지는 않는다**.

Context rot의 메커니즘:
- 긴 컨텍스트에서 토큰들이 모델의 어텐션을 경쟁함
- 초반에 확인된 중요한 제약사항이 이후 정보에 묻힘
- 모델이 잊어버리는 것이 아니라, 신호가 잡음에 익사하는 것

실용적 임계값:
- 컨텍스트 60~80%에서 `/compact` 실행 권장
- `/compact` 후에도 품질 저하 존재 (summarization의 한계)
- 에이전트팀: 팀원당 독립 컨텍스트 → 비용은 선형 증가, 품질은 각각 독립

### 7.3 Claude Code Plugin 시스템 자체의 한계

1. **plugin update 버그**: 알려진 미해결 버그 3건
   - `#29071`: fetch without merge (업데이트 후에도 이전 버전 유지)
   - `#17361`: 캐시 갱신 안 됨
   - `#26744`: `lastUpdated` 업데이트 안 됨

2. **온디맨드 플러그인 로딩 미작동**: 컨텍스트 10% 초과 시 동적 로딩 기능 있으나 실제로는 신뢰할 수 없음 (버그 3건 보고: `#19560`, `#18370`, `#14884`).

3. **Claude Code 버전 종속**: 플러그인들이 Claude Code 2.1+에 종속되어 있어 버전 업 시 호환성 위험.

4. **Rate limit**: Pro($20) = 5시간 롤링 윈도우 제한. 에이전트 팀 실행 시 빠르게 소진.

### 7.4 모델 과적합 문제

프론티어 코딩 모델은 자신의 하네스에 대해 사후 훈련(post-trained)된다. Claude는 Claude Code 하네스에 최적화되어 있어, Claude Code 자체 하네스와 함께 사용할 때 가장 잘 수행된다. 서드파티 플러그인이 이 학습된 패턴을 우회하거나 충돌하면 성능이 저하될 수 있다.

반면, 모델이 자신의 하네스에 과적합될 수도 있다. OpenCode가 GPT/Codex 모델을 위해 `apply_patch` 도구를 추가해야 했던 것이 그 예다. Claude는 여전히 일반 edit/write 도구를 사용하므로, Claude 전용 최적화는 다른 모델에서 작동하지 않을 수 있다.

---

## 8. 실전 선택 가이드

### 8.1 상황별 추천

| 상황 | 추천 | 이유 |
|------|------|------|
| **Harness Engineering 개념 학습** | `anthropics/autonomous-coding` | 공식 레퍼런스, 이론-구현 1:1 |
| **장기 프로젝트, 세션 간 기억 유지** | `panayiotism/claude-harness` | 4레이어 메모리 + 실패 학습 |
| **코드 품질/보안 리뷰 자동화** | `Chachamaru127/claude-code-harness` | 4관점 리뷰 + TypeScript 가드레일 |
| **GitLab + Docker 팀 환경** | `GantisStorm/autonomous-coding-harness` | Docker 격리 + Regression Gate |
| **비용 최우선** | 직접 CLAUDE.md 최적화 | 플러그인 없이 최소 오버헤드 |
| **프리랜서 (클라이언트 리포트)** | `Chachamaru127/claude-code-harness` | 리뷰 리포트 자동 생성 |
| **TDD 엄격 적용** | `panayiotism/claude-harness` | RED→GREEN→REFACTOR→ACCEPT 강제 |
| **PRD → GitHub 이슈 자동화** | `panayiotism/claude-harness` | `/prd-breakdown` 기능 |

### 8.2 규모별 추천

**개인 개발자 (Solo)**:
- 빠른 프로토타이핑: `Chachamaru127/claude-code-harness`
- 장기 프로젝트: `panayiotism/claude-harness`
- 학습 목적: `anthropics/autonomous-coding`

**소규모 팀 (2~5명)**:
- GitHub 기반: `panayiotism/claude-harness` + GitHub MCP
- 코드 리뷰 표준화: `Chachamaru127/claude-code-harness`

**중소기업 팀 (5명+)**:
- GitLab 환경: `GantisStorm/autonomous-coding-harness`
- GitHub 환경: `panayiotism/claude-harness` + org-level CLAUDE.md

### 8.3 비용 수준별 추천

| 월 예산 | 추천 접근 |
|---------|-----------|
| $0 (무료 플랜) | 플러그인 없이 CLAUDE.md 최적화만 |
| $20 (Pro) | 단일 플러그인 선택, Sonnet 기본 사용 |
| $100 (Max 5x) | 에이전트 팀 실험 가능 |
| $200 (Max 20x) | 에이전트 팀 + 병렬 세션 운영 |
| API 직접 | 제한 없음, 사용량 직접 관리 |

### 8.4 플러그인 조합 고려

단일 플러그인으로 모든 문제를 해결하려 하지 말 것. 두 플러그인의 목적이 다르므로 조합 가능하다.

**추천 조합 (GitHub 기반 팀)**:
- `panayiotism/claude-harness` — 세션 간 기억 + TDD + PRD 분해
- `Chachamaru127/claude-code-harness` — 릴리스 자동화 + 코드 리뷰

단, 두 플러그인 동시 활성화 시 토큰 오버헤드 증가에 주의.

### 8.5 "하네스 없이" 직접 구현하는 방법

플러그인 설치 없이 CLAUDE.md와 레포지토리 구조만으로 Harness Engineering을 구현할 수 있다. 이것이 가장 토큰 효율적이며 커스터마이징 자유도가 높다.

**최소 레포지토리 구조**:

```
your-project/
├── CLAUDE.md                    # 에이전트 지침 (60줄 이하 권장)
├── docs/
│   └── feature_list.json        # 모든 기능, passes:false 시작
├── progress/
│   └── claude-progress.txt      # 세션 간 핸드오프 노트
├── init.sh                      # 개발 서버 + E2E 스모크 테스트
└── .claudeignore                # 불필요한 파일 제외
```

**CLAUDE.md 핵심 내용**:

```markdown
## 세션 시작 프로토콜 (반드시 이 순서로)
1. `pwd` 실행
2. `cat progress/claude-progress.txt` 읽기
3. `git log --oneline -20` 확인
4. `cat docs/feature_list.json` 읽기 (passes:false인 최우선 기능 선택)
5. `./init.sh` 실행 (개발 서버 기동 + 스모크 테스트)
6. 스모크 테스트 통과 확인 후 작업 시작

## 세션 종료 프로토콜 (반드시)
1. 구현한 기능 E2E 테스트
2. feature_list.json의 passes 필드 업데이트
3. git commit (단 하나의 기능만)
4. progress/claude-progress.txt 업데이트

## 절대 규칙
- feature_list.json에서 passes 필드 외 수정 금지
- 한 세션에 하나의 기능만
- 테스트 없이 passes:true 변경 금지
```

---

## 9. 용어 정리

| 용어 | 정의 |
|------|------|
| **Harness Engineering** | AI 에이전트가 여러 세션에 걸쳐 일관된 진행을 유지할 수 있도록 에이전트 외부에 구축하는 구조적 인프라 설계 분야 |
| **Context Rot** | 컨텍스트 창이 길어질수록 초반의 중요한 정보가 이후 내용에 묻혀 모델 추론 품질이 저하되는 현상 |
| **Initializer Agent** | 프로젝트 최초 세션에서 환경 전체를 초기화하는 전용 에이전트 (feature_list, progress 파일, init.sh 생성) |
| **Coding Agent** | 매 후속 세션에서 progress를 읽고 기능 하나씩 증분 구현하는 에이전트 |
| **SSOT** | Single Source of Truth — 플랜, 기능 목록 등의 단일 권위 있는 소스 파일 |
| **passes: false** | feature_list.json에서 아직 구현 또는 검증되지 않은 기능 상태 |
| **Context Window** | LLM이 한 번의 추론에서 처리할 수 있는 최대 토큰 수 (Claude: 1M, 2026-03-13 GA) |
| **Compaction** | 컨텍스트 창이 한계에 다다를 때 이전 내용을 요약하여 공간을 확보하는 자동 처리 |
| **git worktree** | 하나의 레포지토리에서 여러 브랜치를 물리적으로 다른 디렉터리에서 동시에 작업하는 git 기능 |
| **ATDD** | Acceptance Test-Driven Development — 사용자 관점의 인수 테스트를 먼저 작성하고 구현하는 방법론 |
| **Gherkin** | Given/When/Then 구조로 인수 기준을 작성하는 BDD 언어 |
| **Context Engineering** | 에이전트에게 매 호출 시점에 최적의 컨텍스트를 제공하는 기술 (Harness Engineering의 하위 개념) |
| **Agent Daemon** | 상시 실행되며 여러 에이전트 서브프로세스를 관리하는 프로세스 |
| **Session Briefing** | 세션 시작 시 자동으로 주입되는 현재 상태 요약 파일 |
| **Post-trained** | 특정 환경(하네스)에 최적화되도록 사후 파인튜닝된 모델 상태 |

---

## 부록: 빠른 비교 매트릭스

```
                    anthropics/    panayiotism/   Chachamaru127/  GantisStorm/
                    autonomous     claude-        claude-code-    autonomous-
                    coding         harness        harness         coding-harness

Harness 적합도       ████████████  ██████████░   ███░░░░░░░░░   ██████████░
설치 용이성          ████░░░░░░░░  ███████░░░░   ████████░░░░   ██░░░░░░░░░
프로덕션 준비도      ████░░░░░░░░  ██████░░░░░   ███████░░░░░   ███████░░░░
학습 가치            ████████████  ████████░░░   ████████░░░░   ██████░░░░░
커뮤니티 규모        █████░░░░░░░  ██░░░░░░░░░   ██████████░░   █░░░░░░░░░░
토큰 효율            ████████░░░░  ███████░░░░   ██████░░░░░░   ████████░░░
GitHub 통합          ██░░░░░░░░░░  █████████░░   ██████░░░░░░   ██░░░░░░░░░
TDD 지원             ████████░░░░  ██████████    ░░░░░░░░░░░░   █████████░░
```

---

*이 문서는 2026년 3월 19일 기준의 정보를 담고 있습니다. Claude Code 플러그인 생태계는 빠르게 변화하고 있으며, 각 플러그인의 최신 상태는 해당 GitHub 레포지토리를 직접 확인하시기 바랍니다.*
