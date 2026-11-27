# Módulo: Idiomas (IDI)

> O sistema entra em produção em português, espanhol e inglês. Isso vale para as telas, para o conteúdo do estúdio (serviços, termos da ficha) e para as mensagens à cliente.
> Hoje todo texto é português, concentrado num lugar do arquivo de cada tela, para facilitar a tradução depois. **Não existe estrutura de idiomas no código.**

**Telas e rotas:** futuro seletor em Ajustes › Minha conta; site público com prefixo `/en` e `/es` · **Código:** nenhum (não há biblioteca de idiomas instalada; busca por `paraglide` em `package.json` e `src` não achou nada) · **Spec(s):** sem spec no atual. Decisão: `docs/adr/2026-11-20-idiomas.md`. No legado: `docs/produto/legado/produto/i18n-multiidioma.md` (plano inteiro).

Como ler a coluna Origem: "plano §2:14" = `docs/produto/legado/produto/i18n-multiidioma.md`, seção 2, linha 14. "ADR:14-16" = `docs/adr/2026-11-20-idiomas.md` linhas 14 a 16.

## Recursos
| ID | Recurso | Estado | Onde | Origem |
|---|---|---|---|---|
| IDI-01 | Lançamento em português, espanhol e inglês (a tradução é item da lista da virada) | planejado | todo o app | ADR:14-20; `docs/runbooks/go-live.md:21`; `docs/STATUS.md:18`; R1 A "Idiomas 20/11" (`own:71`); R3 B falas:189-190 |
| IDI-02 | Desenvolver só em português agora, com os textos de cada tela num único lugar do arquivo | pronto como prática (regra de tela) | molde de spec de tela, seção 7 | ADR:19-20; `docs/specs/screens/_TEMPLATE.md:67`; R2 C C87, C103 |
| IDI-03 | Três camadas de idioma: interface (por usuária, `profiles.locale`, padrão `orgs.default_locale`), conteúdo do estúdio (tabelas `*_translations`), comunicação com a cliente (`clients.preferred_locale`) | planejado | banco; Ajustes | plano §1:6-11; R5 B i18n-multiidioma:3-19 |
| IDI-04 | Biblioteca de idiomas: next-intl (antigo, "validar com Next 16") × Paraglide (atual, "a decisão está na fila") | a definir | — | plano §2:14; `docs/reference/stack.md:12,18`; R2 B ICEBOX item 21 (`ICEBOX.md:28`); R5 D (i18n:14) |
| IDI-05 | Catálogo de textos por módulo (`pt-BR`, `en`, `es`); chaves de sentido, nunca a frase; plurais e variáveis ICU; chave que falta cai em português com aviso; teste falha se EN ou ES tiver menos chaves | planejado | `messages/{pt-BR,en,es}/<módulo>.json` | plano §2:14-19; R5 B i18n-multiidioma:13-19 |
| IDI-06 | Migração aos poucos: Ajustes e Marketing primeiro, depois Agenda, Clientes, Financeiro; lint proíbe texto solto no JSX nos módulos migrados | planejado | todo o app | plano §2:19; plano §7:46 |
| IDI-07 | Sem prefixo de idioma na URL do app interno; `/en` e `/es` só na reserva pública (SEO) | planejado | app; `/b/[slug]` | plano §2:17; legado 38:19-20,52-53 |
| IDI-08 | Datas, números e moeda pelo idioma da usuária; moeda e fuso vêm do estúdio (EUR, `Europe/Madrid`), não do idioma | planejado | formatação | plano §3:21-25 |
| IDI-09 | `src/domain` continua puro: devolve códigos; o texto final é montado na tela. Rótulos de status, pagamento e permissão saem de `src/domain/*-catalog.ts` para chaves | planejado | `src/domain` | plano §3:24-25 |
| IDI-10 | Conteúdo do estúdio traduzível: serviços, categorias, pacotes, termos da ficha; sem tradução, usa o texto base; painel "traduzir" com sugestão revisável | planejado | Catálogo; Anamnese | plano §4:27-30 |
| IDI-11 | Idioma da mensagem à cliente: `clients.preferred_locale`, depois idioma do primeiro contato, depois padrão do estúdio | planejado | Mensagens | plano §1:11, §5:34 |
| IDI-12 | Modelos de WhatsApp e e-mail por idioma (`message_templates` com idioma); WhatsApp exige modelo aprovado pela Meta em cada idioma | planejado | Mensagens › Modelos | plano §5:33; ver MSG-20 |
| IDI-13 | Idioma por procedimento, com o da cliente como reserva (G8) | planejado | Catálogo; Agendamento | R1 A G8 (`reg:124`); R3 B fase1:120 |
| IDI-14 | Telefone começa no Brasil, depois Portugal e Espanha (G8). Conflito com o DDI padrão +34 (client-01) e +55 (spec 52) | planejado, conflito | Clientes; reserva online | R3 B fase1:120; R4 B client-01, 52; `docs/produto/legado/specs/52-guia-de-agendamento.md:308-311` |
| IDI-15 | Idioma da ficha de saúde controla textos, rótulos, perguntas, respostas, botões, recibo e consentimentos; ficha em espanhol usa "Sí/No"; escolhe-se o modelo e o idioma ao criar; idioma da cliente só sugere; padrão espanhol; não usar o idioma do navegador | planejado | Anamnese | R5 B agenda-operational-scope:236-257 |
| IDI-16 | Termos legais por país e idioma, versionados; consentimento de imagem separado (ANAMNESE-LEGAL-01) | planejado | Anamnese | legado 27:176-186; R4 B 27 |
| IDI-17 | Anamnese: estratégia de idioma por modelo (por idioma e país), não tradução automática ao vivo | decidido sem prova | Anamnese | R5 A system-audit-2026-06-19:83 |
| IDI-18 | Página "ficha não encontrada" sempre em espanhol e com "KA Beauty" | parcial | `/forms/$token` | R3 B audit:31 |
| IDI-19 | Rótulos no feminino por padrão ("Nova cliente", "Nova profissional", "a cliente"); falta guia de gênero para o idioma | parcial | todo o app | R5 B v26-auditoria-fluxos:32-33,49 |
| IDI-20 | Bandeira do idioma da cliente no cartão do agendamento | pedido, sem estado | Agendamento | R3 B falas:118 |
| IDI-21 | Ordem de entrega: 1) campo de idioma em perfil, estúdio e cliente + seletor em Minha conta; 2) extrair textos; 3) traduzir conteúdo e reserva pública; 4) modelos de mensagem por idioma; 5) EN e ES completos com revisão nativa | planejado | — | plano §7:44-49 |
| IDI-22 | Idiomas "adiados": entram na fila "depois" | planejado | — | R3 B audit:46 |

