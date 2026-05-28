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

# --- CLAUDE.md (guarda contra sobrescrever) ---
if [ -f "$TARGET/CLAUDE.md" ]; then
  echo "⚠️  Já existe CLAUDE.md — salvando como CLAUDE.orchestrator.md para você mesclar."
  fetch "CLAUDE.md" "$TARGET/CLAUDE.orchestrator.md"
else
  fetch "CLAUDE.md" "$TARGET/CLAUDE.md"
  echo "✅ CLAUDE.md copiado para a raiz"
fi

# --- Scripts ---
for s in scan.sh execute.sh review.sh; do
  fetch ".claude/scripts/$s" "$TARGET/.claude/scripts/$s"
done
chmod +x "$TARGET/.claude/scripts/"*.sh
echo "✅ Scripts copiados para .claude/scripts/ (executáveis)"

# --- settings.json (guarda contra sobrescrever) ---
if [ -f "$TARGET/.claude/settings.json" ]; then
  echo "⚠️  Já existe .claude/settings.json — salvando como settings.orchestrator.json."
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
