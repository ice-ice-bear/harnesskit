# HarnessKit Plugin Trigger Review — 5 Fixes

> 플러그인 트리거링, 마켓플레이스 발견, 프리셋 제어, 데이터 수집, 상태 검증의 5개 개선 사항

## Background

플러그인 구조 검토 결과 5개 핵심 갭이 발견됨:
1. hooks의 프리셋 체크 누락 (post-edit-lint, post-edit-typecheck)
2. `claude plugin path` → 공식 `${CLAUDE_PLUGIN_ROOT}` 미사용
3. 마켓플레이스 검색이 프로그래밍적으로 불가한데 "Search marketplace"로만 기술
4. session-end.sh의 tool sequence 수집이 2-step pair로 제한 (스펙은 3+ step 요구)
5. config.json의 installedPlugins와 실제 설치 상태 불일치 가능

공식 문서 확인 결과:
- `claude plugin search` 명령 없음 — `/plugin` Discover 탭만 인터랙티브로 가능
- `claude plugin path` 없음 — `${CLAUDE_PLUGIN_ROOT}` 환경변수가 공식 방식
- `claude plugin list` 없음 — `~/.claude/plugins/cache/` 디렉토리로 간접 확인 가능
- 공식 마켓플레이스(`claude-plugins-official`) marketplace.json이 GitHub에 공개

## Test Plan

기존 테스트 파일들을 업데이트하고 신규 테스트를 추가:

| 테스트 파일 | 변경 내용 | 관련 Fix |
|-----------|----------|---------|
| `tests/test-session-end-v2a.sh` | 3-step sequence + rawToolSequence 검증 추가 | 3 |
| `tests/test-guardrails.sh` | `${CLAUDE_PLUGIN_ROOT}` 환경변수 설정 후 실행 확인 | 1+5 |
| `tests/test-hooks-integration.sh` | post-edit-lint/typecheck 프리셋 체크 테스트 추가 | 1+5 |
| `tests/test-init-templates.sh` | marketplace-recommendations.json 존재 및 스키마 검증 | 2 |
| `tests/test-update-recommendations.sh` (신규) | 크롤링 스크립트 출력 스키마 검증 | 2 |

## Fix 1+5 (통합): 프리셋 체크 추가 + `${CLAUDE_PLUGIN_ROOT}` 경로 통일

### 문제

- `post-edit-lint.sh`, `post-edit-typecheck.sh`가 프리셋의 `devHooks.postEditLint` / `devHooks.postEditTypecheck` 값을 확인하지 않아 advanced 프리셋에서도 항상 실행됨
- hooks에서 `$(cd "$(dirname "$0")/.." && pwd)`로 상대경로 사용 — 공식 `${CLAUDE_PLUGIN_ROOT}`과 불일치
- skills에서 `claude plugin path harnesskit` 사용 — 존재하지 않는 명령

### 변경 사항

#### `hooks/post-edit-lint.sh`

tool name 확인 직후, 파일 경로 추출 전에 프리셋 체크 삽입:

```bash
# 기존: TOOL 체크 후 바로 FILE 추출
# 변경: TOOL 체크 → 프리셋 체크 → FILE 추출

PRESET="intermediate"
[ -f ".harnesskit/config.json" ] && \
  PRESET=$(jq -r '.preset // "intermediate"' .harnesskit/config.json 2>/dev/null || echo "intermediate")

# ${CLAUDE_PLUGIN_ROOT}을 우선 사용, 미설정 시 dirname fallback (로컬 테스트용)
PLUGIN_DIR="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
# 의도적으로 // true 사용: lint는 기본 활성 (opt-out 방식)
# pre-commit-test의 // false (opt-in)와 다른 의도임
ENABLED=$(jq -r '.devHooks.postEditLint // true' "$PLUGIN_DIR/templates/presets/$PRESET.json" 2>/dev/null || echo "true")
[ "$ENABLED" != "true" ] && exit 0
```

#### `hooks/post-edit-typecheck.sh`

