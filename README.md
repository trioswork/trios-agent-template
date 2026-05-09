# Trios Agent Template

Template de instalador OpenClaw com estrutura pré-configurada.

## O que inclui

- `scripts/` — sync de memória, backup, embeddings, schema SQL
- `AGENTS.template.md` — Regras operacionais (adaptar para seu caso)
- `HEARTBEAT.md` — Checklist de heartbeats
- `DISASTER-RECOVERY.md` — Guia de recuperação
- `install.sh` — Instalador
- `onboarding.sh` — Onboarding
- `package.json` — Dependências

## Não inclui (criar durante setup)

- `SOUL.md` — Persona do agente
- `USER.md` — Info do usuário
- `.env` — Variáveis de ambiente
- `memory/` — Dados de memória
- `openclaw.json` — Config do gateway

## Uso

```bash
bash install.sh
```
