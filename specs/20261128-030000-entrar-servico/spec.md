# Spec · Entrar e camada de serviço (as 6 portas)

- **Status:** Draft
- **Aprovação do dono:** (pendente)
- **Aprovação do merge:** (pendente)
- **Item da fila:** novo, por decisão do dono E36·A, logo antes do núcleo (depois dos itens 2 a 4 de `docs/BACKLOG.md`);
  o Documentador grava o item na fila
- **Branch:** `feat/entrar-servico`, a partir da `previas` (já com o item 2: app, CI e Spec Kit)
- **Tipo:** Login e segurança, Código, Banco (função de passagem e tabela do registro) e Tela (`docs/guias/processo-sdd.md` §3)
- **Revisores:** Auditor de risco e Engenheiro de segurança (login, acesso); Engenheiro de dados que não fez (banco);
  Revisor de código; Revisor de design (tela); QA dá o veredito
- **Escrito por:** Analista de requisitos · **Norma:** IEEE 29148 e BABOK
- **Fontes:** E36·A; E3·1; E4·1; E4·2; E6·1; E6·2; E15·1; `AGENTS.md` §3, §5, §6; `ARCHITECTURE.md` §3, §4, §6, §7, §11;
  `SECURITY.md` §2 a §5; `DESIGN.md` §5, §6, §8, §8b, §9; `src/*/AGENTS.md`; item 3 (`feat/banco-ligacao`: spec, `plan.md`
  R-6 e R-7, ADR 0005); plano da Agenda (`feat/agenda`, `plan.md` §5.1); ADR 0006 (proposto, `feat/agenda`, D1).

## 1. Pedido do dono (literal)
> "E36a" — 28/11/2026, https://claude.ai/code/session_018cV8b9epaQJNqguG5c5Aqb, respondendo a: "E36·A: crio uma spec
> própria, 'Entrar e camada de serviço', como item novo da fila, logo antes do núcleo (depois dos itens 2 a 4)".

Motivo registrado: entrar é acesso (revisão própria de segurança) e a camada única de serviço (E4·1: "E41a") precisa
existir antes do primeiro módulo do núcleo.

## 2. Objetivo
Uma pessoa da equipe de um estúdio entra com e-mail e senha, escolhe o estúdio (se tiver mais de um) e sai. Toda ação
do servidor passa por um caminho único com as 6 portas (`ARCHITECTURE.md` §4), que os módulos do núcleo usam sem
reescrever.

## 3. Requisitos funcionais

### 3.1 Entrar, sair e sessão
| ID | Requisito | Fonte |
|---|---|---|
| RF-01 | A pessoa entra com e-mail e senha, pelo Supabase Auth, chamado só pelo servidor (`src/server`). | E36·A; `ARCHITECTURE.md` §4 porta 1 e §12 |
| RF-02 | E-mail ou senha errados, conta inexistente ou conta sem estúdio ativo recebem a **mesma** mensagem genérica, sem dizer qual parte falhou, com tempo de resposta parecido. | ASVS 4.0.3 V2.2, V3; ADR 0005 (enumeração) |
| RF-03 | A sessão fica em cookie que o JavaScript do navegador não lê (HttpOnly), só por HTTPS (Secure), com SameSite; o token nunca vai ao endereço (URL), ao armazenamento local ou a registro. | ASVS V3.4.1 a V3.4.3; `AGENTS.md` §6 |
| RF-04 | O navegador não tem cliente do banco nem chave do banco: nenhuma chamada do navegador vai ao Supabase. | `ARCHITECTURE.md` §4; `SECURITY.md` §3 |
| RF-05 | A cada entrada nasce uma sessão nova; a anterior do mesmo navegador não é reaproveitada. | ASVS V3.2.1 |
| RF-06 | **Sair** (menu Sua conta) encerra a sessão no Supabase Auth e apaga o cookie. O token antigo é recusado: a porta 1 confere a sessão no Auth a cada pedido **ou** o token de acesso é curto; o plano escolhe um e prova (CA-13). Toda resposta com dado ou de quem tem sessão leva `Cache-Control: no-store`, para que voltar no navegador não mostre dado. | ASVS V3.3.1, V8.2.1; `DESIGN.md` §8b (Sua conta) |
| RF-07 | A sessão termina no tempo decidido em E39·3; depois disso a pessoa volta à tela de entrar, sem perder o que já foi gravado. | ASVS V3.3.2; E39·3 |
| RF-08 | Tentativas de entrar têm limite (por endereço de origem e por conta); passou do limite, a resposta é a mesma mensagem genérica de "tente mais tarde". O contador por endereço de origem fica fora do registro (RF-25) e expira sozinho. Os números ficam no plano. | ASVS V2.2.1; RGPD art. 5(1)(e) |
| RF-09 | Ninguém cria conta pelo app: o cadastro aberto do Supabase Auth fica desligado. Conta só nasce pelo cadastro de estúdio ou pelo convite de equipe (fora, §6). | `ARCHITECTURE.md` §2; ADR 0005 (convite pelo servidor) |
| RF-10 | Pedidos que gravam são protegidos contra envio forjado de outro site (CSRF). | ASVS V4.2.2 |

