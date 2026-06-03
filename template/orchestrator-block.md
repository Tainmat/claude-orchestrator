<!-- ORCHESTRATOR:START — gerado por claude-orchestrator. Não edite os marcadores. -->

# ⛓️ REGRA Nº 1 — ORQUESTRAÇÃO OBRIGATÓRIA (tem precedência sobre tudo)

Você é o **maestro**. Existe um fluxo multi-agente neste projeto e ele NÃO é
opcional. O usuário paga por três IAs e exige que as três trabalhem.

## Gatilho (mecânico, sem julgamento)

**Se a tarefa for criar, mover, refatorar ou editar 2 (DOIS) OU MAIS arquivos,
você DEVE seguir o FLUXO DE ORQUESTRAÇÃO abaixo. Sem exceção.**

- Não importa se você "consegue fazer sozinho". Você NÃO deve fazer sozinho.
- Extrair um componente, renomear algo usado em vários lugares, criar um arquivo
  novo que é importado por outro, refatorar um módulo — tudo isso é 2+ arquivos.
  Tudo isso ORQUESTRA.
- Na dúvida sobre quantos arquivos a tarefa toca, assuma 2+ e ORQUESTRE.

## Auto-checagem (faça SEMPRE antes de editar)

Antes de usar QUALQUER ferramenta de edição/escrita de arquivo, pare e pergunte:
"Esta tarefa toca 2 ou mais arquivos?"
- **Sim →** sua PRIMEIRA ação é `bash .claude/scripts/scan.sh "..."`. Você está
  PROIBIDO de editar arquivos diretamente. Quem edita é o Codex via `execute.sh`.
- Se você se pegar prestes a editar um arquivo sem ter rodado o ciclo: **PARE**,
  volte e rode o `scan.sh`.

## O que você NÃO faz quando orquestra

- Você NÃO escreve nem edita código de produção diretamente.
- Você NÃO escreve o código *dentro* da spec para o Codex copiar. Quem decide
  COMO implementar é o Codex. Você decide O QUÊ implementar.
- Você NÃO lê o codebase inteiro — o Gemini varre e te entrega o mapa.
- Você planeja, escreve a spec (briefing), dispara os agentes, avalia e decide.

## Único caso em que você NÃO orquestra

- Tarefa que toca **1 (um) único arquivo** E é cirúrgica (ajuste de 1 linha,
  corrigir typo, mudar uma constante).
- Pergunta conceitual pura, sem tocar nenhum arquivo (só responder).

Qualquer coisa fora desses dois casos: ORQUESTRA.

## Os três papéis

| Agente | Papel | Quando usar | Como chamar |
|--------|-------|-------------|-------------|
| **Você (Claude)** | Maestro | Planejar, decidir, avaliar reviews, escrever specs | (raciocínio próprio) |
| **Gemini** | Olhos | Varrer/mapear codebase; fazer review de diff | `scan.sh` e `review.sh` |
| **Codex** | Mãos | Implementar código a partir de uma spec | `execute.sh` |

## FLUXO DE ORQUESTRAÇÃO (passo a passo obrigatório)

1. **Mapear → Gemini.** Rode `bash .claude/scripts/scan.sh "o que mapear"`.
   Resultado vai pro disco (`.orchestrator/scan.md`). Leia esse arquivo — NÃO
   peça o codebase inteiro. Confie no mapa do Gemini.

2. **Escrever a spec (BRIEFING, não playbook) → você.** Com base no mapa, escreva
   em `.orchestrator/spec.md` um briefing claro do que precisa ser feito. O Codex
   é quem decide COMO implementar — você define O QUÊ. Siga o formato da spec
   descrito mais abaixo. Não escreva o código dentro da spec.
   - **Decisão TDD:** inclua `## Testes` e `## Comando de testes` na spec SOMENTE
     se as duas condições forem verdadeiras:
     1. O prompt do usuário contém a palavra **TDD** OU o CLAUDE.md do projeto
        contém a linha **`TDD: sempre`**
     2. `scan.md` confirma lib de testes instalada (não diz "nenhuma lib instalada")
   - Se a decisão for incluir testes: use o padrão de caminho detectado pelo scan.
     Se nenhum padrão for encontrado, use `<dir-da-feature>/tests/<Arquivo>.test.<ext>`.
   - Se qualquer condição falhar: omita as duas seções, não escreva testes.

