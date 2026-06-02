#!/usr/bin/env bash
# execute.sh — Codex executa uma spec escrita pelo Claude.
# O Claude escreve a spec num arquivo; o Codex lê o arquivo e implementa.
# Se a spec tiver ## Testes, o Codex segue TDD: testes primeiro, depois implementa.
# Fallback: se Codex estiver indisponível, grava .orchestrator/codex-unavailable
#           e sai com código 3 — o Claude-maestro assume a execução diretamente.
# Uso: execute.sh caminho/para/spec.md
set -euo pipefail

SPEC_FILE="${1:?uso: execute.sh <arquivo-de-spec>}"
[ -f "$SPEC_FILE" ] || { echo "❌ spec não encontrada: $SPEC_FILE"; exit 1; }

OUT_DIR=".orchestrator"
RESULT_FILE="$OUT_DIR/execute-result.md"
UNAVAILABLE_FLAG="$OUT_DIR/codex-unavailable"
mkdir -p "$OUT_DIR"

CODEX_PROMPT="Você recebeu um BRIEFING (não um playbook). O briefing diz O QUÊ fazer, em
quais arquivos, e quais são os critérios de aceite. VOCÊ decide COMO implementar
— escolha a abordagem, escreva o código, leia os arquivos que precisar do projeto.

Regras gerais:
- Cumpra todos os critérios de aceite do briefing.
- Respeite as restrições (o que NÃO pode mudar).
- Se houver trechos de código no briefing (assinatura, tipo, regex), use-os como
  contrato exato — não os reinterprete.
- Se algo no briefing estiver ambíguo, faça a opção mais conservadora e ANOTE no
  resumo final.
- Toque APENAS os arquivos listados em 'Arquivos'. Se precisar mexer em outro,
  PARE e anote no resumo em vez de fazer.

Regras de testes (TDD):
- Se o briefing tiver uma seção '## Testes', siga TDD obrigatoriamente:
  1. Crie o arquivo de teste no caminho especificado em '## Arquivos'.
  2. Rode o comando em '## Comando de testes' — os testes DEVEM falhar (red).
     Se não falharem, algo está errado: anote no resumo e pare.
  3. Implemente a feature nos arquivos de produção.
  4. Rode o comando de testes novamente — os testes DEVEM passar (green).
     Se não passarem após a implementação, tente corrigir (máx. 2 tentativas).
  5. Inclua a saída completa dos testes no resumo final.
- Se o briefing NÃO tiver '## Testes', não crie nem modifique arquivos de teste.

Ao terminar, liste só os arquivos alterados e um resumo de 3 linhas do que foi
feito e por que escolheu essa abordagem. Se rodou testes, inclua o resultado.

=== BRIEFING ===
$(cat "$SPEC_FILE")"

if codex exec \
  --sandbox workspace-write \
  -o "$RESULT_FILE" \
  "$CODEX_PROMPT" 2>/dev/null; then
  echo "✅ Execução concluída. Resumo em $RESULT_FILE"
  echo "--- Resumo ---"
  cat "$RESULT_FILE"
  echo ""
  echo "--- Arquivos modificados (git) ---"
  git diff --name-only 2>/dev/null || echo "(sem repo git ou sem mudanças)"
else
  echo "❌ Codex indisponível ou falhou."
  echo "⚠️  Sinalizando fallback em $UNAVAILABLE_FLAG"
  echo "codex-unavailable: $(date -u +"%Y-%m-%dT%H:%M:%SZ")" > "$UNAVAILABLE_FLAG"
  echo ""
  echo "→ O Claude-maestro deve agora executar a spec diretamente."
  echo "  Leia: .orchestrator/spec.md e siga as instruções de fallback do CLAUDE.md."
  exit 3
fi
