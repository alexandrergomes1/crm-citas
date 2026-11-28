# ADR 0006 · Agenda: dia do estúdio por Intl, tetos, "Desfazer" por recriação e acesso por chave e alcance

- **Status:** Proposto, até a revisão de outro papel (E16·1) · decisões técnicas (`AGENTS.md` §5) · 28/11/2026, com a spec
  `specs/20261128-020000-agenda/spec.md` aprovada (commit `4e5b364`). Revisto em 28/11/2026 (tarefa MP1 de
  `specs/20261128-030000-entrar-servico/tasks.md`): D6 substituída; D7 a D13 novas. **Revisto de novo em 28/11/2026**
  (spec §16 e §17, commits `217a715` e `a0159f6`): D3 e D7 substituídas, D8 e D12 ajustadas, D14 a D16 novas.
  **Revisto pela 3ª vez em 28/11/2026** (spec §18, commit `de894bf`; `DESIGN.md` nos commits `d3f9a43` e `e1ccf73`;
  ficha v4): D17 em vigor (E59·A), D11 e D12 com "+ Adicionar ▾", D18 nova (botão do meio em todo o app). A linha
  `agenda.ver` da matriz do ADR 0020 é substituída pelo ADR 0021.
- **Autor:** Arquiteto de software · **Norma:** modelo C4 e ADR; Clean Architecture; Twelve-Factor; WCAG 2.2; OWASP
  ASVS 4.0.3 V4.1.1, V4.1.3, V4.1.5, V4.2.1, V5.1.3, V8.3.1; RGPD art. 5(1)(c); `ARCHITECTURE.md` §5 e §11
- **Revisão (E16·1):** pendente · Revisor de código (todas) · Revisor de design (D12, D17, D18) · Engenheiro de segurança (D6 a D9, D14, D15) · Engenheiro de
  dados (D3, D7, D14, D15, a parte do banco) · **Revisores de D10/D11:** Revisor de código, Engenheiro de segurança e
  Auditor de risco, ninguém que construiu o Entrar
- **Aviso ao dono:** em uma linha, no pedido de revisão do plano (`AGENTS.md` §3 regra 3).
- **Detalhe:** `specs/20261128-020000-agenda/plan.md` §2 a §6. Decisões de banco (tabelas do antigo, forma das
  políticas e da coluna nova): ADR 0007, do Engenheiro de dados. Base: ADR 0018 (D3, D16, D18, D24) e ADR 0020.

## Contexto
A Agenda é a primeira tela com texto em três idiomas (RNF-05), a primeira regra que depende do fuso do estúdio (RN-01,
RN-02) e o **primeiro módulo do modo `estudio`** (porta 3 por chave e alcance, ADR 0020; envelope com
`estudioDaTela`; matriz copiada no banco). Respostas do dono: E26·2·A (próprios), E26·3·A (colunas) e, em 28/11, a
ordem "cada profissional só vê o dela" com a E58·A (sem "Ocupado" nesta spec; "ver as outras" e "ver ocupação" no item
6a), a E57·B (formatos de visão, resumo, dias marcados, horário de funcionamento e lupa para a spec seguinte), E54·1 a
·4 aprovadas, E54·5 trocada por seletor de horários e E55·1·A a E55·4; depois, E59·A (grade 08:00–20:00 que se alarga)
e E60·1·A a E60·5 ("+ Adicionar ▾" com o bloqueio dentro; botão do meio da barra só com ícone, em todo o app; linha
do agora em azul ardósia; Equipe com ícone de pessoas, qual deles na E63). O `AGENTS.md` §3 regra 6 manda reusar antes
de criar.

## Decisões

