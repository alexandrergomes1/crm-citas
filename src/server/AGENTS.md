# AGENTS.md · src/server (camada única de serviço)

> Rascunho para o dono aprovar (E15). Escrito por: Arquiteto de software · Revisado por: (a preencher) · Norma: modelo C4, Clean Architecture, padrão agents.md, OWASP ASVS 4.0.3.
> Fonte: `AGENTS.md`, `ARCHITECTURE.md`, `SECURITY.md`, `docs/guias/processo-sdd.md`. Este arquivo não cria regra nova.

## O que mora aqui
A camada única de serviço: todo pedido (telas, painel admin, portal, parceiros) entra aqui e passa pelas 6 portas (`ARCHITECTURE.md` §3 e §4). Usa `src/domain` para as regras e `src/data` para o banco.

## Regras que valem aqui
- As 6 portas, nesta ordem: quem é · de qual estúdio · o que pode · dados certos · banco com trava · registro (`ARCHITECTURE.md` §4; `SECURITY.md` §3).
- O estúdio vem da sessão, nunca do pedido; tudo o que chega é validado com esquema (`ARCHITECTURE.md` §4, portas 2 e 4).
- CRUD com o mesmo molde em todo módulo, sempre pelas 6 portas (`ARCHITECTURE.md` §4).
- Registro (auditoria) sem dado pessoal, que não se altera e tem prazo de guarda; exceção declarada do dono no painel admin vale como está (`ARCHITECTURE.md` §4 e §6; `SECURITY.md` §5).
- Limite de pedidos por estúdio (`ARCHITECTURE.md` §5). Envios passam pela fila; aviso de parceiro tem a assinatura conferida e é processado uma vez só (`ARCHITECTURE.md` §10).
- Regra de negócio fica em `src/domain`, não aqui (`ARCHITECTURE.md` §3).

## Nunca aqui
- Pular ou trocar a ordem de uma porta (`ARCHITECTURE.md` §3 e §4).
- Segredo no código ou em registro; dado pessoal ou de saúde em registro de erro, endereço (URL) ou notificação (`SECURITY.md` §2 e §4).

## Prova exigida
Código: testes de unidade e CI verde (`AGENTS.md` §9). Login, acesso, dinheiro, ficha de saúde ou integração: mais a revisão do Auditor de risco e do Engenheiro de segurança (`docs/guias/processo-sdd.md` §3).