### 3.2 Estúdio da sessão (porta 2)
| ID | Requisito | Fonte |
|---|---|---|
| RF-11 | Depois de entrar: sem estúdio ativo → a mensagem genérica de RF-02 e a sessão é encerrada; com um estúdio → ele é escolhido sozinho; com mais de um e nenhum escolhido → tela **Escolher estúdio**; com um já escolhido e ativo → segue nele. | item 3 R-6; ADR 0005 D2 |
| RF-12 | A escolha passa só por `app.escolher_estudio`, chamada pelo servidor com o token da pessoa e a chave pública do banco, por uma função de passagem no esquema `public`, `security invoker`. A chave de serviço nunca é usada para isso, nem no servidor. | recomendação do Engenheiro de segurança; ADR 0005 D1 e D2; `SECURITY.md` §2 |
| RF-13 | A tela Escolher estúdio mostra só o nome dos estúdios em que a pessoa tem papel **ativo**; nada de estúdio em que ela não tem papel. | ADR 0005 (RF-04 do item 3) |
| RF-14 | **Trocar de estúdio** (menu Sua conta, só com mais de um) abre a mesma tela. | `DESIGN.md` §8b |
| RF-15 | Nenhuma ação usa estúdio vindo do pedido: o estúdio é o de `app.estudio_da_sessao()`. Se a tela que fez o pedido mostrava outro estúdio (troca feita em outro aparelho), a ação é recusada com o código `estudio_trocado`, nada é lido nem gravado, e a tela recarrega; o valor enviado só é comparado, nunca usado. A comparação é feita na **mesma transação** da gravação (não antes, em pedido separado). | `ARCHITECTURE.md` §4 porta 2; ADR 0005 D2 (estúdio da sessão é por pessoa, não por aparelho) |

