# HarnessKit v2a — Intelligent Harness Evolution (Core)

> **Date**: 2026-03-20
> **Status**: Design approved, pending implementation
> **선행 조건**: v1 완전 운영 + 5세션 이상 데이터 축적
> **원칙**: 기존 명령어 확장, 새 명령어 추가 없음

---

## 1. 개요

v1은 harness를 **구축하고 관찰**한다. v2a는 축적된 사용 데이터를 기반으로 harness가 **스스로 진화**하게 만든다.

핵심 메커니즘: `/harnesskit:insights`에 새로운 proposal 타입을 추가하여, 실제 세션 데이터 기반으로 skill/agent/hook 생성 및 marketplace plugin 추천을 자동화한다.

### 1.1 범위 — 5개 핵심 기능

| # | 기능 | 설명 |
|---|------|------|
| 1 | **Skill 커스터마이즈** | marketplace plugin 부족 감지 → `/skill-builder`로 프로젝트 맞춤 skill 생성 |
| 2 | **Agent 자동 생성** | 시간 소모 패턴 감지 → `/skill-builder`로 프로젝트 맞춤 agent 생성 |
| 3 | **Hook 자동 생성** | 반복 수동 작업 감지 → shell hook 자동 생성 + 등록 |
| 4 | **Marketplace 자동 추천** | 사용 패턴 분석 → 데이터 기반 plugin 추천 (v1의 정적 추천에서 진화) |
| 5 | **코드 리뷰 내재화** | 점진적: marketplace `/review` 보완 → 충분한 데이터 후 완전 대체 |

### 1.2 설계 원칙

- **새 명령어 없음**: 모든 기능은 기존 `/harnesskit:insights` → `/harnesskit:apply` 흐름에 통합
- **Marketplace First, Customize Later**: 초기에는 marketplace plugin 사용, 데이터 축적 후 커스터마이즈
- **데이터 기반 제안**: 최소 5세션 데이터 없이는 생성 제안 불가
- **사용자 승인 필수**: 모든 자동 생성은 proposal → y/n/edit → 적용

### 1.3 v2b 범위 (본 스펙에 포함하지 않음)

| 기능 | 설명 |
|------|------|
| A/B 테스트 | `/skill-builder` eval + variance analysis로 skill 변형 비교 |
| PRD → GitHub 이슈 분해 | `/harnesskit:prd`로 PRD를 이슈로 분해 + feature_list.json 연동 |
| Git worktree 세션 격리 | 수동 명령어 + insights 자동 제안 |
| 바이블 가이드라인 | 블로그 + 자료 통합 참조 문서 |

---

## 2. 확장된 Insights 분석 엔진

v1의 5개 분석 차원에 **3개 신규 차원 추가** + **2개 기존 차원 강화**.

### 2.1 신규 분석 차원

| 차원 | 데이터 소스 | 감지 로직 | 출력 |
|------|-----------|----------|------|
| **시간 소모 패턴** | session-logs (작업 유형별 시간 분포) | 동일 작업 유형이 3+세션에서 세션 시간의 30%+ 소모 | `agent_creation` proposal |
| **반복 수동 작업** | session-logs (tool call 시퀀스) | 동일 tool call 시퀀스(3단계+)가 3+세션에서 반복 | `hook_creation` proposal |
| **Plugin 커버리지 갭** | session-logs + installedPlugins + uncoveredAreas | 설치된 plugin이 커버하지 못하는 영역에서 에러/패턴 반복 | `plugin_recommendation` 또는 `skill_creation` proposal |

### 2.2 강화된 기존 차원

| 차원 | v1 동작 | v2a 강화 |
|------|---------|---------|
| **Toolkit 사용량** | 어떤 skill이 참조되는지 확인 | 설치된 marketplace plugin의 효과도 추적 — 에러가 줄지 않으면 → `skill_customization` proposal |
| **에러 패턴** | 반복 감지 → CLAUDE.md 규칙 추가 제안 | marketplace plugin이 해당 영역을 커버하는가? 커버하지만 에러 지속 → `skill_customization`. 커버하지 않음 → `skill_creation` |

### 2.3 데이터 최소 요구량

생성 proposal은 최소 세션 수 미만이면 비활성화:

| 프리셋 | 최소 세션 | 근거 |
|--------|----------|------|
| Beginner | 3 | 빠른 도움 제공 |
| Intermediate | 5 | 균형 |
| Advanced | 8 | 강한 신호만 반응 |

