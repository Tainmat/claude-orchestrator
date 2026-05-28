#!/usr/bin/env bash
# uninstall.sh — remove o orquestrador de um projeto.
# Uso: ./uninstall.sh [caminho-do-projeto]
set -euo pipefail

TARGET="${1:-$(pwd)}"
TARGET="$(cd "$TARGET" && pwd)"

echo "🧹 Removendo orquestrador de: $TARGET"
read -r -p "Confirmar? [s/N] " ans
[[ "$ans" =~ ^[sS]$ ]] || { echo "Abortado."; exit 1; }

rm -f "$TARGET/CLAUDE.md" "$TARGET/CLAUDE.orchestrator.md"
rm -f "$TARGET/.claude/scripts/scan.sh" \
      "$TARGET/.claude/scripts/execute.sh" \
      "$TARGET/.claude/scripts/review.sh"
rm -f "$TARGET/.claude/settings.orchestrator.json"
rm -rf "$TARGET/.orchestrator"

# Remove scripts/ se ficou vazia
rmdir "$TARGET/.claude/scripts" 2>/dev/null || true

echo "✅ Removido. (settings.json e a pasta .claude foram preservados se tinham"
echo "   outras configs suas — confira manualmente.)"