### 3.3 Camada única de serviço (`src/server`)
| ID | Requisito | Fonte |
|---|---|---|
| RF-16 | Existe um único jeito de declarar uma ação do servidor: recebe a permissão pedida, o esquema da entrada e o trabalho; resolve as portas 1 a 4 antes do trabalho, entrega ao trabalho `usuarioId`, `orgId` e `papel` (da sessão) e o acesso ao banco com a sessão da pessoa (porta 5), e grava o registro (porta 6). | E4·1; `ARCHITECTURE.md` §4; plano da Agenda §5.1 |
| RF-17 | As portas rodam nesta ordem; a primeira que recusa para tudo, e nada depois dela roda. | `ARCHITECTURE.md` §4; `src/server/AGENTS.md` |
| RF-18 | Porta 3: a permissão é conferida pelo papel da sessão (dona, recepção, profissional); o que cada papel pode em cada módulo vem da spec do módulo. Esta spec entrega o mecanismo e as permissões das ações dela. | ADR 0005 T5 |
| RF-19 | Porta 4: toda entrada é validada por esquema; campo a mais, tipo errado, tamanho acima do limite ou texto vazio onde é obrigatório → `entrada_invalida`, e nada chega ao banco. | ASVS V5.1.3, V5.1.4 |
| RF-20 | Porta 5: o servidor fala com o banco só com a sessão da pessoa (trava RLS); a chave de serviço não aparece em `src/server` nem em `src/data` nesta spec. | `ARCHITECTURE.md` §4; `src/data/AGENTS.md` |
| RF-21 | Toda ação do servidor (das telas, e no futuro do painel, do portal e da API) é declarada por RF-16; ação declarada de outro jeito é barrada por checagem automática. | E4·1; `src/server/AGENTS.md` |
| RF-22 | Erros saem só como **códigos** (`sem_login`, `estudio_trocado`, `sem_estudio`, `sem_permissao`, `entrada_invalida`, `conflito`, `limite`, `erro_interno`), sem mensagem do banco, pilha, identificador interno ou dado de pessoa; a tela traduz o código em frase genérica. | ASVS V7.4.1; `ARCHITECTURE.md` §7 |

### 3.4 Registro (porta 6, auditoria)
| ID | Requisito | Fonte |
|---|---|---|
| RF-23 | Toda ação que grava deixa uma linha de registro; leitura só registra quando a spec do módulo mandar (ex.: ficha de saúde). Entrar (com e sem sucesso), sair, escolher e trocar de estúdio também registram, como em RF-24a. | `ARCHITECTURE.md` §4 porta 6; ASVS V7.1.3, V7.2.1 |
| RF-24 | **O que se grava:** nome do evento (ex.: `bloqueio.criar`), resultado (`ok` ou o código de RF-22), quando (UTC), `usuario_id`, `org_id`, identificadores dos objetos tocados e um identificador do pedido. | ASVS V7.1.3; `ARCHITECTURE.md` §4 |
| RF-24a | Linhas de antes do estúdio da sessão: **entrar com sucesso** grava `usuario_id` e `org_id` vazio; **escolher e trocar de estúdio** gravam o `org_id` do estúdio escolhido (o novo, na troca); **sair** grava o `org_id` da sessão, ou vazio se não havia; **tentativa de entrar que falha** grava só evento, resultado, quando e identificador do pedido: sem e-mail, sem IP, sem `usuario_id` e sem `org_id`. Quem grava essas linhas não usa a chave de serviço (o plano escolhe o meio, com ADR e teste). | ASVS V7.2.1; `SECURITY.md` §2 |
| RF-25 | **O que nunca se grava:** nome, e-mail, telefone, texto digitado, conteúdo dos campos, respostas de ficha de saúde, senha, token, cookie, endereço IP, endereço (URL) com parâmetros. | `ARCHITECTURE.md` §4 e §7; ASVS V7.1.1, V7.1.2; RGPD art. 5(1)(c) |
| RF-26 | Ninguém com login altera nem apaga uma linha do registro; cada pessoa só acrescenta a própria linha, no estúdio da sessão (ou nas formas de RF-24a); a linha de tentativa que falha só aceita os campos de RF-24a. Ler o registro fica para spec própria (nenhuma tela lê nesta spec). | `ARCHITECTURE.md` §4; ASVS V7.3.3 |
| RF-27 | Se o registro de uma ação que grava falha, a gravação é desfeita e a resposta é `erro_interno`. | `ARCHITECTURE.md` §4 ("quem fez o quê") |
| RF-28 | Pedido recusado na porta 1 (sem login) não grava no banco (não há quem), salvo a tentativa de entrar que falha (RF-24a). | dedução de `ARCHITECTURE.md` §4 |
| RF-29 | Exceções E6·1 e E6·2 valem como estão: o modo "entrar como o estúdio" e o painel admin não entram nesta spec, e nada aqui os registra nem os impede. | `SECURITY.md` §5 |

