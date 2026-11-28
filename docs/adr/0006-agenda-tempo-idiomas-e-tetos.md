# ADR 0006 · Agenda: dia do estúdio por Intl, tetos, "Desfazer" por recriação e acesso por chave e alcance

- **Status:** Aceito · decisões técnicas (`AGENTS.md` §5) · 28/11/2026, com a spec
  `specs/20261128-020000-agenda/spec.md` aprovada (commit `4e5b364`). Revisto em 28/11/2026 (tarefa MP1 de
  `specs/20261128-030000-entrar-servico/tasks.md`): D6 substituída; D7 a D13 novas.
- **Autor:** Arquiteto de software · **Norma:** modelo C4 e ADR; Clean Architecture; Twelve-Factor; WCAG 2.2; OWASP
  ASVS 4.0.3 V4.1.1, V4.1.3, V4.1.5, V4.2.1, V8.3.1; RGPD art. 5(1)(c); `ARCHITECTURE.md` §5 e §11
- **Revisão (E16·1):** pendente · Revisor de código (todas; D10 e D11 tocam o contrato do Entrar) · Engenheiro de
  segurança (D6 a D11) · Engenheiro de dados (D3, D7, a parte do banco)
- **Aviso ao dono:** em uma linha, no pedido de revisão do plano (`AGENTS.md` §3 regra 3).
- **Detalhe:** `specs/20261128-020000-agenda/plan.md` §2, §5 e §6. Decisões de banco (tabelas do antigo, forma das
  políticas): ADR 0007, do Engenheiro de dados. Base: ADR 0018 (contrato `acao(...)`, D3, D18, D24) e ADR 0020.

## Contexto
A Agenda é a primeira tela com texto em três idiomas (RNF-05), a primeira regra que depende do fuso do estúdio (RN-01,
RN-02) e o **primeiro módulo do modo `estudio`**: a primeira a usar a porta 3 por chave e alcance (ADR 0020), o envelope
com `estudioDaTela` e a matriz copiada no banco. O dono respondeu E26·1·B ("Ocupado"), E26·2·A (próprios) e E26·3·A
(colunas). O `AGENTS.md` §3 regra 6 manda reusar antes de criar.

## Decisões

