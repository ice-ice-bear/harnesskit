#!/bin/bash
# detect-repo.sh — Zero-token repo property detection
# Outputs JSON to stdout. No Claude API calls.
set -euo pipefail

PROJECT_DIR="${1:-.}"

# --- Monorepo subdirectory scanning ---
# Check root first, then common subdirectories (backend/, frontend/, server/, client/, app/, src/)
find_file() {
  local filename="$1"
  if [ -f "$PROJECT_DIR/$filename" ]; then
    echo "$PROJECT_DIR/$filename"
    return 0
  fi
  for sub in backend server api frontend client app web src; do
    if [ -f "$PROJECT_DIR/$sub/$filename" ]; then
      echo "$PROJECT_DIR/$sub/$filename"
      return 0
    fi
  done
  return 1
}

grep_file() {
  local pattern="$1" filename="$2"
  local found
  found=$(find_file "$filename" 2>/dev/null) || return 1
  grep -qi "$pattern" "$found" 2>/dev/null
}

# --- Language & Package Manager ---
language="unknown"
packageManager="unknown"

PACKAGE_JSON=$(find_file "package.json" 2>/dev/null || echo "")
TSCONFIG=$(find_file "tsconfig.json" 2>/dev/null || echo "")
REQUIREMENTS=$(find_file "requirements.txt" 2>/dev/null || echo "")
PYPROJECT=$(find_file "pyproject.toml" 2>/dev/null || echo "")

if [ -n "$PACKAGE_JSON" ]; then
  language="javascript"
  if [ -f "$PROJECT_DIR/pnpm-lock.yaml" ]; then
    packageManager="pnpm"
  elif [ -f "$PROJECT_DIR/yarn.lock" ]; then
    packageManager="yarn"
  elif [ -f "$PROJECT_DIR/bun.lockb" ]; then
    packageManager="bun"
  else
    packageManager="npm"
  fi
  if [ -n "$TSCONFIG" ] || \
     ([ -n "$PACKAGE_JSON" ] && jq -e '.devDependencies.typescript // .dependencies.typescript' "$PACKAGE_JSON" >/dev/null 2>&1); then
    language="typescript"
  fi
elif [ -n "$REQUIREMENTS" ] || [ -n "$PYPROJECT" ] || [ -f "$PROJECT_DIR/setup.py" ]; then
  language="python"
  if [ -f "$PROJECT_DIR/poetry.lock" ]; then
    packageManager="poetry"
  elif [ -f "$PROJECT_DIR/Pipfile.lock" ]; then
    packageManager="pipenv"
  elif [ -f "$PROJECT_DIR/uv.lock" ]; then
    packageManager="uv"
  else
    packageManager="pip"
  fi
elif [ -f "$PROJECT_DIR/go.mod" ]; then
  language="go"
  packageManager="go"
elif [ -f "$PROJECT_DIR/Cargo.toml" ]; then
  language="rust"
  packageManager="cargo"
fi

# Detect multi-language (monorepo with both backend+frontend)
if [ -n "$PACKAGE_JSON" ] && [ -n "$REQUIREMENTS" ]; then
  language="multi"
fi

# --- Framework ---
framework="unknown"

if find_file "next.config.js" >/dev/null 2>&1 || find_file "next.config.mjs" >/dev/null 2>&1 || find_file "next.config.ts" >/dev/null 2>&1; then
  framework="nextjs"
elif find_file "vite.config.js" >/dev/null 2>&1 || find_file "vite.config.ts" >/dev/null 2>&1 || find_file "vite.config.mjs" >/dev/null 2>&1; then
  framework="vite"
elif find_file "nuxt.config.js" >/dev/null 2>&1 || find_file "nuxt.config.ts" >/dev/null 2>&1; then
  framework="nuxt"
elif find_file "svelte.config.js" >/dev/null 2>&1; then
  framework="sveltekit"
fi

if [ "$language" = "python" ] || [ "$language" = "multi" ]; then
  if grep_file "fastapi" "requirements.txt" || grep_file "fastapi" "pyproject.toml"; then
    if [ "$framework" != "unknown" ]; then
      framework="$framework+fastapi"
    else
      framework="fastapi"
    fi
  elif [ -f "$PROJECT_DIR/manage.py" ] || grep_file "django" "requirements.txt"; then
    if [ "$framework" != "unknown" ]; then
      framework="$framework+django"
    else
      framework="django"
    fi
  elif grep_file "flask" "requirements.txt"; then
    if [ "$framework" != "unknown" ]; then
      framework="$framework+flask"
    else
      framework="flask"
    fi
  fi
