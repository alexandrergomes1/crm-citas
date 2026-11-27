# Fila: depois

> **27/11/2026:** copiado do repositório antigo `crm-agenda` sem mudança. Os caminhos citados abaixo são os de lá; cada item volta à fila só a pedido do dono.

> **23/11/2026:** lista anterior à reorganização, guardada sem mudança. Será revista na Etapa 3 (item 102 de `docs/BACKLOG.md`): cada item vai para o arquivo do seu módulo em `docs/produto/modulos/` ou para a fila.

O que não é para agora. Só se lê quando `docs/BACKLOG.md` acabar ou quando o dono do projeto pedir.
A numeração continua a de `docs/BACKLOG.md`; item que sobe para lá mantém o número. O que é da virada
(abrir a produção a clientes reais) tem a lista completa em `docs/runbooks/go-live.md`.

## Antes da virada

9. **RGPD operacional** — dado de saúde da UE indo para produção, e nenhuma skill instalada cobre: direito de acesso, apagamento e portabilidade (art. 15, 17 e 20); prazo de retenção; base legal do consentimento para dado de saúde; registro de tratamento; cifra em repouso da anamnese; contrato de tratamento de dados com a Karenn; política de privacidade; contas no nome da empresa com 2 administradores. Nível C · **precisa de spec** · **bloqueada por decisão** — pergunta: "Antes de abrir a clientes: (A) um especialista em proteção de dados confere o sistema, ou (B) a proteção atual basta?"
10. Auditoria completa antes da virada (`docs/runbooks/go-live.md`). Inclui conferir o registro de decisões contra o app: **hoje ninguém confere, de forma recorrente, se uma decisão aprovada virou código; esta auditoria é o único gatilho.** · **próxima** (depois do layout)
11. Decisões de design registradas que o app pode ainda não seguir — conferir cada uma no código antes de mexer (duas já estavam aplicadas quando esta lista foi escrita): CAM1-08; CAM5-01; CAM5-02; CAM5-03; o app escrever "Histórico"; o app mostrar "Passo 1 de 4" com traços. Nível B · **próxima**
12. Idempotência em `/pagar` e nos webhooks (chamada repetida não pode duplicar efeito). Nível C · **precisa de spec**
13. Testes multi-inquilino além da linha: apagar um estúdio inteiro, mover dado entre estúdios, o que acontece com a ficha quando o estúdio cancela. Nível C · **precisa de spec**
14. Testes de isolamento para as políticas RLS que não tiverem (o tamanho sai do item 6). Nível C · **próxima** (depois do item 6)
15. Rotação de segredo: roteiro do que fazer se vazar a chave de serviço, a chave do Supabase ou o token da Cloudflare. Nível A · Pronto quando: uma página em `docs/` · **próxima**
16. Roteiro de vazamento de dados (uma página; a lei exige avisar a autoridade em até 72 horas). Nível A · **próxima**
17. Trocar chaves, banco do backup e variáveis do Worker para o projeto de produção; Workers Paid; segunda cópia do backup; religar os agendamentos do backup e do teste de restauração. · **bloqueada por decisão** — é a virada: só com a ordem dele.
18. Painel de Operação e alerta de backup atrasado. · **bloqueada por decisão** — pergunta: "Depois do lançamento: (A) só os avisos prontos de cada ferramenta, por e-mail, ou (B) um painel próprio?"
19. Esqueci a senha por e-mail na produção: SMTP próprio, endereço em Redirect URLs, prazo do link em 3600 segundos (`docs/STATUS.md`, "Fatos e limites conhecidos"). · **próxima**
20. `claude-security`: uma rodada escopada (`src/data` e `src/routes`, esforço baixo). · **bloqueada por decisão** — precisa da autorização dele, porque dispara muitos agentes.
38. Cópia das fotos da anamnese (Storage) no backup: hoje só o banco é copiado. Nível C · **precisa de spec**
39. Usuário só de leitura para o backup, no lugar da senha principal do banco. Nível C · **próxima**
40. Política de conteúdo (CSP) completa (hoje só existe `frame-ancestors`); Turnstile e limite de tentativas no login e no PIN. Nível C · **precisa de spec**
41. Telas do lançamento que o plano previa e não têm item: Entrar, Equipe, Importação do Fresha, Recibo, Mensagens manuais. Cada uma: ficha → spec → código. · **precisa de spec**

## Produto

