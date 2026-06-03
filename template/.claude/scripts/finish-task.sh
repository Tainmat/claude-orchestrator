#!/usr/bin/env bash
# finish-task.sh — Review de branch via Gemini, commit convencional e MR no GitLab.
#
# Variáveis de ambiente necessárias para criar MR:
#   GITLAB_TOKEN       — Personal Access Token com escopo "api"
#                        (GitLab > Preferences > Access Tokens > escopo: api)
#   GITLAB_PROJECT_ID  — ID numérico do projeto (Settings > General > Project ID)
#   GITLAB_URL         — URL base do GitLab (padrão: https://gitlab.com)
#
# Alternativa: rode install.sh para configurar interativamente.
# As variáveis ficam em .orchestrator/.gitlab-config (gitignored).
#
# Uso: finish-task.sh [branch-base]
# Ex:  finish-task.sh main
#      finish-task.sh develop
set -euo pipefail

OUT_DIR=".orchestrator"
FINISH_FILE="$OUT_DIR/finish-task.md"
mkdir -p "$OUT_DIR"

# --- Detecta branch base ---
if [ -n "${1:-}" ]; then
  BASE_BRANCH="$1"
else
  BASE_BRANCH="$(git remote show origin 2>/dev/null | grep 'HEAD branch' | awk '{print $NF}' || true)"
  if [ -z "$BASE_BRANCH" ]; then
    for candidate in main master develop; do
      if git rev-parse --verify "origin/$candidate" >/dev/null 2>&1 || \
         git rev-parse --verify "$candidate" >/dev/null 2>&1; then
        BASE_BRANCH="$candidate"
        break
      fi
    done
  fi
  BASE_BRANCH="${BASE_BRANCH:-main}"
fi

CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"

# --- Calcula merge-base ---
if git rev-parse --verify "origin/$BASE_BRANCH" >/dev/null 2>&1; then
  MERGE_BASE="$(git merge-base "origin/$BASE_BRANCH" HEAD)"
elif git rev-parse --verify "$BASE_BRANCH" >/dev/null 2>&1; then
  MERGE_BASE="$(git merge-base "$BASE_BRANCH" HEAD)"
else
  echo "❌ Branch base '$BASE_BRANCH' não encontrada (local ou remota)."
  exit 1
fi

DIFF="$(git diff "$MERGE_BASE"...HEAD 2>/dev/null || true)"
COMMITS="$(git log "$MERGE_BASE"..HEAD --oneline 2>/dev/null || true)"
FILES_CHANGED="$(git diff "$MERGE_BASE"...HEAD --name-only 2>/dev/null | sort | uniq || true)"
STATS="$(git diff "$MERGE_BASE"...HEAD --stat 2>/dev/null | tail -1 || true)"

if [ -z "$DIFF" ]; then
  echo "⚠️  Nenhuma diferença entre '$CURRENT_BRANCH' e '$BASE_BRANCH'."
  exit 2
fi

DIFF_TRUNCATED="$(echo "$DIFF" | head -c 200000)"

# --- 1. Review + Commit message via Gemini ---
echo "🔍 Analisando branch '$CURRENT_BRANCH' vs '$BASE_BRANCH'..."

PROMPT="Você é um revisor de código sênior. Analise o diff abaixo de uma branch de feature.

Branch: $CURRENT_BRANCH → $BASE_BRANCH
Commits:
$COMMITS

Arquivos alterados:
$FILES_CHANGED

Resumo: $STATS

Responda em markdown com EXATAMENTE esta estrutura (não adicione texto fora dela):

## Review

APROVADO | CORREÇÕES_NECESSÁRIAS

(2-4 linhas descrevendo o que foi alterado, qualidade e riscos. Seja direto.)

## Problemas
(lista numerada; vazia se aprovado. Formato: arquivo:linha — problema — sugestão)

## Commit Sugerido

