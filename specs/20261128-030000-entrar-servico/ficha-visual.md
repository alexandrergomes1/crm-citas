# Ficha visual · Entrar e Escolher estúdio (E41)

- **Spec:** `spec.md` (RF-30 a RF-33) · **Plano:** `plan.md` §7 e L-4 · **Tarefa:** P3 do `tasks.md`
- **Escrito por:** Designer de produto · **Norma:** WCAG 2.2, Material Design, Apple HIG · **Fonte:** só o `DESIGN.md`
- **Conferência:** Revisor de design (P4), **pendente** — esta ficha ainda não vai ao dono antes disso.
- **Protótipo:** HTML estático fora do repositório, com o `tokens.css`, o `base.css` e o CSS das peças do item 4
  (`botao`, `campos`, `bloco-lista`, `conteudo`); fonte Geist; ícones Lucide. Capturas com Playwright (Chromium),
  escala 2×. Dados fictícios: `pessoa@exemplo.com`, "Estúdio Aurora", "Estúdio Lírio".

---

**E41 · Telas Entrar e Escolher estúdio** (fala o Designer de produto · norma WCAG 2.2; conferência do Revisor de
design pendente)

**Antes:** as duas telas não existem (são novas); não há imagem de antes.

**Depois:**

| Estado | Celular (390) | Computador (1440) |
|---|---|---|
| Entrar · vazio | ![](ficha/entrar-vazio-390.png) | ![](ficha/entrar-vazio-1440.png) |
| Entrar · erro genérico | ![](ficha/entrar-erro-390.png) | ![](ficha/entrar-erro-1440.png) |
| Entrar · carregando | ![](ficha/entrar-carregando-390.png) | ![](ficha/entrar-carregando-1440.png) |
| Escolher estúdio · 2 estúdios | ![](ficha/escolher-estudio-390.png) | ![](ficha/escolher-estudio-1440.png) |

**O que já segue o `DESIGN.md` sem decisão nova:** fundo `--page` e bloco branco canto 20 (§2: nenhum controle direto
sobre o fundo) · título 20 forte · campos em pílula, 44, rótulo acima em `--ink2`, contorno `--field` (§4, §8, §8b) ·
uma só ação preta, "Entrar" (§1, §5) · erro com ícone `circle-alert` e palavra em `--danger` (§8) · desativado a 60 %
(§8) · linha de lista 64 com o quadrado da inicial do estúdio (canto 10, `--brand`) e › (§3, §4) · contador no
subtítulo com número e palavra, "2 estúdios" (§5) · anel de foco do item 4 · toque 44/40 (§9).

### E41·1 · Nomes novos (entram no `DESIGN.md` §6)
Botão **Entrar** · rótulos **E-mail** e **Senha** · título **Escolher estúdio** · botão **Sair** · estado
**Entrando…** · nome do ícone de olho **Mostrar senha** / **Esconder senha** (leitor de tela) · frase de erro
**"Não foi possível entrar. Confira o e-mail e a senha e tente de novo."**
- **E41·1·A:** aceitar todos como estão → entram no §6 e nos arquivos de idioma (pt; es e en traduzidos).
- **E41·1·B:** aceitar e trocar algum → diga qual e o novo texto.
- **Recomendo A.** "Sair" já está no §8b (menu Sua conta) e o §6 só o barra como sinônimo de Fechar/Cancelar; aqui é
  encerrar a sessão, que é outro sentido. A frase não diz qual parte falhou (spec RF-02, ASVS V2.2).

### E41·2 · Mostrar e esconder a senha (peça e ícones novos)
- **E41·2·A:** botão de ícone sem fundo dentro do campo, à direita: `eye` (mostrar) e `eye-off` (esconder), com nome
  no leitor; os dois ícones entram no mapa de ícones do §5.
- **E41·2·B:** botão de texto "Mostrar" / "Esconder" dentro do campo.
- **Recomendo A:** segue a regra de botão de ícone (§5: sem fundo, com nome) e ocupa menos espaço no celular; o olho
  é padrão reconhecido (Material Design, Apple HIG). Atende RF-32 e WCAG 2.2 3.3.8 (colar a senha continua permitido).

### E41·3 · Onde fica o erro e como fica o carregando
- **E41·3·A (o das imagens):** erro numa linha só, acima de "Entrar", com ícone e texto vermelhos, anunciado ao leitor
  (`role="alert"`); os campos **não** ficam com contorno vermelho; o e-mail fica, a senha é limpa. Carregando: o botão
  fica esmaecido com "Entrando…" (anunciado), os campos travam; sem linhas cinza.
- **E41·3·B:** contorno vermelho nos dois campos, com a frase embaixo da Senha; carregando com as linhas cinza do §8.
- **Recomendo A:** o §8 manda contorno vermelho para erro **de um campo**; aqui não se pode dizer qual falhou (RF-02),
  e marcar os dois engana. Linhas cinza substituiriam o formulário que a pessoa acabou de preencher; botão travado
  também evita envio em dobro.

### E41·4 · Molde das telas sem menu
- **E41·4·A (o das imagens):** um bloco branco só; no computador, 480 de largura (a medida do painel, §8b), centrado
  na tela; no celular, largura toda com margem 16, no alto. Sem nome do sistema nem logotipo (o `DESIGN.md` não tem).
  Escolher estúdio: a lista é a ação (sem botão preto); "Sair" claro no fim do bloco.
- **E41·4·B:** o mesmo, com o nome do sistema acima do bloco (texto a definir pelo dono; entra no `DESIGN.md`).
- **Recomendo A:** usa só medidas que já existem e não inventa marca. Entra no `DESIGN.md` como "tela sem menu".

**Desfaz-se assim:** mudar o texto ou a peça no `DESIGN.md` e no arquivo de idioma; as telas leem dali.
**Responda:** os códigos, por exemplo "E41·1·A E41·2·A E41·3·A E41·4·A". O "sim" vem junto da aprovação da spec
(`tasks.md` P4); com ele, o Designer grava os nomes e as peças no `DESIGN.md`.

---

## Não verificado
- **Conferência do Revisor de design (P4):** ainda não feita.
- **Fora destas capturas, mas pedido no P3:** Entrar com limite de tentativas, Escolher estúdio carregando e com erro
  ("Tentar de novo"), menu e folha Sua conta (com e sem Trocar de estúdio), estado da senha mostrada (`eye-off`) e a
  inicial da bolinha Sua conta (L-4). Ficam para a próxima rodada da ficha.
- **Acessibilidade:** axe (wcag2a, wcag2aa, wcag21aa, wcag22aa) deu 0 violações no protótipo, nas 8 capturas; não é o
  app real. Não conferi com leitor de tela de verdade nem foco por teclado. O texto "Entrando…" esmaecido (60 %) fica
  abaixo de 4,5:1; a WCAG isenta controle desativado, mas o Revisor deve olhar.
- **Textos em es e en:** não escritos aqui (são do arquivo de idioma, na construção).
- O protótipo não é código do app: o campo Senha com olho ainda não existe em `src/app/ui/campos.tsx` (plano §7: só
  depois da aprovação).
