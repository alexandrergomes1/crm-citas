# Guia · Revisão

Quem constrói não revisa (`AGENTS.md` §4). Cada achado tem um dono só: um revisor não refaz o trabalho do outro.

## Regras comuns a todos os revisores
- Revisor aponta; não corrige e não decide.
- Não roda typecheck, lint nem testes: lê o resultado da CI no PR e o cita. Job que não rodou ou falhou é o primeiro achado.
- Numa segunda rodada (correção de um achado), confere só o diff da correção.
- Gravidade: **Bloqueia**, **Médio** ou **Baixo**, cada achado com arquivo:linha (ou o quadro), o problema em uma frase e a regra ou o trecho da spec que ele descumpre. Termina com veredito.
- Sem evidência: "não verificado", nunca "ok". Nada de lista genérica de boas práticas.
- Revisores do PR rodam em paralelo; o veredito vem depois deles.

## Quem revisa cada tipo de trabalho
| Tipo | Revisores do PR |
|---|---|
| Tela | bugs · código · tela |
| Funcionalidade, Dados, Integração | bugs · código · risco |
| Manutenção e bug | bugs · código |
| Porte | conforme o tipo |
| Configuração, trava, CI | código (confere também o funcionamento) · risco (acesso) |
| Documento | só o veredito |
Sempre, no fim: o veredito. Tipos e níveis: `processo-sdd.md`.

**Revisor da spec** (antes da aprovação, quem não a escreveu): tela → design; nível C → risco; o resto → só a análise do Spec Kit. **Ficha visual:** revisor de design antes de ir ao dono.

## Bugs
Procura erro de lógica no diff. É o único que caça bug; os outros, se tropeçarem num, citam em uma linha no fim, sem investigar.

## Código (spec e arquitetura)
Entrada: o diff e a spec (ou o item da fila, em manutenção). Sem um dos dois, o primeiro achado é "sem spec". Confere, nesta ordem:
1. **Spec:** cada requisito (FR) e critério de sucesso (SC) implementado; nada pedido de fora; nada não pedido dentro.
2. **Orçamento de idas ao banco** (`servidor.md`): consulta em laço, várias idas numa ação que caberiam em uma, função de servidor nova fora do teste do orçamento (Médio).
3. **Arquitetura** (`AGENTS.md` §5, guias da área): domínio puro, banco só em `src/data`, limite de linhas, textos da tela num lugar só.
4. **Duplicação** de algo que já tem função pronta em `src/domain` ou `src/data`.
5. **Só em "Configuração, trava, CI":** o funcionamento — falha em silêncio? Um erro faz a trava deixar de bloquear ou derruba a sessão?
Fora: bug; esquema, RLS, acesso, sessão e vazamento (risco); tela renderizada (tela).

## Risco (nível C)
Dono dos achados de esquema, RLS, grants, acesso, sessão e vazamento. Lê inteiros `docs/reference/database.md` e `docs/reference/server.md` (vencem a prática geral) e `docs/reference/db-budget.md`. O que a CI já trava (`docs/reference/database.md`) não se reconfere. Diz no relatório que método de mercado usou.
**Na spec (antes do código):** regra que falta, quem pode e quem não pode, dado pessoal ou de saúde, efeito que repete (idempotência), critério de aceite que não vira teste, complexidade sem necessidade. Cada lacuna sai como pergunta em linguagem de leigo.
**No PR:**
1. **Isolamento:** `org_id`, id de cliente ou de registro vindo da tela sem passar pelas peças de acesso da casa; teste de isolamento para cada tabela ou política nova ou alterada (ausência é Bloqueia).
2. **Política, grant e chave:** abre leitura ou escrita a mais; soma com outra permissiva; `to authenticated`; UPDATE sem SELECT que alcance a linha; função `definer` e visão no padrão da casa; chave estrangeira nova composta com `org_id`; `on delete` escrito com a razão (ausência é Médio); duas relações entre o mesmo par de tabelas.
3. **`service_role`** onde a RLS do usuário alcança.
4. **Dado de saúde:** só as duas regras técnicas do `AGENTS.md` §5; nada jurídico (RGPD) até a produção. Dado pessoal comum: nunca em log nem em endereço.
5. **Páginas públicas:** token forte com validade, limite de tentativas, cabeçalhos de `docs/reference/server.md`.
6. **Aplicação da migration:** uma transação só; funciona com o código das duas branches; perde dado; tem caminho de volta; mudança que não cabe num deploy traz os passos em ordem (sem plano é Bloqueia). `create index concurrently` é Bloqueia (`banco.md`).
7. **Proteção descrita que não existe** ("Como está hoje" em `docs/reference/server.md`).
8. **Sempre:** injeção, SSRF, segredo no código ou em log, criptografia ou aleatoriedade fracas, caminho de arquivo, webhook sem assinatura; erro engolido em função de servidor e caminho de erro sem teste; trava longa ou índice faltando em migration.
Antes de marcar Bloqueia, escreve: quem alcança o ponto, qual o dano, se há outra defesa no caminho.

