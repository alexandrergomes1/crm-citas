# Guia · Telas

Como construir ou alterar qualquer tela do sistema. Vale para qualquer pessoa ou IA. O **como deve parecer** está em `DESIGN.md` (raiz); este guia diz **o caminho** até a tela pronta.

## 1. A ordem

1. **Passado do módulo.** Se ainda não existe `docs/decisoes/*-base-<módulo>.md`, a primeira parada é a ficha curta do módulo (sim ou não), uma vez por módulo (`AGENTS.md` §3; molde `docs/moldes/pergunta.md`, variante "ficha curta do módulo").
2. **Ficha visual para o dono** (seção 2). Ela é a parada 1 de toda tarefa de tela.
3. **Spec da tela aprovada** em `specs/NNN-nome/`, feita a partir da ficha respondida, com a linha "Aprovação do dono". Sem ela, nada se constrói: não se parte de registro antigo, de imagem solta ou de memória (`docs/guias/processo-sdd.md`).
4. **Construir** seguindo `DESIGN.md` (seção 3).
5. **Conferir** nas duas larguras e entregar (seção 4).

## 2. Ficha visual (para o dono decidir)

O dono decide olhando imagem, em linguagem de leigo. Quem faz a ficha pesquisa, desenha, recomenda com o porquê e espera.

**Antes de desenhar**
- Leia `DESIGN.md`, o arquivo do módulo em `docs/produto/modulos/`, a tela de hoje no código e o **inventário de recursos** da tela (`docs/produto/inventario/`). Sem inventário, crie-o antes, varrendo a prévia, a produção e o sistema antigo. Toda ação do inventário ganha um lugar (tela ou menu); nada some sem pergunta.
- Procure o que já foi respondido, só do assunto: seções "Clarifications" das specs e `docs/decisoes/`. O que já é linha de base aparece na ficha como fato (imagem de hoje), nunca como pergunta.
- Peça ou medida que `DESIGN.md` não tem é **lacuna**: entra na ficha da própria tela, todas juntas, com proposta que segue a lógica do que já foi escolhido. Medida que a fonte não diz é marcada "não está escrito"; nunca se inventa número.
- Use a imagem real que existe; só monte tela nova se não houver, com a mesma tela e os mesmos dados em todas as opções.

**Formato fixo de cada decisão** (um quadro por decisão, nesta ordem)
1. Código único: letras do assunto + número (ex.: `AG4`); cada opção com o código completo (`AG4·A`, `AG4·B`).
2. Pergunta: uma frase, exatamente o que se decide.
3. O que validar: 1 a 3 pontos, marcados na imagem com o mesmo número.
4. Hoje e o que já foi dito: a tela atual e versões anteriores do mesmo ponto, com data; coluna "Mercado" quando houver.
5. Opções A, B, C, todas com os mesmos quadros: computador e celular; fechado e aberto; selecionado e não selecionado; vazio, carregando e erro quando a decisão os toca.
6. O que muda na tela, em uma ou duas frases para leigo.
7. Recomendação: uma frase, com o porquê.
8. Sua escolha: em branco.

**Limites:** até 4 decisões por ficha; com mais de uma, um quadro-resumo numerado primeiro e o dono responde com os códigos ("sim" só vale com uma decisão). A **ficha de tela inteira** traz a tela completa nas duas larguras (a mesma tela nas duas), cada menu aberto ao menos uma vez, um quadro com todas as lacunas e até 4 decisões.

**Apresentação:** sempre imagem com tokens e componentes reais, nunca caixa cinza nem decisão só em texto; diferença sutil ampliada e lado a lado; legível no celular sem zoom; cada mensagem se entende sozinha. A ficha visual são imagens de antes e depois, nas duas larguras. No Claude Code, é feita no canvas Design do claude.ai (o link do projeto, quando houver, fica em `docs/reference/artefatos.md`); fora dele, imagens PNG na pasta da spec (`specs/NNN-nome/`).

