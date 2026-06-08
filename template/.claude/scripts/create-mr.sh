#!/usr/bin/env bash
# create-mr.sh — Faz push da branch atual e abre um Merge Request no GitLab.
#
# Pode ser chamado diretamente ou por outros scripts (commit.sh, finish-task.sh).
#
# Variáveis de ambiente necessárias:
#   GITLAB_TOKEN       — Personal Access Token (escopo: api)
#   GITLAB_PROJECT_ID  — ID numérico do projeto (Settings > General > Project ID)
#   GITLAB_URL         — URL base do GitLab (padrão: https://gitlab.com)
#
# Uso: create-mr.sh [branch-destino] [titulo-fallback]
#   branch-destino  : branch de destino do MR (interativo se omitido)
#   titulo-fallback : título usado se a geração via Gemini falhar
set -euo pipefail

OUT_DIR=".orchestrator"
mkdir -p "$OUT_DIR"

CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"

# ──────────────────────────────────────────────────────────────
# PUSH
# ──────────────────────────────────────────────────────────────
echo ""
read -r -p "Fazer push da branch '$CURRENT_BRANCH'? [s/N] " confirm_push
if [[ ! "$confirm_push" =~ ^[sS]$ ]]; then
  echo "ℹ️  Push cancelado. Faça manualmente: git push origin $CURRENT_BRANCH"
  exit 0
fi
git push origin "$CURRENT_BRANCH"
echo "✅ Push feito."

# ──────────────────────────────────────────────────────────────
# CONFIRMAÇÃO DO MR
# ──────────────────────────────────────────────────────────────
echo ""
read -r -p "Criar Merge Request no GitLab? [s/N] " confirm_mr
if [[ ! "$confirm_mr" =~ ^[sS]$ ]]; then
  echo "ℹ️  MR não criado."
  exit 0
fi

# ──────────────────────────────────────────────────────────────
# BRANCH DE DESTINO
# ──────────────────────────────────────────────────────────────
MR_TARGET="${1:-}"

if [ -z "$MR_TARGET" ]; then
  echo ""
  echo "Branch atual: $CURRENT_BRANCH"
  read -r -p "Branch de DESTINO do MR (ex: develop, main, staging): " MR_TARGET
  while [ -z "$MR_TARGET" ]; do
    echo "   ⚠️  Branch de destino é obrigatória."
    read -r -p "Branch de DESTINO do MR: " MR_TARGET
  done
fi

FALLBACK_TITLE="${2:-$CURRENT_BRANCH}"

# ──────────────────────────────────────────────────────────────
# CREDENCIAIS GITLAB
# ──────────────────────────────────────────────────────────────
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

# ──────────────────────────────────────────────────────────────
# DIFF DA BRANCH (base automática)
# ──────────────────────────────────────────────────────────────
if git rev-parse --verify "origin/$MR_TARGET" >/dev/null 2>&1; then
  MERGE_BASE="$(git merge-base "origin/$MR_TARGET" HEAD)"
elif git rev-parse --verify "$MR_TARGET" >/dev/null 2>&1; then
  MERGE_BASE="$(git merge-base "$MR_TARGET" HEAD)"
else
  echo "⚠️  Branch '$MR_TARGET' não encontrada para calcular o diff — usando HEAD~1."
  MERGE_BASE="$(git rev-parse HEAD~1 2>/dev/null || git rev-parse HEAD)"
fi

BRANCH_DIFF="$(git diff "$MERGE_BASE"...HEAD 2>/dev/null | head -c 200000 || true)"
BRANCH_COMMITS="$(git log "$MERGE_BASE"..HEAD --oneline 2>/dev/null || true)"
BRANCH_FILES="$(git diff "$MERGE_BASE"...HEAD --name-only 2>/dev/null | sort | uniq || true)"
BRANCH_STAT="$(git diff "$MERGE_BASE"...HEAD --stat 2>/dev/null | head -50 || true)"

