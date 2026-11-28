# Spec · Catálogo (primeira versão): serviços e categorias

- **Status:** Draft
- **Aprovação do dono:** (pendente)
- **Aprovação do merge:** (pendente)
- **Pasta:** `specs/20261128-022000-catalogo/` · **Branch:** `feat/catalogo`, empilhada por merge sobre
  `feat/banco-ligacao`, `feat/design-system-codigo` e `feat/entrar-servico` (decisão do Engenheiro de DevOps);
  construção em PR de rascunho, nada é juntado sem o dono (E22·B)
- **Item da fila:** 5 de `docs/BACKLOG.md` (núcleo, um módulo por spec: Catálogo, E3·2), em paralelo por ordem do dono (E22·B)
- **Tipo:** Tela, com Banco e Código; mexe com dinheiro (preço) (`docs/guias/processo-sdd.md` §3 e §4) ·
  **Revisores:** Revisor de design; Engenheiro de dados (quem não fez) e Auditor de risco (banco, dinheiro, acesso);
  Engenheiro de segurança (acesso); Revisor de código; QA
- **Escrito por:** Analista de requisitos · **Norma:** IEEE 29148 e BABOK · **Revisa:** Gerente de projeto (etapa 5b)
- **Fontes lidas:** `AGENTS.md`; `ARCHITECTURE.md` §3 a §7 e §11; `DESIGN.md` (inteiro) e
  `docs/design/imagens/prova-3-servicos-celular.png`; `docs/guias/processo-sdd.md`; `src/*/AGENTS.md`;
  `docs/produto/catalogo.md` e `docs/produto/README.md` (branch `docs/produto-modulos`, PR #2, E21);
  `docs/decisoes/2026-11-27-fundacao.md` (E3·2, E21, E21·3, E22·B, mesma branch);
  `specs/20261128-010000-banco-ligacao/spec.md` (branch `feat/banco-ligacao`, RG-01 a RG-08 e anexo A);
  `specs/20261128-020500-agendamento/spec.md` (branch `feat/agendamento`); `specs/20261128-020000-agenda/spec.md`
  (branch `feat/agenda`, E26·1 a E26·3). Do antigo (E22·B, só leitura, nada copiado): `crm-agenda/supabase/migrations/`
  20260601000003_catalog, 20260601000004_staff, 20260609_001_foundation, 20260612_003_catalog_extensions,
  20260615171959_catalog_contract_hardening, 20261029180000_service_anamnese_template_required,
  20261030301000_servicos_regras_e_sem_duracao e 20261114030200_catalog_limits.

## 1. Pedido do dono (literal)
> "A" — E3·2: "Primeira versão com o núcleo (Agenda, Agendamento, Clientes, Formulários, Catálogo, Checkout, Caixa)".

> "E21-3b" — E21·3, 28/11/2026: cobrança à cliente (link de pagamento, sinal) e vale-presente são recursos do
> Checkout e do Financeiro, depois do núcleo.

> "O banco de dados atual é tudo de desenvolvimento, todos os dados são fictícios. O que se tem são as tabelas e regras
> dele. Então use se precisar. E22b Bom trabalho e obrigado." — E22·B, 28/11/2026,
> https://claude.ai/code/session_018cV8b9epaQJNqguG5c5Aqb

O módulo, pela E21 (`docs/produto/catalogo.md`): "Tudo o que o estúdio oferece: serviços, pacotes, planos e produtos,
com as regras de cada serviço." Para: dona, recepção, profissional.

## 2. Primeira versão (mínima) e depois
Critério: entra só o que o Agendamento (escolher serviço ativo e somar durações, RF-01 a RF-03 da spec dele) e o
Checkout (preço do serviço) precisam para funcionar.

| Recurso candidato (`docs/produto/catalogo.md`) | Primeira versão | Motivo |
|---|---|---|
| Serviços: nome, categoria, duração, preço | **sim** | o Agendamento usa a duração; o Checkout usa o preço |
| Serviço ativo ou arquivado | **sim** | o Agendamento só mostra ativo; arquivar preserva o histórico |
| Categorias (nome) | **sim** | a lista agrupa por categoria (`DESIGN.md` §3 e §7; prova 3) |
| Quem faz cada serviço | conforme **E30·3** | o Agendamento já prevê a regra se existir (RF-03 dele) |
| Pacotes, combos, planos de assinatura | depois | são venda de sessões e cobrança recorrente (dinheiro, Checkout e Financeiro) |
| Produtos | depois | dependem de estoque (módulo Estoque, depois do núcleo) |
| Regras por serviço: retoque incluído, durabilidade | depois | a prova 3 mostra "retoque incluído", mas a regra pede Clientes e Agendamento prontos |
| Regras por serviço: sinal | depois | E21·3 (Checkout, depois do núcleo) |
| Ficha obrigatória por serviço ("pede formulário") | depois | depende da spec de Formulários, que também a deixou para depois |
| Reserva online por serviço (filtro "online") | depois | depende do portal público (E21·1) |
| Descrição com ajuda de IA | depois | módulo Assistente de IA (E21·1) |
| Descrição, intervalo depois do serviço, custo, comissão, preço "a partir de" | depois (ver E30·2) | não são precisos para marcar nem cobrar o básico; comissão e custo são do Financeiro |

## 3. Quem usa e o que cada papel pode
| Papel | Vê | Adiciona, edita, arquiva, exclui serviço e categoria (inclui o preço) |
|---|---|---|
| Dona | todos os serviços e categorias do seu estúdio, com preço | conforme **E30·1** |
| Recepção | idem | conforme **E30·1** |
| Profissional | idem | conforme **E30·1** |
| Sem papel no estúdio ou sem login | nada | nada |

Nenhum papel vê dado de outro estúdio (`ARCHITECTURE.md` §5). O Catálogo não guarda dado de cliente nem de saúde.

## 4. Telas e estados
Só peças, nomes e medidas do `DESIGN.md`. Peça ou nome que faltar entra no `DESIGN.md` com o dono antes de construir.

**Navegação (`DESIGN.md` §5 a §7).** Catálogo é o 3º item do menu (`tag`) e da barra de baixo. Seções: Serviços ·
Pacotes · Combos · Planos de assinatura · Produtos. Na primeira versão só **Serviços** funciona; as outras ficam no
lugar com "em desenvolvimento" (`DESIGN.md` §8).

| Tela | Computador (1440) | Celular (390) |
|---|---|---|
| **Catálogo · nível 1** | — (o computador abre direto em Serviços, com o submenu de seções ao lado e o menu recolhido em 84 px) | título "Catálogo"; lista de seções com ícone simples, nome, quantidade (pílula) e ›; sininho e Sua conta no topo |
| **Serviços** | título "Catálogo" (1ª seção do módulo, `DESIGN.md` §6), subtítulo "N serviços"; barra do topo com Opções e **Adicionar** preto; barra da lista: "Buscar serviço" · "Categoria: Todas ▾" · Filtros ▾ · (à direita) "Ordenar: Nome ▾"; tabela com linhas de 40: faixa de 4 px da cor da categoria, Nome, Categoria, Duração, Preço, ⋮ | como a prova 3: ‹, título "Serviços", subtítulo "N serviços", ⋮ (Opções), "+ Adicionar" com contorno; "Buscar serviço" e funil; seletor de categorias com contador; grupos por categoria (cabeçalho 14 forte com a pílula); linha de 64: faixa de 4 px, nome, duração em detalhe, preço à direita, ⋮; barra de baixo com Catálogo atual |
| **Adicionar / Editar serviço** | painel à direita (480 px): Nome*, Categoria* (pílula ▾), Duração*, Preço* (com o símbolo da moeda do estúdio); Salvar · Cancelar | tela sem barra, ‹ voltar, mesmos campos, **Salvar** preto no rodapé |
| **⋮ da linha** | Editar · Duplicar · Arquivar (ou Desarquivar, se arquivado) · Excluir (vermelho, janelinha de confirmação) | igual |
| **Categorias** (adicionar, renomear, excluir) | ponto de entrada sai da ficha visual (etapa 6) | igual |

**Filtros na primeira versão:** situação (Ativos, padrão · Arquivados); "profissional" só se E30·3·B; "online" e
"pede formulário" ficam "em desenvolvimento". **Ordenar:** Nome (padrão, `DESIGN.md` §8b) · Preço · Duração.

**Estados (`DESIGN.md` §8):** vazio ("Ainda não há serviços" + uma frase + "Adicionar serviço" com contorno; é para cá
que leva o estado vazio do Agendamento) · sem resultado (o que foi buscado e "Limpar filtros") · carregando (linhas
cinza só depois de 0,3 s, anunciado ao leitor) · erro (o que houve e "Tentar de novo"; no formulário, erro no campo
com contorno vermelho e mensagem com ícone) · sucesso (aviso embaixo; "Desfazer" no arquivar).

**Nomes e peças que faltam no `DESIGN.md`** (vão à ficha visual, etapa 6, e entram no `DESIGN.md` antes de construir):
"Desarquivar" no ⋮; a opção de situação (Ativos · Arquivados) dentro de Filtros do Catálogo; o ponto de entrada e os
nomes da gestão de categorias; os ícones das seções no nível 1 do celular; o formato do campo Duração.

## 5. Requisitos funcionais
| ID | Requisito | Fonte |
|---|---|---|
| RF-01 | Adicionar serviço com nome, categoria, duração e preço; nasce ativo. | candidata; §2 |
| RF-02 | Editar qualquer campo do RF-01. A mudança vale para o que for marcado ou cobrado depois; o que o Agendamento já gravou (duração) não muda. | spec do Agendamento §7 (`appointment_items` guarda a duração) |
| RF-03 | Arquivar e desarquivar serviço. Arquivado não aparece para escolha no Agendamento nem no Checkout, e continua aparecendo pelo nome nos atendimentos passados. | spec do Agendamento RF-03 |
| RF-04 | Excluir serviço só se ele nunca foi usado (em nenhum agendamento ou venda); senão a tela recusa e oferece Arquivar. Excluir pede a janelinha de confirmação. | `DESIGN.md` §6 e §8; integridade do histórico |
| RF-05 | Duplicar abre o formulário de Adicionar já preenchido com os dados do original; só grava com Salvar. | `DESIGN.md` §6 |
| RF-06 | Adicionar, renomear e excluir categoria; excluir só se não houver serviço (ativo ou arquivado) nela. | §2 |
| RF-07 | Lista de serviços com busca por nome, categoria (seletor no celular, "Categoria: Todas ▾" no computador), Filtros e Ordenar do §4; paginada. | `DESIGN.md` §5, §7 e §8b; `ARCHITECTURE.md` §5 |
| RF-08 | Leitura para os outros módulos (pela camada de serviço): o Agendamento recebe os serviços **ativos** com id, nome, categoria e duração; o Checkout recebe também o preço em centavos e a moeda do estúdio. | specs do Agendamento (RF-01 a RF-03) e do Checkout (futura) |
| RF-09 | Permissão por papel conforme E30·1, conferida no servidor e na trava do banco (não só escondida na tela). | `ARCHITECTURE.md` §4 e §6; ASVS V4.1.3 |
| RF-10 | Toda gravação passa pelas 6 portas e fica no registro (porta 6): quem, quando, qual serviço ou categoria e, na troca de preço, o valor antigo e o novo; sem dado pessoal no texto. | `ARCHITECTURE.md` §4 |
| RF-11 | Quem faz cada serviço conforme E30·3. | E30·3 |

## 6. Regras de negócio (verificáveis)
| ID | Regra | Fonte |
|---|---|---|
| RN-01 | **Preço** guardado como número inteiro em centavos (a menor unidade da moeda), nunca número com vírgula; o servidor recusa fração de centavo. Limites e tipo de preço: E30·2. | ASVS V5.1.4 (tipo e faixa); precisão de dinheiro |
| RN-02 | **Moeda** é a do estúdio (código ISO 4217, vinda do item 3), não do serviço; o preço é mostrado no formato do idioma da pessoa e na moeda do estúdio (ex.: "230,00 €"). Depende do item 3 (moeda do estúdio, `ARCHITECTURE.md`:117); a construção da regra de preço espera isso existir. | `ARCHITECTURE.md` §11 |
| RN-03 | **Duração** em minutos inteiros, **maior que zero**, entre 5 e 720 e múltipla de 5; mostrada como "45 min", "1 h 30 min". | pedido do Agendamento (RF-02 dele); Assumption 1 |
| RN-04 | **Nome** do serviço: obrigatório, sem espaços nas pontas, de 1 a 120 caracteres, único entre os serviços não excluídos do estúdio (sem diferença de maiúsculas e acentos). Nome da categoria: mesma regra, até 60 caracteres. | ASVS V5.1.3; Assumption 2 |
| RN-05 | **Categoria** obrigatória e do mesmo estúdio do serviço. | `ARCHITECTURE.md` §5; Assumption 3 |
| RN-06 | **Cor da categoria** = `--c1`…`--c4` pela ordem de criação no estúdio (a 5ª volta à 1ª), fixada na criação: excluir uma categoria não muda a cor das outras. Sempre com o nome escrito. | `DESIGN.md` §3; Assumption 4 |
| RN-07 | O estúdio de toda leitura e gravação vem da sessão, nunca do pedido. | `ARCHITECTURE.md` §4 |
| RN-08 | Contadores: total na pílula cinza; zero não aparece. | `DESIGN.md` §5 |

## 7. Tabelas · sugestão para o Engenheiro de dados decidir no plano (RG-02 do item 3)
Base da trava (estúdio, membros, papéis, função de checagem) vem do item 3. Cada linha é **sugestão** do Analista;
quem decide é o Engenheiro de dados, com ADR e revisão de outro papel (E16·1).

| Tabela (antigo) | Sugestão | Motivo |
|---|---|---|
| `service_categories` | **reescrever** | ficam `org_id`, nome, criação e o número de ordem da cor (RN-06); saem `color` (cor fora do `DESIGN.md`, `#F43F5E`), `icon`, `position` e `active` (fora da v1) |
| `services` | **reescrever** | ficam `org_id`, categoria (chave estrangeira do mesmo estúdio), nome, duração, **preço em centavos** (o antigo usa `numeric(10,2)`), arquivado, criação e alteração; saem `price_type` (E30·2), `description`, `cost_amount`, `commission_pct`, `buffer_minutes`, `requires_anamnese`, `anamnese_template_id`, `online_booking`, `position`, `result_months`, `retouch_included_days`, `deposit_type`, `deposit_value` (todos "depois", §2); a duração 0 do antigo não vale (RN-03) |
| `service_staff` | **reescrever** só se E30·3·B, ligando a quem atende, pela E26·3 (não a `staff_members`); **adiada** se E30·3·A | quem faz cada serviço |
| `staff_services` | **descartar** | mesmo fim de `service_staff`, nasce sem `org_id` (achado do item 3) |
| `products` | **adiada** (Estoque) | §2 |
| `service_packages`, `service_package_items`, `package_services`, `service_bundles`, `service_bundle_items`, `subscription_plans` | **adiada** | §2; `package_services` e `service_package_items` nascem sem `org_id` |
| função `upsert_catalog_service_atomic` | **descartar** | a gravação passa pela camada de serviço (`ARCHITECTURE.md` §4); recebe `p_org_id` do pedido, o que o RN-07 proíbe |

Regras que valem (RG-04): `org_id` obrigatório, trava RLS pela função de checagem do item 3, índice por `org_id` e
teste de isolamento em cada tabela. RN-01, RN-03 a RN-05 também como regra (CHECK) no banco, não só no servidor.

## 8. Requisitos não funcionais
| ID | Requisito | Fonte |
|---|---|---|
| RNF-01 | WCAG 2.2 AA: contraste, toque 44/40, foco visível, categoria nunca só pela cor (nome escrito), seletor com papel de abas. | `DESIGN.md` §9 |
| RNF-02 | Lista paginada e número fixo de idas ao banco por tela, que não cresce com o número de serviços (teto no plano). | `ARCHITECTURE.md` §5 e §11 |
| RNF-03 | Textos da tela em português, espanhol e inglês, por arquivo de idioma; nomes de serviço e categoria ficam como o estúdio escreveu. | E3·1; `ARCHITECTURE.md` §11 |
| RNF-04 | Nenhum segredo e nenhum dado pessoal em URL, registro de erro ou notificação; a URL leva só o id. | `ARCHITECTURE.md` §7 |

## 9. Critérios de aceite
| ID | Critério | Prova |
|---|---|---|
| CA-01 | RN-01 a RN-06: preço inteiro em centavos e fração recusada; limites da E30·2; duração 0, negativa, 721, não múltipla de 5 e não inteira recusadas, 5 e 720 aceitas; nome vazio, só espaços, longo ou repetido (maiúsculas e acentos) recusado; formato de duração e de preço por idioma e moeda (EUR e BRL); cor da categoria estável depois de excluir outra. | unidade (`src/domain`), CI verde |
| CA-02 | O estúdio A não lê, cria, altera nem apaga serviço, categoria (e `service_staff`, se E30·3·B) do estúdio B; serviço com categoria de outro estúdio é recusado. | isolamento (molde do item 3), CI verde |
| CA-03 | Sem login ou sem papel no estúdio: nada é lido nem gravado; cada papel × cada ação conforme E30·1, também chamando o servidor e o banco direto. | teste de servidor e de banco, CI verde |
| CA-04 | Estúdio vindo no pedido é ignorado. | teste de servidor |
| CA-05 | Excluir serviço usado e categoria com serviço é recusado; arquivado some da escolha do Agendamento e continua no histórico. | teste de servidor e de banco |
| CA-06 | Toda gravação gera registro (porta 6) com valor antigo e novo do preço, sem dado pessoal. | teste automático |
| CA-07 | Em 390 e 1440: adicionar, editar, duplicar, arquivar com "Desfazer", desarquivar, excluir com janelinha; adicionar e excluir categoria; busca, categoria, filtro de situação e "Limpar filtros"; Ordenar. | e2e (Playwright, `e2e/`), CI verde |
| CA-08 | Em 390 e 1440: estados vazio, sem resultado, carregando, erro e sucesso como no §4; seções não feitas com "em desenvolvimento". | e2e |
| CA-09 | Uma só peça preta de ação por tela; "+ Adicionar" do celular com contorno; nenhuma peça, cor ou nome fora do `DESIGN.md`; checagem automática de acessibilidade sem falha nas duas larguras. | checklist §10 do `DESIGN.md` (Revisor de design) e e2e |
| CA-10 | Cada tabela do §7 tem ADR com saída, motivo, norma e quem conferiu; migration só para as copiadas ou reescritas; nada do antigo copiado sem ADR. | `docs/adr/` × PR |
| CA-11 | Nada aplicado no banco remoto pela IA; banco só local até a "Aprovação do merge". | histórico da CI |
| CA-12 | Revisores do tipo (inclui dinheiro) sem "Bloqueia", veredito do QA e conferência do dono na prévia. | relatórios no PR |

## 10. Dependências
- **Item 2** (fundação técnica): app, pnpm, Vitest, Playwright, CI, banco local, Spec Kit.
- **Item 3** (banco): estúdio, membros, papéis, função de checagem, molde do teste de isolamento e **a moeda e o
  idioma do estúdio**. Depende do item 3 (moeda do estúdio, `ARCHITECTURE.md`:117); a construção da regra de preço
  espera isso existir.
- **Item 4** (design system no código): componentes do `DESIGN.md`.
- **E36·A · Entrar e camada de serviço** (`specs/20261128-030000-entrar-servico/spec.md`, branch
  `feat/entrar-servico`): login, sessão, as 6 portas e o registro (porta 6), de que dependem o RF-09, o RF-10 e o RN-07.
- **Agenda:** quem é profissional (E26·3), só se E30·3·B.
- **Agendamento:** consome o RF-08 e leva o estado vazio para cá; usa os dados de exemplo enquanto o Catálogo não
  existir (RF-15 dele).
- **Checkout** (spec ainda não escrita): consome preço e moeda pelo RF-08; o que fica gravado na venda é dele.
- **E22·B:** leitura do antigo e ADR por tabela; construção em PR de rascunho; nada juntado sem o dono.

## 11. Fora de escopo
Os recursos "depois" do §2; sinal, link de pagamento e vale-presente (E21·3); impostos (IVA), desconto, custo e
comissão (Checkout e Financeiro); troca da moeda do estúdio; "Opções" (importar, exportar, imprimir, ajustar ordem),
que aparece "em desenvolvimento"; reserva online (portal); unidades (`locations`); banco de produção e publicação.

## 12. Dúvidas ao dono (máx. 3)
O que a profissional vê e faz na Agenda e nos agendamentos é a E26·1 e a E26·2 (não se repete aqui).

**E30·1 · Quem cadastra e muda serviços e preços** (acesso, dinheiro)
- **E30·1·A:** só a dona adiciona, edita, arquiva e exclui; recepção e profissional só veem.
- **E30·1·B:** dona e recepção fazem tudo; profissional só vê.
- **E30·1·C:** todos os papéis fazem tudo.
- **Recomendo A:** o preço é o que o estúdio cobra; menos gente mexendo, menos erro de cobrança (OWASP ASVS V4,
  menor privilégio). Desfaz-se mudando a permissão do papel, sem mexer nos dados.

**E30·2 · Como é o preço do serviço** (dinheiro, tela)
- **E30·2·A:** preço fixo, de 0,00 a 100 000,00 na moeda do estúdio (0 serve para avaliação gratuita).
- **E30·2·B:** como A, e o serviço pode ser marcado "a partir de": o valor final se acerta no Checkout.
- **E30·2·C:** como A, mas o preço tem de ser maior que 0.
- **Recomendo A:** é o que a prova 3 mostra e o Checkout cobra sem ajuste; o "a partir de" entra depois com o
  Checkout. Desfaz-se mudando a regra; nenhum preço gravado se perde.

**E30·3 · Quem faz cada serviço** (tela)
- **E30·3·A:** na primeira versão, quem atende, pela E26·3, pode fazer todo serviço; o Agendamento mostra
  quem atende, pela E26·3.
- **E30·3·B:** o serviço tem a lista de quem faz, entre quem atende pela E26·3 (vazia = quem atende, pela E26·3); o Agendamento só oferece essas, e o filtro
  "profissional" funciona.
- **Recomendo A:** primeira versão mínima e sem depender da Equipe; o B entra depois sem mudar os serviços gravados
  (o Agendamento já prevê a regra, RF-03 dele). Desfaz-se ligando a lista.

## 13. Assumptions (decisões do papel, à vista na aprovação; recuse pelo número)
1. Duração de 5 a 720 min, de 5 em 5 (o bloqueio da Agenda também tem mínimo de 5 min; 12 h cobre o dia de trabalho).
2. Nome único por estúdio, para não haver dois serviços iguais na escolha do Agendamento; limites de 120 e 60 caracteres.
3. Categoria obrigatória: a lista é sempre agrupada (prova 3), sem grupo "Sem categoria".
4. Cor da categoria fixada na criação (RN-06), para não trocar de cor quando outra é excluída.
5. Arquivar em vez de "ativo/inativo": é o nome do `DESIGN.md` §6.
6. Ordenar por Nome (padrão), Preço e Duração.
7. Tabelas: as sugestões do §7 são do Engenheiro de dados decidir no plano, com ADR; ADRs na numeração de
   `docs/adr/`; uma migration por tabela.
8. Teto de serviços por página e de idas ao banco: o Arquiteto fixa no plano, depois de lida a documentação oficial.