최소 세션 미달 시 v1 수준의 proposal만 생성 (rule_addition, preset_change 등).

> **v1 스펙과의 차이 (Section 1.6)**: v1 스펙은 agent 자동 생성에 "10세션+ 축적"을 명시했다. v2a는 이를 프리셋별로 세분화하여 3/5/8세션으로 조정했다. 근거: 10세션은 모든 사용자에게 동일하게 적용하기에는 과도하며, 초보자는 더 빠른 도움이 필요하고, 고급 사용자는 더 강한 신호를 원한다. v1 스펙의 "10세션"은 v2a의 intermediate(5) + 반복 횟수(3세션) 조합으로 대체된다.

---

## 3. 신규 Proposal 타입

### 3.1 기존 타입 (v1)

`rule_addition`, `pattern_addition`, `skill_customization`, `skill_creation`, `hook_adjustment`, `preset_change`, `plugin_recommendation`

### 3.2 신규 타입 (v2a)

#### `agent_creation`

```
트리거: 시간 소모 패턴 감지
  예: "API 조사"가 3+세션에서 세션 시간의 30%+ 소모

/skill-builder에 전달하는 데이터:
  - detected.json (프로젝트 컨텍스트)
  - 시간 소모 패턴이 나타난 session-logs 발췌
  - 해당 작업의 구체적 설명

타겟: .harnesskit/agents/{name}.md

예시 제안:
  "API 문서 조사에 세션 시간의 35%를 소모하고 있습니다.
   Next.js + Stripe API 전문 researcher agent를 생성할까요?"
```

#### `hook_creation`

```
트리거: 반복 수동 작업 시퀀스 감지
  예: "tsc --noEmit → 타입 수정 → tsc --noEmit" 패턴이 3+세션에서 반복

실행: shell 스크립트 생성 (/skill-builder 사용 안함 — hook은 shell)

타겟: .harnesskit/hooks/{name}.sh + .claude/settings.json 등록

예시 제안:
  "매 수정 후 수동으로 타입체크를 실행하고 있습니다.
   PostToolUse hook으로 자동화할까요?"

  --- (proposed hook script) ---
  + #!/bin/bash
  + # auto-typecheck.sh
  + INPUT=$(cat)
  + TOOL=$(echo "$INPUT" | jq -r '.tool_name')
  + ...
```

#### `review_supplement`

```
트리거: marketplace /review 피드백에서 프로젝트 특화 패턴 반복
  예: "missing error boundary" 피드백이 5+세션에서 반복

/skill-builder에 전달하는 데이터:
  - 반복된 리뷰 피드백 테마
  - CLAUDE.md의 현재 프로젝트 컨벤션
  - detected.json

타겟: .harnesskit/skills/project-review-rules.md

예시 제안:
  "코드 리뷰에서 'error boundary 누락' 피드백이 6세션 연속 반복됩니다.
   프로젝트 전용 리뷰 규칙 skill을 생성하여 marketplace /review를 보완할까요?"
```

#### `review_replace`

```
트리거: 보완 skill이 리뷰 피드백 테마의 80%+ 커버 + 10세션+ 활성 상태

선행 조건: review_supplement이 존재하고 효과 검증 완료

타겟: .harnesskit/skills/code-review.md (전체 대체)

예시 제안:
  "프로젝트 전용 리뷰 skill이 리뷰 피드백의 85%를 커버합니다 (12세션 검증).
   marketplace /review를 제거하고 완전 내재화할까요?"

주의: 내재화 후 품질 저하 감지 시 → marketplace 재설치 제안
```

### 3.3 기존 타입 강화: `plugin_recommendation`

| v1 | v2a |
|----|-----|
| 정적 규칙: "git remote 있음 → /review 추천" | 데이터 기반: "5세션에서 코드 리뷰를 8회 요청했지만 리뷰 plugin 없음 → /review 추천" |
| setup 시점에만 추천 | insights 실행 시마다 분석 |
| detected.json 기반 | session-logs + 사용 패턴 기반 |

---

## 4. Apply 실행 — Proposal 타입별 적용 방법

### 4.1 실행 매트릭스

