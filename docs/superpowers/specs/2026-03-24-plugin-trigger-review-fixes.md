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

PLUGIN_DIR="${CLAUDE_PLUGIN_ROOT}"
ENABLED=$(jq -r '.devHooks.postEditLint // true' "$PLUGIN_DIR/templates/presets/$PRESET.json" 2>/dev/null || echo "true")
[ "$ENABLED" != "true" ] && exit 0
```

#### `hooks/post-edit-typecheck.sh`

동일 패턴으로 프리셋 체크 삽입:

```bash
PRESET="intermediate"
[ -f ".harnesskit/config.json" ] && \
  PRESET=$(jq -r '.preset // "intermediate"' .harnesskit/config.json 2>/dev/null || echo "intermediate")

PLUGIN_DIR="${CLAUDE_PLUGIN_ROOT}"
ENABLED=$(jq -r '.devHooks.postEditTypecheck // true' "$PLUGIN_DIR/templates/presets/$PRESET.json" 2>/dev/null || echo "true")
[ "$ENABLED" != "true" ] && exit 0
```

#### `hooks/guardrails.sh`

```diff
- PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
+ PLUGIN_DIR="${CLAUDE_PLUGIN_ROOT}"
```

#### `hooks/pre-commit-test.sh`

```diff
- PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
+ PLUGIN_DIR="${CLAUDE_PLUGIN_ROOT}"
```

#### `skills/setup/SKILL.md`

```diff
- bash "$(claude plugin path harnesskit)/scripts/detect-repo.sh" "$(pwd)"
+ bash "${CLAUDE_PLUGIN_ROOT}/scripts/detect-repo.sh" "$(pwd)"
```

## Fix 2: 마켓플레이스 플러그인 발견 방식 재설계

### 문제

init 스킬이 "Search the Claude Code marketplace"로만 기술되어 있지만 프로그래밍적 검색 API가 없음. Claude가 존재하지 않는 플러그인을 추천할 위험.

### 설계: 정적 매핑 + 크롤링 갱신 + init fallback

#### 2-1. `templates/marketplace-recommendations.json` 신규 생성

공식 마켓플레이스(`claude-plugins-official`)에서 검증된 플러그인만 포함하는 추천 매핑 파일.

```json
{
  "schemaVersion": "1.0",
  "lastUpdated": "2026-03-24",
  "source": "https://github.com/anthropics/claude-plugins-official",
  "categories": {
    "lsp": {
      "typescript": "typescript-lsp@claude-plugins-official",
      "python": "pyright-lsp@claude-plugins-official",
      "go": "gopls-lsp@claude-plugins-official",
      "rust": "rust-analyzer-lsp@claude-plugins-official",
      "java": "jdtls-lsp@claude-plugins-official",
      "swift": "swift-lsp@claude-plugins-official",
      "php": "php-lsp@claude-plugins-official",
      "ruby": "ruby-lsp@claude-plugins-official"
    },
    "general": [
      {
        "plugin": "code-simplifier@claude-plugins-official",
        "when": "always",
        "description": "코드 품질 리뷰 + 리팩토링"
      },
      {
        "plugin": "commit-commands@claude-plugins-official",
        "when": "git",
        "description": "Git 커밋 워크플로우"
      }
    ],
    "review": [
      {
        "plugin": "code-review@claude-plugins-official",
        "when": "git",
        "description": "PR 코드 리뷰 자동화"
      },
      {
        "plugin": "pr-review-toolkit@claude-plugins-official",
        "when": "git",
        "description": "PR 리뷰 전문 에이전트"
      }
    ],
    "security": [
      {
        "plugin": "semgrep@claude-plugins-official",
        "when": "always",
        "description": "보안 취약점 실시간 감지"
      },
      {
        "plugin": "security-guidance@claude-plugins-official",
        "when": "api",
        "description": "보안 가이드 hook"
      }
    ],
    "integrations": [
      {
        "plugin": "github@claude-plugins-official",
        "when": "github_remote",
        "description": "GitHub MCP 통합"
      },
      {
        "plugin": "sentry@claude-plugins-official",
        "when": "has_sentry",
        "description": "에러 모니터링"
      }
    ]
  },
  "conditions": {
    "always": "모든 프로젝트",
    "git": "detected.json의 git == true",
    "github_remote": "git remote -v에 github.com 포함",
    "api": "framework가 fastapi, django, nextjs 중 하나",
    "has_sentry": "requirements.txt 또는 package.json에 sentry 패키지 포함"
  }
}
```

#### 2-2. `scripts/update-recommendations.sh` 신규 생성

공식 마켓플레이스 marketplace.json을 fetch하여 recommendations.json을 갱신하는 스크립트.

```bash
#!/bin/bash
# update-recommendations.sh — 공식 마켓플레이스에서 추천 목록 갱신
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

