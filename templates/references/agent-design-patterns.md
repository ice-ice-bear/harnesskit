# Agent Design Patterns — Reference Guide

> 프로그레시브 디스클로저: 이 문서는 /harnesskit:architect 스킬에서 필요 시 로드됩니다.
> Progressive disclosure: This document is loaded on-demand by /harnesskit:architect.

---

## Execution Mode Selection

### Agent Teams vs Sub-agents 비교

| 기준 | Agent Teams | Sub-agents |
|------|-------------|------------|
| 실행 방식 | 병렬 독립 실행 | 순차적 위임 |
| 컨텍스트 공유 | 최소화 (격리) | 오케스트레이터가 전달 |
| 적합한 작업 | 독립적 병렬 처리 | 단계별 의존 작업 |
| 오류 격리 | 에이전트 단위 | 체인 전체 영향 |
| 비용 | 높음 (병렬) | 낮음 (순차) |
| 속도 | 빠름 | 느림 |

### 결정 트리 (Decision Tree)

```
작업이 독립적으로 분리 가능한가?
├── YES → 병렬 처리가 필요한가?
│         ├── YES → Agent Teams (Fan-out/Fan-in, Expert Pool)
│         └── NO  → Sub-agents (Pipeline)
└── NO  → 단계 간 의존성이 강한가?
          ├── YES → Sub-agents (Pipeline, Producer-Reviewer)
          └── NO  → 단일 에이전트 + 도구 조합 고려
```

---

## Orchestration Patterns

### 1. Pipeline (파이프라인)

**설명**: 작업이 단계별로 순서대로 처리됩니다. 각 에이전트는 이전 단계의 출력을 입력으로 받습니다.

**ASCII 다이어그램**:
```
[Input] → [Agent A] → [Agent B] → [Agent C] → [Output]
           (수집)      (분석)      (보고서)
```

**사용 사례**:
- 데이터 수집 → 정제 → 분석 → 보고서 생성
- 코드 작성 → 테스트 → 문서화
- 콘텐츠 초안 → 편집 → 최종 출력

**에이전트 정의 예시**:
```markdown
---
name: pipeline-collector
description: 원본 데이터를 수집하여 다음 단계로 전달합니다
tools: WebSearch, Read
---
주어진 주제에 대한 원시 데이터를 수집하고 구조화된 형식으로 출력하세요.
다음 에이전트(pipeline-analyst)가 처리할 수 있도록 JSON 형식으로 반환하세요.
```

---

### 2. Fan-out / Fan-in (팬아웃/팬인)

**설명**: 하나의 오케스트레이터가 작업을 여러 에이전트에게 병렬로 분배하고, 결과를 수집하여 통합합니다.

**ASCII 다이어그램**:
```
                ┌─→ [Agent A] ─┐
[Orchestrator] ─┼─→ [Agent B] ─┼─→ [Aggregator] → [Output]
                └─→ [Agent C] ─┘
```

**사용 사례**:
- 여러 소스에서 동시 데이터 수집
- 코드베이스의 여러 모듈 동시 분석
- 다국어 콘텐츠 동시 번역

**에이전트 정의 예시**:
```markdown
---
name: fanout-aggregator
description: 병렬 에이전트 결과를 수집하고 통합합니다
tools: Read, Edit
---
각 서브에이전트의 출력을 받아 중복을 제거하고 일관된 보고서로 통합하세요.
충돌하는 정보는 신뢰도 순으로 정렬하여 표시하세요.
```

---

### 3. Expert Pool (전문가 풀)

**설명**: 각 에이전트가 특정 도메인 전문성을 가지며, 라우터가 작업 유형에 따라 적절한 전문가에게 위임합니다.

**ASCII 다이어그램**:
```
             ┌─→ [Security Expert]
[Router] ────┼─→ [Performance Expert]
             ├─→ [Architecture Expert]
             └─→ [Testing Expert]
```

**사용 사례**:
- 코드 리뷰 (보안/성능/아키텍처 전문가 분리)
- 기술 지원 (분야별 전문가 라우팅)
- 문서 작성 (API/튜토리얼/레퍼런스 전문가)

**에이전트 정의 예시**:
```markdown
---
name: security-expert
description: 보안 취약점 분석 전문가 — 인증, 권한, 입력 검증에 집중
tools: Read, Grep
---
코드에서 OWASP Top 10 취약점을 식별하세요.
각 발견 사항을 심각도(Critical/High/Medium/Low)와 함께 보고하세요.
```

---

### 4. Producer-Reviewer (생성-검증)

**설명**: 생성자 에이전트가 산출물을 만들고, 검토자 에이전트가 독립적으로 검증합니다. 필요 시 반복합니다.

**ASCII 다이어그램**:
```
[Producer] → [산출물] → [Reviewer]
     ↑                      │
     └──── [피드백] ─────────┘
              (통과 시 → Output)
```

**사용 사례**:
- 코드 생성 + 코드 리뷰
- 기사 작성 + 팩트체크
- 테스트 케이스 작성 + 커버리지 검증

