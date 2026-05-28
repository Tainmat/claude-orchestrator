#!/usr/bin/env bash
# execute.sh — Codex executa uma spec escrita pelo Claude.
# O Claude escreve a spec num arquivo; o Codex lê o arquivo e implementa.
# Uso: execute.sh caminho/para/spec.md
set -euo pipefail

SPEC_FILE="${1:?uso: execute.sh <arquivo-de-spec>}"
[ -f "$SPEC_FILE" ] || { echo "❌ spec não encontrada: $SPEC_FILE"; exit 1; }

OUT_DIR=".orchestrator"
RESULT_FILE="$OUT_DIR/execute-result.md"
mkdir -p "$OUT_DIR"

codex exec \
  --sandbox workspace-write \
  -o "$RESULT_FILE" \
  "Implemente exatamente a especificação abaixo. Não tome decisões de arquitetura
por conta própria — se algo estiver ambíguo, faça a opção mais conservadora e
ANOTE no resumo final. Ao terminar, liste só os arquivos alterados e um resumo
de 3 linhas do que foi feito.

=== ESPECIFICAÇÃO ===
$(cat "$SPEC_FILE")" 2>/dev/null

echo "✅ Execução concluída. Resumo em $RESULT_FILE"
echo "--- Resumo ---"
cat "$RESULT_FILE"
echo ""
echo "--- Arquivos modificados (git) ---"
git diff --name-only 2>/dev/null || echo "(sem repo git ou sem mudanças)"
