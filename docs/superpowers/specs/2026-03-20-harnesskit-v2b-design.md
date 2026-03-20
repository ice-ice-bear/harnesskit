# HarnessKit v2b — Extended Harness Features

> **Date**: 2026-03-20
> **Status**: Design approved, pending implementation
> **선행 조건**: v2a 완전 구현
> **원칙**: 독립적인 4개 기능, 최소 명령어 추가

---

## 1. 개요

v2a는 insights 기반 자동 진화를 구현했다. v2b는 **4개 독립 기능**으로 HarnessKit의 활용 범위를 확장한다.

### 1.1 범위 — 4개 확장 기능

| # | 기능 | 진입점 | 통합 방식 |
|---|------|--------|----------|
| 6 | **A/B 테스트** | `/harnesskit:apply` 내 opt-in | `/skill-builder` eval — baseline vs proposed |
| 7 | **PRD 분해** | `/harnesskit:prd` (신규 명령어) | GitHub MCP + feature_list.json 자동 연동 |
| 8 | **Worktree 격리** | `/harnesskit:worktree` (신규 명령어) | Claude Code 내장 worktree + harness 파일 동기화 |
| 9 | **바이블 가이드라인** | `/harnesskit:init` 자동 설치 | 고정 참조 문서 복사 (원칙만, 형식 지침 제외) |

### 1.2 설계 원칙

- **신규 명령어 2개만**: `/harnesskit:prd`, `/harnesskit:worktree`
- **기존 흐름 확장**: A/B 테스트는 apply에, 바이블은 setup에 통합
- **외부 도구 활용**: worktree는 Claude Code 내장 기능, PRD는 GitHub MCP 활용
- **신규 hook/script 없음**: 모든 v2b 기능은 skill 기반

---

## 2. A/B 테스트 (Feature 6)

기존 `/harnesskit:apply` 흐름에 내장. 신규 명령어 없음.

### 2.1 트리거

`/harnesskit:apply`에서 `skill_customization` 또는 `skill_creation` proposal 승인(y) 후:

```
🔬 Run eval comparison? (y/n)
   Compares current state (baseline) vs proposed skill.
```

### 2.2 흐름

```
사용자가 skill proposal 승인 → "Run eval?" 프롬프트
  │
  ├─ n → 직접 적용 (비교 없음)
  │
  └─ y → eval 흐름:
       ① Baseline 측정: /skill-builder가 현재 상태로 eval 실행
          - skill_customization: 기존 marketplace plugin이 baseline
          - skill_creation: skill 없는 상태가 baseline
       ② /skill-builder로 제안된 skill 생성
       ③ 제안된 skill로 eval 실행
       ④ 비교 표시:
          "Baseline (현재):     score X/10"
          "With proposed skill: score Y/10 (+Z 개선)"
       ⑤ 사용자 확인: 적용 또는 건너뛰기
```

### 2.3 비교 의미

| Proposal 타입 | Baseline (A) | Proposed (B) | 측정 대상 |
|--------------|-------------|-------------|----------|
| `skill_customization` | 기존 marketplace plugin | 커스터마이즈된 skill | 에러 패턴 감소율 |
| `skill_creation` | skill 없음 (현재 상태) | 새로 생성된 skill | 미커버 영역 개선율 |

기존에 없는 것과 새로운 것을 비교 → **실제 가치**를 측정. 두 변형 비교가 아님.

### 2.4 데이터 기록

별도 `abTests` config 필드 불필요. `insights-history.json`의 proposal 기록에 eval 결과 포함:

```json
{
  "id": "ins-003",
  "type": "skill_creation",
  "status": "accepted",
  "eval": {
    "baseline": 5,
    "proposed": 8,
    "delta": 3,
    "ranAt": "2026-03-25"
  }
}
```

### 2.5 선행 조건

- `/skill-builder` 설치 필요 (eval 실행에 사용)
- `/skill-builder` 미설치 시: eval 프롬프트 표시 안함, 직접 적용만 가능
- 안내: "A/B eval을 사용하려면 /skill-builder를 설치하세요"

### 2.6 파일 변경

| 파일 | 변경 |
|------|------|
| `harnesskit/skills/apply.md` | skill 승인 후 eval 비교 프롬프트 추가 |

