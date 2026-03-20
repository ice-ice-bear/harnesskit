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
| 9 | **바이블 가이드라인** | `/harnesskit:setup` 옵션 | 확장 가능한 참조 문서 컴파일 |

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
   │   {"id": "feat-XXX", "name": "...", "passes": false, "priority": N, "githubIssue": "#123", "source": "prd"}
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

### 5.1 트리거

`/harnesskit:setup` 중, 프리셋 선택 후 init 전:

```
📖 Compile a harness engineering reference guide? (y/n)
   Sources: Anthropic harness article, community best practices
   You can add custom sources later.
```

### 5.2 흐름

```
① 사용자가 setup 중 opt-in (또는 나중에 setup 재실행)
② 소스 레지스트리 읽기: .harnesskit/bible-sources.json
③ 각 소스에 대해 타입별 처리:
   ├─ url: WebFetch로 내용 가져오기
   ├─ file: Read로 직접 읽기
   └─ directory: Glob + Read로 디렉토리 내 모든 markdown 읽기
④ 핵심 원칙, 패턴, 안티패턴 추출
⑤ 카테고리별 정리: 세션 관리, 에러 처리, 테스트, 가드레일 등
⑥ .harnesskit/bible.md로 컴파일
⑦ CLAUDE.md에 참조 추가: "For harness principles → .harnesskit/bible.md"
⑧ 출력: "📖 Bible compiled from {N} sources ({line_count} lines)"
```

### 5.3 소스 레지스트리

`.harnesskit/bible-sources.json`:

```json
{
  "sources": [
    {
      "type": "url",
      "path": "https://ice-ice-bear.github.io/posts/2026-03-19-claude-code-practical-guide/",
      "name": "Claude Code Practical Guide",
      "addedAt": "2026-03-20"
    },
    {
      "type": "file",
      "path": "docs/team-conventions.md",
      "name": "Team Conventions",
      "addedAt": "2026-03-21"
    },
    {
      "type": "directory",
      "path": "docs/references/",
      "name": "Reference Documents",
      "addedAt": "2026-03-22"
    }
  ]
}
```

| 소스 타입 | 처리 방법 |
|----------|----------|
| `url` | WebFetch → 내용 추출 |
| `file` | Read → 직접 읽기 |
| `directory` | Glob + Read → 디렉토리 내 모든 markdown |

### 5.4 크기 제한 및 Lazy Loading

- **bible.md 최대 200줄**: 소스 내용이 초과하면 핵심 원칙 위주로 요약
- **Lazy Loading**: CLAUDE.md에는 참조만 포함 ("For harness principles → .harnesskit/bible.md"). Claude가 관련 작업 시에만 읽음
- 토큰 영향: 매 세션 로드 아님. 필요 시에만 참조하므로 토큰 비용 최소

### 5.5 확장성

- 사용자가 `bible-sources.json`에 URL/파일/디렉토리 추가 → 다음 setup 실행 시 재컴파일
- insights가 규칙 제안 시 bible.md 참조 가능: "바이블 원칙 X에 부합합니다"
- 매 세션 자동 fetch 없음 — setup 또는 명시적 요청 시만 컴파일
- 재컴파일 방법: `/harnesskit:setup --recompile-bible` 또는 setup 재실행 시 "Recompile bible? (y/n)" 프롬프트

### 5.6 파일 변경

| 파일 | 변경 |
|------|------|
| 수정: `harnesskit/skills/setup.md` | setup 흐름에 바이블 opt-in 추가 |
| 수정: `harnesskit/skills/init.md` | 바이블 컴파일 단계 + bible-sources.json 생성 |

---

## 6. 파일 변경 요약

### 6.1 신규 파일

| 파일 | 용도 |
|------|------|
| `harnesskit/skills/prd.md` | `/harnesskit:prd` — PRD → GitHub issues + feature_list |
| `harnesskit/skills/worktree.md` | `/harnesskit:worktree` — harness-aware worktree wrapper |

### 6.2 수정 파일

| 파일 | 변경 내용 |
|------|----------|
| `harnesskit/skills/apply.md` | A/B eval 비교 프롬프트 (skill 승인 후) |
| `harnesskit/skills/setup.md` | 바이블 가이드라인 opt-in 추가 |
| `harnesskit/skills/init.md` | 바이블 컴파일 단계 + bible-sources.json 초기화 |
| `harnesskit/skills/insights.md` | Feature Progress에 worktree 제안 넛지 추가 |
| `harnesskit/plugin.json` | prd.md, worktree.md 등록, 버전 0.1.0 → 0.2.0 |

### 6.3 변경 없는 파일

| 파일 | 이유 |
|------|------|
| `harnesskit/hooks/*` | 신규 hook 없음 — 모든 v2b 기능은 skill 기반 |
| `harnesskit/templates/*` | 신규 템플릿 없음 |
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
  "bibleCompiled": false,
  "bibleSources": ".harnesskit/bible-sources.json"
}
```

> **버전 이력**: v1 = `"1.0"` (또는 없음), v2a = `"2.0"`, v2b = `"2.1"`
> **plugin.json 버전**: v1/v2a = `"0.1.0"`, v2b = `"0.2.0"` (신규 user-facing skills 추가)

`abTests` 별도 필드 불필요 — insights-history.json의 proposal 기록에 eval 결과 포함.

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
