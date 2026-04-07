# Orchestrator Templates — Reference Guide

> 프로그레시브 디스클로저: /harnesskit:architect에서 패턴 선택 후 로드됩니다.

각 템플릿은 오케스트레이터 에이전트 파일의 마크다운 구조를 보여줍니다.
에이전트 파일 프론트매터, 워크플로 단계, 에러 핸들링, 에이전트 간 데이터 포맷을 포함합니다.

---

## 1. Pipeline Orchestrator Template

순차 스테이지 실행 — 각 단계의 출력이 다음 단계의 입력이 됩니다.

```markdown
---
name: pipeline-orchestrator
description: 순차 파이프라인 오케스트레이터 — N개 스테이지를 직렬 실행
---

## Role
각 스테이지를 순서대로 실행하고 데이터를 다음 스테이지로 전달합니다.

## Workflow

### Stage 1 — Input Validation
- Agent: validator-agent
- Input: raw user request
- Output: validated_input.json
- On error: STOP, report validation failure

### Stage 2 — Processing
- Agent: processor-agent
- Input: validated_input.json
- Output: processed_result.json
- On error: retry once, then STOP

### Stage 3 — Output Formatting
- Agent: formatter-agent
- Input: processed_result.json
- Output: final_output.md
- On error: use raw processed_result as fallback

## Error Handling
- 스테이지 실패 시 즉시 파이프라인 중단
- 실패한 스테이지 ID와 에러 메시지를 pipeline_error.json에 기록
- 부분 완료된 결과물은 partial/ 디렉토리에 보존

## Data Format
```json
{
  "stage": "stage-id",
  "status": "success | error | skipped",
  "output_path": "path/to/output.json",
  "error": null
}
```
```

---

## 2. Fan-out / Fan-in Orchestrator Template

병렬 분산 후 결과 병합 — 독립 작업을 동시 실행합니다.

```markdown
---
name: fanout-orchestrator
description: 팬아웃/팬인 오케스트레이터 — 작업을 병렬 분산하고 결과를 병합
---

## Role
작업을 독립 청크로 분할하여 병렬 실행하고, 완료 후 결과를 단일 출력으로 병합합니다.

## Workflow

### Dispatch Phase — Fan-out
- 입력을 N개의 독립 청크로 분할
- 각 청크를 worker-agent에 동시 디스패치
- 각 작업에 고유 task_id 부여

### Collection Phase — Fan-in
- 모든 worker 완료 대기 (또는 timeout 초과 시 부분 결과 수용)
- 결과를 task_id 순으로 수집
- merge-agent를 통해 최종 결과 병합

## Error Handling
- 개별 worker 실패 시 해당 청크만 재시도 (최대 2회)
- 전체 실패율 > 30%이면 전체 작업 중단
- 부분 성공 허용 여부는 `allow_partial: true/false`로 설정

## Data Format
```json
{
  "task_id": "chunk-001",
  "worker": "worker-agent",
  "status": "success | error | timeout",
  "result": {},
  "retry_count": 0
}
```
```

---

## 3. Expert Pool Orchestrator Template

라우터 + 전문가 레지스트리 — 요청 유형에 따라 전문가를 선택합니다.

```markdown
---
name: expert-pool-orchestrator
description: 전문가 풀 오케스트레이터 — 요청을 분류하고 적합한 전문가에게 라우팅
---

## Role
들어오는 요청을 분석하여 전문가 레지스트리에서 최적 에이전트를 선택하고 위임합니다.

## Expert Registry

| Expert Agent     | 전문 분야          | 트리거 키워드                  |
|------------------|--------------------|-------------------------------|
| code-expert      | 코드 리뷰 / 디버깅 | bug, refactor, performance     |
| design-expert    | UI/UX 설계         | layout, component, design      |
| data-expert      | 데이터 분석        | query, dataset, visualization  |
| security-expert  | 보안 감사          | auth, vulnerability, CVE       |
| docs-expert      | 문서 작성          | readme, spec, document         |

## Workflow

### Step 1 — Classification
- router-agent가 요청 분석
- 전문가 레지스트리에서 매칭 전문가 선택
- 신뢰도 점수 계산 (0.0 – 1.0)

### Step 2 — Delegation
- 신뢰도 >= 0.7: 단일 전문가에게 위임
- 신뢰도 < 0.7: 상위 2개 전문가에게 동시 위임 후 결과 비교

### Step 3 — Response Synthesis
- 단일 전문가: 결과 직접 반환
- 다중 전문가: synthesizer-agent가 결과 통합

## Error Handling
- 전문가 미매칭 시 general-agent로 폴백
- 전문가 타임아웃 시 next-best 전문가로 재위임

## Data Format
```json
{
  "request_id": "req-001",
  "selected_expert": "code-expert",
  "confidence": 0.92,
  "fallback_expert": "general-agent",
  "result": {}
}
```
```

---

## 4. Producer-Reviewer Orchestrator Template

반복 생성 + 품질 임계값 — 기준을 충족할 때까지 생성-검토 루프를 실행합니다.