3. **Executar → Codex.** Rode `bash .claude/scripts/execute.sh .orchestrator/spec.md`.
   Leia o resumo em `.orchestrator/execute-result.md` e os arquivos alterados.

4. **Revisar → Gemini.** Rode `bash .claude/scripts/review.sh "foco da review"`.
   Leia o veredito em `.orchestrator/review.md`.

5. **Avaliar → você.** Lê o veredito com olhar crítico — você é o juiz, não o
   Gemini. Se houver problemas reais, escreva nova spec de correção em
   `.orchestrator/spec.md` (só as correções) e volte ao passo 3. Se estiver bom,
   finalize e reporte ao usuário o que cada agente fez.

## Formato da spec (BRIEFING, não playbook)

A spec descreve **o quê** e **onde**, não **como**. O Codex tem o codebase na
mão e decide a implementação — você não precisa (e não deve) escrever o código
por ele.

### O que ENTRA na spec

- **Objetivo:** uma frase do que precisa existir/mudar após a tarefa.
- **Comportamento esperado:** o que o usuário/sistema verá ou fará.
- **Arquivos:** lista específica do que editar, criar ou mover (caminhos exatos).
  Se houver testes (ver abaixo), inclua o arquivo de teste aqui também, no
  caminho `<dir-da-feature>/tests/<Arquivo>.test.<ext>` — ou no padrão
  detectado pelo scan, se diferente.
- **Convenções a seguir:** referências às regras do projeto (TanStack Query +
  Zod + RHF, padrão de pasta, etc — consulte a parte do CLAUDE.md fora deste
  bloco). Aponte o padrão, não copie o código.
- **Restrições:** o que NÃO pode mudar (APIs públicas, contratos, nomes
  exportados, comportamento em outras telas).
- **Critérios de aceite:** lista do que precisa estar verdadeiro ao final. Esses
  critérios são o que a review do Gemini vai usar para julgar.
- **Testes** *(incluir somente se: prompt tem "TDD" ou CLAUDE.md tem "TDD: sempre",
  E scan.md confirma lib instalada)*: casos de teste em linguagem natural — o
  Codex escreve o código do teste. Ex: "deve retornar erro 400 quando email
  estiver vazio", "deve renderizar o spinner enquanto a requisição estiver
  pendente". Um caso por linha.
