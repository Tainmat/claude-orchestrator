# claude-orchestrator

Orquestração multi-agente para desenvolvimento assistido por IA, com o **Claude Code
como maestro** coordenando **Codex** (execução) e **Gemini** (varredura + review).

O Claude recebe o prompt, planeja, e delega: o Gemini varre o codebase, o Codex
implementa, o Gemini revisa, e o Claude avalia e itera — tudo autônomo via Bash,
com os resultados pesados indo pro disco para **economizar token**.

```
       ┌─────────────┐
       │  seu prompt │
       └──────┬──────┘
              ▼
       ┌─────────────┐   planeja, decide, avalia
       │ Claude Code │◄──────────────┐
       │  (maestro)  │               │
       └──┬───┬───┬──┘               │
          │   │   │                  │
   scan ◄─┘   │   └─► review         │ correções
 (Gemini)     │      (Gemini)        │
              ▼                      │
        ┌──────────┐                 │
        │  Codex   │─────────────────┘
        │ (execução)│
        └──────────┘
```

## Pré-requisitos

Os três CLIs instalados e autenticados:

```bash
claude --version   # Claude Code
codex --version    # OpenAI Codex CLI
gemini --version   # Google Gemini CLI
```

## Instalação

### Opção 1 — clonar e rodar o instalador

```bash
git clone https://github.com/SEU_USUARIO/claude-orchestrator.git
cd claude-orchestrator
./install.sh /caminho/do/seu/projeto
```

Sem argumento, instala no diretório atual:

```bash
cd /caminho/do/seu/projeto
/caminho/para/claude-orchestrator/install.sh
```

### Opção 2 — instalar via curl (one-liner)

```bash
curl -fsSL https://raw.githubusercontent.com/SEU_USUARIO/claude-orchestrator/main/install.sh | bash -s -- /caminho/do/projeto
```

> O instalador verifica os 3 CLIs, copia os arquivos, dá `chmod +x` nos scripts e
> adiciona `.orchestrator/` ao `.gitignore`. Se já existir `CLAUDE.md` ou
> `settings.json` no destino, ele salva as versões do orquestrador com sufixo
> `.orchestrator` em vez de sobrescrever.

## O que é instalado

```
seu-projeto/
├── CLAUDE.md                  # o cérebro: regras de roteamento e parada
└── .claude/
    ├── settings.json          # auto-approve restrito aos scripts
    └── scripts/
        ├── scan.sh            # Gemini varre o código
        ├── execute.sh         # Codex implementa
        └── review.sh          # Gemini revisa o diff
```

## Uso

```bash
cd /caminho/do/seu/projeto
claude
```

O Claude lê o `CLAUDE.md` automaticamente. Peça uma tarefa normalmente:

> "Adicione paginação na listagem de ofertas seguindo o padrão de TanStack Query
> que já existe no projeto."

O Claude vai: mapear com Gemini → escrever spec → executar com Codex →
revisar com Gemini → avaliar e iterar (máx. 3 ciclos) → reportar.

## Ajustes finos

- **Trocar modelo de um agente:** edite o `.sh` correspondente. Ex:
  `codex exec --model gpt-5-codex` ou `gemini -m gemini-2.5-pro -p`.
- **Mais/menos rigor na review:** edite o prompt em `review.sh`.
- **Mudar o limite de ciclos:** edite a seção CONDIÇÃO DE PARADA no `CLAUDE.md`.

## Por que via Bash e não MCP?

Se Codex/Gemini fossem MCP servers, todo o contexto trocado passaria pela janela
do Claude (custo de token). Via Bash com saída em disco, o Claude lê só os
resumos. Para a prioridade "economizar token", essa arquitetura ganha.

## Aviso

O Codex roda com `--sandbox workspace-write` e **edita arquivos de verdade**.
Teste primeiro num branch descartável ou projeto-sandbox antes de usar no fluxo
de produção.

## Licença

MIT
