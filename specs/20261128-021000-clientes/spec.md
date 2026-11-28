# Spec · Clientes (primeira versão)

- **Status:** Draft
- **Aprovação do dono:** (pendente)
- **Aprovação do merge:** (pendente)
- **Pasta:** `specs/20261128-021000-clientes/` · **Branch:** `feat/clientes` (da `previas`), empilhada por merge sobre
  `feat/banco-ligacao`, `feat/design-system-codigo` e `feat/entrar-servico` (decisão do Engenheiro de DevOps); construção
  em PR de rascunho, nada é juntado sem o dono (E22·B)
- **Item da fila:** 5 de `docs/BACKLOG.md` (núcleo, um módulo por spec: Clientes, E3·2), em paralelo por ordem do dono (E22·B)
- **Tipo:** Tela, com Banco e Código (`docs/guias/processo-sdd.md` §3 e §4) · **Revisores:** Revisor de design;
  Engenheiro de dados (quem não fez) e Auditor de risco (banco e dado de cliente); Engenheiro de segurança (acesso,
  RGPD e LGPD); Revisor de código; QA
- **Escrito por:** Analista de requisitos · **Norma:** IEEE 29148 e BABOK · **Revisa:** Gerente de projeto (etapa 5b)
- **Fontes lidas:** `AGENTS.md`; `ARCHITECTURE.md` §3 a §7 e §11; `DESIGN.md` (inteiro); `SECURITY.md`;
  `docs/guias/processo-sdd.md`; `src/*/AGENTS.md`; `docs/produto/clientes.md` e `docs/produto/README.md` (branch
  `docs/produto-modulos`, PR #2, E21); `docs/decisoes/2026-11-27-fundacao.md` (E3·2, E21, E22·B, E5·2, E6·1, E6·2,
  mesma branch); `specs/20261128-010000-banco-ligacao/spec.md` (branch `feat/banco-ligacao`, RG-01 a RG-08 e anexo
  A); `specs/20261128-020000-agenda/spec.md` (branch `feat/agenda`); `specs/20261128-020500-agendamento/spec.md`
  (branch `feat/agendamento`). Do antigo (E22·B, só leitura, nada copiado, nenhum seed ou dado):
  `crm-agenda/supabase/migrations/` 20260601000002, 20260609_001, 20260615144330, 20260619225200, 20260616223025,
  20261030300000, 20260613_004, 20261113230100 e 20261114010000.

## 1. Pedido do dono (literal)
> "A" — E3·2: "Primeira versão com o núcleo (Agenda, Agendamento, Clientes, Formulários, Catálogo, Checkout, Caixa)".

> "O banco de dados atual é tudo de desenvolvimento, todos os dados são fictícios. O que se tem são as tabelas e regras
> dele. Então use se precisar. E22b Bom trabalho e obrigado." — E22·B, 28/11/2026,
> https://claude.ai/code/session_018cV8b9epaQJNqguG5c5Aqb

O módulo, pela E21 (`docs/produto/clientes.md`): "Cadastro das clientes do estúdio, com o histórico de cada uma."
Para: dona, recepção, profissional.

## 2. O que é a primeira versão
A tela **Clientes** lista as clientes do estúdio, com busca, filtros e ordem; permite **Adicionar**, **Editar**,
**Arquivar** e abrir o **perfil** da cliente, com os dados e o histórico de atendimentos (só leitura, vindo do
Agendamento). Cumpre os pedidos da cliente pelo RGPD e pela LGPD conforme **E28·3**.

### 2.1 Recursos da lista candidata (`docs/produto/clientes.md`)
| Recurso | Primeira versão | Motivo |
|---|---|---|
| lista, busca, filtros, criar, editar, perfil | **sim** (filtros: só cadastro e última visita; §5 RF-04) | é o núcleo do módulo |
| histórico de atendimentos | **sim, só leitura** | vem do Agendamento; sem ele o perfil não cumpre a frase da E21 |
| exportar | **só os dados de uma cliente, a pedido dela** (E28·3) | dever do RGPD art. 15 e 20 e da LGPD art. 18; exportar a lista inteira fica para Importação e exportação |
| notas e alertas | depois | texto livre e a etiqueta "Alergia" podem receber dado de saúde; entram com a spec de Formulários (E5·2, E21·2), como no Agendamento |
| etiquetas e segmentos | depois | etiquetas do `DESIGN.md` §5 dependem de regras (VIP, retoque) de outros módulos |
| consentimento de marketing | depois | só tem uso com o módulo Marketing; não se coleta antes (RGPD art. 5(1)(c)) |
| juntar duplicados | depois | mexe em agendamentos e, depois, em dinheiro; a v1 só avisa o duplicado (E28·1) |
| saldo da cliente | depois | dinheiro (E21·3; Checkout e Financeiro) |