| Proposal 타입 | 실행 방법 | 검증 |
|--------------|----------|------|
| `agent_creation` | `/skill-builder` 호출 → agent.md 생성 → `.harnesskit/agents/`에 저장 | `/skill-builder` eval 실행 |
| `hook_creation` | shell 스크립트 생성 → `.harnesskit/hooks/`에 저장 → `chmod +x` → `.claude/settings.json` 등록 | mock input으로 dry-run |
| `review_supplement` | `/skill-builder` 호출 → 리뷰 skill 생성 → `.harnesskit/skills/`에 저장 | `/skill-builder` eval 실행 |
| `review_replace` | `/skill-builder` 호출 → 통합 리뷰 skill 생성 → marketplace plugin 제거 확인 | 사용자 확인 필수 |
| `plugin_recommendation` (v2a) | marketplace 설치 명령어 표시 → 승인 시 실행 → `config.json` installedPlugins 업데이트 | plugin 존재 확인 |

### 4.2 Hook 생성 상세

Hook 생성은 `/skill-builder`를 거치지 않는다 (hook은 shell 스크립트):

```
① insights가 반복 tool call 시퀀스 식별
② 해당 패턴을 자동화하는 shell 스크립트 생성
③ proposal에 스크립트 내용 + 등록할 hook 지점 + 이유를 diff로 표시
④ 승인 시:
   ├─ .harnesskit/hooks/{name}.sh에 저장
   ├─ chmod +x
   ├─ .claude/settings.json에 등록:
   │    ├─ Hook 지점 결정 규칙:
   │    │    ├─ "도구 실행 전 검사" 패턴 → PreToolUse
   │    │    ├─ "도구 실행 후 후처리" 패턴 → PostToolUse
   │    │    └─ proposal에 선택한 지점과 근거를 명시
   │    ├─ 기존 hook과의 충돌 검사:
   │    │    ├─ 동일 목적의 hook이 이미 존재하면 → 사용자에게 교체/병존 선택 요청
   │    │    └─ 새 hook은 기존 hook 배열의 끝에 append (기존 순서 보존)
   │    └─ 등록 후 config.json의 customHooks에 기록
⑤ 거절 시: insights-history.json에 기록 (cooldown 적용)
```

### 4.3 코드 리뷰 내재화 생명주기

```
Stage 1: Marketplace Only
  └─ /review 설치됨, 커스텀 skill 없음
  └─ insights가 리뷰 피드백 패턴 추적 시작
       │
       ▼ (5+세션, 동일 피드백 테마 반복)
       │
Stage 2: Supplement (review_supplement 승인)
  └─ /review 여전히 활성
  └─ .harnesskit/skills/project-review-rules.md 생성됨
  └─ CLAUDE.md에 둘 다 참조: marketplace = 범용, 커스텀 = 프로젝트 특화
  └─ insights가 보완 skill의 효과 추적: 반복 피드백이 줄어드는가?
       │
       ▼ (10+세션, 커버리지 80%+)
       │
Stage 3: Replace (review_replace 승인)
  └─ marketplace /review 제거 (config.json의 removedPlugins에 버전 정보 포함 기록)
  └─ .harnesskit/skills/code-review.md가 전체 리뷰 담당
  └─ insights가 계속 모니터링:
       ├─ 품질 저하 감지 기준: replace 후 5세션 내 새로운 에러 패턴 증가 또는
       │   사용자가 수동 리뷰 요청 빈도 증가 (replace 전 대비 50%+)
       └─ 품질 저하 시 → "marketplace /review 재설치 권장" proposal 자동 생성
            (removedPlugins에서 버전 정보 복원)
```

---

## 5. 데이터 스키마 변경

### 5.1 config.json — 신규 필드

```json
{
  "preset": "intermediate",
  "schemaVersion": "2.0",
  "installedPlugins": ["simplify", "review"],
  "uncoveredAreas": ["error-handling", "performance"],
  "reviewInternalization": {
    "stage": "marketplace_only",
    "supplementSince": null,
    "coveragePercent": null
  },
  "customHooks": [],
  "customSkills": [],
  "customAgents": []
}
```

| 필드 | 용도 |
|------|------|
| `uncoveredAreas` | setup 시 marketplace에서 매칭 plugin을 찾지 못한 영역 (아래 5.1.1 분류 체계 참조). insights의 skill_creation 트리거 입력 |
| `reviewInternalization` | 3단계 생명주기 추적 (marketplace_only → supplement → replace) |
| `customHooks` | insights가 생성한 커스텀 hook 목록 |
| `customSkills` | insights가 생성한 커스텀 skill 목록 |
| `customAgents` | insights가 생성한 커스텀 agent 목록 |

