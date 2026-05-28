#!/usr/bin/env bash
# review.sh — Gemini revisa o diff atual e dá um veredito estruturado.
# O Claude lê o veredito e decide se manda correções pro Codex ou se aprova.
# Uso: review.sh ["foco opcional da review"]
set -euo pipefail

FOCUS="${1:-qualidade geral, bugs, segurança e aderência ao padrão do projeto}"
OUT_DIR=".orchestrator"
REVIEW_FILE="$OUT_DIR/review.md"
mkdir -p "$OUT_DIR"

DIFF="$(git diff HEAD 2>/dev/null || true)"
if [ -z "$DIFF" ]; then
  echo "⚠️  Nenhum diff para revisar (git diff HEAD vazio)."
  exit 2
fi

echo "$DIFF" | head -c 200000 | gemini --yolo -p "Revise o diff abaixo.
Foco: $FOCUS

Responda em markdown com EXATAMENTE esta estrutura:

## Veredito
APROVADO  |  CORREÇÕES_NECESSÁRIAS

## Problemas
(lista numerada; vazia se aprovado. Cada item: arquivo:linha — problema — correção sugerida)

## Observações
(opcional, melhorias não-bloqueantes)

Seja rigoroso mas não invente problemas. Se está bom, diga APROVADO." > "$REVIEW_FILE" 2>/dev/null

echo "✅ Review salva em $REVIEW_FILE"
echo "--- Veredito ---"
cat "$REVIEW_FILE"