## 3. Quem usa e o que cada papel vê
| Papel | Vê | Pode |
|---|---|---|
| Dona | todas as clientes do seu estúdio | adicionar, editar, arquivar, desarquivar; pedidos RGPD/LGPD conforme E28·3 |
| Recepção | todas as clientes do seu estúdio | adicionar, editar, arquivar, desarquivar |
| Profissional | conforme E28·2 | conforme E28·2 |
| Sem papel no estúdio ou sem login | nada | nada |

Nenhum papel vê cliente de outro estúdio (`ARCHITECTURE.md` §5). Nenhuma tela de Clientes mostra dado de saúde na v1.

## 4. Telas e estados
Só peças, nomes e medidas do `DESIGN.md`. Peça ou nome que faltar para no caminho e entra no `DESIGN.md` com o dono
primeiro (ficha visual, etapa 6).

**Tela Clientes** (título "Clientes", `DESIGN.md` §6; módulo sem seções, §7).
- **Computador (1440):** barra do topo: título e subtítulo (total, ex.: "128 clientes") · busca geral · **Opções ▾**
  (itens "em desenvolvimento", `DESIGN.md` §8) · **+ Adicionar** (preto, única ação principal) · ajuda · Notificações ·
  Sua conta. Barra da lista: campo "Buscar cliente" · **Filtros ▾** · (à direita) **Ordenar: Última visita ▾**.
  Tabela (linha 40, texto 13): bolinha da cliente 24 · nome · telefone · última visita · ⋮ (Editar · Arquivar;
  "Duplicar" não se aplica a cliente; "Excluir" não fica na lista, só no perfil, conforme E28·3).
- **Celular (390):** nível 1: título "Clientes", sininho e Sua conta; **+ Adicionar** com contorno, com nome, no topo;
  campo "Buscar cliente" com o funil ao lado; linhas de 64 com bolinha 40, nome e telefone; barra de baixo com
  Clientes atual em azul e **Agendar** preto no meio. Filtros e Ordenar em folha de baixo (Ordenar na primeira linha).
- **Perfil da cliente** ("Ver cliente"): cabeçalho com bolinha, nome e ⋮ (Opções da cliente). Seletor com as abas
  **Dados** e **Atendimentos** (`DESIGN.md` §5). Dados: nome, telefone, e-mail e data de nascimento (conforme E28·1),
  "Cliente desde". Atendimentos: linha do tempo do mais novo ao mais antigo (data, serviço, profissional, status com
  ícone e palavra); a profissional vê aqui só o que a E26·1 da Agenda e a E28·2 deixam (atendimento de outra
  profissional aparece sem serviço, se E26·1·B). Botão de agendar para esta cliente leva ao Agendamento ("em desenvolvimento" até ele existir).
  Título do perfil, nome do botão de agendar daqui e "Exportar dados da cliente" (E28·3) não estão no `DESIGN.md`
  §6: vão à ficha visual.
- **Adicionar e Editar cliente:** painel à direita de 480 no computador; tela sem barra no celular com "Salvar" no
  rodapé. Campos conforme E28·1 (rótulo acima, obrigatório com * cinza, erro com contorno vermelho e mensagem com
  ícone); telefone com o código do país, já preenchido com o país do estúdio. Salvar · Cancelar.
- **Aviso de duplicado:** ao salvar com telefone já usado por outra cliente do mesmo estúdio, conforme E28·1.