동일 패턴으로 프리셋 체크 삽입:

```bash
PRESET="intermediate"
[ -f ".harnesskit/config.json" ] && \
  PRESET=$(jq -r '.preset // "intermediate"' .harnesskit/config.json 2>/dev/null || echo "intermediate")

PLUGIN_DIR="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
# 의도적으로 // true: typecheck는 기본 활성 (opt-out 방식)
ENABLED=$(jq -r '.devHooks.postEditTypecheck // true' "$PLUGIN_DIR/templates/presets/$PRESET.json" 2>/dev/null || echo "true")
[ "$ENABLED" != "true" ] && exit 0
```

#### `hooks/guardrails.sh`

```diff
- PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
+ PLUGIN_DIR="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
```

#### `hooks/pre-commit-test.sh`

```diff
- PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
+ PLUGIN_DIR="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
```

#### `skills/setup/SKILL.md`

```diff
- bash "$(claude plugin path harnesskit)/scripts/detect-repo.sh" "$(pwd)"
+ bash "${CLAUDE_PLUGIN_ROOT}/scripts/detect-repo.sh" "$(pwd)"
```

#### `skills/init/SKILL.md` — hook 등록 포맷

init 스킬의 "Register Hooks in .claude/settings.json" 섹션에서 hook command 포맷도 통일:

```
hook command 포맷: bash ${CLAUDE_PLUGIN_ROOT}/hooks/{name}.sh
```

※ `${CLAUDE_PLUGIN_ROOT}`은 hooks/hooks.json 및 plugin.json의 hook 설정에서 자동 치환됨 (공식 문서 확인됨)

## Fix 2: 마켓플레이스 플러그인 발견 방식 재설계

### 문제

init 스킬이 "Search the Claude Code marketplace"로만 기술되어 있지만 프로그래밍적 검색 API가 없음. Claude가 존재하지 않는 플러그인을 추천할 위험.

### 설계: 정적 매핑 + 크롤링 갱신 + init fallback

#### 2-1. `templates/marketplace-recommendations.json` 신규 생성

공식 마켓플레이스(`claude-plugins-official`)에서 검증된 플러그인만 포함하는 추천 매핑 파일.

모든 카테고리를 통일된 배열 형식으로 관리 (LSP 포함):

```json
{
  "schemaVersion": "1.0",
  "lastUpdated": "2026-03-24",
  "source": "https://github.com/anthropics/claude-plugins-official",
  "recommendations": [
    {
      "plugin": "typescript-lsp@claude-plugins-official",
      "category": "lsp",
      "when": "language:typescript",
      "description": "TypeScript 코드 인텔리전스"
    },
    {
      "plugin": "pyright-lsp@claude-plugins-official",
      "category": "lsp",
      "when": "language:python",
      "description": "Python 코드 인텔리전스"
    },
    {
      "plugin": "gopls-lsp@claude-plugins-official",
      "category": "lsp",
      "when": "language:go",
      "description": "Go 코드 인텔리전스"
    },
    {
      "plugin": "rust-analyzer-lsp@claude-plugins-official",
      "category": "lsp",
      "when": "language:rust",
      "description": "Rust 코드 인텔리전스"
    },
    {
      "plugin": "code-simplifier@claude-plugins-official",
      "category": "general",
      "when": "always",
      "description": "코드 품질 리뷰 + 리팩토링"
    },
    {
      "plugin": "commit-commands@claude-plugins-official",
      "category": "general",
      "when": "git",
      "description": "Git 커밋 워크플로우"
    },
    {
      "plugin": "code-review@claude-plugins-official",
      "category": "review",
      "when": "git",
      "description": "PR 코드 리뷰 자동화"
    },
    {
      "plugin": "pr-review-toolkit@claude-plugins-official",
      "category": "review",
      "when": "git",
      "description": "PR 리뷰 전문 에이전트"
    },
    {
      "plugin": "semgrep@claude-plugins-official",
      "category": "security",
      "when": "always",
      "description": "보안 취약점 실시간 감지"
    },
    {
      "plugin": "security-guidance@claude-plugins-official",
      "category": "security",
      "when": "api",
      "description": "보안 가이드 hook"
    },
    {
      "plugin": "github@claude-plugins-official",
      "category": "integrations",
      "when": "github_remote",
      "description": "GitHub MCP 통합"
    }
  ],
  "conditions": {
    "always": "모든 프로젝트",
    "git": "detected.json의 git == true",
    "language:typescript": "detected.json의 language == typescript",
    "language:python": "detected.json의 language == python",
    "language:go": "detected.json의 language == go",
    "language:rust": "detected.json의 language == rust",
    "github_remote": "git remote -v에 github.com 포함",
    "api": "framework가 fastapi, django, nextjs 중 하나"
  }
}
```