# Extrai ranges de linhas modificadas por arquivo (ex: 301-305 | 315 | 410-413)
BRANCH_RANGES="$(git diff "$MERGE_BASE"...HEAD 2>/dev/null | awk '
/^diff --git/ { file=$3; sub(/^a\//, "", file) }
/^@@ / {
  match($0, /\+([0-9]+)(,([0-9]+))?/, arr)
  start = arr[1]+0
  count = (arr[3] != "" ? arr[3]+0 : 1)
  if (count == 0) next
  end = start + count - 1
  range = (count == 1 ? start : start"-"end)
  ranges[file] = (ranges[file] == "" ? range : ranges[file] " | " range)
}
END { for (f in ranges) printf "%s\t%s\n", f, ranges[f] }
' | sort || true)"

# ──────────────────────────────────────────────────────────────
# GERAÇÃO DO TÍTULO E DESCRIÇÃO VIA GEMINI
# ──────────────────────────────────────────────────────────────
echo ""
echo "📝 Gerando título e descrição do MR via Gemini..."

MR_PROMPT="Você é um tech lead revisando código. Crie o título e a descrição de um Merge Request.

Branch: $CURRENT_BRANCH → $MR_TARGET
Commits incluídos:
$BRANCH_COMMITS

Ranges de linhas modificadas por arquivo (formato: arquivo <TAB> range1 | range2):
$BRANCH_RANGES

Retorne ESTRITAMENTE em JSON válido com as chaves 'title' e 'description'. Sem blocos de código em volta, sem texto extra.
- 'title': string descritiva (max 72 chars)
- 'description': markdown com EXATAMENTE estas seções nesta ordem:

## O que foi feito
(bullet points descrevendo as mudanças)

## Arquivos alterados
(tabela markdown com colunas: Arquivo | Linhas modificadas — use os ranges fornecidos, ex: 301-305 | 315 | 410-413)

## Motivação
(explique o porquê da mudança)

## Como testar
(checklist markdown com checkboxes: - [ ] passo 1, - [ ] passo 2, etc.)

=== DIFF ===
$BRANCH_DIFF"

_mr_tmp="$(mktemp)"
if timeout 60 gemini --yolo -p "$MR_PROMPT" > "$_mr_tmp" 2>/dev/null; then
  echo "✅ Descrição gerada (agente: Gemini)"
elif timeout 60 gemini --yolo -m gemini-pro -p "$MR_PROMPT" > "$_mr_tmp" 2>/dev/null; then
  echo "✅ Descrição gerada (agente: Gemini Pro)"
else
  echo "⚠️  Gemini indisponível — usando Codex como fallback..."
  codex exec --sandbox read-only -o "$_mr_tmp" "$MR_PROMPT" 2>/dev/null || true
  echo "✅ Descrição gerada (agente: Codex/fallback)"
fi

MR_DATA="$(cat "$_mr_tmp")"
rm -f "$_mr_tmp"

MR_TITLE=""
MR_DESC=""
if [ -n "$MR_DATA" ]; then
  MR_TITLE="$(echo "$MR_DATA" | jq -r '.title // empty' 2>/dev/null || true)"
  MR_DESC="$(echo "$MR_DATA"  | jq -r '.description // empty' 2>/dev/null || true)"
fi

# Fallback se Gemini falhou ou não retornou JSON válido
if [ -z "$MR_TITLE" ]; then
  MR_TITLE="$FALLBACK_TITLE"
fi
if [ -z "$MR_DESC" ]; then
  MR_DESC="Branch: \`$CURRENT_BRANCH\` → \`$MR_TARGET\`

## O que foi feito
$BRANCH_COMMITS

## Arquivos alterados
$BRANCH_FILES"
fi

# ──────────────────────────────────────────────────────────────
# LINK DE TAREFA (opcional)
# ──────────────────────────────────────────────────────────────
echo ""
read -r -p "Link da tarefa (ClickUp, Jira, Linear…) [Enter para pular]: " TASK_LINK
if [ -n "$TASK_LINK" ]; then
  MR_DESC="$MR_DESC

---
🔗 Tarefa: $TASK_LINK"
fi

# ──────────────────────────────────────────────────────────────
# REVISÃO ANTES DE CRIAR
# ──────────────────────────────────────────────────────────────
echo ""
echo "┌─────────────────────────────────────────────────────────────"
echo "│  Título : $MR_TITLE"
echo "├─────────────────────────────────────────────────────────────"
echo "$MR_DESC" | sed 's/^/│  /'
echo "└─────────────────────────────────────────────────────────────"
echo ""
read -r -p "Confirma? [s] Editar título? [t] Cancelar? [N]: " confirm_create

if [[ "$confirm_create" =~ ^[tT]$ ]]; then
  read -r -p "Novo título (Enter para manter): " new_title
  [ -n "$new_title" ] && MR_TITLE="$new_title"
  confirm_create="s"
fi

if [[ ! "$confirm_create" =~ ^[sS]$ ]]; then
  echo "ℹ️  MR não criado."
  exit 0
fi

# ──────────────────────────────────────────────────────────────
# CRIAÇÃO VIA API GITLAB
# ──────────────────────────────────────────────────────────────
echo "🌐 Criando MR: $CURRENT_BRANCH → $MR_TARGET"

RESPONSE="$(curl -s -X POST \
  "$GITLAB_URL/api/v4/projects/$GITLAB_PROJECT_ID/merge_requests" \
  -H "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$(jq -n \
    --arg src   "$CURRENT_BRANCH" \
    --arg tgt   "$MR_TARGET" \
    --arg title "$MR_TITLE" \
    --arg desc  "$MR_DESC" \
    '{source_branch: $src, target_branch: $tgt, title: $title, description: $desc}'
  )")"

MR_URL="$(echo "$RESPONSE" | jq -r '.web_url // empty' 2>/dev/null || true)"

if [ -n "$MR_URL" ]; then
  echo ""
  echo "✅ Merge Request criado: $MR_URL"
else
  echo "❌ Erro ao criar o MR."
  echo "$RESPONSE" | jq . 2>/dev/null || echo "$RESPONSE"
  exit 1
fi