### 3.5 Tela de entrar e idiomas
| ID | Requisito | Fonte |
|---|---|---|
| RF-30 | Telas desta spec: **Entrar** (campos E-mail e Senha, uma ação preta), **Escolher estúdio** e os itens Trocar de estúdio e Sair do menu Sua conta; os outros itens do menu aparecem com "em desenvolvimento". | `DESIGN.md` §5, §8, §8b |
| RF-31 | As telas seguem só o `DESIGN.md`. Nome ou peça que não está lá (ex.: o botão "Entrar", os rótulos "E-mail" e "Senha", o título "Escolher estúdio") entra no `DESIGN.md` primeiro, pela ficha visual (etapa 6), com aprovação do dono. | `DESIGN.md` cabeçalho e §10 item 8 |
| RF-32 | Cada tela tem os estados carregando, erro (com "Tentar de novo" quando couber) e sucesso; o campo Senha aceita ao menos 64 caracteres, sem cortar nem alterar o que foi digitado, com opção de mostrar e esconder; campos com rótulo e erro com ícone e texto. | `DESIGN.md` §8 e §9; ASVS V2.1.2, V2.1.3, V2.1.12 |
| RF-33 | Nenhum dado de pessoa no endereço (URL): nem e-mail, nem estúdio, nem motivo do erro. | `ARCHITECTURE.md` §7 |
| RF-34 | Nasce aqui a base comum de idiomas `src/app/i18n/` (pt, es, en), no formato do ADR 0006 D1; os módulos só acrescentam blocos. Todos os textos das telas desta spec existem nos três idiomas. | E3·1; decisão técnica do Arquiteto (28/11) |
| RF-35 | Depois de escolhido o estúdio, as telas usam o idioma padrão do estúdio (`estudios.idioma`). | E3·1; item 3 RF-09 |

## 4. Requisitos não funcionais
| ID | Requisito | Fonte |
|---|---|---|
| RNF-01 | ASVS 4.0.3 nível 2 nos capítulos V2 (autenticação), V3 (sessão), V4 (acesso), V5 (validação), V7 (registro) e V8 (proteção de dados, inclusive cache). | `ARCHITECTURE.md` §7 |
| RNF-02 | Nenhum segredo no repositório; endereço e chave pública do banco só por variável de ambiente, guardada nos cofres. | `SECURITY.md` §2; Twelve-Factor III |
| RNF-03 | WCAG 2.2 AA nas telas (contraste, toque 44/40, foco visível, erro anunciado ao leitor de tela, colar senha permitido). | `ARCHITECTURE.md` §11; `DESIGN.md` §9; WCAG 2.2 3.3.8 |
| RNF-04 | Bibliotecas, versões e API só depois de lida a documentação oficial; cada escolha em ADR. | `AGENTS.md` §6 |
| RNF-05 | Banco: só migration em `supabase/`, testada no banco local; nunca aplicada no remoto pela IA. | `AGENTS.md` §1 |

