# Spec · Formulários (núcleo): modelos, preencher e ficha de saúde cifrada

- **Status:** Draft
- **Aprovação do dono:** (pendente)
- **Aprovação do merge:** (pendente)
- **Item da fila:** 5 (`docs/BACKLOG.md`), módulo Formulários do núcleo (E3·2), em paralelo por ordem do dono (E22·B)
- **Branch:** `feat/formularios` (a partir da `previas`), construção em PR de rascunho; nada é juntado sem o dono (E22·B)
- **Tipo:** Tela, com Banco, Código e **ficha de saúde** (`docs/guias/processo-sdd.md` §3) · **Revisores:** Revisor de
  design, Engenheiro de dados (quem não fez), Auditor de risco e Engenheiro de segurança (ficha de saúde e acesso),
  Revisor de código e QA
- **Escrito por:** Analista de requisitos · **Norma:** IEEE 29148 e BABOK; conteúdo de segurança e privacidade pela
  OWASP ASVS 4.0.3 (nível 2; nível 3 neste módulo), RGPD e LGPD
- **Fontes:** E3·2; E5·2; E6·1; E6·2; E21; E21·2·A; E22·B; `docs/produto/formularios.md` (branch `docs/produto-modulos`,
  PR #2); `ARCHITECTURE.md` §3 a §7 e §11; `SECURITY.md` §2 a §5 e §7; `DESIGN.md` §5 a §10; `src/*/AGENTS.md`; spec do
  item 3 (`specs/20261128-010000-banco-ligacao/spec.md`, branch `feat/banco-ligacao`: RG-01 a RG-08 e anexo A).

## 1. Pedido do dono (literal)
> "A" — E3·2: "Primeira versão com o núcleo (Agenda, Agendamento, Clientes, Formulários, Catálogo, Checkout, Caixa)".

> "E21-2a" — E21·2, 28/11/2026: a ficha de saúde fica dentro de Formulários.
> https://claude.ai/code/session_018cV8b9epaQJNqguG5c5Aqb

> "E52a (só se realmente a norma pedir isso )" — E5·2: respostas da ficha de saúde cifradas, porque a ASVS pede
> (V6.1.2).

> "O banco de dados atual é tudo de desenvolvimento, todos os dados são fictícios. O que se tem são as tabelas e regras
> dele. Então use se precisar. E22b" — E22·B, 28/11/2026, https://claude.ai/code/session_018cV8b9epaQJNqguG5c5Aqb

Lista candidata aprovada (E21, `docs/produto/formularios.md`): modelos de formulário · ficha de saúde (anamnese) com
link, assinatura e fotos · modo no estúdio com PIN · corrigir ficha assinada · consentimentos · ficha obrigatória por
serviço.

## 2. Primeira versão (mínima) e depois
| Recurso candidato | Primeira versão | Motivo |
|---|---|---|
| Modelos de formulário (com versão) | **sim** | sem modelo não há ficha |
| Ficha de saúde: preencher e assinar | **sim**, pelo meio da E29·1 | é o núcleo do módulo (E21·2·A) |
| Consentimento explícito da cliente | **sim**, dentro de cada modelo (o "termo" do modelo) | RGPD art. 9(2)(a); LGPD art. 11, I; `ARCHITECTURE.md` §7 |
| Assinatura | **sim**, na forma da E29·3 | candidata; prova do consentimento (RGPD art. 7(1)) |
| Corrigir ficha assinada | conforme E29·3 | integridade do dado de saúde; direito de correção (RGPD art. 16) |
| Fotos na ficha | depois | mais dado de saúde (imagem) e arquivo fora do banco; pede cifra e regra próprias |
| Modo no estúdio com PIN | depois | acesso novo (aparelho do estúdio na mão da cliente) |
| Seção Termos (termo avulso, sem perguntas, ex.: uso de imagem) | depois | na primeira versão o termo mora no modelo |
| Visão geral (painel do módulo) | depois | o `DESIGN.md` §7 já tem a seção; aparece com "em desenvolvimento" (`DESIGN.md` §8) |
| Ficha obrigatória por serviço e "Bloqueia o checkout" | depois | depende do Catálogo e do Checkout |
| Ficha ligada ao agendamento ("Formulários do atendimento") | depois | a spec do Agendamento também deixou para depois |
| Envio do link por WhatsApp ou e-mail, QR | depois | integração (fila de envios, `ARCHITECTURE.md` §10); na primeira versão, "Copiar link" |
| Texto de termo sugerido pelo sistema | depois | texto jurídico pede revisão; na primeira versão o estúdio escreve |

**Regra de proteção por padrão (RGPD art. 25):** na primeira versão, **toda** ficha é tratada como ficha de saúde
(cifrada, acesso restrito), qualquer que seja o modelo. Assim não há erro de classificar um modelo como "sem saúde" e
gravar dado de saúde sem cifra.

## 3. Quem usa e quem vê
| Quem | Modelos | Fichas: criar, copiar link, ver situação | Fichas: ver as respostas |
|---|---|---|---|
| Dona | conforme E29·2 | conforme E29·2 | conforme E29·2 |
| Recepção | conforme E29·2 | conforme E29·2 | conforme E29·2 |
| Profissional | conforme E29·2 | conforme E29·2 | conforme E29·2 |
| Cliente do estúdio | — | — | preenche e assina a própria ficha, pelo meio da E29·1; não vê a ficha depois de assinada |
| Dono da plataforma em "entrar como o estúdio" | vale a E6·2 como está: pode abrir as fichas; nada fica registrado (E6·1) | | |

Mínimo necessário: quem não precisa das respostas para atender vê só a situação (RGPD art. 5(1)(c) e art. 9; ASVS
V4.1.3, menor privilégio).

## 4. Telas e estados (nomes do `DESIGN.md`)
Seções do módulo (`DESIGN.md` §7): Visão geral · Fichas · Modelos · Termos. Na primeira versão funcionam **Fichas** e
**Modelos**; Visão geral e Termos ficam no lugar com "em desenvolvimento". No celular, Formulários abre por "Mais"
(nível 1: lista de seções; nível 2: a seção, com ‹).

| Tela | Computador (1440) | Celular (390) |
|---|---|---|
| **Fichas** (lista) | barra do topo com "Adicionar" preto; barra da lista: "Buscar ficha" · "Modelo: Todos" · "Filtros ▾" (situação, data) · "Ordenar: …"; linha: bolinha da cliente, nome, modelo, situação (ícone + palavra), data; ⋮ da linha: "Ver ficha" · "Copiar link" (só pendente; gera um link novo e o anterior deixa de valer, com aviso, RF-06) · "Substituir" (só concluída, se E29·3·A, RF-09) · "Excluir" (só pendente, com janelinha) | "+ Adicionar" com contorno no topo; seletor de modelo; funil |
| **Adicionar ficha** | painel à direita (480 px): cliente ("Buscar cliente", só com as clientes que a pessoa pode ver, RF-05), modelo; "Salvar" cria a ficha "Aguardando a cliente" e mostra o próximo passo da E29·1 | folha de baixo, mesmo conteúdo |
| **Ver ficha** | painel à direita: situação, modelo e versão, data; respostas e termo aceito **só para quem pode ver** (§3); para os outros, só a situação | tela de nível 2 com ‹ |
| **Modelos** (lista) | "Adicionar" preto; linha: título, versão, nº de perguntas, ativo ou arquivado; ⋮: Editar · Duplicar · Arquivar · Excluir (`DESIGN.md` §6) | "+ Adicionar" com contorno |
| **Editor de modelo** | título; perguntas (texto da pergunta, tipo, obrigatória, opções); termo de consentimento (obrigatório); "Salvar" e "Cancelar" | igual, uma coluna |
| **Página da cliente** (E29·1·A) | página própria, fora do app, só com o nome do estúdio, o título do modelo, as perguntas, o termo com a caixinha (desmarcada) e a assinatura (E29·3); **nenhum dado da cliente na página nem no endereço** | igual (é usada sobretudo no celular) |

**Situação da ficha** (`DESIGN.md` §5): Aguardando a cliente `hourglass` (âmbar) · Concluída `circle-check` (verde).
"Bloqueia o checkout" não é usado na primeira versão.

**Estados de toda tela** (`DESIGN.md` §8): vazio ("Ainda não há fichas" · "Adicionar ficha"; "Ainda não há modelos" ·
"Adicionar modelo") · sem resultado ("Limpar filtros") · carregando (depois de 0,3 s, anunciado ao leitor) · erro
("Tentar de novo"; a mensagem nunca mostra resposta da ficha) · sucesso (aviso embaixo).
**Página da cliente:** link vencido, de ficha já assinada, renovado ou inexistente mostram **a mesma** mensagem ("Este link não está mais
disponível; fale com o estúdio"), para não revelar se a ficha existe; depois de assinar, "Ficha enviada" sem repetir as
respostas.

**Nomes e peças que faltam no `DESIGN.md`** (vão à ficha visual, etapa 6, e entram no `DESIGN.md` antes de construir):
"Copiar link" e o aviso de que o link anterior deixa de valer; "Substituir" e a situação "Substituída" (ícone e cor); o botão de enviar da página da cliente (o `DESIGN.md` §6 proíbe "Enviar formulário"); a peça de
assinatura (E29·3); o editor de perguntas; a ordem padrão de "Ordenar" (o `DESIGN.md` diz "Atendimento", mas a ficha
só se liga ao atendimento depois: proposta "Data", mais nova primeiro) e o filtro "profissional" (pelo mesmo motivo,
fica para depois).

## 5. Requisitos funcionais
| ID | Requisito | Fonte |
|---|---|---|
| RF-01 | Criar, editar, duplicar, arquivar e excluir modelo de formulário: título, perguntas ordenadas e termo de consentimento (texto obrigatório). | candidata |
| RF-02 | Tipos de pergunta: texto curto, texto longo, sim/não, escolha única, escolha múltipla; cada pergunta pode ser obrigatória. | Assumption 1 |
| RF-03 | **Versão do modelo:** toda edição que muda título, perguntas ou termo cria uma nova versão; versões anteriores não mudam nunca. Cada ficha fica presa à versão com que foi criada e é mostrada sempre com as perguntas e o termo daquela versão. | candidata; RGPD art. 7(1) (provar o que a cliente aceitou) |
| RF-04 | Modelo arquivado não serve para ficha nova; as fichas já feitas continuam. Excluir modelo só se nunca foi usado. | Assumption 3 |
| RF-05 | Criar ficha: escolher uma cliente (de Clientes) e um modelo ativo; a ficha nasce "Aguardando a cliente". Em "Buscar cliente", cada papel acha só as clientes que pode ver em Clientes: a profissional, só as que a E28·2 lhe permite (filtro feito no servidor e no banco, não só na tela). | candidata |
| RF-06 | A cliente preenche e assina pelo meio da E29·1. Se E29·1·A: link individual, que só abre aquela ficha e vale 7 dias **até a assinatura** (antes de assinar, a cliente pode abrir de novo dentro do prazo; assinada, o link deixa de valer); o link aparece à equipe ao "Salvar" a ficha; como o sistema não guarda o link (só o resumo, RNF-04), "Copiar link" depois disso **gera um link novo** (a renovação), o anterior deixa de valer na hora e a tela avisa isso. | E29·1; RNF-04 |
| RF-07 | Ao assinar, o servidor confere: respostas obrigatórias preenchidas, tipos e tamanhos válidos, caixinha do termo marcada pela cliente (nunca marcada de início) e a assinatura da E29·3; falhando algo, nada se grava. | RGPD art. 7 e art. 9(2)(a); ASVS V5.1 |
| RF-08 | **Prova do consentimento:** grava-se a versão do modelo e do termo aceito, a data e a hora do servidor e o meio (link ou estúdio). Endereço IP e dados do aparelho **não** se gravam. | RGPD art. 7(1) e art. 5(1)(c) |
| RF-09 | Assinada, a ficha passa a "Concluída" e as respostas, o termo e a assinatura **não mudam e não se apagam** pelo app; erro se trata como manda a E29·3, sempre guardando a original. Se E29·3·A: "Substituir" no ⋮ da ficha concluída cria uma ficha nova, pendente, do mesmo modelo e cliente, ligada à antiga; no histórico da cliente (lista Fichas), a antiga aparece como "Substituída", com link para a nova, e continua legível para quem pode ver respostas. | integridade (RGPD art. 5(1)(d) e art. 16); E29·3 |
| RF-10 | Ficha "Aguardando a cliente" pode ser excluída, com janelinha de confirmação; o link deixa de valer na hora. | `DESIGN.md` §6 e §8 |
| RF-11 | Quem vê o quê (modelos, fichas, respostas) segue a E29·2; quem não pode ver as respostas recebe só a situação, também do banco (não só escondido na tela). | E29·2; ASVS V4.1.3; RGPD art. 9 |
| RF-12 | **Registro de acesso (porta 6):** cada abertura das respostas de uma ficha, criação, exclusão, renovação de link e assinatura fica no registro com quem, qual ficha (pelo id) e quando, **sem** resposta, nome ou termo no texto. Exceção E6·1 e E6·2 como está: o dono no modo suporte não é registrado. | ASVS V8.3.5; RGPD art. 5(2); `ARCHITECTURE.md` §4 e §6 |
| RF-13 | Busca da lista só por nome da cliente e título do modelo; as respostas nunca são buscáveis nem aparecem na lista. | `ARCHITECTURE.md` §7; RNF-01 |
| RF-14 | Toda ação passa pelas 6 portas; o estúdio vem da sessão. Exceção só a página da cliente da E29·1·A: sem login, o link identifica uma única ficha e só permite ler as perguntas e assinar aquela ficha. **Caminho fixo:** o servidor chama uma função do banco que recebe o token, compara só o resumo (hash) dele e age numa única ficha (a do resumo), sem a chave de serviço do banco (`ARCHITECTURE.md` §4, porta 5); a função não aceita id de ficha nem de estúdio vindo do pedido. | `ARCHITECTURE.md` §4; E29·1 |

## 6. Requisitos não funcionais (segurança e privacidade)
| ID | Requisito | Fonte |
|---|---|---|
| RNF-01 | **Cifra:** as respostas e a assinatura de toda ficha (inclusive o nome digitado na assinatura) ficam cifradas no banco e em toda cópia dele; quem lê o banco direto (ou uma cópia) sem a chave não lê nenhuma resposta. Cifra com verificação de integridade (dado alterado no banco é recusado ao abrir). **Como cifrar é do plano**, decidido pelo Engenheiro de segurança e pelo Engenheiro de dados, com ADR. | E5·2; ASVS V6.1.2 e V6.2.7 (nível 3) |
| RNF-02 | **Chave:** fora do banco, num cofre externo de chaves (KMS) que **cifra e decifra ele mesmo**; o aplicativo nunca recebe nem segura a chave; nunca no repositório, no chat ou em registro; troca planejada, e fichas antigas continuam legíveis depois da troca. (Cofre que mora dentro do próprio banco não cumpre "fora do banco".) Se o plano não puder cumprir isso, a diferença e o motivo vão a ADR (CA-13), conferido pelo Auditor de risco. | `ARCHITECTURE.md` §7; `SECURITY.md` §2; ASVS V6.4.1 e V6.4.2; qual cofre: depende da pergunta E40 ao dono (custo, E23·3·A) |
| RNF-03 | Resposta de ficha nunca em endereço (URL), registro de erro, monitoramento, notificação ou armazenamento do navegador; páginas com resposta não ficam em cache. | `ARCHITECTURE.md` §7; ASVS V8.2.1, V8.2.2 e V8.3.1 |
| RNF-04 | Página da cliente (E29·1·A): (a) token com pelo menos 128 bits de fonte aleatória segura; no banco só o resumo (hash), nunca o token; (b) o token não fica no endereço que o servidor registra: vai depois do `#` ou é trocado na primeira requisição por cookie HttpOnly, Secure e SameSite, com redirecionamento para endereço limpo (o plano escolhe um dos dois, com ADR); (c) a página manda Referrer-Policy: no-referrer e Cache-Control: no-store e não carrega nenhum script de terceiros; (d) o token aparece mascarado em todo registro, inclusive de erro e de monitoramento. | ASVS V6.3.1, V8.2.1 e V8.3.1; `ARCHITECTURE.md` §7 |
| RNF-04b | Limite de tentativas na página da cliente, por endereço e por estúdio. | ASVS V11.1.4; `ARCHITECTURE.md` §5 |
| RNF-05 | Os demais requisitos de nível 3 da ASVS que valem para este módulo são listados pelo Engenheiro de segurança no plano, cada um com como se prova. | `ARCHITECTURE.md` §7; `SECURITY.md` |
| RNF-06 | WCAG 2.2 AA também na página da cliente: rótulo em cada pergunta, erro com ícone e texto, toque 44, foco visível, situação nunca só por cor. | `DESIGN.md` §8 e §9 |
| RNF-07 | Textos do sistema nos três idiomas de uso (pt, es, en); o conteúdo do modelo é escrito pelo estúdio no idioma dele. | E3·1; `ARCHITECTURE.md` §11 |
| RNF-08 | Listas paginadas; limite de idas ao banco por tela. | `ARCHITECTURE.md` §5 e §11 |

**Antes da produção (não bloqueia a construção no banco de desenvolvimento, que só tem dado fictício, E22·B):** DPIA
(RGPD art. 35), contrato estúdio–plataforma (RGPD art. 28), retirada do consentimento (RGPD art. 7(3)), prazo de guarda das fichas (RGPD
art. 5(1)(e)) e o fluxo de "apagar os meus dados" (`SECURITY.md` §7). Nenhuma ficha real entra antes disso.

## 7. Tabelas (do anexo A do item 3) · sugestão para o Engenheiro de dados decidir no plano (RG-02)
Lido só para entender (E22·B, nada copiado): `crm-agenda/supabase/migrations/` (`20260610_004_anamnese.sql`,
`20261029110000_anamnese_clinical_read_rls.sql`, `20260614172305_protect_signed_anamnese_evidence.sql`,
`20261030400000_anamnese_link_events_versions.sql`, `20261114120000_ficha_correcao_base.sql`).

| Tabela (antigo) | Sugestão | Motivo |
|---|---|---|
| `anamnese_templates` | **reescrever** em modelo + versão do modelo (versão como linha que não muda) | no antigo a versão é um número que sobe e o conteúdo vai copiado na ficha; país fixo `ES` e termo pronto por padrão não vêm |
| `anamneses` | **reescrever** como ficha | no antigo as respostas (`answers`) **não são cifradas**, o nome da cliente é copiado (`client_name`), IP e aparelho são gravados e o link guardado em texto; nada disso vem (RNF-01, RF-08, RNF-04) |
| `anamnese_answer_versions` | **descartar** se E29·3·A ou B; **reescrever cifrada** se E29·3·C | correções sem cifra no antigo |
| `anamnese_events` | **descartar** (primeira versão) | envio por canal é integração (depois); o registro da porta 6 cobre o RF-12 |
| `anamnese_gate_overrides` | **descartar** | trava do checkout é depois |

Regras que valem (RG-04 e RG-06): `org_id` obrigatório, trava RLS pela função de checagem do item 3, índice por
`org_id`, teste de isolamento em cada tabela; dado de saúde só entra cifrado. Nomes das tabelas e colunas: o
Engenheiro de dados decide, com ADR.

## 8. Critérios de aceite (verificáveis)
| ID | Critério | Prova |
|---|---|---|
| CA-01 | Editar modelo cria versão nova; a ficha criada antes continua mostrando as perguntas e o termo da versão dela; versão antiga não se altera. | unidade (`src/domain`) e teste de banco |
| CA-02 | Assinar sem obrigatória, com tipo inválido, com a caixinha do termo desmarcada ou sem a assinatura da E29·3 é recusado e nada se grava. | unidade e teste de servidor |
| CA-03 | Ficha assinada: qualquer tentativa de alterar ou apagar respostas, termo ou assinatura é recusada pelo banco, não só pela tela. | teste de banco na CI |
| CA-04 | **Cifra:** depois de assinar uma ficha com uma resposta conhecida, a leitura direta da tabela no banco (sem passar pelo app) não contém esse texto; sem a chave não se lê; com a chave trocada, a ficha antiga continua legível; dado alterado à mão no banco é recusado ao abrir; o nome digitado na assinatura também não aparece em claro; o aplicativo não tem a chave (decifra só pelo cofre, RNF-02, ou a diferença está no ADR do CA-13). | teste automático na CI |
| CA-05 | O estúdio A não lê, cria, altera nem apaga modelo, versão ou ficha do estúdio B; sem login ou sem papel, nada; o token de uma ficha não lê nem grava outra ficha, do mesmo estúdio ou de outro, e a função do link não usa a chave de serviço. | teste de isolamento na CI (molde do item 3) |
| CA-06 | Cada papel × cada ação conforme E29·2; quem não pode ver respostas não as recebe nem pedindo direto ao servidor ou ao banco. | teste de servidor e de banco |
| CA-06b | A profissional, em "Buscar cliente", não acha cliente que a E28·2 não lhe deixa ver, nem pedindo direto ao servidor. | teste de servidor e de banco |
| CA-07 | Link (E29·1·A): abre só a sua ficha; antes de assinar, abre de novo dentro do prazo; vencido, assinado, renovado ou excluído dá a mesma mensagem; token com ≥128 bits e só o resumo no banco; o endereço registrado pelo servidor não contém o token; a resposta tem Referrer-Policy: no-referrer e Cache-Control: no-store e nenhum script de terceiros; o token sai mascarado em todo registro, inclusive de erro; nenhum dado da cliente no endereço nem na página; limite de tentativas age. | teste de servidor e e2e |
| CA-08 | Abrir respostas, criar, excluir, renovar link e assinar geram registro sem resposta, nome ou termo no texto. | teste automático e revisão do Engenheiro de segurança |
| CA-09 | Nenhuma resposta em URL, registro de erro ou armazenamento do navegador; páginas com resposta sem cache. | teste e revisão do Engenheiro de segurança |
| CA-10 | Ponta a ponta em 390 e 1440: criar modelo, editar (vira versão 2), criar ficha, a cliente preencher e assinar, ver a ficha (com e sem permissão), excluir pendente com janelinha. | Playwright (`e2e/`) |
| CA-11 | Estados vazio, sem resultado, carregando, erro e sucesso presentes; checklist do `DESIGN.md` §10 sem falha. | e2e e Revisor de design |
| CA-12 | Cada tabela do §7 tem ADR com saída, motivo, norma e o papel que conferiu; nada do antigo copiado sem ADR; nenhuma resposta do antigo trazida. | `docs/adr/` |
| CA-13 | ADR da cifra e do cofre (onde fica a chave, como se troca, quem cifra e decifra; qualquer diferença do RNF-02 com o motivo) e ADR da forma do token fora do endereço (RNF-04 b), conferidos pelo Auditor de risco. | `docs/adr/` e relatório |
| CA-14 | Revisores do tipo sem "Bloqueia", veredito do QA e conferência do dono na prévia. | relatórios no PR |

## 9. Dependências
- **Item 2** (CI, app vazio, Spec Kit) · **item 3** (estúdio, membros, papéis, função de checagem, molde do teste de
  isolamento) · **item 4** (design system no código).
- **Spec "Entrar e camada de serviço"** (E36·A do dono, 28/11/2026: "E36a"; branch `feat/entrar-servico`, antes do
  núcleo): login e as 6 portas; desta spec usa também a ação pública sem login (B-3) e o registro sem login (B-4) para
  a página da cliente (E29·1·A, RF-14, RF-12).
- **Clientes:** a tabela, a busca da cliente e a regra da E28·2 (RF-05). **Agendamento:** só se E29·2·A (a profissional
  vê as fichas das clientes que já atendeu ou tem marcadas com ela).
- **Cofre de chaves** para a cifra, fora do banco (RNF-02): qual, depende da pergunta à parte **E40** ao dono (custo,
  E23·3·A); sem resposta, a cifra (RNF-01 e RNF-02) não se constrói.
- **E22·B:** leitura do antigo e ADR por tabela. A página da cliente (E29·1·A) é uma página só, não o Portal público
  (`ARCHITECTURE.md` §2).

## 10. Dúvidas ao dono (máx. 3)
**E29·1 · Como a cliente preenche a ficha** (acesso, dado de saúde)
- **E29·1·A:** por link individual: a equipe copia o link e manda à cliente; ela preenche no próprio celular, sem login.
  O link só abre aquela ficha e vale 7 dias, até a cliente assinar.
- **E29·1·B:** só no estúdio: a equipe abre a ficha no aparelho do estúdio e entrega à cliente; link fica para depois.
- **Recomendo A:** a cliente nunca segura um aparelho com o sistema do estúdio aberto (menor acesso, ASVS V4.1.3) e o
  link é a forma da lista aprovada; o risco (link sem login) fica contido nas regras do RF-06 e RNF-04.
  **Desfaz-se** desligando a página do link; as fichas já assinadas ficam.

**E29·2 · Quem vê as respostas da ficha de saúde** (acesso, dado de saúde) · **vai ao dono junto da E26·1 da Agenda**
(o que a profissional vê na Agenda) **e da E28·2 de Clientes** (o que a profissional vê em Clientes); as três respostas
têm de ser coerentes.
- **E29·2·A:** dona vê tudo e é a única que cria e edita modelos; profissional cria ficha e vê as respostas só das
  clientes que já atendeu ou tem marcadas com ela; recepção cria ficha e copia o link, mas vê só a situação.
  Coerente com E26·1·B e E28·2·B.
- **E29·2·B:** como A, mas a profissional vê as respostas de todas as clientes do estúdio. Choca com E28·2·B (veria a
  ficha de saúde de cliente que nem vê em Clientes); só coerente com E28·2·A ou C.
- **E29·2·C:** todos os papéis veem tudo. Choca com E28·2·B pelo mesmo motivo e expõe dado de saúde à recepção.
- **Recomendo A, junto com E26·1·B e E28·2·B:** mínimo necessário para dado de saúde (RGPD art. 5(1)(c) e art. 9;
  OWASP ASVS V4.1.3, menor acesso). **Desfaz-se** mudando a permissão do papel. A E6·2 (dono no modo suporte) vale
  como está em todas as opções.

**E29·3 · Assinatura e erro numa ficha assinada** (dado de saúde, tela)
- **E29·3·A:** a cliente assina marcando a caixinha do termo e digitando o nome completo; ficha assinada não muda;
  se houver erro, faz-se uma ficha nova e a antiga fica guardada como "substituída".
- **E29·3·B:** como A, mais o traço da assinatura desenhado com o dedo (imagem guardada cifrada).
- **E29·3·C:** como B, mais "corrigir ficha assinada" já nesta versão (a profissional corrige com motivo; a original
  fica guardada).
- **Recomendo A:** assinatura eletrônica simples tem valor legal (UE: eIDAS art. 25(1); base legal no Brasil a confirmar), guarda menos dado (RGPD art.
  5(1)(c)) e a ficha nova cumpre o direito de correção (RGPD art. 16); B e C podem entrar depois sem perder fichas.
  **Desfaz-se** acrescentando B ou C em spec própria.

## 11. Assumptions (decisões técnicas do papel, à vista na aprovação)
1. Tipos de pergunta do RF-02; limites: até 100 perguntas por modelo, 20 opções por pergunta e 2.000 caracteres por
   resposta (proteção contra abuso, ASVS V5.1.4); o Arquiteto pode ajustar no plano.
2. Nomes das tabelas e colunas do §7 são sugestão; o Engenheiro de dados decide com ADR (RG-02).
3. Modelo arquivado volta a ativo pelo ⋮ (Arquivar desfaz-se); Excluir só para modelo nunca usado (RF-04).
4. Os ADRs seguem a numeração de `docs/adr/`; uma migration por tabela (como no item 3).

## 12. Fora de escopo
Fotos na ficha · modo no estúdio com PIN · seção Termos e termo avulso · Visão geral · ficha obrigatória por serviço e
"Bloqueia o checkout" · ficha ligada ao agendamento · envio por WhatsApp, e-mail ou QR · texto de termo sugerido ·
etiqueta "Alergia" automática · exportar fichas · retirada do consentimento e "apagar os meus dados" (antes da
produção, §6) · banco de produção e publicação.
