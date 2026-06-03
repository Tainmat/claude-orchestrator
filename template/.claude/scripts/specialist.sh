#!/usr/bin/env bash
# specialist.sh — Detecta linguagem do projeto e gera guia de especialista via Gemini.
# Saída: .orchestrator/specialist.md
# Uso: specialist.sh [linguagem-forçada]  # ex: specialist.sh python
set -euo pipefail

OUT_DIR=".orchestrator"
OUT_FILE="$OUT_DIR/specialist.md"
mkdir -p "$OUT_DIR"

# Linguagem forçada via argumento ou detecção automática
FRAMEWORK_DETECTED=""
if [ -n "${1:-}" ]; then
  LANG_DETECTED="$1"
else
  LANG_DETECTED=""

  # Detecta pela presença de arquivos-chave (ordem de prioridade)

  if [ -f "package.json" ]; then
    if grep -qiE '"typescript"|"ts-node"|"@types/' package.json 2>/dev/null; then
      LANG_DETECTED="TypeScript"
    else
      LANG_DETECTED="JavaScript"
    fi

    # Detecta framework JS/TS
    if grep -q '"@angular/core"' package.json 2>/dev/null; then
      FRAMEWORK_DETECTED="Angular"
    elif grep -q '"next"' package.json 2>/dev/null; then
      FRAMEWORK_DETECTED="Next.js"
    elif grep -q '"react"' package.json 2>/dev/null; then
      FRAMEWORK_DETECTED="React"
    elif grep -q '"vue"' package.json 2>/dev/null; then
      FRAMEWORK_DETECTED="Vue"
    elif grep -q '"svelte"' package.json 2>/dev/null; then
      FRAMEWORK_DETECTED="Svelte"
    elif grep -q '"@nestjs/core"' package.json 2>/dev/null; then
      FRAMEWORK_DETECTED="NestJS"
    elif grep -q '"express"' package.json 2>/dev/null; then
      FRAMEWORK_DETECTED="Express"
    fi

  elif [ -f "go.mod" ]; then
    LANG_DETECTED="Go"
    if grep -q "gin-gonic/gin" go.mod 2>/dev/null; then
      FRAMEWORK_DETECTED="Gin"
    elif grep -q "labstack/echo" go.mod 2>/dev/null; then
      FRAMEWORK_DETECTED="Echo"
    fi

  elif [ -f "Cargo.toml" ]; then
    LANG_DETECTED="Rust"
    if grep -q "actix-web" Cargo.toml 2>/dev/null; then
      FRAMEWORK_DETECTED="Actix Web"
    elif grep -q "axum" Cargo.toml 2>/dev/null; then
      FRAMEWORK_DETECTED="Axum"
    fi

  elif [ -f "pyproject.toml" ] || [ -f "requirements.txt" ] || [ -f "setup.py" ]; then
    LANG_DETECTED="Python"
    REQS_FILE=""
    [ -f "requirements.txt" ] && REQS_FILE="requirements.txt"
    [ -f "pyproject.toml" ] && REQS_FILE="pyproject.toml"
    if [ -n "$REQS_FILE" ]; then
      if grep -qi "django" "$REQS_FILE" 2>/dev/null; then
        FRAMEWORK_DETECTED="Django"
      elif grep -qi "fastapi" "$REQS_FILE" 2>/dev/null; then
        FRAMEWORK_DETECTED="FastAPI"
      elif grep -qi "flask" "$REQS_FILE" 2>/dev/null; then
        FRAMEWORK_DETECTED="Flask"
      fi
    fi

  elif [ -f "pom.xml" ] || [ -f "build.gradle" ]; then
    LANG_DETECTED="Java"
    BUILD_FILE=""
    [ -f "pom.xml" ] && BUILD_FILE="pom.xml"
    [ -f "build.gradle" ] && BUILD_FILE="build.gradle"
    if grep -qi "spring-boot" "$BUILD_FILE" 2>/dev/null; then
      FRAMEWORK_DETECTED="Spring Boot"
    fi

  elif ls ./*.cs 2>/dev/null | grep -q '.'; then
    LANG_DETECTED="C#"
  else
    LANG_DETECTED="desconhecida"
  fi
fi

# Compõe descrição completa
if [ -n "$FRAMEWORK_DETECTED" ]; then
  STACK_DETECTED="$LANG_DETECTED + $FRAMEWORK_DETECTED"
else
  STACK_DETECTED="$LANG_DETECTED"
fi

echo "🔍 Stack detectada: $STACK_DETECTED"

if [ "$LANG_DETECTED" = "desconhecida" ]; then
  {
    echo "# Guia de especialista"
    echo ""
    echo "> ⚠️ **Linguagem não detectada.** Nenhum arquivo de projeto reconhecido foi encontrado."
    echo "> Rode \`specialist.sh <linguagem>\` para forçar uma linguagem específica."
  } > "$OUT_FILE"
  echo "ℹ️  Linguagem desconhecida — aviso gravado em $OUT_FILE"
  exit 0
fi

SPECIALIST_PROMPT="Você é um especialista em $STACK_DETECTED. Este projeto usa $STACK_DETECTED.
Gere um guia conciso de boas práticas e convenções para revisão de código nesta stack.
Foque em: nomenclatura, estrutura de arquivos, padrões idiomáticos, erros comuns, ferramentas de lint/format padrão.
Se houver framework detectado, priorize convenções específicas dele (ex: hooks do React, módulos do Angular, rotas do Next.js).
Máximo 400 palavras. Responda em português."

echo "🧠 Gerando guia de especialista para '$STACK_DETECTED' via Gemini..."

if gemini --yolo -p "$SPECIALIST_PROMPT" > "$OUT_FILE" 2>/dev/null; then
  echo "✅ Guia salvo em $OUT_FILE (agente: Gemini, $(wc -l < "$OUT_FILE") linhas)"
else
  echo "⚠️  Gemini indisponível — usando Claude como fallback..."
  {
    echo "> ⚠️ **Fallback:** guia gerado pelo Claude (Gemini indisponível)"
    echo ""
    claude -p "$SPECIALIST_PROMPT"
  } > "$OUT_FILE"
  echo "✅ Guia salvo em $OUT_FILE (agente: Claude/fallback, $(wc -l < "$OUT_FILE") linhas)"
fi

echo "--- Resumo (primeiras 20 linhas) ---"
head -n 20 "$OUT_FILE"
