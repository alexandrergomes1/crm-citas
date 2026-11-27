# Status (situação)

Onde o trabalho parou. O que vem a seguir: `docs/BACKLOG.md`. O que cada módulo tem e precisa ter:
`docs/produto/modulos/`. Endereços e fatos: `docs/reference/project.md`. Histórico anterior a 27/11/2026: o repositório
antigo `crm-agenda` (congelado, só consulta; `docs/adr/0001-repositorio-novo.md`).

## Ponto de partida
- **27/11/2026: repositório novo aberto** por decisão do dono (P-E5·4, `docs/decisoes/2026-11-27-projeto-novo.md`).
  Item 1 da fila, **Fundação**, em andamento na branch `chore/base-fundacao` (spec `specs/20261127-000000-fundacao/spec.md`).
- **Entrou na fundação:** constituição (`AGENTS.md`), `CLAUDE.md`, guias (`docs/guias/`), `DESIGN.md` 6ª edição, regras
  por pasta, travas (`.claude/hooks/`, `.claude/settings.json`, `.githooks/`, `scripts/conferir-pedido.mjs`) com testes,
  agentes e skills como cascas finas, Spec Kit v1.4.4, molde de PR, documentos de controle. App mínimo, migrations
  copiadas do crm-agenda e CI entram na mesma branch, em paralelo.
- **Sem telas ainda.** Os módulos entram um por vez, por spec própria, já no design novo (itens 3 em diante).
- **Banco:** o mesmo do crm-agenda; este repositório ainda não está ligado a ele (ligação só na virada, ADR 0001).
- **Produção:** nenhuma. Nada publicado por este repositório.

## Fatos e limites conhecidos
- O GitHub ainda não tem a branch `previas`; até ela existir, a trava barra editar qualquer migration (sem a base para
  comparar, ela bloqueia por segurança) e o início de sessão lê o arquivo local.
- Os endereços de prévia em `docs/guias/git-e-deploy.md` e `docs/reference/project.md` ainda são os do crm-agenda; mudam
  quando a Cloudflare for ligada a este repositório.
