#!/bin/bash
# detect-repo.sh — Zero-token repo property detection
# Outputs JSON to stdout. No Claude API calls.
set -euo pipefail

PROJECT_DIR="${1:-.}"

# --- Language & Package Manager ---
language="unknown"
packageManager="unknown"

if [ -f "$PROJECT_DIR/package.json" ]; then
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
  if [ -f "$PROJECT_DIR/tsconfig.json" ] || \
     ([ -f "$PROJECT_DIR/package.json" ] && jq -e '.devDependencies.typescript // .dependencies.typescript' "$PROJECT_DIR/package.json" >/dev/null 2>&1); then
    language="typescript"
  fi
elif [ -f "$PROJECT_DIR/requirements.txt" ] || [ -f "$PROJECT_DIR/pyproject.toml" ] || [ -f "$PROJECT_DIR/setup.py" ]; then
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

# --- Framework ---
framework="unknown"

if [ -f "$PROJECT_DIR/next.config.js" ] || [ -f "$PROJECT_DIR/next.config.mjs" ] || [ -f "$PROJECT_DIR/next.config.ts" ]; then
  framework="nextjs"
elif [ -f "$PROJECT_DIR/vite.config.js" ] || [ -f "$PROJECT_DIR/vite.config.ts" ] || [ -f "$PROJECT_DIR/vite.config.mjs" ]; then
  framework="vite"
elif [ -f "$PROJECT_DIR/nuxt.config.js" ] || [ -f "$PROJECT_DIR/nuxt.config.ts" ]; then
  framework="nuxt"
elif [ -f "$PROJECT_DIR/svelte.config.js" ]; then
  framework="sveltekit"
fi

if [ "$language" = "python" ]; then
  if [ -f "$PROJECT_DIR/requirements.txt" ] && grep -qi "fastapi" "$PROJECT_DIR/requirements.txt" 2>/dev/null; then
    framework="fastapi"
  elif [ -f "$PROJECT_DIR/pyproject.toml" ] && grep -qi "fastapi" "$PROJECT_DIR/pyproject.toml" 2>/dev/null; then
    framework="fastapi"
  elif [ -f "$PROJECT_DIR/manage.py" ] || ([ -f "$PROJECT_DIR/requirements.txt" ] && grep -qi "django" "$PROJECT_DIR/requirements.txt" 2>/dev/null); then
    framework="django"
  elif [ -f "$PROJECT_DIR/requirements.txt" ] && grep -qi "flask" "$PROJECT_DIR/requirements.txt" 2>/dev/null; then
    framework="flask"
  fi
fi

# --- Test Framework ---
testFramework="unknown"

if [ -f "$PROJECT_DIR/vitest.config.js" ] || [ -f "$PROJECT_DIR/vitest.config.ts" ] || \
   ([ -f "$PROJECT_DIR/package.json" ] && jq -e '.devDependencies.vitest' "$PROJECT_DIR/package.json" >/dev/null 2>&1); then
  testFramework="vitest"
elif [ -f "$PROJECT_DIR/jest.config.js" ] || [ -f "$PROJECT_DIR/jest.config.ts" ] || \
     ([ -f "$PROJECT_DIR/package.json" ] && jq -e '.devDependencies.jest' "$PROJECT_DIR/package.json" >/dev/null 2>&1); then
  testFramework="jest"
elif [ "$language" = "python" ]; then
  if [ -f "$PROJECT_DIR/pytest.ini" ] || [ -f "$PROJECT_DIR/conftest.py" ] || \
     ([ -f "$PROJECT_DIR/requirements.txt" ] && grep -qi "pytest" "$PROJECT_DIR/requirements.txt" 2>/dev/null) || \
     ([ -f "$PROJECT_DIR/pyproject.toml" ] && grep -qi "pytest" "$PROJECT_DIR/pyproject.toml" 2>/dev/null); then
    testFramework="pytest"
  fi
elif [ "$language" = "go" ]; then
  testFramework="go-test"
elif [ "$language" = "rust" ]; then
  testFramework="cargo-test"
fi

# --- Linter ---
linter="unknown"

if [ -f "$PROJECT_DIR/.eslintrc.js" ] || [ -f "$PROJECT_DIR/.eslintrc.json" ] || [ -f "$PROJECT_DIR/.eslintrc.yml" ] || [ -f "$PROJECT_DIR/eslint.config.js" ] || [ -f "$PROJECT_DIR/eslint.config.mjs" ] || \
   ([ -f "$PROJECT_DIR/package.json" ] && jq -e '.devDependencies.eslint' "$PROJECT_DIR/package.json" >/dev/null 2>&1); then
  linter="eslint"
elif [ -f "$PROJECT_DIR/biome.json" ]; then
  linter="biome"
fi

if [ "$language" = "python" ]; then
  if [ -f "$PROJECT_DIR/ruff.toml" ] || ([ -f "$PROJECT_DIR/pyproject.toml" ] && grep -qi "\[tool.ruff\]" "$PROJECT_DIR/pyproject.toml" 2>/dev/null) || \
     ([ -f "$PROJECT_DIR/requirements.txt" ] && grep -qi "ruff" "$PROJECT_DIR/requirements.txt" 2>/dev/null); then
    linter="ruff"
  elif [ -f "$PROJECT_DIR/.flake8" ] || ([ -f "$PROJECT_DIR/requirements.txt" ] && grep -qi "flake8" "$PROJECT_DIR/requirements.txt" 2>/dev/null); then
    linter="flake8"
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