#### 5.1.1 uncoveredAreas 분류 체계

영역(area)은 프레임워크 감지 결과에서 파생되는 구조적 분류:

| 영역 | 매칭 기준 | 예시 marketplace plugin |
|------|----------|----------------------|
| `conventions` | 프레임워크 컨벤션/코딩 스타일 | nextjs-conventions plugin |
| `testing` | 테스트 패턴/전략 | testing-patterns plugin |
| `error-handling` | 에러 처리/예외 관리 | - |
| `performance` | 성능 최적화 | - |
| `security` | 보안 패턴 | /security-review |
| `code-review` | 코드 리뷰 | /review, /simplify |
| `deployment` | 배포/CI/CD | - |
| `state-management` | 상태 관리 패턴 | - |

init 시 각 영역에 대해 marketplace를 탐색하고, 매칭 plugin이 없으면 `uncoveredAreas`에 추가. insights가 해당 영역에서 반복 에러를 감지하면 `skill_creation` proposal 트리거.

#### 5.1.2 customHooks/Skills/Agents 항목 스키마

```json
{
  "customSkills": [
    {
      "name": "error-handling",
      "file": ".harnesskit/skills/error-handling.md",
      "createdAt": "2026-03-25",
      "sourceProposal": "ins-003",
      "type": "skill_creation"
    }
  ],
  "customHooks": [
    {
      "name": "auto-typecheck",
      "file": ".harnesskit/hooks/auto-typecheck.sh",
      "hookPoint": "PostToolUse",
      "createdAt": "2026-03-28",
      "sourceProposal": "ins-007"
    }
  ],
  "removedPlugins": [
    {
      "name": "review",
      "removedAt": "2026-04-15",
      "replacedBy": ".harnesskit/skills/code-review.md"
    }
  ]
}
```

#### 5.1.3 리뷰 내재화 커버리지 측정

`review_replace`의 "80% 커버리지" 정의:

```
커버리지 = (보완 skill이 다루는 고유 피드백 테마 수) / (최근 10세션의 전체 고유 피드백 테마 수) × 100

측정 방법:
① 최근 10세션의 pluginUsage.feedbackThemes에서 고유 slug 추출 (정규화 후)
② .harnesskit/skills/project-review-rules.md의 규칙 목록과 대조
③ 대조는 insights 분석 시 Claude가 수행 (의미적 매칭)
④ 결과를 config.json의 reviewInternalization.coveragePercent에 기록
```

### 5.2 session-logs — 확장 필드

```json
{
  "sessionId": "2026-03-20-1430",
  "startedAt": "...",
  "endedAt": "...",
  "currentFeature": "feat-006",
  "filesChanged": ["..."],
  "errors": [{"pattern": "...", "file": "...", "count": 2}],
  "featuresCompleted": [],
  "featuresFailed": [],
  "toolCallSequences": [
    {
      "sequence": ["Bash:tsc --noEmit", "Edit:fix-type", "Bash:tsc --noEmit"],
      "count": 3,
      "context": "type-checking cycle"
    }
  ],
  "taskTimeDistribution": {
    "coding": 0.45,
    "research": 0.30,
    "debugging": 0.15,
    "review": 0.10
  },
  "pluginUsage": {
    "review": {
      "invocations": 2,
      "feedbackThemes": ["missing-error-boundary", "no-loading-state"]
    },
    "simplify": {
      "invocations": 1,
      "feedbackThemes": []
    }
  }
}
```

| 신규 필드 | 용도 | 생성 주체 |
|----------|------|----------|
| `toolCallSequences` | 반복 tool call 패턴 감지 → hook_creation 트리거 | session-end.sh (current-session.jsonl의 tool_call 이벤트에서 추출) |
| `taskTimeDistribution` | 작업 유형별 시간 분포 → agent_creation 트리거 | session-end.sh (tool_call 이벤트 분류에서 추정) |
| `pluginUsage` | marketplace plugin 사용량 + 피드백 → review 내재화 + plugin 효과 추적 | session-end.sh (plugin_invocation 이벤트에서 추출) |

### 5.3 데이터 파이프라인 — 토큰 비용 모델

v2a의 데이터 수집은 **하이브리드 모델**이다:

