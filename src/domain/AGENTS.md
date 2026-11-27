# AGENTS.md · src/domain (regras do negócio)

> Rascunho para o dono aprovar (E15). Escrito por: Arquiteto de software · Revisado por: (a preencher) · Norma: modelo C4, Clean Architecture, padrão agents.md.
> Fonte: `AGENTS.md`, `ARCHITECTURE.md`, `SECURITY.md`, `docs/guias/processo-sdd.md`. Este arquivo não cria regra nova.

## O que mora aqui
As regras do negócio, em TypeScript puro, com teste (`ARCHITECTURE.md` §3). A tela e o servidor usam estas regras; elas não usam ninguém.

## Regras que valem aqui
- Só TypeScript puro: nada de tela, banco ou framework (`ARCHITECTURE.md` §3).
- Toda regra tem teste de unidade (`ARCHITECTURE.md` §11).
- Idioma, fuso horário e moeda vêm do estúdio, nunca fixos no código (`ARCHITECTURE.md` §11).
- Biblioteca ou API só depois de lida no código ou na documentação oficial (`AGENTS.md` §6).
- Só os arquivos que o plano da spec permite (`AGENTS.md` §6).

## Nunca aqui
- Importar `src/app`, `src/server`, `src/data`, o cliente do banco ou o framework (`ARCHITECTURE.md` §3).
- Ler sessão, pedido, variável de ambiente ou segredo (`ARCHITECTURE.md` §4; `SECURITY.md` §2).
- Pôr dado pessoal ou de saúde em mensagem de erro ou registro (`ARCHITECTURE.md` §7).

## Prova exigida
Código: testes de unidade e CI verde (`AGENTS.md` §9). Revisa o Revisor de código; o QA dá o veredito (`docs/guias/processo-sdd.md` §3).
