# Plano · Módulos do produto em `docs/produto/`

- **Escrito por:** Arquiteto de software · **Norma:** C4 (modelo de contexto), ADR
- **Spec:** `spec.md` desta pasta (Status: Draft) · **Tipo:** texto e regras (`docs/guias/processo-sdd.md` §3)
- **Data:** 27/11/2026
- **Construção:** só depois de "Status: Approved" e da linha "Aprovação do dono" na spec (`AGENTS.md` §3 item 1).

## 1. Como fazer
1. Esperar as respostas do dono a E21·1, E21·2 e E21·3. Se a tabela da spec §3 mudar, o Analista de requisitos
   atualiza a spec e o Arquiteto atualiza a lista do §2 deste plano **antes** da construção.
2. Quem escreve trabalha **só a partir da tabela aprovada da spec §3** e dos documentos do crm-citas
   (`ARCHITECTURE.md`, `DESIGN.md`, `docs/decisoes/`, `docs/BACKLOG.md`). **Não abre o projeto antigo**: a lista
   de recursos já está na spec; assim o risco de cópia fica perto de zero (`AGENTS.md` §3 item 4).
3. Um arquivo por módulo, no molde do §3, na ordem da spec §3. Depois o `README.md` com a frase do sistema e o
   índice.
4. Apagar `docs/produto/.gitkeep` (a pasta deixa de estar vazia).
5. Rodar as conferências do §5 e entregar à revisão.

## 2. Arquivos que podem mudar (lista fechada)
Qualquer arquivo fora desta lista bloqueia (`AGENTS.md` §6, escopo estrito).

**Criar em `docs/produto/`** (tabela atual da spec §3; nomes pela regra da spec §2 item 4):
`README.md` · `agenda.md` · `agendamento.md` · `clientes.md` · `formularios.md` · `catalogo.md` · `checkout.md` ·
`caixa.md` · `painel-admin.md` · `cadastro-de-estudio-e-assinatura.md` · `portal-publico-do-estudio.md` ·
`marketplace.md` · `api-publica.md` · `financeiro.md` · `estoque.md` · `mensagens.md` · `marketing.md` ·
`fidelidade.md` · `equipe.md` · `ajustes.md` · `importacao-e-exportacao.md` · `central-de-ajuda.md` ·
`assistente-de-ia.md` · `impulsionamento.md`

**Apagar:** `docs/produto/.gitkeep`

**Esta pasta de spec:** `specs/20261127-232350-produto-modulos/spec.md`, `plan.md`, `tasks.md` (aprovações e ajustes
pelas respostas do E21).

**Documentos de controle, só pelo Documentador:** `docs/BACKLOG.md` · `docs/STATUS.md` ·
`docs/decisoes/2026-11-27-fundacao.md` (registro das respostas do E21) · `CHANGELOG.md` (se o Documentador julgar que a entrega vale entrada).

## 3. Molde de cada arquivo de módulo
Os títulos são fixos, nesta ordem, sem seção a mais (spec §4 critério 3).

```markdown
# <Nome do módulo, como na spec §3>

## O que é
<até 2 frases, escritas do zero>

## Para quem
<um ou mais: dona, recepção, profissional, cliente do estúdio, dono da plataforma, público>

## Recursos
Lista candidata; o que entra na primeira versão se decide na spec do módulo.
- <um recurso por linha, só os da linha do módulo na spec §3>

## Quando entra
<núcleo ou depois, igual à coluna "Quando entra" da spec §3, com a fonte (E3·2, E4·3, `ARCHITECTURE.md` §2,
`docs/BACKLOG.md`)>

## Fonte
<igual à coluna "Fonte" da spec §3; arquivo do antigo citado só pelo nome, sem trecho>
```

**`README.md`:** `# Produto`, uma frase sobre o sistema (a ideia do `ARCHITECTURE.md` §1, com outras palavras),
`## Módulos` com três grupos (núcleo, outras partes da plataforma, os outros módulos), uma linha por módulo:
`- [Nome](arquivo.md): uma frase`.

## 4. Quem revisa
- **Escreve:** Engenheiro de software (etapa 8).
- **Revisor de texto e regras:** Documentador (norma Diátaxis), que não escreveu `docs/produto/`. Roda as
  conferências do §5 e anexa a saída ao PR.
- **QA:** veredito, com as conferências do §5 refeitas por ele.
- **Analista de requisitos:** confere o pedido item por item (etapa 10).

## 5. Como verificar
Rodar em `bash`, de `/home/user/crm-citas`. O projeto antigo só é lido, nunca alterado.

**5.1 Sem cópia (spec §4 critério 6).** Normaliza o texto (minúsculas, sem acento, sem pontuação), gera todas as
sequências de 8 palavras e mostra as que aparecem nos dois lados. **Passa se a saída final for `0`.**

```bash
A=/home/user/crm-agenda/docs/produto/legado/produto
R=/home/user/crm-agenda-reorg/docs/reorganizacao/02-mapa-de-modulos.md
ANT="$A/scope-master.md $A/future-modules-map.md $A/fidelidade-mapa-futuro.md $A/ecossistema.md $R"
shingles() { LC_ALL=C perl -CSD -MUnicode::Normalize -0777 -ne '$_=NFD(lc); s/\p{M}//g; s/[^\p{L}\p{N}]+/ /g; @w=split; print join(" ",@w[$_..$_+7]),"\n" for 0..$#w-7' "$@" | LC_ALL=C sort -u; }
LC_ALL=C comm -12 <(shingles docs/produto/*.md) <(shingles $ANT) | tee /dev/stderr | wc -l
```

Testado pelo Arquiteto em 27/11/2026: contra um arquivo vazio deu `0`; contra um arquivo com 3 linhas tiradas do
`02-mapa-de-modulos.md` mostrou as sequências iguais (o comando acha cópia). Os 5 arquivos do antigo deram 6919
sequências. Se aparecer sequência, quem escreveu reescreve a frase; nome de módulo ou de recurso sozinho não chega
a 8 palavras.

**5.2 Molde (critério 3).** Cada arquivo de módulo deve imprimir exatamente
`O que é|Para quem|Recursos|Quando entra|Fonte|`:

```bash
for f in docs/produto/*.md; do [ "$f" = docs/produto/README.md ] && continue; printf '%s: ' "$f"; grep '^## ' "$f" | sed 's/^## //' | tr '\n' '|'; echo; done
```

**5.3 Escopo (critério 8).** `git diff --name-status previas...HEAD` só pode listar arquivos do §2.

**5.4 Índice (critérios 1 e 2).** Cada arquivo de módulo tem uma linha com link no `README.md`, e nenhum link
aponta para arquivo que não existe: `grep -o '([a-z-]*\.md)' docs/produto/README.md`, comparado com
`ls docs/produto`.

**5.5 Texto (critério 7), leitura humana com ajuda de busca:**
`grep -niE 'dono (decidiu|aprovou)|decidido|aprovado' docs/produto/*.md` (cada achado precisa ter E-código de
`docs/decisoes/`), e nenhum nome de pessoa, cliente real, marca do antigo ou segredo.

Os critérios 4 e 5 (recursos e "Quando entra" iguais à tabela) o revisor confere lendo, linha por linha.

## 6. Decisão técnica
Não há decisão técnica nova; **não se cria ADR**. É texto em Markdown em pasta que já existe, sem código, banco,
ferramenta ou estrutura nova. O comando do §5.1 usa só `perl`, `sort` e `comm`, já instalados, e não entra no
repositório.
