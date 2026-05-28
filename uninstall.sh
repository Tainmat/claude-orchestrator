#!/usr/bin/env bash
# uninstall.sh — remove o orquestrador de um projeto.
# Remove o bloco de orquestração do CLAUDE.md (entre marcadores) preservando
# as regras do projeto, e apaga scripts e arquivos auxiliares.
# Uso: ./uninstall.sh [caminho-do-projeto]
set -euo pipefail

TARGET="${1:-$(pwd)}"
TARGET="$(cd "$TARGET" && pwd)"

echo "🧹 Removendo orquestrador de: $TARGET"
if [ -t 0 ]; then
  read -r -p "Confirmar? [s/N] " ans
  [[ "$ans" =~ ^[sS]$ ]] || { echo "Abortado."; exit 1; }
fi

CLAUDE_FILE="$TARGET/CLAUDE.md"
if [ -f "$CLAUDE_FILE" ] && grep -qF "<!-- ORCHESTRATOR:START" "$CLAUDE_FILE"; then
  # Remove tudo entre START e END (inclusive), e a linha "---" separadora logo após
  awk '
    /<!-- ORCHESTRATOR:START/ { skip=1 }
    skip && /<!-- ORCHESTRATOR:END -->/ { skip=0; next }
    !skip { print }
  ' "$CLAUDE_FILE" > "$CLAUDE_FILE.tmp"
  # Tira linhas em branco e "---" sobrando no topo
  sed -i '/./,$!d' "$CLAUDE_FILE.tmp"
  awk 'NR==1 && $0=="---"{next} NR==1 && $0==""{next} {print}' "$CLAUDE_FILE.tmp" > "$CLAUDE_FILE"
  rm -f "$CLAUDE_FILE.tmp"
  echo "✅ Bloco de orquestração removido do CLAUDE.md (regras do projeto preservadas)"
fi

rm -f "$TARGET/.claude/scripts/scan.sh" \
      "$TARGET/.claude/scripts/execute.sh" \
      "$TARGET/.claude/scripts/review.sh"
rm -f "$TARGET/.claude/settings.orchestrator.json"
rm -rf "$TARGET/.orchestrator"
rmdir "$TARGET/.claude/scripts" 2>/dev/null || true

echo "✅ Scripts e arquivos auxiliares removidos."
echo "ℹ️  .claude/settings.json e a pasta .claude foram preservados se tinham"
echo "   outras configs suas — confira manualmente."
