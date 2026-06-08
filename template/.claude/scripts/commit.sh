#!/usr/bin/env bash
# commit.sh — Gera mensagem de commit via Gemini e commita após confirmação.
# Chamado automaticamente ao final do fluxo de orquestração (veredito APROVADO).
# Não faz push nem cria MR — use finish-task.sh para o fluxo completo.
set -euo pipefail

OUT_DIR=".orchestrator"
mkdir -p "$OUT_DIR"

UNCOMMITTED_DIFF="$(git diff HEAD 2>/dev/null || true)"
UNCOMMITTED_STATUS="$(git status --short 2>/dev/null || true)"

if [ -z "$UNCOMMITTED_DIFF" ] && [ -z "$UNCOMMITTED_STATUS" ]; then
  echo "ℹ️  Nenhuma alteração uncommitted — nada para commitar."
  exit 0
fi

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

# ──────────────────────────────────────────────────────────────
# OPCIONAL — MERGE REQUEST
# ──────────────────────────────────────────────────────────────
echo ""
read -r -p "Deseja criar um Merge Request agora? [s/N] " confirm_mr_now
if [[ "$confirm_mr_now" =~ ^[sS]$ ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  bash "$SCRIPT_DIR/create-mr.sh" "" "$COMMIT_MSG"
fi
