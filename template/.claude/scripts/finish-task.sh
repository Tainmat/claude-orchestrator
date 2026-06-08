#!/usr/bin/env bash
# finish-task.sh — Fecha uma tarefa: commit convencional e MR no GitLab.
#
# Fase 1 — COMMIT: lê os arquivos uncommitted, gera mensagem via Gemini e commita.
# Fase 2 — MR: lê o diff completo da branch, gera título/descrição e abre o MR.
#
# Variáveis de ambiente para o MR (ou configure via install.sh):
#   GITLAB_TOKEN       — Personal Access Token (escopo: api)
#   GITLAB_PROJECT_ID  — ID numérico do projeto (Settings > General > Project ID)
#   GITLAB_URL         — URL base do GitLab (padrão: https://gitlab.com)
#
# Uso: finish-task.sh [branch-base-para-diff]
set -euo pipefail

OUT_DIR=".orchestrator"
mkdir -p "$OUT_DIR"

CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"

# ══════════════════════════════════════════════════════════
# FASE 1 — COMMIT
# Gera mensagem de commit a partir do que está uncommitted agora.
# ══════════════════════════════════════════════════════════

UNCOMMITTED_DIFF="$(git diff HEAD 2>/dev/null || true)"
UNCOMMITTED_STATUS="$(git status --short 2>/dev/null || true)"

if [ -z "$UNCOMMITTED_DIFF" ] && [ -z "$UNCOMMITTED_STATUS" ]; then
  echo "ℹ️  Nenhuma alteração uncommitted — pulando fase de commit."
  SKIP_COMMIT=1
else
  SKIP_COMMIT=0
  echo "📋 Arquivos com alterações uncommitted:"
  echo "$UNCOMMITTED_STATUS"
  echo ""

  COMMIT_PROMPT="Você é um especialista em Git. Analise as alterações abaixo e gere UMA mensagem de commit seguindo Conventional Commits.

Arquivos alterados:
$UNCOMMITTED_STATUS

Responda com EXATAMENTE este bloco (sem texto fora dele):

\`\`\`
<tipo>(<escopo>): <mensagem imperativa, max 72 chars, sem ponto final>

<corpo opcional: explique o porquê, não o quê. max 72 chars por linha>
\`\`\`

Tipos: feat, fix, docs, style, refactor, perf, test, chore, ci, build
Escopo: módulo/componente afetado (omita os parênteses se não aplicável)
Idioma: siga o padrão dos commits já existentes (português ou inglês)

=== DIFF ===
$(echo "$UNCOMMITTED_DIFF" | head -c 150000)"

  echo "🧠 Gerando mensagem de commit via Gemini..."
  COMMIT_FILE="$OUT_DIR/commit-msg.md"

  if timeout 30 gemini --yolo -p "$COMMIT_PROMPT" > "$COMMIT_FILE" 2>/dev/null; then
    echo "✅ Mensagem gerada (agente: Gemini)"
  elif timeout 30 gemini --yolo -m gemini-pro -p "$COMMIT_PROMPT" > "$COMMIT_FILE" 2>/dev/null; then
    echo "✅ Mensagem gerada (agente: Gemini Pro)"
  else
    echo "⚠️  Gemini indisponível — usando Codex como fallback..."
    _tmp="$(mktemp)"
    codex exec --sandbox read-only -o "$_tmp" "$COMMIT_PROMPT" 2>/dev/null || true
    cat "$_tmp" > "$COMMIT_FILE"
    rm -f "$_tmp"
    echo "✅ Mensagem gerada (agente: Codex/fallback)"
  fi

  # Extrai a mensagem de dentro do bloco de código
  COMMIT_MSG="$(awk '/^```/{found=!found; next} found{print}' "$COMMIT_FILE" | sed '/^$/d' | head -20)"

  if [ -z "$COMMIT_MSG" ]; then
    echo "⚠️  Não foi possível extrair a mensagem automaticamente. Conteúdo gerado:"
    cat "$COMMIT_FILE"
    echo ""
    read -r -p "Digite a mensagem de commit manualmente: " COMMIT_MSG
  fi

  echo ""
  echo "💾 Mensagem sugerida:"
  echo "───────────────────────────────────────"
  echo "$COMMIT_MSG"
  echo "───────────────────────────────────────"
  echo ""
  read -r -p "Confirma? [s] Editar? [e] Cancelar? [N]: " confirm_commit

  if [[ "$confirm_commit" =~ ^[eE]$ ]]; then
    read -r -p "Nova mensagem de commit: " COMMIT_MSG
    confirm_commit="s"
  fi

  if [[ "$confirm_commit" =~ ^[sS]$ ]]; then
    git add -A
    git commit -m "$COMMIT_MSG"
    echo "✅ Commit feito."
  else
    echo "ℹ️  Commit cancelado."
    exit 0
  fi
fi

# ══════════════════════════════════════════════════════════
# FASE 2 — MERGE REQUEST
# Delega ao script compartilhado: push + geração de título/descrição + API GitLab.
# ══════════════════════════════════════════════════════════

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "$SCRIPT_DIR/create-mr.sh" "${1:-}" "${COMMIT_MSG:-}"