## Tela (tela renderizada)
Referência: a spec aprovada da tela; sem ela, para. Nunca confere contra memória nem registro antigo. A aprovação visual é sempre do dono. Só as duas larguras de conferência (`testes.md`); toque, contraste e fonte pelos mínimos de `DESIGN.md`; leitor de tela é "não verificado". As capturas da CI servem de evidência; sem como abrir a tela com dados, não inventa: "não verificado", com o motivo. Diz como capturou.
- **Aparência:** cada requisito e item do inventário de recursos aparece (faltando é Divergente); diferença da imagem de referência, com medida; só componentes e tokens do design system (fonte fora é Divergente); barra inferior não cobre conteúdo, alvo de toque no mínimo, nada cortado, nas duas larguras; dinheiro e data no formato do estúdio; textos como na spec.
- **Funcionamento:** capturas nas duas larguras; estados vazio, carregando e erro com texto e ação; teclado (ordem do foco, foco visível, Esc fecha a camada certa); nenhum erro no console.
- **Desempenho:** só lê o resultado da rotina de medição sem IA; enquanto ela não existir, "não verificado: sem rotina de medição".
Saída: três tabelas (Ok, Divergente, Não verificado). **Divergente em Aparência impede o merge.** "Não verificado" não impede, mas vai no PR e na mensagem ao dono como ponto a conferir na prévia.

## Design (ficha e spec de tela)
Critica a ficha antes de ir ao dono e a spec de tela antes da aprovação. Fatos: `DESIGN.md`, a linha de base (`AGENTS.md` §3), as escolhas do dono em "Clarifications" e em `docs/decisoes/`, o formato da ficha (`telas.md`). Confere:
1. **Contradição** com escolha registrada do dono, com a linha de base sem dizer que muda, ou com `DESIGN.md`.
2. **Clareza para leigo:** uma pergunta só, opções que mostram a diferença, "o que muda na tela" sem saber programar; diferença sutil ampliada.
3. **Completude:** computador e celular; fechado e aberto; estados vazio, carregando e erro quando a decisão os toca; até 4 decisões por ficha. Na spec: cada escolha da ficha em "Clarifications"; até 3 dúvidas, com opções e recomendação.
4. **Acessibilidade:** toque e contraste pelos mínimos, foco, nome em botão só-ícone.
5. **Lacuna aplicada sem escolha.**
6. **Pergunta demais:** item que reconfirma a linha de base ou algo já respondido (Médio: sai da ficha).
"Bloqueia" só para contradição com escolha do dono ou lacuna aplicada sem escolha. Os achados vão ao dono como informação; quem decide é ele.

## Veredito
Junta os relatórios dos revisores do tipo; faltou um exigido: REPROVADO com "falta X". Confere só o que fica entre eles, no diff contra a `previas`:
1. Arquivo fora de "Arquivos permitidos" (documentos de controle e `specs/NNN-nome/` são sempre permitidos).
2. Critério de "Como verificar" sem prova; em documento, cada item da spec cumprido.
3. Spec sem "Aprovação do dono", ou "o dono decidiu" sem registro na spec ou em `docs/decisoes/`.
4. Documentos de controle atualizados no mesmo PR.
5. Prova do tipo de trabalho lida e citada, não rodada.
Saída: lista única, mais grave primeiro (arquivo:linha · problema · quem achou · gravidade) e APROVADO ou REPROVADO.

No Claude Code: bugs = `/code-review`; código = agente `code-reviewer`; risco = `risk-auditor`; tela = `ui-qa`; design = `design-critic`; veredito = `critico-qa`.

## Origem
`.claude/agents/code-reviewer.md`, `risk-auditor.md`, `ui-qa.md`, `design-critic.md`, `critico-qa.md` · `docs/projeto/estrutura.md` (coluna "Revisores", "Revisor da spec", "Ficha visual") · `.claude/skills/sdd-construir/SKILL.md` · `docs/projeto/DESIGN-SYSTEM.md`.
