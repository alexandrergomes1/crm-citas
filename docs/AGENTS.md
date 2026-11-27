# Pasta: docs · documentação

Vale junto com o `AGENTS.md` da raiz.

**O que mora aqui:** guias por área (`guias/`), produto e módulos (`produto/`, linha de base em `produto/modulos/`), decisões do dono fora de spec (`decisoes/`), decisões técnicas (`adr/`), incidentes (`postmortems/`), moldes (`moldes/`), fatos de banco e servidor (`reference/`), manuais de operação (`runbooks/`), controle (`BACKLOG.md`, `STATUS.md`, `OWNER.md`, `ROADMAP.md`, `ICEBOX.md`) e o arquivo antigo (`arquivo-antigo/`).

**Regras**
- A regra mora num lugar só: no guia da área (`guias/`), em `DESIGN.md` ou no `AGENTS.md`; o resto aponta para ele (`AGENTS.md` raiz; `docs/guias/processo-sdd.md`).
- Mudança num guia, em `DESIGN.md` ou na constituição precisa de spec própria aprovada (`AGENTS.md` §3).
- Documentos de controle e arquivos de módulo só mudam no PR da tarefa (`docs/guias/processo-sdd.md`).
- Resposta do dono fora de spec vai para `decisoes/` (molde `moldes/decisao.md`); decisão técnica para `adr/` (molde `moldes/adr.md`) (`AGENTS.md` §3).
- Mensagem ao dono segue `moldes/pergunta.md` (`AGENTS.md` §8).
- `reference/` guarda fatos do projeto e vence o método de mercado quando houver conflito (`docs/reference/database.md`, `server.md`).

**Nunca**
- Tratar `arquivo-antigo/` ou `produto/legado/` como decisão: só leitura.
- Mexer em `design/decisoes/mesa/` (está publicada na internet).
- Segredo, usuário ou senha de teste, dado pessoal ou de saúde em qualquer arquivo.

## Origem
`AGENTS.md` §3, §5 e §9 · `docs/README.md` · `docs/projeto/estrutura.md` §Controle · `docs/reorganizacao/06-plano-etapa5.md` §3, T8, T10 e T14 · estrutura real (`ls docs`, 27/11/2026).