※ `has_sentry` 조건은 제거 — `detect-repo.sh`에서 지원하지 않으며, init 시점에서 패키지 의존성 파싱은 범위 초과. 향후 detect-repo.sh 확장 시 재도입 가능.

#### 2-2. `scripts/update-recommendations.sh` 신규 생성

공식 마켓플레이스 marketplace.json을 fetch하여 recommendations.json을 갱신하는 스크립트.

```bash
#!/bin/bash
# update-recommendations.sh — 공식 마켓플레이스에서 추천 목록 갱신
# 이 스크립트는 개발자가 수동 실행하거나 CI에서 주기적 실행
# ${CLAUDE_PLUGIN_ROOT}이 아닌 dirname 사용: 플러그인 컨텍스트 외부에서도 실행 가능해야 하므로
set -euo pipefail

MARKETPLACE_URL="https://raw.githubusercontent.com/anthropics/claude-plugins-official/main/.claude-plugin/marketplace.json"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT="$SCRIPT_DIR/../templates/marketplace-recommendations.json"

# 1. Fetch marketplace.json
RAW=$(curl -sL "$MARKETPLACE_URL")
if [ -z "$RAW" ]; then
  echo "❌ Failed to fetch marketplace.json" >&2
  exit 1
fi

# 2. Schema validation — marketplace.json은 .plugins[] 배열을 가져야 함
#    각 plugin 엔트리: name(필수), description, category, keywords, tags
#    검증된 스키마: https://code.claude.com/docs/en/plugin-marketplaces#marketplace-schema
PLUGIN_COUNT=$(echo "$RAW" | jq '.plugins | length' 2>/dev/null || echo "0")
if [ "$PLUGIN_COUNT" = "0" ]; then
  echo "❌ marketplace.json has no plugins or unexpected schema" >&2
  echo "   Expected: {plugins: [{name, description, ...}]}" >&2
  exit 1
fi
echo "📦 Found $PLUGIN_COUNT plugins in marketplace"

# 3. Extract all plugins with metadata
ALL_PLUGINS=$(echo "$RAW" | jq '[.plugins[] | {
  name: .name,
  description: (.description // ""),
  category: (.category // "uncategorized"),
  keywords: (.keywords // []),
  tags: (.tags // [])
}]')

# 4. Auto-classify — 기존 recommendations의 수동 매핑을 보존하면서
#    새로 발견된 플러그인을 카테고리별로 출력
LSP_NAMES=$(echo "$ALL_PLUGINS" | jq -r '[.[] | select(.name | endswith("-lsp")) | .name] | join(", ")')
SECURITY_NAMES=$(echo "$ALL_PLUGINS" | jq -r '[.[] | select(
  .category == "Security" or
  (.keywords // [] | any(. == "security")) or
  (.name | test("security|semgrep|aikido"))
) | .name] | join(", ")')
REVIEW_NAMES=$(echo "$ALL_PLUGINS" | jq -r '[.[] | select(
  (.name | test("review|simplif")) or
  (.description | test("review|code quality"; "i"))
) | .name] | join(", ")')

echo ""
echo "📋 Auto-classified plugins:"
echo "   LSP: $LSP_NAMES"
echo "   Security: $SECURITY_NAMES"
echo "   Review: $REVIEW_NAMES"
echo ""

# 5. Preserve existing recommendations (수동 조건 매핑 유지)
#    이 스크립트는 allPlugins 목록만 갱신하고, recommendations 배열은 수동 관리
if [ -f "$OUTPUT" ]; then
  EXISTING_RECS=$(jq '.recommendations // []' "$OUTPUT")
  EXISTING_CONDITIONS=$(jq '.conditions // {}' "$OUTPUT")
else
  EXISTING_RECS='[]'
  EXISTING_CONDITIONS='{}'
fi

# 6. 갱신: lastUpdated + allPlugins (검색용), recommendations + conditions는 보존
jq -n \
  --arg date "$(date -u +%Y-%m-%d)" \
  --argjson all "$ALL_PLUGINS" \
  --argjson recs "$EXISTING_RECS" \
  --argjson conditions "$EXISTING_CONDITIONS" \
  '{
    schemaVersion: "1.0",
    lastUpdated: $date,
    source: "https://github.com/anthropics/claude-plugins-official",
    allPlugins: $all,
    recommendations: $recs,
    conditions: $conditions
  }' > "$OUTPUT"

echo "✅ Updated $OUTPUT — $PLUGIN_COUNT plugins indexed, $(echo "$EXISTING_RECS" | jq length) recommendations preserved"
echo ""
echo "💡 Review auto-classified plugins above and manually add new entries to"
echo "   recommendations[] in $OUTPUT with appropriate 'when' conditions."
```

