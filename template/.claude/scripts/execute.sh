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
  "Você recebeu um BRIEFING (não um playbook). O briefing diz O QUÊ fazer, em
quais arquivos, e quais são os critérios de aceite. VOCÊ decide COMO implementar
— escolha a abordagem, escreva o código, leia os arquivos que precisar do projeto.

Regras:
- Cumpra todos os critérios de aceite do briefing.
- Respeite as restrições (o que NÃO pode mudar).
- Se houver trechos de código no briefing (assinatura, tipo, regex), use-os como
  contrato exato — não os reinterprete.
- Se algo no briefing estiver ambíguo, faça a opção mais conservadora e ANOTE no
  resumo final.
- Toque APENAS os arquivos listados em 'Arquivos'. Se precisar mexer em outro,
  PARE e anote no resumo em vez de fazer.

Ao terminar, liste só os arquivos alterados e um resumo de 3 linhas do que foi
feito e por que escolheu essa abordagem.

=== BRIEFING ===
$(cat "$SPEC_FILE")" 2>/dev/null

echo "✅ Execução concluída. Resumo em $RESULT_FILE"
echo "--- Resumo ---"
cat "$RESULT_FILE"
echo ""
echo "--- Arquivos modificados (git) ---"
git diff --name-only 2>/dev/null || echo "(sem repo git ou sem mudanças)"
