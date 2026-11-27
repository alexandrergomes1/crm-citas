# Pasta: src/domain · regras de negócio

Vale junto com o `AGENTS.md` da raiz.

**O que mora aqui:** a regra de negócio pura, em TypeScript, um arquivo por assunto com o teste ao lado (`agenda-slots.ts` + `agenda-slots.test.ts`).

**Regras**
- TypeScript puro: sem React, sem banco, sem roteador (`ARCHITECTURE.md`; `AGENTS.md` §5). Bibliotecas puras já em uso (Zod, libphonenumber-js) podem.
- Toda regra tem teste Vitest no arquivo `*.test.ts` ao lado (`docs/guias/testes.md`).
- Regra que uma tela ou função de servidor usa mora aqui, nunca no componente nem na função (`docs/guias/telas.md` §3; `docs/guias/servidor.md`).
- Textos de tela não moram aqui: ficam no objeto de textos do arquivo da tela (`docs/guias/telas.md` §3).
- Só o que a spec aprovada pede, nos "Arquivos permitidos" do plano (`docs/guias/processo-sdd.md`).

**Nunca**
- Importar React, Supabase ou o roteador; ler ou gravar no banco daqui.
- Regra sem teste.

## Origem
`AGENTS.md` §5 · `docs/reference/project.md` §Pastas · `docs/reference/server.md` §Regras da casa · `.claude/rules/servidor.md` · `src/workspace/agenda/AGENTS.md` · estrutura real (`ls src/domain`, 27/11/2026).