**스크립트 역할 분담**:
- `allPlugins`: 크롤링으로 자동 갱신 (마켓플레이스 전체 목록)
- `recommendations`: 수동 관리 (검증된 추천 + 조건 매핑)
- 스크립트는 새 플러그인 발견을 보고하고, 개발자가 판단하여 recommendations에 추가

개발자가 수동 실행하거나, CI에서 주기적으로 실행.

#### 2-3. `init/SKILL.md` 마켓플레이스 섹션 수정

기존 "Search the Claude Code marketplace" 섹션을 교체:

```markdown
### 3. Marketplace Plugin Discovery ("Curate, Don't Reinvent")

Read the verified recommendations from `${CLAUDE_PLUGIN_ROOT}/templates/marketplace-recommendations.json`.

**If file exists and lastUpdated < 30 days:**
1. Match detected.json properties against recommendation conditions:
   - language → lsp category (language-specific LSP plugin)
   - git == true → general/review plugins with "git" condition
   - framework matches api condition → security plugins
   - Check git remote for github_remote condition
2. Present matched plugins for user selection

**If file missing or stale (> 30 days):**
1. Attempt live fetch from marketplace URL in the recommendations file
2. If fetch fails, use hardcoded minimal list:
   - code-simplifier@claude-plugins-official (always)
   - commit-commands@claude-plugins-official (if git)
   - code-review@claude-plugins-official (if git)

**Always append:**
"더 많은 플러그인은 `/plugin` → Discover 탭에서 탐색하세요."

**Present recommendations:**
```
📦 Marketplace Plugins for {framework} project:

  LSP:
    [1] {lsp-plugin} — 코드 인텔리전스 (install? y/n)

  General:
    [2] code-simplifier — 코드 품질 리뷰 (install? y/n)
    [3] commit-commands — Git 커밋 워크플로우 (install? y/n)

  Review:
    [4] code-review — PR 리뷰 자동화 (install? y/n)

  Security:
    [5] semgrep — 보안 취약점 감지 (install? y/n)

  💡 More plugins: /plugin → Discover tab
```

Install approved plugins:
  /plugin install {plugin-name}@claude-plugins-official

Record installed plugins in .harnesskit/config.json → installedPlugins array.
Record unmatched areas in config.json → uncoveredAreas array.
```

