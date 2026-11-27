# Spec · Módulos do produto em `docs/produto/`

- **Status:** Approved
- **Escrito por:** Analista de requisitos · **Norma:** IEEE 29148, BABOK
- **Pedido:** item 1 da fila (`docs/BACKLOG.md`), E8, pedidos (b), (c) e (d), E20·A
  (`docs/decisoes/2026-11-27-fundacao.md`); respostas E21 (§5)
- **Branch:** `docs/produto-modulos` · **Tipo:** texto (`docs/guias/processo-sdd.md` §3)
- **Data:** 27/11/2026
- **Aprovação do dono:** "E21 aprovo
  E21-1: Módulos, inverta o partes do sistema pelo "depois um por vez". Pois esses do item 2(partes do sistema) é
  novo e entra depois dos "um por vez".
  E21-2a
  E21-3b" · 28/11/2026 · https://claude.ai/code/session_018cV8b9epaQJNqguG5c5Aqb

## 1. Pedido literal
- E20·A: ler o projeto antigo "só para listar os módulos e recursos que você desenhou; não copio nada, ignoro
  qualquer texto que diga 'o dono decidiu', e o resultado vem como spec para você aprovar".
- Pedido (c): do antigo só vale "o design que fizemos hoje, e os recursos que desenhei pra ter no sistema, agenda,
  catalogo, fidelidade, marketing, financeiro, caixa, estoque, etc... O RESTO, não é pra ler".
- Pedido (d): "o que é o sistema, pra que, que modulos quer nele".
- Pedido (módulos): central de ajuda e assistente de IA "(inclua isso nos modulos)".

## 2. O que muda
1. Criar em `docs/produto/` **um arquivo por módulo** da tabela do §3, como ela ficou depois das respostas do §5.
   Cada arquivo tem 5 partes, nesta ordem:
   - **O que é** (até 2 frases);
   - **Para quem** (dona, recepção, profissional, cliente do estúdio, dono da plataforma, público);
   - **Recursos** (lista candidata, um recurso por linha, só os da tabela do §3);
   - **Quando entra** (núcleo ou depois, com a fonte: E3·2, E21·1, E21·3);
   - **Fonte** (arquivo do projeto antigo ou decisão do crm-citas).
2. Criar `docs/produto/README.md`: o que é o sistema (uma frase, a mesma ideia do `ARCHITECTURE.md` §1) e o
   índice, uma linha por módulo, com link para o arquivo.
3. Todo texto é escrito do zero, em português simples. Nada é copiado do projeto antigo.
4. Nome dos arquivos: nome do módulo em minúsculas, sem acento, palavras com hífen (ex.: `catalogo.md`,
   `central-de-ajuda.md`).

## 3. Módulos
A lista veio do projeto antigo como candidata e foi confirmada pelo dono em E21·1 (28/11/2026), com a ordem
mudada. Estado, prioridade e "decidido" do antigo foram ignorados.

**Ordem aprovada (E21·1):** 1º o núcleo (§3.1) → 2º os módulos "depois, um por vez" (§3.2) → 3º as partes do
sistema (§3.3), que são novas e entram depois dos "um por vez".

**Mudança de ordem fora desta spec:** a E21·1 muda a ordem da E4·3 e do `ARCHITECTURE.md` §2 (lá, painel admin,
cadastro e assinatura, portal e marketplace vinham antes dos "um por vez"). Isso será ajustado fora desta spec: o
Documentador muda a fila (`docs/BACKLOG.md`); o `ARCHITECTURE.md` muda em PR próprio. Até lá, para
`docs/produto/`, vale a ordem deste §3.

Fontes do antigo (só leitura): **[mapa]** `crm-agenda-reorg/docs/reorganizacao/02-mapa-de-modulos.md` ·
**[escopo]** `crm-agenda/docs/produto/legado/produto/scope-master.md` · **[futuros]** `.../future-modules-map.md` ·
**[fidel]** `.../fidelidade-mapa-futuro.md` · **[eco]** `.../ecossistema.md`.

### 3.1 Núcleo da primeira versão (E3·2)