# 2. Extract all plugins with metadata
ALL_PLUGINS=$(echo "$RAW" | jq '[.plugins[] | {
  name: .name,
  description: (.description // ""),
  category: (.category // "uncategorized"),
  keywords: (.keywords // []),
  tags: (.tags // [])
}]')

# 3. Auto-classify into categories
LSP=$(echo "$ALL_PLUGINS" | jq '[.[] | select(.name | endswith("-lsp"))]')
SECURITY=$(echo "$ALL_PLUGINS" | jq '[.[] | select(
  .category == "Security" or
  (.keywords | any(. == "security")) or
  (.name | test("security|semgrep|aikido|autofix"))
)]')
REVIEW=$(echo "$ALL_PLUGINS" | jq '[.[] | select(
  (.name | test("review|simplif")) or
  (.description | test("review|code quality"; "i"))
)]')

# 4. Generate recommendations.json (preserving manual condition mappings)
# Read existing conditions from current file if it exists
if [ -f "$OUTPUT" ]; then
  EXISTING_CONDITIONS=$(jq '.conditions // {}' "$OUTPUT")
else
  EXISTING_CONDITIONS='{}'
fi

# 5. Update lastUpdated and plugin lists, preserve conditions
jq -n \
  --arg date "$(date -u +%Y-%m-%d)" \
  --argjson lsp "$LSP" \
  --argjson security "$SECURITY" \
  --argjson review "$REVIEW" \
  --argjson all "$ALL_PLUGINS" \
  --argjson conditions "$EXISTING_CONDITIONS" \
  '{
    schemaVersion: "1.0",
    lastUpdated: $date,
    source: "https://github.com/anthropics/claude-plugins-official",
    allPlugins: ($all | length),
    categories: {
      lsp: [$lsp[] | {(.name | sub("-lsp$";"")): "\(.name)@claude-plugins-official"}] | add,
      security: $security,
      review: $review
    },
    conditions: $conditions
  }' > "$OUTPUT"

echo "✅ Updated $OUTPUT — $(echo "$ALL_PLUGINS" | jq length) plugins indexed"
```

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

기존 2-step pair:
```bash
($tools[$i] + " → " + $tools[$i+1]) as $pair
```

변경 — 3-step sliding window:
```bash
TOOL_CALL_SEQUENCES=$(echo "$TOOL_LINES" | jq -s '
  [.[] | .tool] as $tools |
  if ($tools | length) < 3 then [] else
    (reduce range(0; ($tools | length) - 2) as $i (
      {};
      ($tools[$i] + " → " + $tools[$i+1] + " → " + $tools[$i+2]) as $triple |
      .[$triple] = ((.[$triple] // 0) + 1)
    )) as $triples |
    [$triples | to_entries[] | select(.value >= 2) |
      (.key | split(" → ")) as $seq |
      {sequence: $seq, count: .value, context: "repeated 3-step pattern"}
    ]
  end
' 2>/dev/null || echo "[]")
```

#### session log에 `rawToolSequence` 필드 추가

```bash
RAW_TOOL_SEQ="[]"
if [ -n "$TOOL_LINES" ]; then
  RAW_TOOL_SEQ=$(echo "$TOOL_LINES" | jq -s '[.[] | .tool]' 2>/dev/null || echo "[]")
fi
```

jq output에 추가:
```bash
--argjson raw "$RAW_TOOL_SEQ"
```

JSON 구조에 추가:
```json
{
  "toolCallSequences": "...(3-step 집계)",
  "rawToolSequence": ["Edit", "Bash", "Edit", "Bash", "Write"]
}
```

insights는 `rawToolSequence`를 사용해 임의 길이의 반복 패턴을 분석할 수 있음.

## Fix 4: status 스킬에서 실제 설치 상태 검증

### 문제

config.json의 `installedPlugins`와 실제 설치된 플러그인 상태가 불일치할 수 있음. 비인터랙티브 `claude plugin list` 명령이 없음.

### 변경 사항

#### `skills/status/SKILL.md` — 플러그인 검증 단계 추가

기존 "Read config.json for installedPlugins" 이후에 추가:

```markdown
## Plugin Installation Verification

After reading installedPlugins from config.json:

1. Check if `~/.claude/plugins/cache/` directory exists
2. If it exists, for each plugin in installedPlugins:
   - Check if a matching directory exists under the cache
   - Cache path pattern: `~/.claude/plugins/cache/{marketplace-name}/{plugin-name}/`
3. Report status per plugin:
   - ✅ {name} — installed and cached
   - ⚠️ {name} — in config but not found in cache (may need reinstall)

If cache directory doesn't exist, skip verification and display config as-is.

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
| `hooks/guardrails.sh` | 수정 — 경로 통일 | 5 |
| `hooks/pre-commit-test.sh` | 수정 — 경로 통일 | 5 |
| `hooks/session-end.sh` | 수정 — 3-step window + rawToolSequence | 3 |
| `skills/setup/SKILL.md` | 수정 — 경로 통일 | 5 |
| `skills/init/SKILL.md` | 수정 — 마켓플레이스 섹션 재작성 | 2 |
| `skills/insights/SKILL.md` | 수정 — plugin_recommendation 로직 | 2 |
| `skills/status/SKILL.md` | 수정 — 플러그인 검증 추가 | 4 |
| `templates/marketplace-recommendations.json` | 신규 | 2 |
| `scripts/update-recommendations.sh` | 신규 | 2 |