"Estado" é o que os documentos dizem; o código é conferido quando o módulo entra em trabalho.

## Decisões
| ID | Decisão | Situação | Origem |
|---|---|---|---|
| IDI-D01 (ADR 20/11) | Desenvolver só em português agora (opção A); lançamento em português, espanhol e inglês; telas com os textos num lugar só | **a confirmar** (antes: vale) (pergunta A ou B, resposta literal do dono: "Sistema tem de entrar em produção em Portugues, espanhol e ingles No entanto, não devemos travar isso na fase de desenvolvimento para evitar desfoco do que importa. e como disse que ja ta sendo construido de forma que facilita traduzir depois, vá pela A.", 20/11/2026) | ADR:7-20; R2 A idiomas; R3 A falas:189 |
| IDI-D02 | "Idiomas NÃO bloqueia a camada 10": construir Agenda e Agendamento em português, com o texto de cada tela num lugar do arquivo | **a confirmar** (antes: vale) (pedido dele com as próprias palavras, texto colado por ele em 19/11/2026, 20h36; coberta também pela IDI-D01) | R3 B falas:190 |
| IDI-D03 (G8) | Idioma por procedimento com o da cliente como reserva; telefone começa no Brasil, depois Portugal e Espanha | **sugestão a confirmar** (lote "aceito todas", 22/11; 05/11 sem frase) | R1 A G8 (`reg:124`); `docs/decisoes/historico/registro-ate-2026-11-24.md:124` |
| IDI-D04 | Idioma da ficha controla tudo; padrão espanhol; não usar idioma do navegador | **sugestão a confirmar** | R5 A agenda-operational-scope:236-257 |
| IDI-D05 | Idioma em três camadas; sem prefixo de idioma no app interno; `/en` e `/es` só na reserva pública; português como idioma padrão e reserva | **sugestão a confirmar** (plano antigo, sem prova) | plano §1-2:6-19; R5 A i18n-multiidioma:3-19 |
| IDI-D06 | Proibido criar estrutura de idioma sem spec (regra da skill de tela, derivada da IDI-D01) | **sugestão a confirmar** | R2 C C87, C103; `docs/reference/stack.md:12,18` |
| IDI-D07 | Textos jurídicos (ficha, RGPD) não são traduzidos automaticamente; revisão nativa antes de ativar para clientes | **sugestão a confirmar** (plano antigo) | plano §8:51-53; plano §7:49 |