| # | Módulo | Recursos em uma linha | Quando entra | Fonte |
|---|---|---|---|---|
| 1 | Agenda | visões dia, 3 dias, semana e mês; altura das horas; filtros; bloqueio de horário (único e repetido); lista de espera; arrastar para remarcar; status no cartão; resumo do dia; conflito de horário; exportar e imprimir; aviso no sininho; ligação com Google Agenda | núcleo (E3·2) | E3·2; [mapa]; [escopo]; `DESIGN.md` §7 |
| 2 | Agendamento | novo agendamento em etapas: cliente, serviços, data e hora, conferência; atendimento de balcão sem reserva; remarcar; status; notas; formulários do atendimento; atendimento repetido; linha do tempo do atendimento; política de cancelamento e falta | núcleo (E3·2) | E3·2; [mapa]; [escopo] |
| 3 | Clientes | lista, busca, filtros, criar, editar, perfil; histórico de atendimentos; notas e alertas; etiquetas e segmentos; consentimento de marketing; juntar duplicados; saldo da cliente; exportar | núcleo (E3·2) | E3·2; [mapa]; [escopo] |
| 4 | Formulários | modelos de formulário; ficha de saúde (anamnese) com link, assinatura e fotos; modo no estúdio com PIN; corrigir ficha assinada; consentimentos; ficha obrigatória por serviço | núcleo (E3·2); a ficha de saúde fica dentro de Formulários, não é módulo próprio (E21·2·A) | E3·2; E21·2; [mapa] (Anamnese); [escopo]; `DESIGN.md` §7 |
| 5 | Catálogo | serviços e categorias; pacotes, combos e planos de assinatura; produtos; regras por serviço (duração, retoque, sinal); ficha obrigatória por serviço; descrição com ajuda de IA | núcleo (E3·2); a cobrança do sinal à cliente entra depois do núcleo, no Checkout (E21·3·B) | E3·2; E21·3; [mapa]; [escopo]; `DESIGN.md` §7 |
| 6 | Checkout | comanda por atendimento e venda avulsa; etapas revisar, pagar, concluído; várias formas de pagamento no mesmo pagamento; desconto, gorjeta e taxa; usar crédito da cliente; reembolso; comprovante interno sem valor fiscal; cobrança à cliente por link de pagamento e sinal | núcleo (E3·2); cobrança à cliente por link de pagamento e sinal entra depois do núcleo, um por vez (E21·3·B) | E3·2; E21·3; [mapa] (Comanda/Checkout); [escopo] |
| 7 | Caixa | abrir, retirar (sangria), reforçar (suprimento), fechar com contagem cega, reabrir; aviso na hora de fechar | núcleo (E3·2) | E3·2; [mapa] |

### 3.2 Depois do núcleo, um por vez (E3·2; E21·1)
A ordem entre eles não está decidida: entra pela fila, quando chegar a vez (`AGENTS.md` §5).

| # | Módulo | Recursos em uma linha | Quando entra | Fonte |
|---|---|---|---|---|
| 8 | Financeiro | receitas e despesas; contas a pagar; resumo do mês; relatórios com exportação; DRE; comissões das profissionais; saldos de clientes; vale-presente | depois do núcleo, um por vez (E3·2; E21·1); vale-presente aqui, depois do núcleo (E21·3·B) | pedido (c); E21·3; [mapa]; [escopo]; `DESIGN.md` §7 |
| 9 | Estoque | produtos com entrada e saída; fornecedores; pedidos de compra; recebimento; reposição | depois do núcleo, um por vez (E3·2; E21·1) | pedido (c); [mapa] (Estoque/Compras); `DESIGN.md` §7 |
| 10 | Mensagens | conversas; modelos de mensagem; lembretes e confirmações automáticos; WhatsApp e e-mail; histórico de envios | depois do núcleo, um por vez (E3·2; E21·1) | [mapa]; [escopo]; `DESIGN.md` §7; `ARCHITECTURE.md` §10 |
| 11 | Marketing | campanhas só para quem autorizou; segmentos de clientes; cupons e ofertas; retorno por procedimento; aniversário; pedido de avaliação no Google | depois do núcleo, um por vez (E3·2; E21·1) | pedido (c); [mapa]; [escopo]; [futuros] |
| 12 | Fidelidade | pontos e extrato; ajuste manual; níveis; recompensas e resgate; validade; indicação e aniversário; avisos pela mensagem | depois do núcleo, um por vez (E3·2; E21·1) | pedido (c); [mapa]; [escopo]; [futuros]; [fidel] |
| 13 | Equipe | pessoas do estúdio; convite com aceite; papéis e permissões por módulo; agenda de cada profissional | depois do núcleo, um por vez (E3·2; E21·1); os papéis fixos dona, recepção e profissional já valem desde o núcleo (E4·1; `ARCHITECTURE.md` §6) | [mapa] (Equipe/Acessos); [futuros]; `DESIGN.md` §7 |
| 14 | Ajustes | dados do estúdio; horário; atendimento; formas de pagamento; ficha de saúde; aparência; preferências da pessoa; conta | depois do núcleo, um por vez (E3·2; E21·1) | [mapa]; `DESIGN.md` §7 |
| 15 | Importação e exportação | importar clientes e dados de outro sistema; exportar os dados do estúdio | depois do núcleo, um por vez (E3·2; E21·1) | [mapa]; `ARCHITECTURE.md` §7 |
| 16 | Central de ajuda | perguntas frequentes e respostas dentro do sistema antes de virar chamado; chamado de suporte | depois do núcleo, um por vez (E21·1) | Pedido (módulos) |
| 17 | Assistente de IA | IA gratuita (Gemini ou outra) para tirar dúvidas, ajudar e executar ações no sistema | depois do núcleo, um por vez (E21·1) | Pedido (módulos) |
| 18 | Impulsionamento | ferramentas para o estúdio divulgar o próprio site e trazer clientes | depois do núcleo, um por vez (E21·1) | [eco] |