21. **Idiomas (es/pt/en).** Registro de decisão (quais idiomas, qual biblioteca, onde moram os textos, moeda, data e fuso), depois spec do porte, depois a regra definitiva na skill de tela. **Não bloqueia a camada 10**: até lá as telas saem em português, com os textos concentrados num lugar por tela. · **bloqueada por decisão** — pergunta: "No lançamento: (A) só português, ou (B) português, espanhol e inglês?"
22. **Levantar o que falta para vender:** produzir a lista para o Alexandre decidir (a examinar, sem valor de decisão: planos e cobrança, cadastro de estúdio novo, termos de uso, política de privacidade, nome do produto). O item 9 é pré-requisito. Nível A · **próxima**
23. Porte que sobra: Importar e exportar. · **precisa de spec**
24. Porte que sobra: motor de envio das automações; capturas lado a lado com o sistema de origem; `/anterior/inicio` → agenda. · **próxima**
25. Teste automático das funções de servidor: a escolha entre A e B de `docs/specs/teste-funcoes-servidor.md` é técnica; a IA decide, registra e avisa. Nível B · **próxima**
26. Convite com aceite para quem já usa o sistema em outro estúdio; remover pessoa da equipe; criar estúdio novo sem a chave de serviço. Nível C · **precisa de spec**
27. Faxina diária das fotos órfãs da Anamnese (precisa de uma chave de serviço guardada no GitHub). · **bloqueada por decisão** — vai com a virada.
42. Auditoria da exportação CSV de clientes; aviso de falha da exportação pelo design system (hoje é `window.alert` em 9 telas). Nível B · **próxima**

## Qualidade e manutenção

28. Testes instáveis: `supabase/tests/96_anamnese_gate.sql` falhou uma vez e passou ao repetir; o E2E falhou uma vez por porta 54322 ocupada. Achar a causa. · **próxima**
29. Números das migrations do PR #37 diferem entre o repositório (20261114130000 a 130400) e o banco de desenvolvimento (20261114170945 a 171327). Ajustar. · **próxima**
30. Limites do Workers (tempo de CPU, subrequisições, tempo limite da API do banco, paginação obrigatória): medir e acrescentar a `docs/reference/db-budget.md`; a medição vira rotina mensal sem IA. · **próxima**
31. Regressão visual com imagens de referência no Playwright (depende do item 2). · **precisa de spec**
33. Diferença entre o design system do código (`src/design-system`) e o publicado: conferir os dois inventários. · **bloqueada por decisão** — pergunta: "A imagem que você aprova usa uma cópia das peças do app: (A) a IA confere a cópia contra o app antes de cada ficha, ou (B) segue como está?"
34. Rodada agrupada de testes na branch de produção, sem IA. · **próxima** (depois da virada)
35. Medição de desempenho por tela: criar a rotina sem IA. Constava "limite combinado de 3 segundos no celular", **sem prova**. O limite é escolha técnica: a IA propõe com a medição na mão, registra e avisa. · **próxima**
36. Revisão trimestral de automações e conexões, manual, sem IA (`docs/reference/project.md`, "Fatos do GitHub"). Primeira: na virada. · **próxima**
37. Dado pessoal em log: conferir com `backend-design:observability-by-default`. · **próxima**
43. Seção "Termos do sistema" (Comanda, Ficha, Faltou…) em `docs/GLOSSARY.md`, tirada do registro de design. Nível A · **próxima**
44. Desligar a publicação da "Mesa" (Worker `ka-mesa`), que não é mais usada. · **bloqueada por decisão** — mexe em serviço dele: só com o ok.
46. Chave estrangeira composta com `org_id` nas relações que ainda são simples (mensagens, marketing, locais), com teste que confira pelo catálogo do banco, não por lista fixa. Nível C · **precisa de spec**
47. A trava barra comando que só **cita** o texto proibido (mensagem de commit, busca com `grep`, corpo de PR). Erra para o lado seguro; refinar sem abrir brecha, com casos de teste. Nível A com executável · **próxima**
45. O teste do orçamento passar a falhar quando uma função de servidor fica fora da lista (hoje só trava as listadas). Nível B · **próxima**

48. Acessibilidade automática (axe) nos testes de ponta a ponta, nas duas larguras. Nível B · **próxima**
49. Separar `.claude/`, os moldes e `docs/README.md` num repositório-modelo (template) para projetos futuros, depois de 2 a 3 semanas de uso estável da base de 20/11. Nível A · **próxima**
50. Skills `infra-deploy` (Cloudflare, segredos, rotinas, publicar e voltar versão) e `observability-ops` (Sentry, /health, avisos), criadas perto do lançamento, quando houver o que pôr nelas; antes disso o `docs/runbooks/go-live.md` cobre. Nível A · **próxima** (na virada)

Decidido não fazer (registro em `docs/adr/2026-11-19-base-de-ia.md`): cobertura mínima obrigatória
de testes (era o item 32); matriz de rastreio; teste em formato Gherkin com ferramenta.
