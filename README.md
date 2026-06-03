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
jq --version       # Processamento de JSON (sudo apt install jq)
```

## Instalação

### Opção 1 — clonar e rodar o instalador

```bash
git clone https://github.com/Tainmat/claude-orchestrator.git
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
curl -fsSL https://raw.githubusercontent.com/Tainmat/claude-orchestrator/main/install.sh | bash -s -- ~/projetos/meu-projeto
```

> **Importante:** troque `~/projetos/meu-projeto` pelo caminho real do seu
> projeto. O one-liner via curl só funciona se o repositório for **público**.
> Para repos privados, use a Opção 1 (clonar).

O instalador faz as seguintes perguntas interativas:

| Pergunta | O que configura |
|---|---|
| `Este projeto usa TDD?` | Adiciona `TDD: sempre` ao `CLAUDE.md` |
| `Configurar integração com GitLab?` | Salva as credenciais em `.orchestrator/.gitlab-config` (gitignored) |

> O instalador verifica os 3 CLIs, copia os arquivos, dá `chmod +x` nos scripts e
> adiciona `.orchestrator/` ao `.gitignore`. Se já existir `CLAUDE.md` no destino,
> ele **anexa o bloco de orquestração no topo** (entre marcadores
> `<!-- ORCHESTRATOR:START -->` e `<!-- ORCHESTRATOR:END -->`), preservando suas
> regras do projeto. O `uninstall.sh` remove apenas o bloco, mantendo o resto.

## O que é instalado

```
seu-projeto/
├── CLAUDE.md                        # o cérebro: regras de roteamento e parada
└── .claude/
    ├── settings.json                # auto-approve restrito aos scripts
    └── scripts/
        ├── scan.sh                  # Gemini varre o codebase
        ├── execute.sh               # Codex implementa a partir de uma spec
        ├── review.sh                # Gemini revisa o diff atual
        └── finish-task.sh           # fecha a tarefa: review de branch + commit + MR
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

## Fechamento de tarefa — "tarefa finalizada"

Ao terminar uma tarefa, basta digitar **"tarefa finalizada"** no prompt. O Claude
dispara o fluxo de fechamento:

```
1. Gemini analisa o diff completo da branch vs base
2. Gera mensagem de commit (Conventional Commits)
3. Apresenta review + commit sugerido
4. Pergunta se confirma o commit → git add -A && git commit
5. Pergunta se faz push → git push origin <branch>
6. Pergunta se cria Merge Request no GitLab → cria via API REST
7. Exibe a URL do MR criado
```

### Configuração do GitLab

Durante o `install.sh`, o instalador pergunta se você quer configurar o GitLab.
Se sim, solicita:

- **URL do GitLab** (padrão: `https://gitlab.com`)
- **Personal Access Token** — crie em `Preferences > Access Tokens` com escopo **`api`**
- **Project ID** — encontrado em `Settings > General > Project ID`

As credenciais são salvas em `.orchestrator/.gitlab-config` (ignorado pelo git).

Para configurar manualmente depois da instalação:

```bash
cat > .orchestrator/.gitlab-config <<EOF
export GITLAB_URL="https://gitlab.minhaempresa.com"
export GITLAB_TOKEN="glpat-xxxxxxxxxxxx"
export GITLAB_PROJECT_ID="42"
EOF
```

Ou via variáveis de ambiente no `~/.zshrc` / `~/.bashrc`:

```bash
export GITLAB_TOKEN="glpat-xxxxxxxxxxxx"
export GITLAB_PROJECT_ID="42"
export GITLAB_URL="https://gitlab.minhaempresa.com"  # omitir se for gitlab.com
```

## Ajustes finos

- **Trocar modelo de um agente:** edite o `.sh` correspondente. Ex:
  `codex exec --model gpt-5-codex` ou `gemini -m gemini-2.5-pro -p`.
- **Mais/menos rigor na review:** edite o prompt em `review.sh`.
- **Mudar o limite de ciclos:** edite a seção CONDIÇÃO DE PARADA no `CLAUDE.md`.
- **TDD automático:** adicione `TDD: sempre` ao `CLAUDE.md` do projeto.

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