### 3.3 Partes do sistema, depois dos "um por vez" (E21·1)
Entram só depois dos módulos do §3.2, nesta ordem entre si (a mesma da E4·3; a API pública só quando precisarem,
E4·1).

| # | Módulo | Recursos em uma linha | Quando entra | Fonte |
|---|---|---|---|---|
| 19 | Painel admin | área separada do dono da plataforma; ver e gerir os estúdios; entrar como o estúdio para suporte | depois dos "um por vez" (E21·1) | E3 (pedido); E4·2; `ARCHITECTURE.md` §2 e §6; [mapa] (SaaS/Planos) |
| 20 | Cadastro de estúdio e assinatura | criar estúdio e primeiro acesso; planos que ligam e desligam módulos; cobrança da assinatura | depois do painel admin (E21·1; E4·3) | E4·3; `ARCHITECTURE.md` §2 e §5; [futuros]; [mapa] |
| 21 | Portal público do estúdio | página do estúdio e reserva online pelo cliente; páginas públicas de formulário e de pagamento | depois da cobrança da assinatura (E21·1; E4·3) | E4·3; `ARCHITECTURE.md` §2; [mapa]; [eco] |
| 22 | Marketplace | portal público para encontrar estúdios e serviços | depois da reserva online (E21·1; E4·3) | E3 (pedido); E4·3; [mapa]; [eco] |
| 23 | API pública | porta para o marketplace e parceiros chamarem o sistema | depois dos "um por vez" e só quando precisarem (E21·1; E4·1) | E4·1; `ARCHITECTURE.md` §2 |

**Ficou fora da lista** (não é módulo; o dono aprovou a lista em E21·1 sem trazer de volta): design system (já
está no `DESIGN.md`), menu e navegação (`DESIGN.md`), idiomas, fuso e moeda (valem em todo o sistema,
`ARCHITECTURE.md` §11), segurança, cópia do banco e monitoramento (`ARCHITECTURE.md` §7 a §11), processo de
trabalho da IA (`AGENTS.md`).

## 4. Critérios de aceite
1. Existe `docs/produto/README.md` com uma frase sobre o sistema e um índice com uma linha e um link por módulo,
   na ordem do §3 (núcleo, depois "um por vez", depois partes do sistema).
2. Existe um arquivo em `docs/produto/` para cada módulo da tabela aprovada, e nenhum outro (23 arquivos de
   módulo; sem arquivo próprio para ficha de saúde, cobrança à cliente ou vale-presente).
3. Cada arquivo tem as 5 partes do §2, nesta ordem e com esses nomes.
4. Cada recurso escrito está na linha do módulo na tabela aprovada; nenhum recurso novo.
5. "Quando entra" de cada arquivo bate com o §3 e com E3·2, E21·1 e E21·3. Onde E4·3, `ARCHITECTURE.md` §2 ou
   `docs/BACKLOG.md` ainda mostrarem a ordem antiga, vale o §3 (ajuste feito fora desta spec, ver §3).