**Estados (`DESIGN.md` §8):** carregando (linhas cinza só depois de 0,3 s, anunciado ao leitor) · vazio ("Ainda não há
clientes" + frase + "Adicionar cliente" com contorno) · sem resultado (o que foi buscado e "Limpar filtros") ·
aba Atendimentos vazia ("Ainda não há atendimentos") · erro (o que houve e "Tentar de novo") · sucesso (aviso depois
de salvar; "Desfazer" depois de arquivar).

## 5. Requisitos funcionais
| ID | Requisito | Fonte |
|---|---|---|
| RF-01 | A lista mostra as clientes ativas do estúdio, paginada, na ordem "Última visita" (mais recente primeiro; quem nunca veio por último); **Ordenar** também oferece "Nome" (A–Z). | `DESIGN.md` §7 e §8b; `ARCHITECTURE.md` §5 |
| RF-02 | **Buscar cliente** acha por parte do nome (sem diferença de maiúscula e acento) ou por parte do telefone (só os dígitos). | `DESIGN.md` §5 e §6 |
| RF-03 | **Adicionar** cria a cliente com os campos e as regras da E28·1. | candidata; E28·1 |
| RF-04 | **Filtros** (dentro do botão, com a pílula de contador e "Limpar filtros"): cadastro (Ativas, padrão · Arquivadas), última visita (nunca · há mais de 30, 60 ou 90 dias). Aniversário: depois, com Marketing (o uso para campanha não se apoia na base do DP-02). Etiquetas, saldo e origem: depois. | `DESIGN.md` §7; DP-02 |
| RF-05 | **Editar** muda os mesmos campos, com as mesmas regras. | candidata |
| RF-06 | **Arquivar** tira a cliente da lista padrão e da busca do Agendamento, sem apagar dado nem atendimento; desarquivar a traz de volta. | `DESIGN.md` §6 |
| RF-07 | O **perfil** mostra os dados e os atendimentos da cliente (todos os status), lidos do Agendamento. | E21 (`docs/produto/clientes.md`) |
| RF-08 | **Última visita** é a data do último atendimento Concluído da cliente, no fuso do estúdio. | spec do Agendamento (status) |
| RF-09 | O cadastro rápido do Agendamento (E27·1·A, nome e telefone) usa as mesmas regras desta spec (RN-01 a RN-04) e a mesma tabela; a cliente nasce com o cadastro incompleto e se completa em Clientes. | spec do Agendamento RF-14 |
| RF-10 | Pedidos da cliente pelo RGPD e pela LGPD: acesso, portabilidade e apagamento conforme E28·3; retificação (corrigir dado errado) pelo **Editar** (RF-05). Antes de cumprir, quem atende confere que quem pede é a própria cliente (ex.: pedido vindo do telefone ou e-mail cadastrado, ou presencial); na dúvida, pede mais um dado. | RGPD art. 12(6), 15, 16, 17 e 20; LGPD art. 18 II, III, V e VI |
| RF-11 | Toda ação passa pelas 6 portas; criar, editar, arquivar, desarquivar, exportar e apagar ficam no registro (porta 6) só com identificadores, sem nome, telefone, e-mail ou data de nascimento. | `ARCHITECTURE.md` §4 e §7 |

## 6. Regras de negócio (verificáveis)
| ID | Regra |
|---|---|
| RN-01 | Nome obrigatório: 1 a 120 caracteres depois de tirar espaços das pontas. |
| RN-02 | Telefone guardado no formato internacional (código do país + número, ex.: +34…); só dígitos depois do "+"; número válido para o país escolhido. Obrigatório ou não: E28·1. |
| RN-03 | E-mail, se houver: formato válido, guardado em minúsculas. Data de nascimento, se houver: não pode ser futura nem antes de 1900. |
| RN-04 | Telefone repetido: só se compara dentro do mesmo estúdio, entre clientes não apagadas; o que acontece é a E28·1. A checagem nunca diz nada sobre clientes de outro estúdio. |
| RN-05 | O estúdio de toda leitura e gravação vem da sessão, nunca do pedido. |
| RN-06 | Cliente arquivada não aparece na lista padrão nem na busca do Agendamento; seus atendimentos continuam no histórico e na Agenda. |
| RN-07 | Cliente apagada a pedido (E28·3) perde nome, telefone, e-mail e data de nascimento de forma que não se recuperam; nos atendimentos passados aparece como "Cliente removida". |
| RN-08 | A busca e a lista têm teto de itens por página; passou do teto, pagina, nunca corta calado. |

## 7. Dado pessoal (RGPD e LGPD)
| ID | Requisito | Fonte |
|---|---|---|
| DP-01 | Papéis: o estúdio é o responsável pelos dados das suas clientes; a plataforma é a operadora, com contrato entre os dois. | RGPD art. 4(7), 4(8) e 28; LGPD art. 5 VI e VII; `ARCHITECTURE.md` §7 |
| DP-02 | Base legal do cadastro: executar o serviço pedido pela cliente (marcar e fazer o atendimento). Não se pede consentimento para o cadastro; consentimento só para marketing (depois, módulo Marketing) e saúde (Formulários). | RGPD art. 6(1)(b); LGPD art. 7 V |
| DP-03 | Minimização: a v1 guarda só os campos da E28·1; documento, gênero, endereço, foto e notas não entram. | RGPD art. 5(1)(c); LGPD art. 6 III |
| DP-04 | Nome, telefone, e-mail, data de nascimento e o texto buscado nunca em URL, registro de erro, monitoramento ou notificação; o perfil abre pelo identificador. | `ARCHITECTURE.md` §7; `SECURITY.md` §4 |
| DP-05 | Exportar e apagar a pedido da cliente: o que entra na v1 é a E28·3. Prazo automático de guarda (apagar depois de X anos sem visita): depois, com Ajustes. | RGPD art. 5(1)(e), 15, 17 e 20; LGPD art. 16 e 18 |
| DP-07 | Apagamento e cópias de segurança: o dado apagado continua só nas cópias diárias cifradas (`SECURITY.md` §6; E5·3) até elas vencerem, pelo prazo de guarda das cópias, que ainda não está escrito em `ARCHITECTURE.md` nem em `SECURITY.md` e tem de ser fixado na spec da cópia diária antes da produção; a cliente é informada desse prazo. Numa restauração, o processo reaplica os apagamentos feitos depois da cópia, e o dado não volta. | RGPD art. 17 e 5(1)(e); E5·3 |
| DP-08 | Arquivo exportado (E28·3): nome só com identificador e data, sem nome nem telefone da cliente; resposta sem guarda em cache (`Cache-Control: no-store`); nada do arquivo fica guardado no servidor depois da entrega. | OWASP ASVS 4.0.3 V8.2.1 e V8.3; RGPD art. 32 |
| DP-06 | Dados na UE (E5·1). As exceções E6·1 e E6·2 valem como estão: o modo suporte do dono não gera registro. | E5·1; `ARCHITECTURE.md` §6 |

## 8. Tabelas
Base da trava (estúdio, membros, papéis, função de checagem) vem do item 3. Cada linha é **sugestão** do Analista;
quem decide é o Engenheiro de dados no plano, com ADR e revisão de outro papel (E16·1; RG-02 do item 3).

| Tabela ou função (antigo) | Sugestão | Motivo |
|---|---|---|
| `clients` | **reescrever** | ficam `org_id`, nome, telefone (com código do país), e-mail, data de nascimento (conforme E28·1), arquivada em, apagada em, criada e alterada em, quem criou; chave única (`org_id`, `id`) para as ligações com o mesmo estúdio (como no antigo, 20260619225200); índices por `org_id` + telefone, `org_id` + nome normalizado e `org_id` + última visita. Saem: `cpf`, documento, `gender`, cidade, `notes`, `fixed_notes`, `alert_*` (podem ter saúde), `tags`, `contact_pref`, `status` em texto, `balance`, `total_spent` e `loyalty_*` (dinheiro e Fidelidade), `source`, `location_id`, consentimento de imagem, `merged_*`, `blocked_*` |
| `client_notes` | **adiada** (Formulários) | texto livre pode ter dado de saúde |
| `client_balance_entries` | **adiada** (Checkout e Financeiro) | dinheiro |
| `client_entitlements`, `client_entitlement_entries` | **adiada** (Catálogo e Checkout) | pacotes e planos |
| `client_marketing_preferences` | **adiada** (Marketing) | consentimento sem uso na v1 |
| funções `client_list_summary`, `client_profile`, mesclagem e bloqueio de cliente | **descartar** na v1 | dependem de colunas que saem; a leitura da lista e do perfil se desenha de novo no plano |

Última visita: guardada ou calculada a partir dos agendamentos é decisão do Engenheiro de dados (RF-08).
Regras que valem (RG-04): `org_id` obrigatório, trava RLS pela função de checagem do item 3, índice por `org_id`
e teste de isolamento em cada tabela.

## 9. Requisitos não funcionais
| ID | Requisito | Fonte |
|---|---|---|
| RNF-01 | WCAG 2.2 AA: contraste, toque 44/40, foco visível, status do atendimento com ícone e palavra, erros de campo ligados ao campo no leitor de tela. | `DESIGN.md` §9 |
| RNF-02 | A lista e o perfil fazem um número fixo de idas ao banco, que não cresce com o número de clientes ou de atendimentos (teto no plano). | `ARCHITECTURE.md` §5 e §11 |
| RNF-03 | A busca responde com a lista de um estúdio grande (volume de teste fixado no plano) sem varrer a tabela inteira. | `ARCHITECTURE.md` §5 |
| RNF-04 | Textos por arquivo de idioma (pt, es, en); data no formato do idioma e no fuso do estúdio. | E3·1; `ARCHITECTURE.md` §11 |

## 10. Critérios de aceite
| ID | Critério | Prova |
|---|---|---|
| CA-01 | RN-01 a RN-04, RN-07 e RN-08, a busca sem acento e por dígitos e o cálculo da última visita têm teste em `src/domain`. | unidade, CI verde |
| CA-02 | O estúdio A não lê, cria, altera, arquiva nem apaga cliente do estúdio B; a busca e o aviso de duplicado de A nunca devolvem nem revelam cliente de B (mesmo telefone em B não avisa nada em A). | isolamento, CI verde |
| CA-03 | Sem login e sem papel no estúdio: nada é lido nem gravado; cada papel × cada ação conforme a §3 (após E28·2 e E28·3). | teste de banco e do servidor, CI verde |
| CA-04 | Estúdio vindo no pedido é ignorado. | teste do servidor |
| CA-05 | Em 390 e 1440: adicionar, editar, erro de campo, aviso de duplicado (E28·1), buscar por nome e por telefone, filtros e "Limpar filtros", Ordenar, arquivar com "Desfazer", abrir o perfil e as duas abas. | e2e (`e2e/`), CI verde |
| CA-06 | Em 390 e 1440: estados carregando, vazio, sem resultado, aba vazia e erro como na §4. | e2e |
| CA-07 | Pedidos RGPD/LGPD conforme E28·3: o arquivo exportado tem todos os dados da cliente e nada de outra, nome do arquivo sem dado pessoal, resposta com `no-store` e nada guardado no servidor (DP-08); depois de apagar, nenhum campo pessoal se lê no banco e o histórico mostra "Cliente removida". | teste do servidor e de banco |
| CA-07b | A profissional (conforme E28·2) não recebe, nem no aviso de telefone repetido nem na aba Atendimentos, nome de cliente ou serviço que não pode ver. | teste do servidor |
| CA-08 | Nenhuma URL, registro, erro ou notificação contém nome, telefone, e-mail, data de nascimento ou o texto buscado. | teste e revisão do Engenheiro de segurança |
| CA-09 | Uma só peça preta de ação por tela; nenhuma peça, cor ou nome fora do `DESIGN.md`; checagem automática de acessibilidade sem falha nas duas larguras. | checklist §10 do `DESIGN.md`, Revisor de design, e2e |
| CA-10 | Cada tabela e função da §8 tem ADR com saída, motivo, norma e quem conferiu; migration só para as copiadas ou reescritas; nenhum seed ou dado do antigo no PR. | `docs/adr/` × PR; gitleaks |
| CA-11 | Nada aplicado no banco remoto; banco só local até a "Aprovação do merge". | histórico da CI |
| CA-12 | Revisores sem "Bloqueia", veredito do QA e conferência do dono na prévia. | relatórios no PR |

## 11. Dependências
- **Item 2** (fundação técnica): app, pnpm, Vitest, Playwright, CI, banco local, Spec Kit, gitleaks.
- **Item 3** (banco): estúdio com fuso e país, membros, papéis, função de checagem, molde do teste de isolamento.
  O país do estúdio (para o código do telefone, RN-02) hoje não está no item 3: ou o Engenheiro de dados o acrescenta
  lá, ou o plano de Clientes traz a migration que o cria, decisão do plano com ADR.
- **Item 4** (design system no código): componentes do `DESIGN.md`.
- **Spec "Entrar e camada de serviço"** (E36·A do dono, 28/11/2026: "E36a"; branch `feat/entrar-servico`, antes do
  núcleo): login e as 6 portas (`ARCHITECTURE.md` §4) por onde passa toda ação desta spec (RF-11).
- **Agendamento:** atendimentos e status (aba Atendimentos, última visita); usa a tabela e as regras desta spec no
  cadastro rápido (E27·1). Sem ele construído, a aba fica vazia e a última visita "nunca".
- **Agenda:** mostra o nome da cliente no cartão; cliente apagada aparece como "Cliente removida" (RN-07).
- **E22·B:** construção em PR de rascunho; banco só local; leitura do antigo e ADR por tabela; nada juntado sem o dono.

## 12. Fora de escopo
Ficha de saúde e anamnese (Formulários, E21·2); notas e alertas; etiquetas e segmentos; consentimento de marketing e
envios; juntar duplicados; saldo, pacotes e planos da cliente; exportar e importar a lista inteira (Importação e
exportação); foto da cliente; unidades (`locations`); portal público e cadastro feito pela própria cliente; prazo
automático de guarda; banco de produção e publicação.

## 13. Dúvidas ao dono (máx. 3)
**E28·1 · Dados do cadastro e telefone repetido** (dado de cliente, tela)
- **E28·1·A:** nome* e telefone*, e-mail e data de nascimento opcionais; telefone já usado no estúdio mostra "já
  existe uma cliente com este telefone", com o nome dela só para quem pode ver essa cliente (para a profissional,
  conforme E28·2; senão, sem nome), e deixa salvar (mãe e filha dividem número).
