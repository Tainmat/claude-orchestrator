#!/usr/bin/env bash
# scan.sh — Gemini varre o codebase e escreve o mapa no disco.
# O Claude (maestro) NÃO recebe o codebase inteiro: lê só este arquivo de saída.
# Uso: scan.sh "o que mapear"
set -euo pipefail

PROMPT="${1:?uso: scan.sh \"o que mapear\"}"
OUT_DIR=".orchestrator"
OUT_FILE="$OUT_DIR/scan.md"
mkdir -p "$OUT_DIR"

gemini --yolo -p "Você está MAPEANDO um codebase para outro agente trabalhar nele.
NÃO escreva nem edite código. Apenas analise e descreva.

Tarefa de mapeamento: $PROMPT

Produza um relatório CONCISO em markdown com:
- Arquivos relevantes (caminho + 1 linha do que fazem)
- Funções/símbolos chave envolvidos
- Dependências e pontos de integração que importam para a tarefa
- Riscos ou armadilhas (efeitos colaterais, acoplamentos)

Seja denso. Sem preâmbulo. Máximo ~400 linhas." > "$OUT_FILE" 2>/dev/null

echo "✅ Mapa salvo em $OUT_FILE ($(wc -l < "$OUT_FILE") linhas)"
echo "--- Resumo (primeiras 40 linhas) ---"
head -n 40 "$OUT_FILE"
