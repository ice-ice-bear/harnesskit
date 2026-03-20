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

### 2.5 파일 변경

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

```json
{
  "version": "1.0.0",
  "features": [
    {
      "id": "feat-001",
      "name": "User authentication",
      "passes": false,
      "priority": 1,
      "githubIssue": "#42",
      "source": "prd"
    }
  ]
}
```

| 신규 필드 | 용도 |
|----------|------|
| `priority` | PRD 분해 시 순서 기반 우선순위 (1 = 최고) |
| `githubIssue` | 생성된 GitHub issue 번호 (없으면 null) |
| `source` | `"prd"` = PRD에서 생성, `"manual"` = 사용자 직접 추가 |

### 3.5 파일 변경

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
③ harness 파일 동기화:
   ├─ .harnesskit/ (config, detected, failures, insights-history) 복사
   ├─ CLAUDE.md 복사
   ├─ .claudeignore 복사
   ├─ docs/feature_list.json 복사
   └─ progress/claude-progress.txt 복사
④ .harnesskit/current-feature.txt를 지정된 feature로 설정
⑤ 출력:
   "🌲 Worktree ready for feat-007: {feature name}
    Harness files synced. Session data will be recorded here.
    When done, use ExitWorktree to return."
```

### 4.3 Insights 연동

insights의 Feature Progress 분석 차원에 다음 감지 추가:

```
세션 중 feature 전환 감지 (current-feature.txt가 여러 번 변경):
  "feat-003과 feat-005 사이를 3회 전환했습니다.
   /harnesskit:worktree feat-005 를 사용하여 격리 작업을 고려해보세요."
```

넛지만 제공 — 별도 proposal 타입 불필요. insights가 Feature Progress 분석 시 출력에 포함.

### 4.4 파일 변경

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

### 5.4 확장성

- 사용자가 `bible-sources.json`에 URL/파일/디렉토리 추가 → 다음 setup 실행 시 재컴파일
- insights가 규칙 제안 시 bible.md 참조 가능: "바이블 원칙 X에 부합합니다"
- 매 세션 자동 fetch 없음 — setup 또는 명시적 요청 시만 컴파일

### 5.5 파일 변경

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

```json
{
  "bibleCompiled": false,
  "bibleSources": ".harnesskit/bible-sources.json"
}
```

`abTests` 별도 필드 불필요 — insights-history.json의 proposal 기록에 eval 결과 포함.

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