**Antes de entregar:** um revisor de design que não fez a ficha confere contradição com escolha do dono, clareza, completude, acessibilidade e lacuna aplicada sem escolha. A resposta do dono vai, com citação literal, data e link, para "Clarifications" da spec da tela.

## 3. Construir

- Só tokens e componentes do design system (`src/styles/globals.css`, `src/design-system/`). Componente que falta nasce no design system, com teste, nunca dentro da tela.
- Peça, cor, tamanho, espaçamento, ícone ou texto que nem `DESIGN.md` nem a spec definem: pare e pergunte (vira lacuna na ficha). O texto da tela vem da spec.
- **Arquivo de tela com até 300 linhas; qualquer arquivo com até 500.** Passou, divida em partes com nome claro.
- Textos em português, **num lugar só do arquivo** (um objeto de textos no topo), nunca espalhados (`docs/guias/idiomas.md`).
- Dinheiro e data pelas funções únicas de formato do estúdio (fuso e moeda do estúdio).
- Navegação pelo adaptador (`src/lib/nav`), nunca import direto do roteador.
- Regra de negócio em `src/domain`, nunca no componente; banco só por `src/data` (`docs/guias/servidor.md`).
- Idas ao banco dentro do orçamento (`docs/guias/servidor.md`).
- Estados de toda tela: vazio, sem resultado, carregando, erro e sucesso (`DESIGN.md` §8).

**Onde o projeto contraria o método de mercado:** textos em português (regras de maiúscula e de data em inglês não valem); fonte, toque, contraste e larguras são os de `DESIGN.md`; só as duas larguras de conferência.

## 4. Conferir e entregar

- **Duas larguras** (`DESIGN.md` §11). A mesma tela nas duas, cada menu aberto ao menos uma vez, lado a lado com a imagem de referência da spec.
- **Capturas na CI:** tela nova entra na lista `TELAS` de `e2e/capturas-telas.spec.ts`; as capturas saem como artefato `capturas-telas` do PR (`docs/guias/testes.md`).
- **Revisão da tela renderizada** por quem não construiu, em três listas: aparência (requisitos e inventário item a item, diferença da imagem com medida, só peças do design system, barra de baixo sem cobrir conteúdo, nada cortado, dinheiro e data no formato do estúdio); funcionamento (estados com texto e ação, ordem do foco, foco visível, Esc fecha a camada certa, console sem erro); desempenho. Sem evidência é "não verificado", nunca "ok". Divergência de aparência impede o merge.
- O checklist de `DESIGN.md` §10 é passado antes de o dono ver a tela; o inventário é atualizado se uma ação mudou de lugar.

## 5. Pare e pergunte

- A spec e a ficha aprovada se contradizem.
- Um requisito ou item do inventário não cabe na tela como está.
- Duas fontes da linha de base divergem num ponto que a tela muda.
- O dono respondeu algo que não casa com nenhuma opção: pergunte de novo só aquele ponto.

## Proibido

- Construir sem spec aprovada; aplicar uma lacuna antes da escolha do dono; reabrir o que está decidido sem ele pedir.
- Pedir "aceito todas" a uma lista, ou pergunta visual sem imagem de antes e depois.
- Criar estrutura de idioma sem spec própria.
- Usar o gerador antigo e a "Mesa" de `docs/design/decisoes/` (históricos).

## Origem

`.claude/skills/ui-standards/SKILL.md`, `.claude/skills/design-decision/SKILL.md`, `.claude/rules/ui-layout.md`, `.claude/agents/ui-qa.md`, `.claude/agents/design-critic.md`, `docs/moldes/pergunta.md` (variantes "ficha de tela" e "ficha curta do módulo"), `docs/projeto/estrutura.md` (tipo Tela; até 4 decisões por ficha), `docs/reference/project.md` (§Pastas, §Tela, "Como ver uma tela"). Inventário em `docs/produto/inventario/`: decisão T9 de `docs/reorganizacao/06-plano-etapa5.md`.