| # | Decisão | Motivo e norma |
|---|---|---|
| D1 | Idiomas pela base que já existe (`src/app/i18n/{pt,es,en}.ts`, `Intl.PluralRules` e `Intl.DateTimeFormat`); a Agenda só acrescenta o bloco `agenda` (com os atalhos de motivo, RF-22). Sem biblioteca de idiomas | reuso (`AGENTS.md` §3 regra 6); o tipo acusa chave faltando e `i18n.test.ts` acusa texto vazio ou marcador diferente |
| D2 | Limites do dia do estúdio em `src/domain` só com `Intl.DateTimeFormat`, sem `Temporal` e sem biblioteca de datas; o dia começa no primeiro instante que tem aquela data no fuso | `Temporal` não verificado no Cloudflare Workers nem no Chromium do teste; `Intl` existe nos três. Regra pura com teste (23 h, 25 h, meia-noite que não existe) |
| D3 | **(substitui a D3 anterior, que contava a leitura de "ocupados")** Tetos no trabalho: leitura do dia com no máximo **2 pedidos** (colunas; bloqueios das colunas visíveis); gravação com **1 leitura + 1 gravação**; **500 itens** por dia, lidos com `limit 501`. A spec do Agendamento e a spec seguinte da Agenda sobem o teto no ADR delas | `ARCHITECTURE.md` §5 e §11; ADR 0018 · D3. 500 cabe abaixo do `max_rows` 1000 da API local. Provado por teste do servidor que conta as idas |
| D4 | "Desfazer" depois de excluir = criar de novo com os mesmos dados, pela ação `agenda.bloqueio.criar`; nada fica guardado no banco depois de excluído | minimização (RGPD art. 5(1)(c)): sem lixeira. Custo: outro `id` e possível conflito |
| D5 | A escolha do "Equipe N de M" fica no armazenamento local do navegador, por estúdio, só com identificadores das colunas escondidas | spec Assumption 2; sem dado pessoal (`ARCHITECTURE.md` §7); sem tabela nem ida ao banco |
| D6 | Acesso por **chave e alcance** (ADR 0020): `agenda.ver`, `agenda.criar`, `agenda.editar`, `agenda.remover`; a matriz do código ganha 8 linhas (recepção `todos`, profissional `proprios`) e a M2 copia as mesmas no banco. **Nenhuma chave de ocupação** (E58·A). `src/domain/agenda/acesso.ts` recebe alcance e `usuarioId`, nunca papel; "próprios" = a coluna da própria pessoa, conferida na linha antiga e na nova ao alterar | ADR 0020 · D1 a D5, D7; ASVS V1.4.4, V4.1.3; o item 6a troca só a fonte, sem tocar a Agenda |
| D7 | **(substitui a D7 anterior, "Ocupado em duas camadas")** **Sem "Ocupado"** e sem leitura de "ocupados" (nenhuma função `security definer` nova). **Só a própria coluna, em duas camadas:** (1) a política de leitura de `bloqueios` só entrega a linha a quem tem `agenda.ver` `todos`, ou `proprios` e a linha é da própria pessoa; (2) com `proprios`, o servidor só pede e só devolve a coluna da pessoa, e o teste confere que nada de outra coluna sai. A política do banco fica como **defesa**, não como recurso | E58·A; CA-13; ASVS V4.2.1 e defesa em profundidade: se só o servidor filtrasse, um erro dele mostraria a agenda das colegas. Tirar a leitura de "ocupados" remove superfície (uma função privilegiada a menos) e uma ida ao banco. "Ver ocupação" volta no item 6a com ADR próprio |
| D8 | **Colunas pelo papel das colegas é compatível com ADR 0020 · D5**, com quatro condições: o papel da pessoa da sessão segue fora do trabalho; "é coluna" mora em um lugar só de cada lado (`ehColuna` e uma condição no banco); o papel das colegas não sai do servidor (só `id` e nome de exibição); se o item 6a separar "atende" do papel, só `ehColuna` e a condição do banco mudam | a D5 proíbe decidir **o que a pessoa pode** pelo papel dela; quem é coluna é dado do estúdio aplicado a uma regra do dono (E26·3·A). Minimização (RGPD art. 5(1)(c)) |
| D9 | A leitura do dia é ação **`POST` com `grava: false`**; a URL da tela leva só `dia`, e a entrada vai no corpo | o molde recusa `GET` no modo `estudio` (ADR 0018 · D18); ASVS V8.3.1; RNF-04 |
| D10 | `sessao.ler` passa a devolver `orgId` (`SessaoLida`), e a tela usa esse valor como `estudioDaTela` | o envelope do modo `estudio` exige `estudioDaTela`; é identificador, sem dado pessoal, fica no contexto da rota, nunca na URL. Alternativa descartada: ação só para buscar o estúdio (uma ida a mais por tela) |
| D11 | O `ContextoEstudio` ganha `alcances`: o alcance de cada chave do módulo da ação, pela **mesma fonte** da porta 3 (`infra.alcanceDe`), falha fechada. `agenda.dia.ler` devolve esses alcances para a tela esconder o ⋮, o "Bloquear horário" do "+ Adicionar ▾" e da folha "Adicionar" e o menu do horário vazio | RF-11, RF-13 e ADR 0020 · D9; fonte única (ADR 0020 · D6), sem papel no trabalho (D5). Alternativa descartada: `alcancePadrao(papel, ...)` na Agenda |
| D12 | As peças novas do `DESIGN.md` §7b que a Agenda usa (grade com a faixa, cabeçalho de coluna, cartões, linha do "agora" em `--id`, horário vazio escolhido, data em pílula) ficam em `src/app/ui/`, com teste, vitrine e `@import` no `app.css`; `src/app/paginas/agenda/` só compõe. "+ Adicionar ▾" e o menu do horário vazio reusam `MenuAcoes` (computador) e `Folha` (celular); o seletor de horários reusa `CampoSelecao`, salvo pedido da ficha | fonte única do design system (ADR 0004); a dívida D24 do ADR 0018 nasceu de copiar peças em páginas; reuso (`AGENTS.md` §3 regra 6) |
| D13 | No e2e, as contas da Agenda (com nome de exibição fictício) entram pelo `e2e/preparo-global.ts`; os bloqueios são criados pelos testes, pela tela ou pela ação | o gatilho de registro recusa gravação sem pessoa e sem `x-acao` da lista; criar pelas portas também prova o caminho real (ISTQB) |
| D14 | **Nome de exibição (E55·1·A, RF-21) mora em `public.membros.nome_exibicao`**, por vínculo pessoa × estúdio: `text null`, de 1 a 60 caracteres sem espaço nas pontas, **sem `grant update`** para `authenticated` nesta spec (o módulo Equipe acrescenta privilégio, ação e tela). Em desenvolvimento, nomes fictícios pelo preparo dos testes. Iniciais calculadas na tela. Nunca o e-mail no lugar. Forma final do Engenheiro de dados (ADR 0007) | **Por vínculo:** a mesma pessoa em dois estúdios pode ter nomes diferentes, e o isolamento vem da RLS que `membros` já tem (`ARCHITECTURE.md` §5). **Não em `auth.users`:** os metadados são mudados pela própria pessoa pela API de Auth, fora das portas, e valem para todos os estúdios (ASVS V4.1.3). **Não em tabela nova:** uma ida a mais por tela (D3), mais RLS e teste por um campo. **Sem gravação na v1:** nenhum caminho do app grava, então nenhum privilégio a mais (mínimo privilégio, ASVS V4.1.3; RGPD art. 5(1)(c)) |
| D15 | **Hora só por seletor, em passos de 15 min, recusada no servidor fora do passo** (E54·5 trocada, RN-09, CA-15). As opções são instantes do dia do estúdio gerados por `src/domain/agenda/horarios.ts` (rótulo local por `Intl`, inclusive dias de 23 e 25 h); o servidor recebe instantes ISO com fuso e recusa com `entrada_invalida`, sem ir ao banco, o que tiver segundos, minuto fora do múltiplo de 15 ou cair fora do dia. Defesa no banco por `check` do passo, se o Engenheiro de dados decidir | Instante, não "HH:MM": no dia de 25 h a mesma hora local existe duas vezes e "HH:MM" seria ambíguo. Passo em UTC = passo local porque os deslocamentos de fuso são múltiplos de 15 min (não verificado para todos os fusos aceitos; o teste cobre os usados). Validar no servidor, não só na tela (ASVS V5.1.3) |
| D16 | **`/` redireciona para `/agenda`** no `beforeLoad` da rota `/_app/` (RF-12, E55·2·A); `src/app/paginas/inicio.tsx` e o teste saem, e `e2e/inicio.spec.ts` prova o redirecionamento | uma tela só por endereço; a tela inicial provisória do `DESIGN.md` §8b valia "até a Agenda existir". `redirect` do TanStack Router a ler na documentação antes da construção (`AGENTS.md` §6) |