- **E28·1·B:** os mesmos campos; telefone repetido não deixa salvar.
- **E28·1·C:** como A, mais documento (NIF, DNI, CPF), gênero e cidade.
- **Recomendo A:** o mínimo que o atendimento usa (RGPD art. 5(1)(c)), igual ao cadastro rápido do Agendamento
  (E27·1·A), sem barrar famílias. Desfaz-se: campo novo entra por migration; B liga uma trava.

**E28·2 · O que a profissional vê e faz em Clientes** (acesso, dado de cliente) · **vai ao dono junto da E26·1 da
Agenda** (o que a profissional vê na Agenda); as duas respostas têm de ser coerentes.
- **E28·2·A:** vê e busca todas as clientes (nome e telefone) e o perfil; adiciona e edita; não arquiva nem faz os
  pedidos RGPD/LGPD. Coerente só com E26·1·A.
- **E28·2·B:** vê, busca e abre o perfil só das clientes que já atendeu, tem marcadas com ela ou que ela cadastrou (coerente com a E27·1·A do Agendamento); adiciona cliente nova
  (para marcar o próprio agendamento) e edita as que vê; não arquiva nem faz os pedidos RGPD/LGPD; o aviso de
  telefone repetido não lhe mostra nome de cliente que ela não vê. Coerente com E26·1·B.