\`\`\`
<tipo>(<escopo>): <mensagem imperativa, max 72 chars, sem ponto final>

<corpo opcional: explique o porquê, não o quê. max 72 chars por linha>

<BREAKING CHANGE: descrição — omita se não houver>
\`\`\`

Tipos válidos: feat, fix, docs, style, refactor, perf, test, chore, ci, build
Escopo: módulo/componente afetado (omita os parênteses se não aplicável)
Mensagem: em português ou inglês conforme o padrão dos commits existentes

=== DIFF ===
$DIFF_TRUNCATED"

if gemini --yolo -p "$PROMPT" > "$FINISH_FILE" 2>/dev/null; then
  echo "✅ Análise salva em $FINISH_FILE (agente: Gemini)"
else
  echo "⚠️  Gemini indisponível — usando Claude como fallback..."
  {
    echo "> ⚠️ **Fallback:** análise gerada pelo Claude (Gemini indisponível)"
    echo ""
    claude -p "$PROMPT"
  } > "$FINISH_FILE"
  echo "✅ Análise salva em $FINISH_FILE (agente: Claude/fallback)"
fi

echo ""
echo "--- Review e commit sugerido ---"
cat "$FINISH_FILE"
echo ""

# --- 2. Extrai mensagem de commit do arquivo gerado ---
COMMIT_MSG="$(awk '/^```$/{found=1; next} found && /^```$/{exit} found{print}' "$FINISH_FILE" | head -1)"

if [ -z "$COMMIT_MSG" ]; then
  echo "⚠️  Não foi possível extrair a mensagem de commit automaticamente."
  echo "   Verifique $FINISH_FILE e faça o commit manualmente."
  exit 0
fi

echo "💾 Mensagem de commit extraída:"
echo "   $COMMIT_MSG"
echo ""

# --- 3. Confirmação do commit ---
if [ -t 0 ]; then
  read -r -p "Confirma o commit? [s/N] " confirm_commit
else
  echo "ℹ️  Não interativo — pulando commit automático. Faça manualmente:"
  echo "   git add -A && git commit -m \"$COMMIT_MSG\""
  exit 0
fi

if [[ "$confirm_commit" =~ ^[sS]$ ]]; then
  git add -A
  git commit -m "$COMMIT_MSG"
  echo "✅ Commit feito."
else
  echo "ℹ️  Commit cancelado."
  exit 0
fi

# --- 4. Push ---
echo ""
read -r -p "Fazer push da branch '$CURRENT_BRANCH'? [s/N] " confirm_push
if [[ "$confirm_push" =~ ^[sS]$ ]]; then
  git push origin "$CURRENT_BRANCH"
  echo "✅ Push feito."
else
  echo "ℹ️  Push cancelado. Faça manualmente: git push origin $CURRENT_BRANCH"
  exit 0
fi

# --- 5. Merge Request no GitLab ---
echo ""
read -r -p "Criar Merge Request no GitLab? [s/N] " confirm_mr
if [[ ! "$confirm_mr" =~ ^[sS]$ ]]; then
  echo "ℹ️  MR não criado."
  exit 0
fi

read -r -p "Branch de destino do MR [$BASE_BRANCH]: " MR_TARGET
MR_TARGET="${MR_TARGET:-$BASE_BRANCH}"

# Carrega config local do projeto se existir (criada pelo install.sh)
GITLAB_CONFIG=".orchestrator/.gitlab-config"
if [ -f "$GITLAB_CONFIG" ]; then
  # shellcheck source=/dev/null
  source "$GITLAB_CONFIG"
fi

# Verifica variáveis necessárias
GITLAB_URL="${GITLAB_URL:-https://gitlab.com}"
if [ -z "${GITLAB_TOKEN:-}" ]; then
  echo "❌ GITLAB_TOKEN não definido."
  echo "   Adicione ao ~/.bashrc ou ~/.zshrc:"
  echo "   export GITLAB_TOKEN=\"seu-personal-access-token\""
  echo "   export GITLAB_PROJECT_ID=\"id-numerico-do-projeto\""
  echo "   export GITLAB_URL=\"https://seu-gitlab.empresa.com\"  # se não for gitlab.com"
  exit 1
fi
if [ -z "${GITLAB_PROJECT_ID:-}" ]; then
  echo "❌ GITLAB_PROJECT_ID não definido."
  echo "   Encontre em: Settings > General > Project ID"
  echo "   export GITLAB_PROJECT_ID=\"123\""
  exit 1
fi

# Gera título e descrição do MR via Gemini
echo "📝 Elaborando título e descrição do MR..."

MR_PROMPT="Você é um tech lead revisando código. Com base no diff abaixo, crie o título e a descrição de um Merge Request.

Branch: $CURRENT_BRANCH → $BASE_BRANCH
Commits: $COMMITS

Retorne ESTRITAMENTE em JSON válido com as chaves 'title' e 'description'. Sem blocos de código em volta, sem texto extra.
'title': string curta e descritiva (max 72 chars)
'description': markdown com o que foi feito, por quê e como testar

=== DIFF ===
$DIFF_TRUNCATED"

MR_DATA="$(gemini --yolo -p "$MR_PROMPT" 2>/dev/null || echo '')"

if [ -z "$MR_DATA" ]; then
  # Fallback: usa o commit msg como título
  MR_TITLE="$COMMIT_MSG"
  MR_DESC="$(cat "$FINISH_FILE")"
else
  MR_TITLE="$(echo "$MR_DATA" | jq -r '.title // empty' 2>/dev/null || echo "$COMMIT_MSG")"
  MR_DESC="$(echo "$MR_DATA" | jq -r '.description // empty' 2>/dev/null || cat "$FINISH_FILE")"
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