---

## 3. PRD 분해 (Feature 7)

### 3.1 명령어

```
/harnesskit:prd [path-to-prd.md]
```

경로 미지정 시 PRD 내용 붙여넣기 또는 경로 입력 요청.

### 3.2 흐름

```
① PRD 문서 읽기
② 분석 → 개별 feature/task로 분해
③ 각 feature에 대해:
   ├─ GitHub issue 생성 (제목, 본문, 라벨) — GitHub MCP 사용
   ├─ feature_list.json 항목 생성:
   │   {"id": "feat-XXX", "description": "...", "passes": false, "priority": N, "githubIssue": "#123", "source": "prd"}
   └─ 미리보기 표시
④ 분해 결과 승인 요청:
   "8개 feature 발견. GitHub issue + feature_list 생성? (y/n/edit)"
⑤ 승인 시: issue 생성 + feature_list.json 갱신
⑥ 요약 출력 (issue 링크 포함)
```

### 3.3 선행 조건

- GitHub MCP 사용 가능 → issue 생성 + feature_list 연동
- GitHub MCP 없음 → issue 생성 건너뛰기, feature_list.json만 갱신
- `.harnesskit/config.json` 존재 (HarnessKit 초기화 완료)

### 3.4 feature_list.json 확장

v1 스키마 (`id`, `category`, `description`, `steps`, `passes`)를 유지하면서 신규 필드를 추가:

```json
{
  "version": "1.0.0",
  "features": [
    {
      "id": "feat-001",
      "description": "User authentication",
      "category": "auth",
      "steps": ["implement login", "add session management"],
      "passes": false,
      "priority": 1,
      "githubIssue": "#42",
      "source": "prd"
    }
  ]
}
```

> **v1 호환성**: `description` (v1 필드) 유지, `name`은 사용하지 않음. `category`와 `steps`는 PRD 분해 시 자동 생성. 기존 v1 항목은 신규 필드가 없어도 정상 동작 (null 처리).

| 신규 필드 | 용도 | 필수 |
|----------|------|------|
| `priority` | PRD 분해 시 순서 기반 우선순위 (1 = 최고) | optional |
| `githubIssue` | 생성된 GitHub issue 번호 (없으면 null) | optional |
| `source` | `"prd"` = PRD에서 생성, `"manual"` = 사용자 직접 추가 | optional |

### 3.5 중복 감지

동일 PRD 재실행 시 중복 방지:
1. 기존 feature_list.json의 `description`과 PRD 분해 결과의 `description`을 비교
2. 유사 feature 발견 시: "이미 존재하는 feature입니다. 건너뛸까요? (y/n)"
3. GitHub issue도 동일 제목 검색 → 중복 시 경고

### 3.6 파일 변경

| 파일 | 변경 |
|------|------|
| 신규: `harnesskit/skills/prd.md` | `/harnesskit:prd` skill |
| 수정: `harnesskit/plugin.json` | prd.md 등록 |

---

## 4. Worktree 격리 (Feature 8)

### 4.1 명령어

```
/harnesskit:worktree feat-007
```

feature_list.json의 feature ID를 인자로 받음.

### 4.2 흐름 — Claude Code 내장 worktree 활용

```
① feature ID가 docs/feature_list.json에 존재하는지 검증
② Claude Code 내장 worktree 생성 (EnterWorktree 호출)
③ harness 파일 동기화 (git에 포함되지 않는 파일만):
   ├─ .harnesskit/ (config, detected, failures, insights-history, session-logs/) 복사
   └─ .harnesskit/current-feature.txt 생성
   ※ CLAUDE.md, .claudeignore, docs/feature_list.json, progress/ 는 git 추적 대상이므로
     worktree에 이미 존재 — 별도 복사 불필요
④ .harnesskit/current-feature.txt를 지정된 feature로 설정
⑤ 출력:
   "🌲 Worktree ready for feat-007: {feature name}
    Harness files synced. Session data will be recorded here.
    When done, use ExitWorktree to return."
```

### 4.3 Exit — 데이터 동기화

Claude Code의 `ExitWorktree` 실행 시, worktree 정리 전에 harness 데이터를 메인으로 복귀:

```
ExitWorktree 실행 시:
① .harnesskit/session-logs/*.json → 메인의 .harnesskit/session-logs/에 복사 (append, 덮어쓰지 않음)
② .harnesskit/failures.json → 메인의 failures.json과 병합:
   ├─ 새 failure는 추가
   └─ 기존 failure는 occurrences 합산 + lastSeen 갱신
③ .harnesskit/current-session.jsonl → 있으면 메인으로 이동
④ docs/feature_list.json → 메인과 비교:
   └─ passes: true로 변경된 feature만 반영 (false→true 단방향)
⑤ progress/claude-progress.txt → 메인에 append
```

> **구현 방식**: worktree.md skill 내에 "exit 시 동기화" 지시 포함. Claude Code의 ExitWorktree 호출 전에 동기화 수행을 안내. 자동 hook은 불필요 — skill 지시로 충분.

> **충돌 방지**: session-logs는 타임스탬프 기반 파일명이므로 충돌 없음. failures.json은 병합 로직 사용. feature_list.json은 passes 필드만 단방향 업데이트.

### 4.4 Insights 연동

insights의 Feature Progress 분석 차원에 다음 감지 추가:

```
세션 중 feature 전환 감지 (current-feature.txt가 여러 번 변경):
  "feat-003과 feat-005 사이를 3회 전환했습니다.
   /harnesskit:worktree feat-005 를 사용하여 격리 작업을 고려해보세요."
```

넛지만 제공 — 별도 proposal 타입 불필요. insights가 Feature Progress 분석 시 출력에 포함.

### 4.5 파일 변경

| 파일 | 변경 |
|------|------|
| 신규: `harnesskit/skills/worktree.md` | `/harnesskit:worktree` skill |
| 수정: `harnesskit/plugin.json` | worktree.md 등록 |
| 수정: `harnesskit/skills/insights.md` | Feature Progress에 worktree 제안 추가 |

---

## 5. 바이블 가이드라인 (Feature 9)

### 5.1 설계 원칙 — Constant, Not Extensible

바이블은 **플러그인과 함께 배포되는 고정 참조 문서**이다. 사용자가 수정/확장하지 않는다.

이유:
- 임의의 외부 소스 추가 시 기존 CLAUDE.md/skill/agent 구조와 **충돌하는 가이드라인** 유입 위험
- 블로그 포스트의 핵심 가치는 Claude Code의 **실제 skill/agent 스펙 형식에 부합하는** 원칙 제공
- 다른 소스의 다른 형식 지침이 섞이면 **생성 품질 저하** (HarnessKit의 핵심 기능 훼손)
- 업데이트가 필요하면 플러그인 관리자(개발자)가 직접 수행

### 5.2 소스 — 검증된 2개 블로그 포스트

