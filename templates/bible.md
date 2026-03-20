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
