# AGENTS.md · src/domain (regras do negócio)

> Rascunho para o dono aprovar (E15). Escrito por: Arquiteto de software · Revisado por: Revisor de código · Norma: modelo C4, Clean Architecture, padrão agents.md.
> Fonte: `AGENTS.md`, `ARCHITECTURE.md`, `SECURITY.md`, `docs/guias/processo-sdd.md`. Este arquivo não cria regra nova; deduções marcadas como tal.

## O que mora aqui
As regras do negócio, em TypeScript puro, com teste (`ARCHITECTURE.md` §3). A tela e o servidor usam estas regras; elas não usam ninguém.

## Regras que valem aqui
- Só TypeScript puro: nada de tela, banco ou framework (`ARCHITECTURE.md` §3).
- Toda regra tem teste de unidade (`ARCHITECTURE.md` §11).
- Idioma, fuso horário e moeda são por estúdio (`ARCHITECTURE.md` §11).
- Biblioteca ou API só depois de lida no código ou na documentação oficial (`AGENTS.md` §6).
- Só os arquivos que o plano da spec permite (`AGENTS.md` §6).
- Sessão, estúdio e configuração chegam por parâmetro, vindos do `src/server`; aqui nada os busca (dedução de `ARCHITECTURE.md` §3 e §4).

## Nunca aqui
- Importar `src/app`, `src/server`, `src/data`, o cliente do banco ou o framework (`ARCHITECTURE.md` §3).
- Pôr dado pessoal ou de saúde em registro de erro, endereço (URL) ou notificação (`ARCHITECTURE.md` §7).

## Prova exigida
Código: testes de unidade e CI verde (`AGENTS.md` §9). Revisa o Revisor de código; o QA dá o veredito (`docs/guias/processo-sdd.md` §3).
