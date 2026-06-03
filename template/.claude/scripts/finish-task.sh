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

  if gemini --yolo -p "$COMMIT_PROMPT" > "$COMMIT_FILE" 2>/dev/null; then
    echo "✅ Mensagem gerada (agente: Gemini)"
  else
    echo "⚠️  Gemini indisponível — usando Claude como fallback..."
    claude -p "$COMMIT_PROMPT" > "$COMMIT_FILE"
    echo "✅ Mensagem gerada (agente: Claude/fallback)"
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
# Usa o diff completo da branch para gerar o MR.
# ══════════════════════════════════════════════════════════

echo ""
read -r -p "Fazer push da branch '$CURRENT_BRANCH'? [s/N] " confirm_push
if [[ "$confirm_push" =~ ^[sS]$ ]]; then
  git push origin "$CURRENT_BRANCH"
  echo "✅ Push feito."
else
  echo "ℹ️  Push cancelado. Faça manualmente: git push origin $CURRENT_BRANCH"
  exit 0
fi

echo ""
read -r -p "Criar Merge Request no GitLab? [s/N] " confirm_mr
if [[ ! "$confirm_mr" =~ ^[sS]$ ]]; then
  echo "ℹ️  MR não criado."
  exit 0
fi

# Pergunta explícita — sem assumir branch
echo ""
echo "Branch atual: $CURRENT_BRANCH"
read -r -p "Branch de DESTINO do MR (ex: develop, main, staging): " MR_TARGET
while [ -z "$MR_TARGET" ]; do
  echo "   ⚠️  Branch de destino é obrigatória."
  read -r -p "Branch de DESTINO do MR: " MR_TARGET
done

# Carrega config local do projeto se existir (criada pelo install.sh)
GITLAB_CONFIG=".orchestrator/.gitlab-config"
if [ -f "$GITLAB_CONFIG" ]; then
  # shellcheck source=/dev/null
  source "$GITLAB_CONFIG"
fi

GITLAB_URL="${GITLAB_URL:-https://gitlab.com}"
if [ -z "${GITLAB_TOKEN:-}" ]; then
  echo "❌ GITLAB_TOKEN não definido."
  echo "   Configure via install.sh ou adicione ao ~/.zshrc:"
  echo "   export GITLAB_TOKEN=\"glpat-xxxx\""
  echo "   export GITLAB_PROJECT_ID=\"123\""
  echo "   export GITLAB_URL=\"https://gitlab.minhaempresa.com\""
  exit 1
fi
if [ -z "${GITLAB_PROJECT_ID:-}" ]; then
  echo "❌ GITLAB_PROJECT_ID não definido."
  echo "   Encontre em: Settings > General > Project ID"
  exit 1
fi

# Diff completo da branch para o MR (detecta base automaticamente)
if [ -n "${1:-}" ]; then
  BASE_BRANCH="$1"
else
  BASE_BRANCH="$MR_TARGET"
fi

if git rev-parse --verify "origin/$BASE_BRANCH" >/dev/null 2>&1; then
  MERGE_BASE="$(git merge-base "origin/$BASE_BRANCH" HEAD)"
elif git rev-parse --verify "$BASE_BRANCH" >/dev/null 2>&1; then
  MERGE_BASE="$(git merge-base "$BASE_BRANCH" HEAD)"
else
  echo "⚠️  Branch '$BASE_BRANCH' não encontrada para calcular o diff — usando HEAD~1."
  MERGE_BASE="$(git rev-parse HEAD~1 2>/dev/null || git rev-parse HEAD)"
fi

BRANCH_DIFF="$(git diff "$MERGE_BASE"...HEAD 2>/dev/null | head -c 200000 || true)"
BRANCH_COMMITS="$(git log "$MERGE_BASE"..HEAD --oneline 2>/dev/null || true)"
BRANCH_FILES="$(git diff "$MERGE_BASE"...HEAD --name-only 2>/dev/null | sort | uniq || true)"

echo ""
echo "📝 Gerando título e descrição do MR via Gemini..."

MR_PROMPT="Você é um tech lead revisando código. Crie o título e a descrição de um Merge Request.

Branch: $CURRENT_BRANCH → $MR_TARGET
Commits incluídos:
$BRANCH_COMMITS

Arquivos alterados:
$BRANCH_FILES

Retorne ESTRITAMENTE em JSON válido com as chaves 'title' e 'description'. Sem blocos de código em volta, sem texto extra.
- 'title': string descritiva (max 72 chars)
- 'description': markdown estruturado com o que foi feito, motivação e como testar

=== DIFF ===
$BRANCH_DIFF"

MR_DATA="$(gemini --yolo -p "$MR_PROMPT" 2>/dev/null || echo '')"

if [ -n "$MR_DATA" ]; then
  MR_TITLE="$(echo "$MR_DATA" | jq -r '.title // empty' 2>/dev/null || true)"
  MR_DESC="$(echo "$MR_DATA" | jq -r '.description // empty' 2>/dev/null || true)"
fi

# Fallback se Gemini falhou ou não retornou JSON válido
if [ -z "${MR_TITLE:-}" ]; then
  MR_TITLE="${COMMIT_MSG:-$CURRENT_BRANCH}"
fi
if [ -z "${MR_DESC:-}" ]; then
  MR_DESC="Branch: \`$CURRENT_BRANCH\` → \`$MR_TARGET\`

Commits:
$BRANCH_COMMITS

Arquivos:
$BRANCH_FILES"
fi

echo "🌐 Criando MR: $CURRENT_BRANCH → $MR_TARGET"

RESPONSE="$(curl -s -X POST \
  "$GITLAB_URL/api/v4/projects/$GITLAB_PROJECT_ID/merge_requests" \
  -H "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$(jq -n \
    --arg src "$CURRENT_BRANCH" \
    --arg tgt "$MR_TARGET" \
    --arg title "$MR_TITLE" \
    --arg desc "$MR_DESC" \
    '{source_branch: $src, target_branch: $tgt, title: $title, description: $desc}'
  )")"

MR_URL="$(echo "$RESPONSE" | jq -r '.web_url // empty' 2>/dev/null || true)"

if [ -n "$MR_URL" ]; then
  echo ""
  echo "✅ Merge Request criado: $MR_URL"
else
  echo "❌ Erro ao criar o MR."
  echo "$RESPONSE" | jq . 2>/dev/null || echo "$RESPONSE"
fi
