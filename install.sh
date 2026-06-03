#!/usr/bin/env bash
# install.sh — instala o orquestrador multi-agente num projeto.
#
# Uso local (repo clonado):
#   ./install.sh [caminho-do-projeto]
#
# Uso remoto (sem clonar):
#   curl -fsSL https://raw.githubusercontent.com/Tainmat/claude-orchestrator/main/install.sh | bash -s -- [caminho-do-projeto]
#
# Se nenhum caminho for passado, instala no diretório atual.
set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/Tainmat/claude-orchestrator/main"
MARK_START="<!-- ORCHESTRATOR:START"
MARK_END="<!-- ORCHESTRATOR:END -->"

# --- Descobrir se rodamos a partir de um arquivo local ou via pipe (curl|bash) ---
SRC="${BASH_SOURCE[0]:-}"
if [ -n "$SRC" ] && [ -f "$SRC" ]; then
  SCRIPT_DIR="$(cd "$(dirname "$SRC")" && pwd)"
else
  SCRIPT_DIR=""
fi

if [ -n "$SCRIPT_DIR" ] && [ -d "$SCRIPT_DIR/template" ]; then
  MODE="local"
  TEMPLATE_DIR="$SCRIPT_DIR/template"
else
  MODE="remote"
fi

# --- Destino: argumento 1 ou diretório atual ---
TARGET_ARG="${1:-$(pwd)}"
if [ ! -d "$TARGET_ARG" ]; then
  echo "❌ O caminho de destino não existe: $TARGET_ARG"
  echo "   Dica: troque o placeholder pelo caminho real do seu projeto, ex:"
  echo "   ...| bash -s -- ~/projetos/cclx-frontend"
  exit 1
fi
TARGET="$(cd "$TARGET_ARG" && pwd)"

echo "🎯 Instalando orquestrador em: $TARGET   (modo: $MODE)"
echo ""

# --- Checagem dos 3 CLIs ---
echo "🔍 Verificando os CLIs..."
MISSING=0
for cli in claude codex gemini; do
  if command -v "$cli" >/dev/null 2>&1; then
    echo "   ✅ $cli encontrado"
  else
    echo "   ❌ $cli NÃO encontrado no PATH"
    MISSING=1
  fi
done
if [ "$MISSING" -eq 1 ]; then
  echo ""
  echo "⚠️  Algum CLI está faltando. O orquestrador precisa dos três para funcionar."
  if [ -t 0 ]; then
    read -r -p "Continuar mesmo assim? [s/N] " ans
    [[ "$ans" =~ ^[sS]$ ]] || { echo "Abortado."; exit 1; }
  else
    echo "   (rodando via pipe, seguindo mesmo assim — instale os CLIs depois)"
  fi
fi
echo ""

# --- Configuração de TDD ---
USE_TDD=0
if [ -t 0 ]; then
  read -r -p "🧪 Este projeto usa TDD? [s/N] " tdd_ans
  [[ "$tdd_ans" =~ ^[sS]$ ]] && USE_TDD=1
else
  echo "ℹ️  Rodando via pipe — TDD desativado por padrão. Adicione 'TDD: sempre' ao"
  echo "   CLAUDE.md depois se quiser ativar, ou use a palavra 'TDD' no prompt."
fi
echo ""

# --- Configuração do GitLab ---
GITLAB_CONFIG_FILE="$TARGET/.orchestrator/.gitlab-config"
USE_GITLAB=0
if [ -t 0 ]; then
  read -r -p "🦊 Configurar integração com GitLab? [s/N] " gl_ans
  if [[ "$gl_ans" =~ ^[sS]$ ]]; then
    USE_GITLAB=1
    echo ""
    read -r -p "   URL do GitLab [https://gitlab.com]: " gl_url
    gl_url="${gl_url:-https://gitlab.com}"

    read -r -p "   Personal Access Token (escopo: api — Preferences > Access Tokens): " gl_token
    while [ -z "$gl_token" ]; do
      echo "   ⚠️  Token não pode ser vazio."
      read -r -p "   Personal Access Token: " gl_token
    done

    read -r -p "   Project ID numérico (Settings > General > Project ID): " gl_project
    while [ -z "$gl_project" ]; do
      echo "   ⚠️  Project ID não pode ser vazio."
      read -r -p "   Project ID: " gl_project
    done

    mkdir -p "$(dirname "$GITLAB_CONFIG_FILE")"
    cat > "$GITLAB_CONFIG_FILE" <<EOF
# Configuração GitLab — gerado por install.sh
# Este arquivo é local e está no .gitignore (.orchestrator/)
export GITLAB_URL="$gl_url"
export GITLAB_TOKEN="$gl_token"
export GITLAB_PROJECT_ID="$gl_project"
EOF
    echo "✅ Configuração GitLab salva em .orchestrator/.gitlab-config"
  else
    echo "ℹ️  GitLab não configurado. Defina GITLAB_TOKEN, GITLAB_PROJECT_ID e"
    echo "   opcionalmente GITLAB_URL no ambiente, ou rode install.sh novamente."
  fi