## Grade da v1 · E59·A respondida (spec §18, RN-11)
Sai a grade de 24 h. Vale 08:00 a 20:00 que se alarga para caber item fora e, no dia de hoje, a hora atual: função
pura `faixaVisivel` em `grade.ts` com teste (CA-01); seletor de horários, banco, servidor e tetos não mudam. Detalhe:
`plan.md` §3.2.

| # | Decisão (em vigor desde a E59·A) | Motivo e norma |
|---|---|---|
| D17 | No dia de hoje, se a hora atual (fuso do estúdio) está fora da faixa 08:00–20:00, **a faixa se alarga até ela** (hora cheia anterior ou seguinte), como faz com item fora; a linha do "agora" em `--id` (E60·3·A, `DESIGN.md` §7b·12) aparece sempre que o dia é hoje. Em outro dia, o "agora" não conta. O "agora" vem do relógio do navegador, relido a cada minuto | RF-14 manda a linha na coluna de hoje sem exceção; sumir tiraria a referência justo de quem atende cedo ou tarde (heurística de Nielsen 1, visibilidade do estado do sistema). Mesma regra pura do alargamento por item, com teste (CA-01) |

## Botão do meio e folha "Adicionar" (E60·2, E60·5)

| # | Decisão | Motivo e norma |
|---|---|---|
| D18 | **Uma peça só para o botão do meio, em todo o app:** `BotaoAdicionar` em `src/app/ui/estrutura.tsx` substitui o `Agendar` (sai o nome escrito; fica o círculo 52 `--ink` com `calendar-plus`, `aria-label="Adicionar"`, `aria-haspopup="dialog"`, `aria-expanded`), e a `BarraBaixo` o recebe. A **folha "Adicionar"** mora no layout (`src/app/routes/_app.tsx` com `src/app/paginas/adicionar.tsx`): a tela aberta entrega as opções por um contexto; sem tela que entregue, a folha mostra as mesmas opções da Agenda e "Bloquear horário" leva à `/agenda` com um pedido na memória do layout, nunca na URL. O token `--d-agendar` mantém o nome. No computador, "+ Adicionar ▾" pelo `MenuAcoes`, com a mesma lista de opções | `DESIGN.md` §5, §6 e §8b (E60·2: "vale em todo o app"); fonte única do design system (ADR 0004; dívida D24 do ADR 0018); a barra é do layout, não de uma tela, então a folha também; WCAG 4.1.2 (nome, papel e estado do botão sem texto) e 2.5.8 (alvo); RNF-04 (nada na URL). Renomear o token só mexeria em `tokens.css`, `tokens.test.ts` e `vitrine.css` sem efeito visível. Alternativa descartada: cada tela desenhar a própria folha (o mesmo botão abriria coisas diferentes, Nielsen 4) |