- **E28·2·C:** tudo o que a recepção faz.
- **Recomendo B, junto com E26·1·B:** não vê cliente alheia (RGPD art. 5(1)(c), minimização; OWASP ASVS V4.1.3,
  menor acesso) e ainda cadastra e marca as próprias clientes, como pede a E26·2·A da Agenda. Desfaz-se mudando
  a permissão do papel.

**E28·3 · Pedidos da cliente: exportar e apagar os dados** (dado de cliente)
- **E28·3·A:** na v1, no ⋮ do perfil, só a dona: "Exportar dados da cliente" (arquivo baixado na hora, DP-08) e "Excluir"
  (vermelho, janelinha de confirmação), que apaga nome, telefone, e-mail e nascimento para sempre e mantém os
  atendimentos como "Cliente removida".
- **E28·3·B:** na v1 nada na tela; o estúdio pede ao suporte da plataforma, que faz à mão.
- **E28·3·C:** só "Excluir" na v1; exportar depois.
- **Recomendo A:** o estúdio cumpre sozinho o prazo de 1 mês do RGPD (art. 12(3)) e o da LGPD (art. 19), e o
  suporte não toca dado de cliente. **Não se desfaz:** o dado apagado não volta (a janelinha avisa).

## 14. Assumptions (técnicas e de formato, à vista na aprovação; recuse pelo número)
1. A lista carrega por páginas ao rolar; tamanho da página e tetos de idas ao banco: o Arquiteto fixa no plano.
2. A busca começa a partir de 2 caracteres (ou 3 dígitos de telefone) e espera a pessoa parar de digitar.
3. Validação do telefone por biblioteca de mercado, escolhida pelo Arquiteto depois de lida a documentação oficial.
4. Formato do arquivo exportado (E28·3): estruturado e de uso comum (RGPD art. 20), escolhido pelo Arquiteto.
5. A escolha de filtros e ordem fica guardada no aparelho, sem dado pessoal; a busca não fica guardada.
6. ADRs na numeração de `docs/adr/`; uma migration por tabela.