## 5. Critérios de aceite (verificáveis)
| ID | Critério | Como se prova |
|---|---|---|
| CA-01 | Entrar com e-mail e senha certos cria sessão; senha errada, e-mail sem conta e conta sem estúdio ativo dão a mesma resposta. | integração com o Auth do banco local |
| CA-02 | O cookie da sessão tem HttpOnly, Secure e SameSite; `document.cookie` não o mostra; nada no armazenamento local. | e2e |
| CA-03 | O pacote do navegador não contém cliente do banco, endereço do banco nem chave; nenhuma ida do navegador ao Supabase durante o fluxo. | teste do build e e2e (rede observada) |
| CA-04 | **Sem sessão, nada passa:** um teste percorre todas as ações declaradas e chama cada uma sem sessão e com sessão vencida → `sem_login`, nada gravado. | integração |
| CA-05 | **Um estúdio não usa a sessão de outro:** pessoa de A e B com A escolhido manda `org_id` de B no pedido → recusado com `estudio_trocado`, nada lido nem gravado em A ou B; pessoa só de A tenta escolher B → recusado, nada muda; pessoas de A e de B ao mesmo tempo nunca veem dado uma da outra. | integração e pgTAP |
| CA-06 | Troca de estúdio feita em outro aparelho → a próxima ação da tela antiga recebe `estudio_trocado` e não grava. | integração |
| CA-07 | As portas rodam na ordem; recusa numa porta impede as seguintes (inclusive o trabalho e o banco). | unidade |
| CA-08 | Entrada fora do esquema (campo a mais, tipo, tamanho, vazio) → `entrada_invalida`, nenhuma ida ao banco. | unidade |
| CA-09 | Ação que grava cria uma linha de registro com os campos de RF-24; busca no registro pelos e-mails, nomes e textos usados no teste não acha nada. | integração |
| CA-09a | Entrar com sucesso, entrar que falha, escolher, trocar e sair gravam as linhas de RF-24a; a de falha não tem e-mail, IP, `usuario_id` nem `org_id`; o contador de tentativas não aparece no registro e expira. | integração |
| CA-10 | Ninguém com login altera ou apaga o registro, nem grava linha de outra pessoa ou de outro estúdio; `anon` não toca o registro. | pgTAP (molde de isolamento do item 3) |
| CA-11 | Registro que falha desfaz a gravação da ação. | integração |
| CA-12 | Respostas de erro só com códigos de RF-22; nenhuma mensagem do banco nem pilha na resposta. | unidade e integração |
| CA-13 | Depois de Sair, o token antigo é recusado no pedido seguinte (pelo meio escolhido em RF-06); toda resposta com dado traz `Cache-Control: no-store`; voltar no navegador não mostra dado. | e2e e integração |
| CA-14 | Passado o limite de tentativas, a entrada é recusada com a mensagem genérica. | integração |
| CA-15 | Sessão expira conforme E39·3. | integração (relógio controlado) |
| CA-16 | Não existe criação de conta pelo app; o cadastro aberto está desligado na configuração local. | integração e leitura de `supabase/config.jsonc` |
| CA-17 | A função de passagem é `security invoker` e só funciona com o token da pessoa; `anon` e `public` não a executam (sem privilégio de execução); nenhum uso da chave de serviço em `src/`. | pgTAP e checagem automática no código |
| CA-18 | Tela Escolher estúdio lista só estúdios com papel ativo da pessoa. | integração e e2e |
| CA-18a | O campo Senha aceita e envia 64 caracteres ou mais sem cortar. | unidade e e2e |
| CA-19 | Fluxos entrar, erro, carregando, escolher, trocar e sair passam em 390 px e 1440 px, com checagem automática de acessibilidade. | e2e (projetos `celular` e `computador` do item 2) |
| CA-20 | Textos das telas existem em pt, es e en, com as mesmas chaves e sem texto vazio; após escolher o estúdio vale `estudios.idioma`. | checagem de tipos e unidade |
| CA-21 | Ação declarada fora do molde de RF-16 é barrada. | lint ou teste automático na CI |
| CA-22 | Revisões do tipo (§ cabeçalho) sem "Bloqueia"; veredito do QA; conferência do dono na prévia. | relatórios no PR |

## 6. Fora de escopo
- **Cadastro de estúdio** (cria estúdio e a conta da dona): item "Cadastro de estúdio e cobrança da assinatura" da fila.
- **Convite de equipe** (com aceite e resposta igual com ou sem conta, item 3 R-7) e regra "sempre uma dona": spec da
  tela de equipe. Regra de senha (tamanho, senhas vazadas, ASVS V2.1) entra onde a senha é criada: cadastro e convite.
- **Recuperação de senha:** depende de E39·1.
- **Dupla verificação:** no painel admin pela E4·2; no app do estúdio depende de E39·2.
- **Painel admin** e o modo "entrar como o estúdio" (E4·2, E6·1, E6·2).
- **Tela de leitura do registro**, **prazo de guarda** do registro e a tarefa que apaga o vencido: spec da vida do
  estúdio, antes da produção (`SECURITY.md` §7). Até lá nada se apaga.