| # | Decisão | Motivo e norma |
|---|---|---|
| D1 | Idiomas pela base que já existe (`src/app/i18n/{pt,es,en}.ts`, chaves do `pt.ts` como tipo das outras, `Intl.PluralRules` e `Intl.DateTimeFormat`); a Agenda só acrescenta o bloco `agenda`. Sem biblioteca de idiomas | reuso (`AGENTS.md` §3 regra 6); o tipo acusa chave faltando e `i18n.test.ts` acusa texto vazio ou marcador diferente |
| D2 | Limites do dia do estúdio em `src/domain` só com `Intl.DateTimeFormat`, sem `Temporal` e sem biblioteca de datas; o dia começa no primeiro instante que tem aquela data no fuso | `Temporal` não verificado no Cloudflare Workers nem no Chromium do teste; `Intl` existe nos três. Regra pura com teste (23 h, 25 h, meia-noite que não existe) |
| D3 | Tetos no trabalho: leitura do dia com no máximo **3 pedidos** (colunas; bloqueios completos; "ocupados" das outras colunas, só com alcance `proprios`); gravação com **1 leitura + 1 gravação**; **500 itens** por dia, lidos com `limit 501`. A spec do Agendamento sobe o teto no ADR dela | `ARCHITECTURE.md` §5 e §11 (limite de idas por tela; nada cortado calado, RN-08); ADR 0018 · D3 (uma gravação por ação). 500 cabe abaixo do `max_rows` 1000 da API local. Provado por teste do servidor que conta as idas |
| D4 | "Desfazer" depois de excluir = criar de novo com os mesmos dados, pela ação `agenda.bloqueio.criar` (mesmas portas e conflito); nada fica guardado no banco depois de excluído | minimização (RGPD art. 5(1)(c)): sem lixeira; o registro mostra a exclusão e a nova criação. Custo: outro `id` e possível conflito |
| D5 | A escolha do "Equipe N de M" fica no armazenamento local do navegador, por estúdio, só com identificadores das colunas escondidas | spec Assumption 2; sem dado pessoal (`ARCHITECTURE.md` §7); sem tabela nem ida ao banco |
| D6 | **(substitui a D6 anterior, "constante das E26 e função do papel")** Acesso por **chave e alcance** (ADR 0020): as ações declaram `agenda.ver`, `agenda.criar`, `agenda.editar`, `agenda.remover`; a matriz do código ganha 8 linhas (recepção `todos`, profissional `proprios`, E26·1·B e E26·2·A) e a M2 copia as mesmas no banco. `src/domain/agenda/acesso.ts` recebe alcance e `usuarioId`, nunca papel; "próprios" = a coluna da própria pessoa, conferida na linha antiga e na nova ao alterar | ADR 0020 · D1 a D5, D7; ASVS V1.4.4 (um mecanismo), V4.1.3; o item 6a troca só a fonte, sem tocar a Agenda |
| D7 | **"Ocupado" em duas camadas:** o banco não entrega linha completa de outra coluna a quem tem `agenda.ver` só `proprios` (política de leitura por `app.pode`) e dá os horários das outras colunas numa leitura que devolve só profissional, início e fim; o servidor monta "Ocupado" sem `id`, cliente, serviço, status nem motivo, e o teste confere que nenhum campo a mais sai. A forma da leitura é do Engenheiro de dados (ADR 0007) | E26·1·B; CA-13 ("esses dados não saem do servidor"); ASVS V4.2.1 e defesa em profundidade: se só o servidor mascarasse, um erro dele ou um acesso direto à API (hoje barrado pela chave do servidor, ADR 0018 · D16) mostraria o motivo das colegas |
| D8 | **Colunas pelo papel das colegas é compatível com ADR 0020 · D5**, com quatro condições: o papel da pessoa da sessão segue fora do trabalho; "é coluna" mora em um lugar só de cada lado (`ehColuna` em `acesso.ts` e uma condição no banco); o papel das colegas não sai do servidor; se o item 6a separar "atende" do papel, só `ehColuna` e a condição do banco mudam, com pergunta ao dono na spec do 6a | a D5 proíbe decidir **o que a pessoa pode** pelo papel dela; quem é coluna é dado do estúdio aplicado a uma regra do dono (E26·3·A), não decisão de acesso. Ler `membros.papel` já é permitido a todo membro (`membros_ler`, item 3): nada novo exposto. Minimização (RGPD art. 5(1)(c)) para a tela |
| D9 | A leitura do dia é ação **`POST` com `grava: false`**; a URL da tela leva só `dia` (`validateSearch`), e a entrada da ação vai no corpo | o molde recusa `GET` no modo `estudio` (ADR 0018 · D18; `conferirDefinicao`); ASVS V8.3.1; RNF-04 |
| D10 | `sessao.ler` passa a devolver `orgId` (`SessaoLida`), e a tela usa esse valor como `estudioDaTela` | o envelope do modo `estudio` exige `estudioDaTela` uuid (`executar.ts`) e hoje a tela não o tem; é identificador, sem dado pessoal, e fica no contexto da rota, nunca na URL; o valor só é comparado no banco (RF-15 do Entrar). Alternativa descartada: ação só para buscar o estúdio (uma ida a mais por tela) |
| D11 | O `ContextoEstudio` ganha `alcances`: o alcance de cada chave do módulo da ação, pela **mesma fonte** da porta 3 (`infra.alcanceDe`), falha fechada. `agenda.dia.ler` devolve esses alcances para a tela esconder o ⋮ e a entrada de bloqueio | RF-11 e ADR 0020 · D9 (lista efetiva só para a tela); fonte única (ADR 0020 · D6), sem papel no trabalho (D5). Alternativa descartada: calcular na Agenda com `alcancePadrao(papel, ...)`, que leria o papel e pularia a fonte que o 6a troca |
| D12 | As peças novas do `DESIGN.md` que a Agenda usa (grade, cartões, "Ocupado", data em pílula, campo de hora) ficam em `src/app/ui/`, com teste, vitrine e `@import` no `app.css`; `src/app/paginas/agenda/` só compõe | fonte única do design system (ADR 0004); a dívida D24 do ADR 0018 nasceu de deixar `src/app/ui` fora da lista de arquivos e copiar peças em páginas |
| D13 | No e2e, as contas da Agenda entram pelo `e2e/preparo-global.ts` (único com a chave local de administração); os bloqueios são criados pelos testes, pela tela ou pela ação com a sessão da dona | o gatilho de registro (`app.registrar_mudanca`) recusa gravação sem pessoa e sem `x-acao` da lista: dado criado pela chave de administração seria recusado; criar pelas portas também prova o caminho real (ISTQB: ambiente controlado) |

## Consequências
- Texto novo de qualquer módulo entra nos três arquivos; a checagem de tipos falha se faltar um.
- Outros módulos que precisem do dia do estúdio usam `src/domain/agenda/dia.ts`; se virar geral, muda de pasta num ADR
  novo.
- Os módulos seguintes usam `ctx.alcances` (D11) e `SessaoLida.orgId` (D10) sem mudar o contrato de novo.
- E50·1 e as ideias E50·I1 a I8 esperam o dono; onde cada uma entraria está no `plan.md` §3.2 e §3.3. Se aprovadas,
  as que mudam tetos (E50·1·B, E50·I7) pedem linha nova aqui.
- Para desfazer qualquer linha: ADR novo que a substitui, com o motivo.

## Não verificado
- D10 e D11 tocam arquivos já juntados do Entrar: nada rodado; dependem da revisão do Revisor de código e do
  Engenheiro de segurança.
- D7: a forma da leitura de "ocupados" no banco e o uso de `rpc(..., { get: true })` nela não foram rodados.
- D2: o comportamento do `Intl` na meia-noite que não existe é provado só pelo teste do CA-01, ainda não escrito.