| 단계 | 주체 | 토큰 비용 | 설명 |
|------|------|----------|------|
| **데이터 생산** | Claude (세션 중) | 소량 (JSONL append) | CLAUDE.md 프로토콜에 따라 tool_call, plugin_invocation 이벤트를 current-session.jsonl에 기록 |
| **데이터 추출** | session-end.sh (Stop hook) | 0 | shell 스크립트로 JSONL 파싱, 패턴 감지, session-log 생성 |
| **데이터 분석** | Claude (insights 실행 시) | 사용자 트리거 시만 | session-logs 읽기 → 분석 → proposal 생성 |

> **v1과의 차이**: v1도 Claude가 error/feature_done/feature_fail을 current-session.jsonl에 기록하므로 동일한 하이브리드 모델이다. v2a는 기록하는 이벤트 종류만 추가한다. JSONL append는 한 줄 쓰기이므로 토큰 소비가 미미하다.

### 5.4 session-end.sh — 신규 책임

v1의 기존 책임 (로그 저장 + failures 기록 + 넛지 감지)에 추가:

| 책임 | 구현 | 토큰 소비 |
|------|------|----------|
| Tool call 시퀀스 감지 | `current-session.jsonl`의 `tool_call` 이벤트 스캔 → 3+번 반복 시퀀스 추출 → `toolCallSequences`에 기록 | 0 |
| 시간 분포 추정 | `tool_call` 이벤트의 tool 유형별 분류 (Bash:test/lint = debugging, WebSearch = research, Edit/Write = coding) → 비율 계산 | 0 |
| Plugin 사용량 추출 | `plugin_invocation` 이벤트 집계 → `pluginUsage`에 기록 | 0 |

추출/분석은 모두 shell 기반, 토큰 0. 데이터 생산(Claude의 JSONL 기록)은 소량 토큰 소비.

### 5.5 current-session.jsonl — 확장 이벤트

v1의 이벤트 (error, feature_done, feature_fail)에 추가:

```jsonl
{"type":"tool_call","tool":"Bash","summary":"tsc --noEmit","timestamp":"14:32"}
{"type":"tool_call","tool":"Edit","summary":"fix type error in auth.ts","timestamp":"14:33"}
{"type":"tool_call","tool":"Bash","summary":"tsc --noEmit","timestamp":"14:35"}
{"type":"plugin_invocation","plugin":"review","feedback":["missing-error-boundary","no-loading-state"]}
```

CLAUDE.md의 세션 프로토콜에 다음 규칙을 추가:

```markdown
## v2a 세션 중 이벤트 기록 (자동)
- 주요 tool 사용 시 `.harnesskit/current-session.jsonl`에 기록:
  {"type":"tool_call","tool":"도구명","summary":"간략 설명","timestamp":"HH:MM"}
  ※ 모든 tool call이 아닌, Bash/Edit/Write/WebSearch 등 주요 도구만 기록
  ※ 한 줄 append이므로 토큰 소비 최소
- marketplace plugin 사용 시:
  {"type":"plugin_invocation","plugin":"플러그인명","feedback":["키워드1","키워드2"]}
- 리뷰 피드백의 키워드는 정규화된 slug 형식 사용:
  소문자, 공백 대신 하이픈, 예: "missing-error-boundary", "no-loading-state"
  ※ 의미적 중복 방지를 위해 기존 feedbackThemes 목록을 참조하여 동일 개념은 동일 slug 사용
```

### 5.6 feedbackThemes 정규화 규칙

리뷰 피드백 테마의 cross-session 비교 정확도를 위한 정규화:

1. **Slug 형식**: 소문자, 공백→하이픈, 특수문자 제거. 예: "Missing Error Boundary" → `missing-error-boundary`
2. **기존 테마 참조**: CLAUDE.md 프로토콜에 "기존 `.harnesskit/session-logs/`의 feedbackThemes를 확인하고, 동일 개념이면 기존 slug 재사용" 규칙 포함
3. **Insights가 정규화 검증**: insights 분석 시 유사 slug 병합 (예: `missing-error-boundary`와 `no-error-boundary`는 동일 테마로 취급). 이 단계는 Claude 기반이므로 의미적 판단 가능

### 5.7 insights-history.json — 스키마 변경 없음

기존 구조가 v2a proposal을 그대로 처리. `type` 필드는 문자열이므로 신규 타입 수용 가능. `status` (accepted/rejected) + `rejectedUntilSession`도 동일하게 작동.

---

## 6. 임계값 설정 및 트리거 규칙

### 6.1 트리거 규칙 매트릭스