```markdown
---
name: producer-reviewer-orchestrator
description: 생산자-검토자 오케스트레이터 — 품질 임계값을 충족할 때까지 반복 생성
---

## Role
producer-agent가 결과물을 생성하고, reviewer-agent가 품질을 평가합니다.
기준 미충족 시 피드백과 함께 재생성을 요청합니다.

## Workflow

### Iteration Loop
1. producer-agent: 요청 기반 초안 생성
2. reviewer-agent: 품질 점수 산출 (0–100)
3. 점수 >= threshold: 루프 종료, 결과 반환
4. 점수 < threshold: 피드백 생성 → 1번으로 돌아감
5. max_iterations 도달 시: 최고 점수 결과물 반환

## Configuration
- `quality_threshold`: 70 (기본값, 0–100)
- `max_iterations`: 3 (기본값)
- `feedback_detail`: "brief | detailed" (기본값: brief)

## Error Handling
- reviewer 연속 실패 2회: 현재 최선 결과물 반환
- producer 실패: 직전 성공 결과물 유지

## Data Format
```json
{
  "iteration": 2,
  "draft": "생성된 내용",
  "quality_score": 65,
  "threshold": 70,
  "feedback": "구체적인 개선 사항",
  "status": "retry | accepted | max_reached"
}
```
```

---

## 5. Supervisor Orchestrator Template

동적 작업 할당 및 모니터링 — 작업 상태를 추적하며 에이전트를 지휘합니다.

```markdown
---
name: supervisor-orchestrator
description: 슈퍼바이저 오케스트레이터 — 에이전트 풀을 동적으로 관리하고 작업을 재할당
---

## Role
작업 큐를 유지하고 에이전트 가용성에 따라 작업을 할당합니다.
실패한 작업을 자동으로 다른 에이전트에게 재할당합니다.

## Workflow

### Initialization
- 작업 큐 로드 (task_queue.json)
- 가용 에이전트 풀 등록

### Monitoring Loop
1. 가용 에이전트 확인
2. 큐에서 우선순위 높은 작업 선택
3. 에이전트에 작업 할당
4. 상태 모니터링 (heartbeat 30초 간격)
5. 완료 시 큐에서 제거, 실패 시 재할당

### Completion
- 모든 작업 완료 시 final_report.json 생성

## Agent Pool Configuration
- `min_agents`: 2
- `max_agents`: 8
- `heartbeat_interval_sec`: 30
- `task_timeout_sec`: 300

## Error Handling
- heartbeat 미응답 에이전트: dead로 마킹, 작업 재할당
- 동일 작업 3회 실패: BLOCKED로 마킹, 수동 개입 요청

## Data Format
```json
{
  "task_id": "task-007",
  "assigned_agent": "worker-3",
  "status": "pending | running | done | failed | blocked",
  "assigned_at": "HH:MM:SS",
  "retry_count": 0
}
```
```

---

## 6. Hierarchical Delegation Template

재귀적 분해 + 깊이 제한 — 복잡한 목표를 하위 목표로 반복 분해합니다.

```markdown
---
name: hierarchical-orchestrator
description: 계층적 위임 오케스트레이터 — 목표를 재귀적으로 분해하여 하위 에이전트에 위임
---

## Role
최상위 목표를 받아 실행 가능한 단위로 재귀 분해합니다.
각 레이어는 독립적으로 오케스트레이터 역할을 수행합니다.

## Workflow

### Decomposition (Layer 0 — Root)
1. 목표를 2–5개의 하위 목표로 분해
2. 각 하위 목표에 sub-orchestrator 할당
3. depth 카운터 증가

### Recursion (Layer 1–N)
- 하위 목표가 단일 에이전트로 실행 가능하면: 직접 실행
- 추가 분해가 필요하면: 재귀 호출 (depth < max_depth)
- depth == max_depth: 강제 실행 (분해 중단)

### Aggregation
- 리프 노드부터 결과 수집
- 각 레이어에서 하위 결과 집계
- 루트에서 최종 결과 조합

## Configuration
- `max_depth`: 3 (기본값, 과도한 재귀 방지)
- `min_subtask_size`: "단일 에이전트가 30분 내 완료 가능한 단위"

## Error Handling
- 하위 목표 실패 시 부모 레이어에 에러 버블링
- 부분 실패 허용 여부: `allow_partial_hierarchy: true/false`

## Data Format
```json
{
  "node_id": "node-1-2",
  "depth": 2,
  "goal": "하위 목표 설명",
  "children": ["node-1-2-1", "node-1-2-2"],
  "status": "pending | running | done | failed",
  "result": {}
}
```
```

---

## 7. CLAUDE.md Registration Template

에이전트 팀을 CLAUDE.md에 등록하는 방법입니다.

```markdown
## Agent Team: [팀 이름]

### Orchestrator
- File: `agents/[team-name]/orchestrator.md`
- Pattern: [pipeline | fanout | expert-pool | producer-reviewer | supervisor | hierarchical]
- Trigger: [이 팀이 활성화되는 조건]

### Worker Agents
| Agent File                              | 역할          | 입출력 포맷        |
|-----------------------------------------|---------------|--------------------|
| `agents/[team-name]/worker-a.md`        | [역할 설명]   | JSON → Markdown    |
| `agents/[team-name]/worker-b.md`        | [역할 설명]   | JSON → JSON        |

### Shared Context
- Shared file: `agents/[team-name]/context.json`
- Access: read-only for workers, read-write for orchestrator

### Invocation
```
Task: [작업 설명]
Read agents/[team-name]/orchestrator.md and execute the workflow.
```

### Notes
- 에이전트 파일은 각각 독립적으로 읽을 수 있어야 합니다
- 오케스트레이터는 워커를 Task 도구로 호출합니다
- 공유 상태는 JSON 파일을 통해서만 전달합니다
```

---

> 이 문서는 `/harnesskit:architect` 스킬에 의해 로드됩니다.
> 패턴 선택 → 템플릿 복사 → `agents/` 디렉토리에 저장하여 사용하세요.