6. Nenhuma sequência de 8 palavras seguidas de `docs/produto/` aparece igual nos 5 arquivos do antigo do §3
   (comparação automática feita pelo revisor; resultado anexado à revisão).
7. Nenhum texto diz que o dono decidiu algo que não está em `docs/decisoes/`; nenhum nome de pessoa, de cliente
   real ou de marca do projeto antigo; nenhum segredo.
8. O PR muda só `docs/produto/` e esta pasta de spec (mais os documentos de controle do Documentador, `AGENTS.md`
   §9).
9. Outro papel, que não escreveu, revisou o texto sem bloqueio (`AGENTS.md` §9, tipo texto).

## 5. Dúvidas para o dono (respondidas em 28/11/2026)
- **E21·1 · A lista está certa?**
  A: confirma os 23 módulos como estão · B: confirma tirando ou acrescentando (diga quais) · C: refazer a lista.
  Recomendação: **B** se faltar algo que você desenhou; senão **A**.
  **Resposta:** lista aprovada com os 23 módulos, mas a ordem muda: as partes do sistema (painel admin, cadastro e
  assinatura, portal público, marketplace, API pública) são novas e entram depois dos "um por vez". Fala: "E21-1:
  Módulos, inverta o partes do sistema pelo "depois um por vez". Pois esses do item 2(partes do sistema) é novo e
  entra depois dos "um por vez"." Aplicado no §3.
- **E21·2 · Ficha de saúde (anamnese): dentro de Formulários ou módulo próprio?**
  A: dentro de Formulários, como no E3·2 e no menu do `DESIGN.md` · B: módulo próprio, ao lado de Formulários.
  Desfaz: mudar só a lista em `docs/produto/`. Recomendação: **A** (já é o nome aprovado no núcleo; as travas
  extras da ficha valem igual, `ARCHITECTURE.md` §7).
  **Resposta: A** ("E21-2a"). A ficha de saúde fica dentro de Formulários (§3.1, linha 4).
- **E21·3 · Cobranças à cliente (link de pagamento, sinal) e vale-presente: onde e quando?**
  A: recursos do Checkout, já no núcleo · B: recursos do Checkout e do Financeiro, depois do núcleo, um por vez ·
  C: módulos próprios, depois. Desfaz: mudar só a lista. Recomendação: **B** (mantém o núcleo do E3·2 pequeno; o
  Checkout já nasce com várias formas de pagamento).
  **Resposta: B** ("E21-3b"). Link de pagamento e sinal são recursos do Checkout; vale-presente é recurso do
  Financeiro; ambos entram depois do núcleo (§3.1, linhas 5 e 6; §3.2, linha 8).

## 6. Assumptions (decisões de formato, à vista na aprovação)
1. Um arquivo por módulo em Markdown, nomes pela regra do §2 item 4.
2. Painel admin, cadastro e assinatura, portal, marketplace e API pública entram na lista como módulos, porque são
   partes do sistema no `ARCHITECTURE.md` §2 (quando entram: E21·1, §3.3).
3. Os nomes dos módulos seguem o `DESIGN.md` §7 (menu) e o E3·2 quando o antigo usa outro nome (ex.: "Comanda"
   vira Checkout; "Estoque/Compras" vira Estoque; "Equipe/Acessos" vira Equipe).
4. A linha de recursos é a lista candidata. Quais recursos entram na primeira versão de cada módulo, e o que um
   módulo do núcleo precisa de outro (ex.: horário do estúdio para a Agenda), se decide na spec daquele módulo.
5. O estado do antigo (pronto, parcial, planejado) não entra em `docs/produto/`: o crm-citas começa do zero.

## 7. Fora de escopo
Código, banco, telas e fichas visuais; ordem entre os módulos "um por vez" do §3.2; mudar a fila
(`docs/BACKLOG.md`, papel do Documentador) e o `ARCHITECTURE.md` §2 (PR próprio) para a nova ordem da E21·1;
preços e planos; copiar texto, regra, spec, código ou banco do projeto antigo; ler do antigo algo além dos 5
arquivos do §3.