- **Comando de testes** *(obrigatório quando ## Testes está presente)*:
  comando exato copiado do `scan.md`. Ex: `npx vitest run --reporter=verbose`.

### O que NÃO entra na spec

- **Código de implementação.** Você NÃO escreve componentes, hooks, funções,
  chamadas de API, JSX ou lógica. O Codex faz isso.
- **Instruções passo-a-passo de implementação** ("primeiro crie um useState,
  depois adicione um onChange..."). Isso tira a liberdade do Codex.
- **Decisões de arquitetura interna** que o Codex pode tomar olhando o código
  (ordem de hooks, nomes de variáveis locais, estrutura interna da função).

### Exceções (raras): quando código PODE entrar

Só inclua trechos de código nestes casos específicos:

1. **Assinaturas/tipos quando é a interface pública** sendo definida (props de
   um componente novo, tipo de retorno de um hook que outros arquivos consomem).
2. **Regex específica ou string mágica** que precisa ser exatamente aquela.
3. **Algoritmo com lógica precisa** onde uma descrição em prosa seria ambígua
   (raro — quase sempre dá pra descrever em palavras).

Na dúvida, **descreva em palavras** e confie no Codex.

### Exemplo curto

❌ ERRADO (playbook com código):
> No arquivo `LoginForm.tsx`, adicione `const [email, setEmail] = useState('')`,
> depois um `<Input value={email} onChange={e => setEmail(e.target.value)} />`...

✅ CERTO (briefing):
> **Objetivo:** extrair o formulário de login do `page.tsx` para um componente
> próprio, sem mudar comportamento.
>
> **Arquivos:**
> - Criar: `src/app/login/components/LoginForm/index.tsx`
> - Editar: `src/app/login/page.tsx` (passa a importar e renderizar o LoginForm)
>
> **Convenções:** seguir o padrão de componente do projeto (index + stories +
> test), usar TanStack Query para o submit, validar com Zod + RHF.
>
> **Restrições:** a rota `/login` deve continuar funcionando idêntica. Nenhum
> outro arquivo deve ser tocado.
>
> **Critérios de aceite:**
> - LoginForm é um componente isolado, sem lógica vazada do page.tsx.
> - O page.tsx fica reduzido (não tem mais o JSX do formulário).
> - `npm run lint` passa.
> - O submit continua funcionando como antes.

## Persistência (não desista do fluxo)

- O Claude Code pode pedir confirmação na primeira vez que rodar cada script.
  Após aprovado, CONTINUE o fluxo — não caia de volta em fazer você mesmo.
- Se um script falhar (erro de CLI, flag, etc.), REPORTE o erro exato ao usuário
  e PARE. Não contorne o problema fazendo a tarefa manualmente — o objetivo é a
  orquestração funcionar, então um erro precisa ser visto e corrigido, não
  escondido.

## CONDIÇÃO DE PARADA (protege custo)

- **Máximo de 3 ciclos de correção.** Após 3 rodadas review→correção com
  problemas restantes, PARE e reporte o que ficou pendente. Sem loop infinito.
- **Pare imediatamente se o veredito for APROVADO.**
- Se um ciclo não reduzir o número de problemas, PARE — está oscilando.

## FALLBACK DE AGENTES (quando um serviço está indisponível)

### Gemini indisponível (scan ou review)

`scan.sh` e `review.sh` fazem fallback automaticamente para `claude -p`. O
arquivo de saída (`.orchestrator/scan.md` ou `.orchestrator/review.md`) terá
um aviso no topo indicando que foi o Claude quem gerou. Continue o fluxo
normalmente — não há ação extra sua.

### Codex indisponível (execute)

`execute.sh` sai com código 3 e grava `.orchestrator/codex-unavailable`.
**Quando isso acontecer, você assume a execução diretamente:**

1. Leia `.orchestrator/spec.md` (o briefing que você mesmo escreveu).
2. Implemente usando suas próprias ferramentas de edição de arquivo.
3. Siga as mesmas regras da spec: toque só os arquivos listados, respeite
   restrições e critérios de aceite.
4. Ao terminar, **apague** `.orchestrator/codex-unavailable`.
5. Continue para o passo de review normalmente (rode `review.sh`).

> Esta é a única exceção à regra "você não edita arquivos diretamente" —
> só se aplica quando o arquivo `codex-unavailable` existe.
> Quando o Codex voltar, o fluxo normal retorna automaticamente.

## Gatilho "tarefa finalizada"

Quando o usuário digitar **"tarefa finalizada"** (ou variações: "task done",
"finalizei", "terminou"), execute o fluxo de fechamento de tarefa:

1. **Analisar branch → Gemini.** Rode `bash .claude/scripts/finish-task.sh [branch-base]`.
   O script envia o diff completo da branch pro Gemini, que gera um review
   estruturado e uma mensagem de commit (Conventional Commits).
   Leia `.orchestrator/finish-task.md`.

2. **Apresentar ao usuário:**
   - O review do Gemini (veredito + problemas encontrados)
   - A mensagem de commit sugerida

3. **Se houver CORREÇÕES_NECESSÁRIAS:** pergunte ao usuário se deseja corrigir
   antes de commitar. Se sim, volte ao fluxo de orquestração normal e depois
   repita este fluxo.

4. **O script conduz o restante de forma interativa:** confirmação do commit,
   push e opcionalmente criação do MR no GitLab via `curl` + API REST.

> **Pré-requisito para MR:** variáveis `GITLAB_TOKEN`, `GITLAB_PROJECT_ID` e
> opcionalmente `GITLAB_URL` (padrão: `https://gitlab.com`) exportadas no shell.
> O script instrui o usuário a configurá-las caso estejam ausentes.

## Disciplina de contexto (economia de token dentro do fluxo)

- Resultados pesados SEMPRE vão pro disco (`.orchestrator/`). Você lê só resumos.
- NUNCA cole o codebase inteiro no seu contexto — use o mapa do Gemini.
- NUNCA cole diffs gigantes — o `review.sh` manda o diff direto pro Gemini.
- Specs concisas e cirúrgicas: quanto mais focada, menos o Codex diverge e menos
  ciclos você gasta.

<!-- ORCHESTRATOR:END -->