## Regras de negócio
- Texto final de tela fica concentrado num lugar do arquivo da tela (molde de spec de tela, seção 7); nada de texto espalhado. Origem: ADR:19-20; `docs/specs/screens/_TEMPLATE.md:67`.
- Sem estrutura de idiomas (biblioteca, pasta, tabelas de tradução) antes de existir spec aprovada. Origem: R2 C C87.
- A moeda e o fuso vêm do estúdio, não do idioma. Origem: plano §3:22.
- Idioma de interface, de conteúdo e de comunicação com a cliente são três coisas diferentes. Origem: plano §1:6-11.
- Chave de texto ausente cai em português e registra aviso; teste falha se EN ou ES tiverem menos chaves que PT. Origem: plano §2:18.
- WhatsApp só envia modelo aprovado pela Meta no idioma certo. Origem: plano §5:33.
- Termos legais da ficha: tradução revisada, e a versão aceita fica gravada com o idioma. Origem: plano §4:30; §8:52.
- Textos em EN e ES são 15 a 30 % maiores que em português: a verificação de layout em 390 px roda também nesses idiomas. Origem: plano §8:53.
- A ordem de entrega só começa quando o dono mandar; a tradução é item da virada. Origem: ADR:19-20; `docs/runbooks/go-live.md:21`.

## Pendências e perguntas
| Pergunta ou pendência | Origem |
|---|---|
| Biblioteca: Paraglide (stack atual) ou next-intl (plano antigo)? Onde moram os textos, moeda, data e fuso? | `docs/reference/stack.md:12,18`; R2 B ICEBOX item 21; R5 D (i18n:14) |
| O ICEBOX item 21 ainda pergunta "(A) só português ou (B) português, espanhol e inglês", que o ADR de 20/11 já respondeu. Atualizar o item | R2 F-14; ADR:14-16 |
| Gatilho para reabrir: o dono pedir a tradução antes da virada, ou a virada ser marcada. A virada não tem data | ADR:22-23; `docs/reorganizacao/03-decisoes.md` (R5: "nao ha data definida do go live", 23/11/2026) |
| Qual é o DDI padrão do telefone: +55, +34 ou outro? | R3 B fase1:120; R4 B client-01, 52 |
| "Ficha não encontrada" em espanhol com "KA Beauty" | R3 B audit:31 |
| Guia global de gênero dos rótulos (feminino por padrão) em es e en | R5 B v26-auditoria-fluxos:32-33,49 |
| Termos legais ES/UE, PT/UE e BR: textos e revisão jurídica | R5 D (privacy-consent-risk-register:303-312); legado 27:176-186 |
| Idioma da cliente (bandeira no cartão) e idioma preferido: onde se grava hoje? | R3 B falas:118; R4 D 54 (`legado 54:19-31`) |

## Referências
- ADR: `docs/adr/2026-11-20-idiomas.md`. Plano antigo inteiro: `docs/produto/legado/produto/i18n-multiidioma.md`.
- Specs do legado: `28-navegacao-marketing-ajustes.md` (fora desta spec: idiomas, linha 16), `38-site-de-agendamento-do-estudio.md`, `27-anamnese-legal-language-audit-roadmap.md`, `client-01-international-identity.md`, `52-guia-de-agendamento.md`.
- Corte do projeto: `docs/STATUS.md:18`, `docs/runbooks/go-live.md:21`, `docs/reference/stack.md:12,18`, `docs/ICEBOX.md:28`.
- Módulos vizinhos: MSG (modelos por idioma), RES (site em três idiomas), Anamnese (termos legais), Catálogo (conteúdo traduzido).

Regra: só vale decisão registrada em `docs/decisoes/` (molde de pergunta). Tudo desta tabela é **a confirmar**; a situação antiga fica entre parênteses só como histórico e volta a ser perguntada quando o módulo for trabalhado (resposta 15a do dono, 24/11/2026).