| Proposal 타입 | 최소 세션 | 트리거 조건 | 거절 후 쿨다운 |
|--------------|----------|------------|--------------|
| `skill_customization` | 5 | 설치된 plugin 커버 영역에서 동일 에러 3+세션 반복 | 10세션 |
| `skill_creation` | 5 | uncoveredArea에서 동일 에러 3+세션 반복 | 10세션 |
| `agent_creation` | 5 | 동일 작업 유형이 3+세션에서 세션 시간 30%+ 소모 | 15세션 |
| `hook_creation` | 5 | 동일 tool call 시퀀스(3단계+)가 3+세션에서 반복 | 10세션 |
| `review_supplement` | 5 | 동일 리뷰 피드백 테마 5+세션 반복 | 15세션 |
| `review_replace` | supplement 후 10 | 보완 skill이 테마 80%+ 커버 + 10+세션 활성 | 20세션 |
| `plugin_recommendation` (v2a) | 3 | 사용 패턴이 알려진 plugin 카테고리와 매칭, 3+세션 | 10세션 |

### 6.2 프리셋별 임계값 스케일링

| 임계값 | Beginner | Intermediate | Advanced |
|--------|----------|-------------|----------|
| 최소 세션 | 3 | 5 | 8 |
| 패턴 반복 횟수 | 2세션 | 3세션 | 5세션 |
| Agent 시간 소모 % | 25% | 30% | 40% |
| Review replace 대기 | 8세션 | 10세션 | 15세션 |

Beginner는 빠른 도움 (낮은 임계값), Advanced는 강한 신호만 반응 (높은 임계값).

### 6.3 Insights 실행당 최대 proposal 수

v1과 동일하게 **최대 5개**. 초과 시 우선순위로 선별:

| 우선순위 | Proposal 타입 | 근거 |
|---------|--------------|------|
| 1 (최고) | `skill_customization` / `skill_creation` | 에러 직접 감소 |
| 2 | `hook_creation` | 매 세션 시간 절약 |
| 3 | `review_supplement` / `review_replace` | 품질 개선 |
| 4 | `agent_creation` | 생산성 개선 |
| 5 (최저) | `plugin_recommendation` | 생태계 확장 |

5개 초과 proposal은 다음 insights 실행으로 이월.

**동일 우선순위 내 정렬**: 영향받은 세션 수가 많은 순 → 동점 시 에러/반복 횟수가 많은 순.

### 6.4 쿨다운 키 정의

거절 후 쿨다운은 **타입 + 타겟 조합**으로 적용:

| Proposal 타입 | 쿨다운 키 | 예시 |
|--------------|----------|------|
| `skill_customization` | type + 대상 plugin명 | `skill_customization:nextjs-conventions` |
| `skill_creation` | type + 대상 영역명 | `skill_creation:error-handling` |
| `agent_creation` | type + 대상 작업 유형 | `agent_creation:api-research` |
| `hook_creation` | type + 대상 시퀀스 요약 | `hook_creation:typecheck-cycle` |
| `review_supplement` | type (단일 대상) | `review_supplement` |
| `review_replace` | type (단일 대상) | `review_replace` |
| `plugin_recommendation` | type + 추천 plugin명 | `plugin_recommendation:security-review` |

동일 키가 아닌 같은 타입의 다른 타겟은 쿨다운 영향 없음. 예: `agent_creation:api-research` 거절이 `agent_creation:debugging` 제안을 차단하지 않는다.

---

## 7. 파일 변경 요약

### 7.1 수정 파일

| 파일 | 변경 내용 |
|------|----------|
| `harnesskit/skills/insights.md` | 3개 신규 분석 차원, 4개 신규 proposal 타입, 임계값 규칙, 우선순위 정렬, plugin_recommendation 강화 |
| `harnesskit/skills/apply.md` | `agent_creation`, `hook_creation`, `review_supplement`, `review_replace` 실행 경로 추가. `/skill-builder` 위임 (agent, review skill). hook 스크립트 생성 + 등록 |
| `harnesskit/skills/status.md` | 리뷰 내재화 단계, 커스텀 skills/agents/hooks 수, uncoveredAreas 표시 |
| `harnesskit/skills/init.md` | `config.json`에 v2a 필드 초기화 (`uncoveredAreas`, `reviewInternalization`, `customHooks/Skills/Agents`), `schemaVersion: "2.0"` |
| `harnesskit/hooks/session-end.sh` | tool call 시퀀스 감지, 시간 분포 추정, plugin 사용량 추출 추가 |
| `harnesskit/templates/claude-md/base.md` | 세션 프로토콜에 plugin 사용 + 리뷰 피드백 로깅 규칙 추가 |