## Consequências
- Texto novo de qualquer módulo entra nos três arquivos; a checagem de tipos falha se faltar um.
- Outros módulos que precisem do dia do estúdio ou do seletor de horários usam `dia.ts` e `horarios.ts`; se virarem
  gerais, mudam de pasta num ADR novo.
- Os módulos seguintes usam `ctx.alcances` (D11) e `SessaoLida.orgId` (D10) sem mudar o contrato de novo.
- "Ver as outras" e "ver ocupação" (item 6a) pedem ADR novo: chave nova ou alcance novo (ADR 0020 · D2), política de
  leitura e, se houver "Ocupado", uma leitura só de horários. Nada disso existe nesta spec.
- RF-16 a RF-20 (spec seguinte) podem subir o teto da D3 (dias marcados: uma ida por mês aberto) no ADR delas.
- O módulo Equipe acrescenta a gravação de `nome_exibicao` (D14): privilégio por coluna, ação com chave e registro.
- Pessoa que deixou de ser coluna: pendência da Equipe (spec §12); defesa: a ligação sem apagar em cascata.
- Toda tela nova dentro do `_app` que crie algo entrega as próprias opções à folha "Adicionar" (D18); o que mais entra
  na folha vem com pedido do dono (RF-08).
- Para desfazer qualquer linha: ADR novo que a substitui, com o motivo.

## Não verificado
- D10 e D11 tocam arquivos já juntados do Entrar: nada rodado; dependem dos revisores de D10/D11.
- D2 e D15: o `Intl` na meia-noite que não existe e os rótulos do dia de 25 h são provados só pelos testes do CA-01 e
  do CA-15, ainda não escritos; que todo fuso aceito por `estudios_conferir_fuso` tenha deslocamento múltiplo de 15 min
  não foi conferido.
- D14: a forma final da coluna e o efeito no `010_base_estrutura_test.sql` são do Engenheiro de dados (ADR 0007).
- D16: a forma exata do `redirect` na versão instalada do TanStack Router não foi lida ainda.
- D17: o salto de rolagem quando o "agora" do navegador alarga a faixa vinda do servidor não foi testado.
- D18: a forma do contexto no layout com a versão instalada do TanStack Router não foi lida; se quem usa entende o botão
  sem nome escrito não foi testado (ficha v4).