| 소스 | 추출 내용 |
|------|----------|
| [Claude Code 실전 가이드](https://ice-ice-bear.github.io/posts/2026-03-19-claude-code-practical-guide/) | 세션 관리, lazy loading, MCP 다이어트, WAT 프레임워크, TDD 사이클, 모델 선택 전략 |
| [Vibe Coding Fundamentals](https://ice-ice-bear.github.io/posts/2026-03-16-vibe-coding-fundamentals/) | 4대 원칙 (명확한 컨텍스트, 반복적 소단위, 검증 가능한 출력, 생성 시스템 구축), 바이브코딩 성숙도 스펙트럼 |

**제외한 소스와 이유:**

| 제외 소스 | 이유 |
|----------|------|
| Claude Skills V2 포스트 | skill frontmatter 스펙은 Claude Code 자체 영역 — bible이 아닌 `/skill-builder`가 관리 |
| HarnessKit 개발기 | 우리 자체 스펙에 이미 포함 — 중복 |
| YouTube 영상 | 블로그에 핵심 내용 이미 반영됨 |

### 5.3 바이블 내용 — 원칙만, 구조/형식 지침 제외

bible.md는 **철학과 원칙**만 포함. skill/agent/hook의 **파일 형식이나 구조 지침은 절대 포함하지 않는다**.

`harnesskit/templates/bible.md` (플러그인 내 고정 파일):

```markdown
# HarnessKit Bible — Harness Engineering Principles

> 이 문서는 참조용 원칙 모음입니다. 파일 구조나 형식 지침은 CLAUDE.md와 HarnessKit 템플릿을 따르세요.
> 출처: Claude Code 실전 가이드, Vibe Coding Fundamentals

## 1. 컨텍스트 관리
- Fresh context > bloated context (컨텍스트는 우유 — 시간이 지나면 상한다)
- Lazy Loading: 목차를 주고, 전체 매뉴얼을 주지 않는다
- MCP 다이어트: 동시 활성 5-6개로 제한, 미사용 MCP 비활성화

## 2. 세션 위생
- One session = one feature (예: "Stripe webhook handler", NOT "전체 결제 시스템")
- /clear로 feature 완료 후 리셋
- /compact를 전략적 시점에 실행 (자동 압축에 의존하지 않음)
- 토큰 사용량을 /statusline으로 지속 모니터링

## 3. 작업 설계
- 반복적 소단위: 전체 feature 한 번에 요청하지 않음
- 검증 가능한 출력: TDD — 가정이 아닌 테스트로 검증
- Plan Mode → Implementation 분리: 계획 세션과 구현 세션을 나눔
- Claude의 사고 과정 무시하지 않기: 잘못된 가정은 Escape로 중단

## 4. 지식 아키텍처
- CLAUDE.md = 팀 공유 규칙 (간결하게)
- MEMORY.md = 개인 선호/패턴 (자동 관리)
- TODO.md / progress files = 세션 간 작업 연속성
- feature_list.json = passes: false 패턴으로 작업 추적
- Mermaid 다이어그램: 산문보다 다이어그램으로 시스템 구조 표현

## 5. 자동화 철학
- Zero-token hooks: 경량 감지는 shell (bash + jq)
- Claude는 판단이 필요한 분석에만 (insights 트리거 시)
- WAT 프레임워크: Workflow → Agent → Tools (단계별 정의)
- 작은 단일 작업 스크립트 > 모놀리식 도구

## 6. 툴킷 철학
- Marketplace First, Customize Later
- 바퀴를 재발명하지 않는다
- 산출물이 아닌 생성 시스템을 구축한다 (재현 가능한 워크플로우)
- 모델 선택: Haiku(간단) → Sonnet(일반) → Opus(설계/복잡)

## 7. 안티패턴
- CLAUDE.md에 모든 것을 넣지 않는다
- 자동 압축에 의존하지 않는다
- 전체 feature를 한 번에 요청하지 않는다
- 스택 트레이스를 해석하지 말고 전체를 붙여넣는다
- 외부 데이터 읽기 시 Prompt Injection 주의
```

### 5.4 트리거

`/harnesskit:setup` 중 init 단계에서 자동으로 bible.md를 사용자 프로젝트에 복사:

```
① harnesskit/templates/bible.md → .harnesskit/bible.md 복사
② CLAUDE.md에 참조 추가: "For harness principles → .harnesskit/bible.md"
③ 출력: "📖 Bible installed (harness engineering principles reference)"
```

별도 opt-in 불필요 — 항상 설치. 참조만 하므로 해가 없음.

### 5.5 Insights 연동

insights가 규칙 제안 시 bible 원칙을 인용 가능:
- "바이블 원칙 '세션 위생: One session = one feature'에 따라, feature 분할을 권장합니다"
- bible은 **인용 소스**이지 **지시 소스**가 아님

### 5.6 업데이트 정책

- bible.md는 **플러그인 업데이트로만 변경** (사용자 수정 불가)
- 새 소스 추가나 내용 변경이 필요하면 플러그인 관리자(개발자)가 판단 후 업데이트
- 사용자 프로젝트의 `.harnesskit/bible.md`는 플러그인 업데이트 시 자동 갱신

### 5.7 파일 변경

| 파일 | 변경 |
|------|------|
| 신규: `harnesskit/templates/bible.md` | 고정 바이블 문서 (플러그인 내 템플릿) |
| 수정: `harnesskit/skills/init.md` | bible.md 복사 단계 추가 |

---

## 6. 파일 변경 요약

### 6.1 신규 파일

| 파일 | 용도 |
|------|------|
| `harnesskit/skills/prd.md` | `/harnesskit:prd` — PRD → GitHub issues + feature_list |
| `harnesskit/skills/worktree.md` | `/harnesskit:worktree` — harness-aware worktree wrapper |
| `harnesskit/templates/bible.md` | 고정 바이블 — harness engineering 원칙 참조 문서 |

### 6.2 수정 파일

| 파일 | 변경 내용 |
|------|----------|
| `harnesskit/skills/apply.md` | A/B eval 비교 프롬프트 (skill 승인 후) |
| `harnesskit/skills/init.md` | bible.md 복사 단계 추가 |
| `harnesskit/skills/insights.md` | Feature Progress에 worktree 제안 넛지 추가 |
| `harnesskit/plugin.json` | prd.md, worktree.md 등록, 버전 0.1.0 → 0.2.0 |

### 6.3 변경 없는 파일

| 파일 | 이유 |
|------|------|
| `harnesskit/hooks/*` | 신규 hook 없음 — 모든 v2b 기능은 skill 기반 |
| `harnesskit/skills/setup.md` | 바이블이 항상 설치되므로 setup opt-in 불필요 |
| `harnesskit/scripts/*` | 신규 스크립트 없음 |
| `harnesskit/skills/status.md` | v2b 대시보드 변경 없음 (필요 시 v2c에서) |

### 6.4 plugin.json (v2b 후)

```json
{
  "name": "harnesskit",
  "version": "0.2.0",
  "description": "Adaptive harness for vibe coders — detect, configure, observe, improve",
  "skills": [
    "skills/setup.md", "skills/init.md", "skills/insights.md",
    "skills/apply.md", "skills/status.md", "skills/test.md",
    "skills/lint.md", "skills/typecheck.md", "skills/dev.md",
    "skills/prd.md", "skills/worktree.md"
  ],
  "agents": ["agents/orchestrator.md"]
}
```

### 6.5 config.json 스키마 추가

v2b는 `schemaVersion: "2.1"`로 범프:

```json
{
  "schemaVersion": "2.1",
  "bibleInstalled": true
}
```

> **버전 이력**: v1 = `"1.0"` (또는 없음), v2a = `"2.0"`, v2b = `"2.1"`
> **plugin.json 버전**: v1/v2a = `"0.1.0"`, v2b = `"0.2.0"` (신규 user-facing skills 추가)

`abTests` 별도 필드 불필요 — insights-history.json의 proposal 기록에 eval 결과 포함.
`bibleSources` 필드 불필요 — bible은 고정 템플릿, 소스 레지스트리 없음.

### 6.6 PRD → Worktree 사용 패턴

PRD와 Worktree는 코드 의존성은 없지만 자연스러운 사용 순서가 있음:

```
/harnesskit:prd requirements.md → feature_list.json에 8개 feature 생성
                ↓
/harnesskit:worktree feat-001 → 첫 번째 feature를 격리 환경에서 작업
```

이는 데이터 의존성(feature_list.json 공유)이지 코드 의존성이 아님. 구현 순서에 제약 없음.

---

## 7. 테스트 전략

v2b 기능은 모두 skill(markdown) 기반이므로 shell 단위 테스트 대상이 아님. 검증은 다음으로 수행:

### 7.1 Skill 파일 검증

| 테스트 | 검증 내용 |
|--------|----------|
| prd.md frontmatter | name, description, user_invocable: true 존재 |
| worktree.md frontmatter | name, description, user_invocable: true 존재 |
| plugin.json 유효성 | 모든 등록된 skill 파일이 실제 존재 |
| plugin.json 버전 | version = "0.2.0" |

### 7.2 기존 테스트 회귀

| 테스트 | 기대 |
|--------|------|
| test-init-templates.sh | 기존 22개 통과 (신규 skill 파일 추가 검증) |
| test-session-end-v2a.sh | 기존 16개 통과 (변경 없음) |
| 나머지 6개 suite | 전체 통과 (변경 없음) |

### 7.3 E2E 검증

- plugin.json에 등록된 모든 skill 파일이 존재하고 frontmatter 유효
- 기존 89개 테스트 전체 통과