### 7.2 신규 파일

없음. v2a는 기존 파일만 확장한다. 커스텀 skills, agents, hooks는 런타임에 사용자 프로젝트의 `.harnesskit/`에 생성 — 플러그인 자체에는 포함되지 않는다.

### 7.3 변경 없는 파일

| 파일 | 이유 |
|------|------|
| `plugin.json` | 신규 skill/agent 추가 없음 |
| `harnesskit/hooks/guardrails.sh` | 신규 가드레일 규칙 없음 |
| `harnesskit/hooks/session-start.sh` | 커스텀 agent/skill 브리핑 언급은 nice-to-have, 핵심 아님 |
| `harnesskit/templates/presets/*.json` | 임계값 설정은 insights skill 로직에 포함, 프리셋 파일에는 없음 |

### 7.4 마이그레이션

v1 데이터가 있는 프로젝트에 v2a 배포 시:

**감지**: `session-start.sh`가 `config.json`의 `schemaVersion` 확인:
- 필드 없음 또는 `"1.0"` → v1 프로젝트로 판단
- `"2.0"` → v2a 프로젝트, 정상 진행

**마이그레이션 모드**: v1 감지 시 `/harnesskit:setup --migrate` 안내 (기존 reset mode와 별도):
```
setup --migrate 실행:
① 기존 config.json 읽기
② 신규 필드 추가 (비파괴적):
   ├─ schemaVersion: "2.0"
   ├─ uncoveredAreas: [] (다음 insights에서 분석)
   ├─ reviewInternalization: {stage: "marketplace_only", ...}
   ├─ customHooks: []
   ├─ customSkills: []
   └─ customAgents: []
③ base.md 세션 프로토콜 업데이트 (v2a 이벤트 로깅 규칙 추가)
④ 기존 데이터 보존: session-logs, failures, insights-history 모두 유지
```

**하위 호환**: 기존 session-logs에 v2a 필드(toolCallSequences 등)가 없어도 insights는 null로 처리. 분석 차원에서 해당 데이터가 없으면 해당 proposal 타입을 건너뛴다.

---

## 8. 테스트 전략

### 8.1 session-end.sh 확장 테스트

| 테스트 | 검증 내용 |
|--------|----------|
| tool call 시퀀스 감지 | current-session.jsonl에 tool_sequence 이벤트 포함 시 → session-log에 toolCallSequences 기록 |
| 시간 분포 추정 | 다양한 tool call 유형 → taskTimeDistribution 비율 합 = 1.0 |
| plugin 사용량 추출 | plugin_invocation 이벤트 포함 시 → session-log에 pluginUsage 기록 |
| 이벤트 없는 세션 | 신규 이벤트 없으면 → 해당 필드 빈 객체/배열 (null 아님) |
| v1 하위 호환 | 신규 필드 없는 current-session.jsonl → 정상 처리 (에러 없음) |

### 8.2 insights 분석 테스트

Insights는 Claude 기반이므로 shell 단위 테스트가 아닌 **fixture 기반 검증**:

| 테스트 | 검증 내용 |
|--------|----------|
| 최소 세션 미달 | 3세션 데이터 + intermediate 프리셋 → 생성 proposal 없음 |
| skill_customization 트리거 | 5세션 동일 에러 + plugin 설치됨 → skill_customization proposal |
| agent_creation 트리거 | 5세션 research 35% → agent_creation proposal |
| hook_creation 트리거 | 5세션 동일 시퀀스 → hook_creation proposal |
| 우선순위 정렬 | 6개 proposal 자격 → 상위 5개만 출력, 우선순위 순 |
| 거절 쿨다운 | 이전에 거절된 동일 타입+타겟 → 쿨다운 내 재제안 안함 |

### 8.3 apply 실행 테스트

| 테스트 | 검증 내용 |
|--------|----------|
| hook_creation 적용 | 승인 → .harnesskit/hooks/ 파일 생성 + chmod +x + settings.json 등록 |
| review_replace 거부 | marketplace plugin 유지, config 변경 없음 |
| config.json 업데이트 | 각 proposal 적용 후 customHooks/Skills/Agents 배열 업데이트 |