#### 2-4. `insights/SKILL.md`의 `plugin_recommendation` 수정

기존 "Usage pattern matches known plugin category" 로직에 추가:

```markdown
For `plugin_recommendation` proposals:
1. Read ${CLAUDE_PLUGIN_ROOT}/templates/marketplace-recommendations.json
2. Cross-reference with config.json installedPlugins — only recommend uninstalled plugins
3. Match usage patterns against recommendation conditions
4. Provide exact install command: `/plugin install {name}@claude-plugins-official`
```

## Fix 3: session-end.sh tool sequence 수집 — 3-step sliding window

### 문제

현재 2-step pair만 수집하지만 insights 스펙은 "Same tool call sequence (3+ steps) in 3+ sessions" 감지를 요구.

### 변경 사항

#### `hooks/session-end.sh` — toolCallSequences 로직 교체

기존 2-step pair (bare tool name만 사용):
```bash
($tools[$i] + " → " + $tools[$i+1]) as $pair
```

변경 — 3-step sliding window + **tool:summary 형태** (v2a 스펙 준수):

v2a 설계 스펙의 기대 형식: `["Bash:tsc --noEmit", "Edit:fix-type", "Bash:tsc --noEmit"]`
bare tool name만으로는 `Edit → Bash → Edit`처럼 거의 모든 세션에서 나타나는 패턴이 되어 의미 있는 자동화 후보를 감지할 수 없음.

```bash
# tool:summary 형태로 시퀀스 키 생성
TOOL_CALL_SEQUENCES=$(echo "$TOOL_LINES" | jq -s '
  [.[] | (.tool + ":" + ((.summary // "")[0:30]))] as $labeled |
  if ($labeled | length) < 3 then [] else
    (reduce range(0; ($labeled | length) - 2) as $i (
      {};
      ($labeled[$i] + " → " + $labeled[$i+1] + " → " + $labeled[$i+2]) as $triple |
      .[$triple] = ((.[$triple] // 0) + 1)
    )) as $triples |
    [$triples | to_entries[] |
      (.key | split(" → ")) as $seq |
      {sequence: $seq, count: .value, context: "repeated 3-step pattern"}
    ]
  end
' 2>/dev/null || echo "[]")
```

**threshold 변경**: 기존 `select(.value >= 2)` 제거 — 모든 3-step 시퀀스를 기록.
cross-session 집계는 insights가 담당 ("same sequence in 3+ sessions" 트리거).
within-session에서 1회만 나타나는 시퀀스도 기록해야 insights가 cross-session으로 집계할 수 있음.

#### session log에 `rawToolSequence` 필드 추가

insights가 임의 길이 패턴을 분석할 수 있도록 raw sequence도 보존:

```bash
RAW_TOOL_SEQ="[]"
if [ -n "$TOOL_LINES" ]; then
  RAW_TOOL_SEQ=$(echo "$TOOL_LINES" | jq -s '[.[] | (.tool + ":" + ((.summary // "")[0:30]))]' 2>/dev/null || echo "[]")
fi
```

jq output에 추가 (session-end.sh의 jq -n 호출, 기존 line 98-122):
```bash
--argjson raw "$RAW_TOOL_SEQ"
```

JSON 구조의 `jq -n` 템플릿에 `rawToolSequence: $raw` 추가:
```json
{
  "toolCallSequences": [
    {"sequence": ["Bash:tsc --noEmit", "Edit:fix-type", "Bash:tsc --noEmit"], "count": 3, "context": "repeated 3-step pattern"}
  ],
  "rawToolSequence": ["Edit:update-handler", "Bash:tsc --noEmit", "Edit:fix-type", "Bash:tsc --noEmit", "Write:new-file"]
}
```

insights는 `rawToolSequence`를 사용해 임의 길이의 반복 패턴을 분석하고, `toolCallSequences`로 사전 집계된 3-step 패턴을 빠르게 참조할 수 있음.

## Fix 4: status 스킬에서 실제 설치 상태 검증

### 문제