fi

# --- Test Framework ---
testFramework="unknown"

if find_file "vitest.config.js" >/dev/null 2>&1 || find_file "vitest.config.ts" >/dev/null 2>&1 || \
   ([ -n "$PACKAGE_JSON" ] && jq -e '.devDependencies.vitest' "$PACKAGE_JSON" >/dev/null 2>&1); then
  testFramework="vitest"
elif find_file "jest.config.js" >/dev/null 2>&1 || find_file "jest.config.ts" >/dev/null 2>&1 || \
     ([ -n "$PACKAGE_JSON" ] && jq -e '.devDependencies.jest' "$PACKAGE_JSON" >/dev/null 2>&1); then
  testFramework="jest"
fi

if [ "$language" = "python" ] || [ "$language" = "multi" ]; then
  if find_file "pytest.ini" >/dev/null 2>&1 || find_file "conftest.py" >/dev/null 2>&1 || \
     grep_file "pytest" "requirements.txt" || grep_file "pytest" "pyproject.toml"; then
    if [ "$testFramework" != "unknown" ]; then
      testFramework="$testFramework+pytest"
    else
      testFramework="pytest"
    fi
  fi
elif [ "$language" = "go" ]; then
  testFramework="go-test"
elif [ "$language" = "rust" ]; then
  testFramework="cargo-test"
fi

# --- Linter ---
linter="unknown"

if find_file ".eslintrc.js" >/dev/null 2>&1 || find_file ".eslintrc.json" >/dev/null 2>&1 || find_file "eslint.config.js" >/dev/null 2>&1 || find_file "eslint.config.mjs" >/dev/null 2>&1 || \
   ([ -n "$PACKAGE_JSON" ] && jq -e '.devDependencies.eslint' "$PACKAGE_JSON" >/dev/null 2>&1); then
  linter="eslint"
elif find_file "biome.json" >/dev/null 2>&1; then
  linter="biome"
fi

if [ "$language" = "python" ] || [ "$language" = "multi" ]; then
  if find_file "ruff.toml" >/dev/null 2>&1 || grep_file "\\[tool.ruff\\]" "pyproject.toml" || grep_file "ruff" "requirements.txt"; then
    if [ "$linter" != "unknown" ]; then
      linter="$linter+ruff"
    else
      linter="ruff"
    fi
  elif find_file ".flake8" >/dev/null 2>&1 || grep_file "flake8" "requirements.txt"; then
    if [ "$linter" != "unknown" ]; then
      linter="$linter+flake8"
    else
      linter="flake8"
    fi
  fi
fi

# --- Monorepo ---
monorepo=false
if [ -f "$PROJECT_DIR/turbo.json" ] || [ -f "$PROJECT_DIR/nx.json" ] || [ -f "$PROJECT_DIR/lerna.json" ]; then
  monorepo=true
elif [ -f "$PROJECT_DIR/pnpm-workspace.yaml" ]; then
  monorepo=true
elif [ -d "$PROJECT_DIR/packages" ] && [ -d "$PROJECT_DIR/apps" ]; then
  monorepo=true
elif [ "$language" = "multi" ]; then
  monorepo=true
elif [ -d "$PROJECT_DIR/backend" ] && [ -d "$PROJECT_DIR/frontend" ]; then
  monorepo=true
fi

# --- Git ---
gitInitialized=false
if [ -d "$PROJECT_DIR/.git" ]; then
  gitInitialized=true
fi

# --- Existing Harness ---
existingClaudeMd=false
existingFeatureList=false
existingProgress=false
existingHarnesskit=false

[ -f "$PROJECT_DIR/CLAUDE.md" ] && existingClaudeMd=true
[ -f "$PROJECT_DIR/docs/feature_list.json" ] && existingFeatureList=true
[ -f "$PROJECT_DIR/progress/claude-progress.txt" ] && existingProgress=true
[ -d "$PROJECT_DIR/.harnesskit" ] && existingHarnesskit=true

# --- Output ---
cat <<EOF
{
  "language": "$language",
  "framework": "$framework",
  "packageManager": "$packageManager",
  "testFramework": "$testFramework",
  "linter": "$linter",
  "monorepo": $monorepo,
  "git": $gitInitialized,
  "existingHarness": {
    "claudeMd": $existingClaudeMd,
    "featureList": $existingFeatureList,
    "progress": $existingProgress,
    "harnesskit": $existingHarnesskit
  }
}
EOF