**에이전트 정의 예시**:
```markdown
---
name: code-reviewer
description: 생성된 코드를 독립적으로 검토하고 피드백을 제공합니다
tools: Read, Bash
---
제공된 코드를 검토하세요. 다음 기준을 확인하세요:
1. 명시된 요구사항 충족 여부
2. 엣지 케이스 처리
3. 코드 스타일 준수
통과 여부를 PASS/FAIL로 명시하고, FAIL 시 구체적 수정 사항을 제시하세요.
```

---

### 5. Supervisor (감독자)

**설명**: 감독자 에이전트가 워커 에이전트들의 진행 상황을 모니터링하고 동적으로 조율합니다. 중간 결과에 따라 다음 단계를 결정합니다.

**ASCII 다이어그램**:
```
              [Supervisor]
             /      |      \
      [Worker A] [Worker B] [Worker C]
          ↓           ↓          ↓
      [결과 A]    [결과 B]   [결과 C]
             \      |      /
              [Supervisor]
            (평가 후 재지시)
```

**사용 사례**:
- 복잡한 연구 작업 (방향 동적 조정)
- 장기 실행 프로젝트 관리
- 불확실한 도메인 탐색

**에이전트 정의 예시**:
```markdown
---
name: research-supervisor
description: 연구 작업을 감독하고 워커 에이전트에 동적으로 지시합니다
tools: Read, Write, Task
---
워커 에이전트의 중간 결과를 평가하세요.
목표 달성에 부족한 부분이 있으면 추가 조사를 지시하세요.
모든 필요 정보가 수집되면 최종 보고서 작성을 지시하세요.
```

---

### 6. Hierarchical Delegation (계층적 위임)

**설명**: 여러 계층의 에이전트가 있으며, 상위 에이전트가 하위 에이전트에게 점진적으로 세부 작업을 위임합니다.

**ASCII 다이어그램**:
```
[L1: Strategist]
    │
    ├─→ [L2: Team Lead A] ──→ [L3: Worker A1]
    │                    └──→ [L3: Worker A2]
    │
    └─→ [L2: Team Lead B] ──→ [L3: Worker B1]
                         └──→ [L3: Worker B2]
```

**사용 사례**:
- 대규모 소프트웨어 개발 (아키텍처 → 모듈 → 구현)
- 조직 구조를 반영한 복잡한 문서 생성
- 멀티-도메인 연구 프로젝트

**에이전트 정의 예시**:
```markdown
---
name: team-lead-frontend
description: 프론트엔드 팀 리드 — UI 컴포넌트 구현을 워커에게 위임합니다
tools: Read, Write, Task
---
Strategist로부터 받은 UI 요구사항을 컴포넌트 단위로 분해하세요.
각 컴포넌트를 적절한 워커 에이전트에게 위임하고 결과를 통합하세요.
```

---

## Agent Definition Structure

`.claude/agents/{name}.md` 파일 템플릿:

```markdown
---
name: agent-name
description: >
  에이전트의 역할과 언제 사용하는지 설명 (1-2줄).
  오케스트레이터가 라우팅 결정에 사용하는 핵심 키워드 포함.
tools: Read, Grep, Bash
# 필요한 도구만 명시 — 최소 권한 원칙
---

## 역할

이 에이전트가 수행하는 작업을 명확히 정의합니다.

## 입력 형식

오케스트레이터로부터 받을 입력의 예상 형식을 정의합니다.

## 출력 형식

다음 에이전트 또는 오케스트레이터에게 전달할 출력 형식을 정의합니다.

## 제약 조건

- 이 에이전트가 하지 말아야 할 작업
- 범위를 벗어난 요청은 오케스트레이터에게 반환
```

---

## Agent Separation Criteria

### 분리해야 할 때 (Split)

- 도구 집합이 명확히 다를 때 (읽기 전용 vs 쓰기 권한)
- 컨텍스트 오염을 방지해야 할 때 (보안 검토 vs 기능 구현)
- 병렬 실행으로 속도를 높일 수 있을 때
- 에이전트 재사용이 여러 워크플로우에서 필요할 때
- 책임 경계가 명확할 때 (단일 책임 원칙)

### 통합해야 할 때 (Consolidate)

- 두 에이전트가 항상 같이 실행될 때
- 컨텍스트 전달 오버헤드가 실제 작업보다 클 때
- 에이전트 수가 3개 미만이고 작업이 단순할 때
- 단일 도메인 내의 연속적인 작업일 때

---

## Skill vs Agent Distinction

| 기준 | Skill (`skills/*/SKILL.md`) | Agent (`.claude/agents/*.md`) |
|------|------------------------------|-------------------------------|
| 실행 주체 | 현재 Claude 세션 | 별도 격리 컨텍스트 |
| 컨텍스트 | 대화 히스토리 공유 | 독립 컨텍스트 |
| 상태 | 세션 내 지속 | 호출마다 초기화 |
| 적합한 용도 | 사용자 인터랙션, UI | 백그라운드 처리, 병렬 작업 |
| 오버헤드 | 낮음 | 높음 (컨텍스트 생성 비용) |
| 재사용성 | 대화 기반 재사용 | 워크플로우 기반 재사용 |
| 예시 | `/harnesskit:test`, `/commit` | `code-reviewer`, `data-collector` |

**경험칙**: 사용자와 직접 대화하는 흐름이면 Skill. 백그라운드에서 독립 작업을 수행하면 Agent.
