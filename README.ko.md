<div align="center">

# HarnessKit

**바이브 코더를 위한 적응형 하네스 — 감지, 설정, 관찰, 개선**

[![Version](https://img.shields.io/badge/version-0.2.0-blue)]()
[![Tests](https://img.shields.io/badge/tests-89%20passing-green)]()
[![License](https://img.shields.io/badge/license-MIT-yellow)]()

English | [한국어](README.ko.md)

</div>

---

## 개요

HarnessKit은 [Claude Code](https://docs.anthropic.com/en/docs/claude-code) 플러그인으로, 개발 워크플로를 적응형 하네스로 감싸줍니다. 스택을 자동 감지하고, 숙련도에 맞는 가드레일을 적용하며, 세션을 관찰하고, 스스로를 지속적으로 개선합니다 — 컨텍스트 토큰을 낭비하지 않으면서.

```
┌─────────────────────────────────────────────────┐
│                  HarnessKit                      │
│                                                  │
│    감지 ──▶  설정 ──▶  관찰 ──▶  개선             │
│     │         │         │         │              │
│   언어     프리셋     세션      인사이트           │
│  프레임워크  가드레일   훅       제안               │
│   도구      브리핑    메트릭    자동 적용           │
│                                                  │
│        제로 토큰 셸 훅                            │
│        ── bash + jq, LLM 비용 없음 ──            │
└─────────────────────────────────────────────────┘
```

## 주요 기능

| 단계 | 기능 | 방식 |
|------|------|------|
| **감지** | 레포의 언어, 프레임워크, 테스트 프레임워크, 린터, 패키지 매니저 자동 감지 | 제로 토큰 셸 스크립트 — LLM 호출 없음 |
| **설정** | 3가지 프리셋 중 하나 적용 (초급 / 중급 / 고급) | 가드레일 강도, 브리핑 상세도, 개발 훅 제어 |
| **관찰** | 세션별 에러, 도구 사용량, 플러그인 효과 추적 | 셸 기반 훅 (session-start, guardrails, session-end) |
| **개선** | 세션 데이터 분석, 스킬/에이전트/훅/규칙 개선안 제안 | `/harnesskit:insights`로 분석, `/harnesskit:apply`로 실행 |

## 설치

```bash
/plugin marketplace add ice-ice-bear/harnesskit
/plugin install harnesskit@harnesskit
```

## 빠른 시작

```bash
# 1. 레포에 하네스 초기화
/harnesskit:setup

# 2. 평소처럼 코딩 — 훅이 자동으로 세션을 관찰합니다

# 3. 몇 세션 후, 인사이트 확인
/harnesskit:insights

# 4. 추천 개선안 적용
/harnesskit:apply
```

이게 전부입니다. HarnessKit은 시간이 지나면서 워크플로에 적응합니다.

## 명령어

HarnessKit은 슬래시 명령어로 사용할 수 있는 11개의 스킬을 제공합니다:

| 명령어 | 설명 |
|--------|------|
| `/harnesskit:setup` | 하네스 초기화 — 스택 감지, 프리셋 선택, 설정 생성 |
| `/harnesskit:insights` | 세션 데이터 분석, 개선안 제안 |
| `/harnesskit:apply` | 제안 검토 및 적용 (A/B 평가 옵션) |
| `/harnesskit:status` | 하네스 상태, 메트릭, 커버리지 대시보드 |
| `/harnesskit:test` | 테스트 실행 + 실패 추적 및 에러 분류 |
| `/harnesskit:lint` | 설정된 린터 실행 |
| `/harnesskit:typecheck` | TypeScript 타입 체크 |
| `/harnesskit:dev` | 개발 서버 시작 |
| `/harnesskit:prd` | PRD를 GitHub 이슈 + 기능 목록으로 분해 |
| `/harnesskit:worktree` | 하네스 인식 워크트리로 기능별 격리 작업 |

> **참고**: `setup`은 내부적으로 `init`을 호출하여 감지와 파일 생성을 처리합니다. 11번째 스킬(`init`)은 setup의 일부로 실행되며 직접 호출하지 않습니다.

## 프리셋

`/harnesskit:setup` 실행 시 숙련도에 맞는 프리셋을 선택합니다:

| | 초급 | 중급 | 고급 |
|---|---|---|---|
| **가드레일** | 엄격 — 위험한 작업 전 확인, 커밋 전 테스트 강제 | 보통 — 경고만, 안전한 작업은 확인 생략 | 최소 — 개발자를 신뢰 |
| **브리핑** | 상세 — 각 훅이 하는 일을 설명 | 표준 — 간결한 요약 | 무음 — 에러가 아니면 브리핑 없음 |
| **세션 훅** | 전체 활성화 + 상세 로깅 | 전체 활성화, 간결한 로깅 | 선택적 — 에러 추적만 |
| **자동 적용** | 끔 — 변경 전 항상 확인 | 제안 — 차이점 표시, 원클릭 적용 | 자동 — 저위험 개선안 자동 적용 |
| **적합한 사용자** | AI 보조 코딩 입문자 | 일반 Claude Code 사용자 | 파워 유저, 바이브 코더 |

## 아키텍처

### 설계 원칙

- **마켓플레이스 우선**: 커스텀 도구를 만들기 전에 기존 Claude Code 플러그인을 먼저 사용합니다. 세션 데이터에서 갭이 확인될 때만 커스터마이즈합니다.
- **제로 토큰 훅**: 모든 관찰 훅(`session-start`, `guardrails`, `session-end`)은 bash + jq 스크립트로 실행됩니다. LLM 토큰 비용이 없습니다.
- **바이블**: 모든 스킬이 일관성을 위해 참조하는, 엄선된 하네스 엔지니어링 원칙 모음입니다.

### 서브시스템

| 서브시스템 | 목적 |
|-----------|------|
| **v2a** — 적응형 생성 | 세션 데이터에서 스킬, 에이전트, 훅, 규칙을 자동 생성합니다. `insights` → `apply` 루프를 구동합니다. |
| **v2b** — 고급 워크플로 | 제안에 대한 A/B 테스트, PRD의 이슈 분해, 하네스 인식 워크트리 격리. |

### 플러그인 구조

```
HarnessKit/
├── .claude-plugin/
│   ├── plugin.json        # 플러그인 매니페스트 (v0.2.0)
│   └── marketplace.json   # 마켓플레이스 카탈로그
├── skills/                # 11개 스킬 정의
├── agents/                # 오케스트레이터 에이전트
├── hooks/                 # 세션 훅 (bash + jq)
├── scripts/               # 감지 및 유틸리티 스크립트
├── templates/             # 설정 템플릿, 프리셋, 바이블
├── tests/                 # 8개 스위트, 89개 테스트
├── docs/                  # 설계 명세, 계획, 리서치
├── README.md
├── README.ko.md
└── LICENSE
```

## 생성 파일

`/harnesskit:setup` 실행 시 프로젝트에 다음 파일들이 생성됩니다:

| 파일 | 목적 |
|------|------|
| `CLAUDE.md` | 세션 프로토콜 + 프레임워크 규칙 (템플릿에서 구성) |
| `.claudeignore` | 언어별 컨텍스트 제외 패턴 |
| `.claude/settings.json` | 훅 등록 (session-start, guardrails, session-end) |
| `docs/feature_list.json` | 기능 추적 (`passes: false` 패턴) |
| `progress/claude-progress.txt` | 세션 간 작업 연속성 |
| `.harnesskit/config.json` | 프리셋, 스키마 버전, 설치된 플러그인, 커스텀 툴킷 |
| `.harnesskit/detected.json` | 자동 감지된 레포 속성 |
| `.harnesskit/failures.json` | 세션 간 에러 패턴 추적 |
| `.harnesskit/session-logs/` | 세션별 관찰 데이터 (도구 사용량, 시간 분포) |
| `.harnesskit/bible.md` | 엄선된 하네스 엔지니어링 원칙 참조 문서 |

모든 생성 파일은 선택한 프리셋에 맞게 조정됩니다.

## 개선 루프 작동 방식

```
세션이 데이터를 축적
        │
        ▼
/harnesskit:insights
  ├── 분석: 에러, 도구 사용량, 시간 소모, 커버리지 갭
  ├── 제안: 새 스킬, 에이전트, 훅, 규칙 또는 설정 변경
  └── 분류: skill_creation, hook_creation, review_supplement, ...
        │
        ▼
/harnesskit:apply
  ├── 각 제안을 차이점 미리보기와 함께 표시
  ├── 옵션: 수락 / 거절 / A/B 테스트
  └── 실행: 파일 생성, 설정 업데이트
        │
        ▼
다음 세션이 개선사항의 혜택을 받음
```

## 기여

기여를 환영합니다.

```bash
# 클론
git clone https://github.com/ice-ice-bear/harnesskit.git
cd harnesskit

# 전체 테스트 실행 (8개 스위트, 89개 테스트)
for t in tests/test-*.sh; do bash "$t"; done
```

큰 변경사항은 PR 전에 이슈를 먼저 열어주세요.

## 라이선스

[MIT](LICENSE) — Copyright 2026 HarnessKit Contributors