- Minha conta, Preferências (idioma pessoal), Meu faturamento; entrar com Google, link mágico ou código; API pública.
- Mudar a configuração do Auth no projeto remoto: é produção e acesso; o dono faz pelo painel do Supabase, com
  passo a passo no pedido de merge.

## 7. Dependências
- Itens 2 a 4 da fila juntados: item 2 (app, CI), item 3 (`estudios`, `membros`, `app.estudio_da_sessao()`,
  `app.escolher_estudio()`, molde de isolamento) e item 4 (design system no código).
- Lacuna para o plano: hoje a trava de `estudios` só mostra o estúdio da sessão; RF-13 precisa dos nomes dos estúdios
  da pessoa antes da escolha (Engenheiro de dados decide o meio, com ADR).
- O script `db:start` do item 2 desliga o Auth e a API do banco local; CA-01 e CA-04 precisam deles (o plano ajusta).

## 8. Dúvidas ao dono (máx. 3, todas de acesso)
**E39·1 · Recuperação de senha na primeira versão**
- **E39·1·A:** entra agora: "Esqueci a senha" manda um link por e-mail, com resposta igual com ou sem conta; pede um
  serviço de e-mail na UE já nesta spec.
- **E39·1·B:** fica para a spec do convite de equipe; até lá só há contas de teste. **Trava a abertura a clientes:**
  sem recuperação de senha, o sistema não abre a estúdios reais (ASVS V2.5).
- **Recomendo B:** não há estúdio real antes do cadastro e o serviço de e-mail ainda não foi escolhido. Desfaz-se
  reabrindo a spec.

**E39·2 · Dupla verificação (código do app autenticador) para a equipe do estúdio**
- **E39·2·A:** agora não; só no painel admin (E4·2); a pergunta volta na spec da ficha de saúde (nível 3 da ASVS);
  a dupla verificação da dona é obrigatória antes de dados reais.
- **E39·2·B:** opcional, cada pessoa liga se quiser (tela nova de configurar).
- **E39·2·C:** obrigatória para a dona.
- **Recomendo A, com a condição:** a dupla verificação da dona é obrigatória antes de qualquer dado real. Motivo:
  menor escopo agora; o dado mais sensível (ficha) ainda não existe. Risco até lá: conta só com senha. Desfaz-se com
  spec nova.

**E39·3 · Tempo da sessão**
- **E39·3·A:** entra de novo a cada 12 h desde a entrada, sem corte por parada. Não cumpre sozinha a ASVS V3.3.2
  nível 2 (12 h **ou** 30 min parado, as duas regras).
- **E39·3·B:** 12 h no máximo e corte após 30 min parado.
- **E39·3·C:** 30 dias, como app de celular; fica abaixo do nível 2 da ASVS e vira exceção declarada.
- **Recomendo B:** cumpre a ASVS V3.3.2 nível 2 e protege a recepção, onde o aparelho é dividido. Se o corte por
  parada do Supabase exigir plano pago, o corte é feito pelo servidor; se nem assim der, o trabalho para e vira
  pergunta ao dono (E23·3·A: só o gratuito). Desfaz-se mudando um valor de configuração.

## 9. Assumptions (decisões técnicas do papel, à vista na aprovação)
1. Antes de entrar (sem estúdio), a tela usa o idioma do navegador entre pt, es e en; fora deles, pt.
2. Depois de entrar, a pessoa vai à página inicial do app do item 2 (o primeiro módulo do núcleo passa a ser o destino
   na spec dele).
3. Bibliotecas, desenho do registro e da função de passagem, e os números de RF-08: no plano, com ADR (sugestão do
   plano da Agenda §5.1: `@supabase/supabase-js`, `@supabase/ssr` sem cliente no navegador, `zod`).
