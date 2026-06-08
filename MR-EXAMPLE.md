# Exemplo de Merge Request gerado

Este é um exemplo do título e descrição que o `create-mr.sh` gera via Gemini.

---

## Título

```text
feat(auth): adiciona autenticação JWT com refresh token
```

---

## Descrição gerada

### O que foi feito
- Implementado middleware de autenticação JWT no Express
- Adicionado endpoint `/auth/refresh` para renovar o access token
- Criada tabela `refresh_tokens` com TTL de 7 dias
- Adicionados testes unitários para o middleware

### Arquivos alterados

| Arquivo | Linhas modificadas |
| --- | --- |
| `src/middleware/auth.js` | 12-18 \| 45 \| 87-103 |
| `src/routes/auth.js` | 301-305 \| 315 \| 410-413 |
| `src/middleware/__tests__/auth.test.js` | 1-62 |
| `migrations/20240608_refresh_tokens.sql` | 1-18 |

### Motivação
O sistema usava sessões em memória, o que impedia escalar horizontalmente.
A migração para JWT permite múltiplas instâncias sem compartilhamento de estado.

### Como testar
- [ ] `POST /auth/login` com credenciais válidas retorna `access_token` e `refresh_token`
- [ ] `Authorization: Bearer <token>` autentica corretamente nas rotas protegidas
- [ ] Após 15 min, o `access_token` expira com 401
- [ ] `POST /auth/refresh` com `refresh_token` válido retorna novo par de tokens
- [ ] `refresh_token` expirado (>7 dias) retorna 401
- [ ] `npm test` passa sem erros

---
🔗 Tarefa: https://app.clickup.com/t/abc123xyz

---

## Fluxo interativo completo

```text
$ bash .claude/scripts/finish-task.sh

# — FASE 1: COMMIT —
📋 Arquivos com alterações uncommitted:
 M src/middleware/auth.js
 M src/routes/auth.js
 A src/middleware/__tests__/auth.test.js

🧠 Gerando mensagem de commit via Gemini...
✅ Mensagem gerada (agente: Gemini)

💾 Mensagem sugerida:
───────────────────────────────────────
feat(auth): adiciona autenticação JWT com refresh token
───────────────────────────────────────

Confirma? [s] Editar? [e] Cancelar? [N]: s
✅ Commit feito.

# — FASE 2: MERGE REQUEST —
Fazer push da branch 'feature/jwt-auth'? [s/N] s
✅ Push feito.

Criar Merge Request no GitLab? [s/N] s

Branch atual: feature/jwt-auth
Branch de DESTINO do MR (ex: develop, main, staging): develop

📝 Gerando título e descrição do MR via Gemini...
✅ Descrição gerada (agente: Gemini)

Link da tarefa (ClickUp, Jira, Linear…) [Enter para pular]: https://app.clickup.com/t/abc123xyz

┌─────────────────────────────────────────────────────────────
│  Título : feat(auth): adiciona autenticação JWT com refresh token
├─────────────────────────────────────────────────────────────
│  ## O que foi feito / ## Arquivos alterados / ## Como testar ...
└─────────────────────────────────────────────────────────────

Confirma? [s] Editar título? [t] Cancelar? [N]: s
🌐 Criando MR: feature/jwt-auth → develop

✅ Merge Request criado: https://gitlab.com/empresa/projeto/-/merge_requests/42
```
