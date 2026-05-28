#!/usr/bin/env bash
# install.sh — instala o orquestrador multi-agente num projeto.
#
# Uso:
#   ./install.sh [caminho-do-projeto]
#
# Se nenhum caminho for passado, instala no diretório atual.
# Pode também ser rodado via curl (veja README).
set -euo pipefail

# Onde está este script (raiz do repo)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="$SCRIPT_DIR/template"

# Destino: argumento 1 ou diretório atual
TARGET="${1:-$(pwd)}"
TARGET="$(cd "$TARGET" && pwd)"

echo "🎯 Instalando orquestrador em: $TARGET"
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
  read -r -p "Continuar mesmo assim? [s/N] " ans
  [[ "$ans" =~ ^[sS]$ ]] || { echo "Abortado."; exit 1; }
fi
echo ""

# --- Guarda: CLAUDE.md já existe? ---
if [ -f "$TARGET/CLAUDE.md" ]; then
  echo "⚠️  Já existe um CLAUDE.md no destino."
  echo "   Para não sobrescrever, vou salvar o do orquestrador como CLAUDE.orchestrator.md"
  echo "   Junte o conteúdo manualmente se quiser."
  cp "$TEMPLATE_DIR/CLAUDE.md" "$TARGET/CLAUDE.orchestrator.md"
else
  cp "$TEMPLATE_DIR/CLAUDE.md" "$TARGET/CLAUDE.md"
  echo "✅ CLAUDE.md copiado para a raiz"
fi

# --- Copia a pasta .claude (merge, sem apagar config existente) ---
mkdir -p "$TARGET/.claude/scripts"
cp "$TEMPLATE_DIR/.claude/scripts/"*.sh "$TARGET/.claude/scripts/"
chmod +x "$TARGET/.claude/scripts/"*.sh
echo "✅ Scripts copiados para .claude/scripts/ (executáveis)"

# settings.json: merge cuidadoso se já existir
if [ -f "$TARGET/.claude/settings.json" ]; then
  echo "⚠️  Já existe .claude/settings.json — salvando o do orquestrador como"
  echo "   .claude/settings.orchestrator.json para você mesclar as permissões."
  cp "$TEMPLATE_DIR/.claude/settings.json" "$TARGET/.claude/settings.orchestrator.json"
else
  cp "$TEMPLATE_DIR/.claude/settings.json" "$TARGET/.claude/settings.json"
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
echo "   Depois é só pedir uma tarefa. O Claude vai orquestrar Gemini e Codex."
echo "   ⚠️  Teste primeiro num branch descartável — o Codex edita arquivos de verdade."
