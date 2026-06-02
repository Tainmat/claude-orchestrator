#!/usr/bin/env bash
# scan.sh — Gemini varre o codebase e escreve o mapa no disco.
# O Claude (maestro) NÃO recebe o codebase inteiro: lê só este arquivo de saída.
# Fallback: se Gemini estiver indisponível, Claude assume o scan via --print.
# Uso: scan.sh "o que mapear"
set -euo pipefail

PROMPT="${1:?uso: scan.sh \"o que mapear\"}"
OUT_DIR=".orchestrator"
OUT_FILE="$OUT_DIR/scan.md"
mkdir -p "$OUT_DIR"

SCAN_PROMPT="Você está MAPEANDO um codebase para outro agente trabalhar nele.
NÃO escreva nem edite código. Apenas analise e descreva.

Tarefa de mapeamento: $PROMPT

Produza um relatório CONCISO em markdown com:
- Arquivos relevantes (caminho + 1 linha do que fazem)
- Funções/símbolos chave envolvidos
- Dependências e pontos de integração que importam para a tarefa
- Riscos ou armadilhas (efeitos colaterais, acoplamentos)

Inclua obrigatoriamente uma seção '## Setup de testes' com:
- Lib de testes instalada (jest / vitest / mocha / junit / nenhuma)
- Se nenhuma: escreva exatamente 'Testes: nenhuma lib instalada' e encerre a seção
- Se houver lib: comando exato para rodar os testes (ex: npx vitest run --reporter=verbose)
- Padrão de localização dos arquivos de teste encontrado no projeto
  (ex: colocado junto ao arquivo, __tests__/, tests/ dentro da feature)
  Se não houver testes existentes, escreva: 'Padrão: nenhum encontrado — usar <dir-da-feature>/tests/'
- Libs auxiliares encontradas (testing-library, mockito, supertest, etc.)

Seja denso. Sem preâmbulo. Máximo ~400 linhas."

if gemini --yolo -p "$SCAN_PROMPT" > "$OUT_FILE" 2>/dev/null; then
  echo "✅ Mapa salvo em $OUT_FILE (agente: Gemini, $(wc -l < "$OUT_FILE") linhas)"
else
  echo "⚠️  Gemini indisponível — usando Claude como fallback para scan..."
  {
    echo "> ⚠️ **Fallback:** mapa gerado pelo Claude (Gemini indisponível)"
    echo ""
    claude -p "$SCAN_PROMPT"
  } > "$OUT_FILE"
  echo "✅ Mapa salvo em $OUT_FILE (agente: Claude/fallback, $(wc -l < "$OUT_FILE") linhas)"
fi

echo "--- Resumo (primeiras 40 linhas) ---"
head -n 40 "$OUT_FILE"