config.json의 `installedPlugins`와 실제 설치된 플러그인 상태가 불일치할 수 있음. 비인터랙티브 `claude plugin list` 명령이 없음.

### 변경 사항

#### `skills/status/SKILL.md` — 플러그인 검증 단계 추가

기존 "Read config.json for installedPlugins" 이후에 추가:

```markdown
## Plugin Installation Verification

After reading installedPlugins from config.json:

1. Check if `$HOME/.claude/plugins/cache/` directory exists
   ※ 공식 문서 확인: 플러그인 캐시 경로는 `~/.claude/plugins/cache/` (plugins-reference#plugin-caching-and-file-resolution)
2. If it exists, for each plugin in installedPlugins:
   - Use glob search: `find $HOME/.claude/plugins/cache/ -maxdepth 2 -name "{plugin-name}" -type d`
   - 캐시 경로 패턴은 `{marketplace-name}/{plugin-name}/{version}/` 형태로 추정되나,
     정확한 구조는 Claude Code 버전에 따라 달라질 수 있으므로 name 기반 glob이 안전
3. Report status per plugin:
   - ✅ {name} — installed and cached
   - ⚠️ {name} — in config but not found in cache (may need reinstall)
   - If glob search fails or returns unexpected results, fall back to "unverified"

If cache directory doesn't exist, skip verification and display config as-is with note:
  "(plugin cache not found — verification skipped)"

If installedPlugins is empty, display:
  "Marketplace Plugins: none installed"

If mismatches found, suggest:
  "Run `/plugin install {name}@claude-plugins-official` to reinstall missing plugins,
   or update .harnesskit/config.json to remove stale entries."
```

출력 포맷에 검증 결과 통합:

```
🛠  Toolkit:
    Marketplace Plugins:
      ✅ code-simplifier — installed
      ✅ commit-commands — installed
      ⚠️  semgrep — config에 기록되었으나 캐시 없음
    Custom Skills: none yet
    ...
```

## Summary — 전체 변경 파일 목록

| 파일 | 변경 유형 | Fix |
|------|----------|-----|
| `hooks/post-edit-lint.sh` | 수정 — 프리셋 체크 + 경로 통일 | 1+5 |
| `hooks/post-edit-typecheck.sh` | 수정 — 프리셋 체크 + 경로 통일 | 1+5 |
| `hooks/guardrails.sh` | 수정 — 경로 fallback 통일 | 5 |
| `hooks/pre-commit-test.sh` | 수정 — 경로 fallback 통일 | 5 |
| `hooks/session-end.sh` | 수정 — 3-step window (tool:summary) + rawToolSequence | 3 |
| `skills/setup/SKILL.md` | 수정 — 경로 통일 | 5 |
| `skills/init/SKILL.md` | 수정 — 마켓플레이스 섹션 재작성 + hook 등록 포맷 | 2, 5 |
| `skills/insights/SKILL.md` | 수정 — plugin_recommendation 로직 | 2 |
| `skills/status/SKILL.md` | 수정 — 플러그인 검증 추가 (glob 기반) | 4 |
| `templates/marketplace-recommendations.json` | 신규 — 통일된 배열 형식 | 2 |
| `scripts/update-recommendations.sh` | 신규 — allPlugins 갱신 + 수동 추천 보존 | 2 |

### 테스트 파일

| 파일 | 변경 내용 | Fix |
|------|----------|-----|
| `tests/test-session-end-v2a.sh` | 3-step tool:summary sequence + rawToolSequence 검증 | 3 |
| `tests/test-guardrails.sh` | CLAUDE_PLUGIN_ROOT fallback 테스트 | 1+5 |
| `tests/test-hooks-integration.sh` | post-edit 프리셋 체크 테스트 | 1+5 |
| `tests/test-init-templates.sh` | recommendations.json 스키마 검증 | 2 |
| `tests/test-update-recommendations.sh` (신규) | 크롤링 스크립트 출력 검증 | 2 |