else
  echo "ℹ️  Rodando via pipe — GitLab não configurado. Defina as variáveis manualmente"
  echo "   ou execute: bash install.sh $TARGET"
fi
echo ""

# --- Função que obtém um arquivo do template: copia (local) ou baixa (remote) ---
fetch() {
  local rel="$1" dest="$2"
  mkdir -p "$(dirname "$dest")"
  if [ "$MODE" = "local" ]; then
    cp "$TEMPLATE_DIR/$rel" "$dest"
  else
    curl -fsSL "$REPO_RAW/template/$rel" -o "$dest"
  fi
}

# Pega o conteúdo do bloco de orquestração (de arquivo local ou da web) para stdout
get_block() {
  if [ "$MODE" = "local" ]; then
    cat "$TEMPLATE_DIR/orchestrator-block.md"
  else
    curl -fsSL "$REPO_RAW/template/orchestrator-block.md"
  fi
}

# --- CLAUDE.md: anexa o bloco no TOPO (ou cria) ---
CLAUDE_FILE="$TARGET/CLAUDE.md"
TMP_BLOCK="$(mktemp)"
get_block > "$TMP_BLOCK"

if [ -f "$CLAUDE_FILE" ]; then
  if grep -qF "$MARK_START" "$CLAUDE_FILE"; then
    echo "ℹ️  Bloco de orquestração já existe no CLAUDE.md — pulando (use --force para atualizar)."
  else
    # Anexa o bloco no topo, preservando o conteúdo existente abaixo
    TMP_NEW="$(mktemp)"
    cat "$TMP_BLOCK" > "$TMP_NEW"
    echo "" >> "$TMP_NEW"
    echo "---" >> "$TMP_NEW"
    echo "" >> "$TMP_NEW"
    cat "$CLAUDE_FILE" >> "$TMP_NEW"
    if [ "$USE_TDD" -eq 1 ]; then
      echo "" >> "$TMP_NEW"
      echo "TDD: sempre" >> "$TMP_NEW"
    fi
    mv "$TMP_NEW" "$CLAUDE_FILE"
    if [ "$USE_TDD" -eq 1 ]; then
      echo "✅ Bloco de orquestração anexado no TOPO do CLAUDE.md existente (TDD ativado)"
    else
      echo "✅ Bloco de orquestração anexado no TOPO do CLAUDE.md existente"
    fi
  fi
else
  # Cria um CLAUDE.md novo só com o bloco + um placeholder pras regras do projeto
  {
    cat "$TMP_BLOCK"
    echo ""
    echo "---"
    echo ""
    echo "# Regras do projeto"
    echo ""
    echo "<!-- Adicione aqui o stack, comandos e convenções específicas do seu projeto. -->"
    if [ "$USE_TDD" -eq 1 ]; then
      echo ""
      echo "TDD: sempre"
    fi
  } > "$CLAUDE_FILE"
  if [ "$USE_TDD" -eq 1 ]; then
    echo "✅ CLAUDE.md criado com o bloco de orquestração (TDD ativado)"
  else
    echo "✅ CLAUDE.md criado com o bloco de orquestração"
  fi
fi
rm -f "$TMP_BLOCK"

# --- Scripts ---
for s in scan.sh execute.sh review.sh finish-task.sh commit.sh specialist.sh; do
  fetch ".claude/scripts/$s" "$TARGET/.claude/scripts/$s"
done
chmod +x "$TARGET/.claude/scripts/"*.sh
echo "✅ Scripts copiados para .claude/scripts/ (executáveis)"

# --- settings.json (guarda contra sobrescrever) ---
if [ -f "$TARGET/.claude/settings.json" ]; then
  echo "⚠️  Já existe .claude/settings.json — salvando como settings.orchestrator.json."
  echo "   Mescle as permissões de auto-approve manualmente."
  fetch ".claude/settings.json" "$TARGET/.claude/settings.orchestrator.json"
else
  fetch ".claude/settings.json" "$TARGET/.claude/settings.json"
  echo "✅ settings.json copiado (auto-approve dos scripts)"
fi

# --- .gitignore ---
GITIGNORE="$TARGET/.gitignore"
if ! grep -q "^\.orchestrator/" "$GITIGNORE" 2>/dev/null; then
  echo ".orchestrator/" >> "$GITIGNORE"
  echo "✅ .orchestrator/ adicionado ao .gitignore"
else
  echo "ℹ️  .orchestrator/ já está no .gitignore"
fi

echo ""
echo "🎉 Pronto! Para usar:"
echo "   cd \"$TARGET\""
echo "   claude"
echo ""
echo "   ⚠️  Teste primeiro num branch descartável — o Codex edita arquivos de verdade."
