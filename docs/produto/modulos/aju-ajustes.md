# Módulo: Ajustes (AJU)

> Onde a dona configura o estúdio: dados e horário, etapas do atendimento, formas de receber, aparência do sistema e preferências de cada pessoa.
> Equipe, Acessos e Perfis moram aqui na tela, mas o conteúdo está em `eqp-equipe-acessos.md`.

**Telas e rotas:** `/{org}/configuracoes` (existe: `src/routes/$orgSlug/configuracoes/index.tsx`) com as seções Estúdio, Horário, Atendimento, Profissionais, Acessos, Perfis, Plano, Pagamentos, Dados, Aparência, Preferências, Ficha de saúde e Privacidade (lista em `src/workspace/ajustes/sections.ts`) · **Código:** `src/workspace/ajustes/` · **Spec(s):** sem spec no crm-agenda. Antigo: `docs/produto/legado/specs/33-studio-settings-receipt.md`, `31-user-preferences.md`, `46-padrao-fresha-aprovado.md` (G9, aparência) e `54-novo-agendamento-pendencias.md` (P4, Atendimento).

## Recursos
| ID | Recurso | Estado | Onde | Origem |
|---|---|---|---|---|
| AJU-01 | Estúdio: nome comercial, razão social, NIF/CIF/NIE, endereço, código postal, cidade, telefone, e-mail (aparecem no comprovante) | pronto (antigo) · pronto (atual) | Ajustes › Estúdio | legado spec 33:15-26,43-48; R2 B history:41; R3 B audit:30 |
| AJU-02 | Região e moeda corretas (Espanha, Portugal, Reino Unido, Brasil); o fuso atual do estúdio sempre aparece e salvar nunca o troca sozinho (corrige `Europe/Madrid` virando São Paulo) | pronto (antigo) · não declarado (atual) | Ajustes › Estúdio | legado spec 33:19-21,45; R5 B core-delivery-control:129-134 |
| AJU-03 | Políticas em texto: sinal e cancelamento (para a equipe e, depois, para links públicos e reserva online) | pronto (antigo) · não declarado (atual) | Ajustes › Estúdio | legado spec 33:22-23 |
| AJU-04 | Comprovante interno ao concluir a comanda: dados do estúdio, número (referência da venda), rodapé editável e "Documento interno, sem valor fiscal" | pronto (antigo) · a tela "Recibo" não existe e "precisa de spec" (atual) | checkout | legado spec 33:24-26,46-47; R2 B ICEBOX:24; R1 D (reg:176) |
| AJU-05 | Horário de funcionamento do estúdio (hoje não é estruturado o bastante para avisos, como o de fechar o caixa) | pronto (atual) · planejado estruturar (antigo) | Ajustes › Horário | R2 B history:41; legado spec 32:69-71 |
| AJU-06 | Campos de horário de Ajustes e do Caixa com o seletor de 15 minutos | planejado (antigo) · não declarado (atual) | Horário e Caixa | R4 D (spec 48:3-5,27-28) |
| AJU-07 | Atendimento: etapas Confirmado e Iniciado ligáveis, nomes (até 20 letras) e descrição (até 120) escritos pela empresa, "Separar chegada e início", "Exigir ficha assinada ao iniciar", "Exigir uma etapa antes do checkout", gorjeta (Desligada, No menu ⋮, Passo próprio) | pronto (antigo, P4) · planejado "configurador" (atual, M7·A) | Ajustes › Atendimento | legado spec 54:138-153; R4 B 54; R3 B falas:87,96,130,187; R3 D fechar:193-199 |
| AJU-08 | Opções de cancelamento configuráveis pelo estúdio | planejado (atual, pedido de 08/11) · parcial (antigo, política em texto) | Ajustes › Atendimento | R3 B falas:187; R5 B roadmap:201 |
| AJU-09 | Ajustes › Financeiro: desconto e gorjeta ligam separados; cada um "No menu ⋮" ou "Etapa própria"; desconto com "Motivo obrigatório" e lista de motivos; gorjeta "vai para a profissional" | planejado "não aplicado" (atual) · gorjeta já tem opção em Atendimento (antigo P4) | Ajustes › Financeiro (seção ainda não existe no código) | R1 A CARD-06-AJ (reg:272; rv:88); R1 B rv:88 |
| AJU-10 | Pagamentos: contas de recebimento (Bizum, SEPA, Pix), texto de orientação, validade padrão do link, comprovante obrigatório; configurador de métodos de pagamento por clínica | pronto (antigo) · pronto (atual) | Ajustes › Pagamentos | legado spec 30:75-78; R5 B scope-master:141; R2 B history:41; R4 B 30 |
| AJU-11 | Plano: plano, situação (teste, ativo, suspenso), total por mês, limites, módulos ativos e extras com preço; "Plano ainda não configurado" sem o banco novo | base pronta (antigo) · botões desligados, planejado (atual); dono do assunto é `saas-planos` | Ajustes › Plano | legado spec 29:111-115; R3 B audit:30; R2 B ICEBOX:29 |
| AJU-12 | Dados (importar e exportar) | pronto o CSV de clientes (antigo) · só tela, botões desligados (atual) | Ajustes › Dados | R4 B client-02; R2 B ICEBOX:30; plano de recuperação 22/11 §2 |
| AJU-13 | Ficha de saúde: travas configuráveis (validade do link, avaliação no fechamento) | em andamento (antigo) · pronto "ficha" (atual); dono do assunto é `anamnese` | Ajustes › Ficha de saúde | R5 B painel-da-jornada; R2 B history:41; R3 B audit:30 |
| AJU-14 | Aparência: formato Reto, Misto (padrão) ou Pílula; 4 tamanhos (Ultra 75%, Compacto 85% padrão, Normal 100%, Grande 110%); tema; botões só ícone ou ícone e texto; guardada por aparelho | parcial, claro/escuro pendente (antigo) · pronto (atual) | Ajustes › Aparência | R1 B rv:25,39; R3 B padrao:28; legado spec 46:18-24,126 |
| AJU-15 | Temas Barbearia e Essencial | "Proposta, sem uso" (atual) · 3 temas prontos (antigo) | Ajustes › Aparência | R2 B STATUS:41; R5 B v25-mockups/Temas.dc.html; R1 B |
| AJU-16 | Preferências da pessoa (por estúdio e por aparelho): tela inicial, visão padrão da agenda, 4 atalhos da barra do celular | pronto (antigo) · seção existe no código, não declarada (atual) | Ajustes › Preferências | legado spec 31:11-41; `src/workspace/ajustes/PreferencesSection.tsx` |
| AJU-17 | Minha conta: trocar a senha | pronto (atual) | Ajustes › Preferências / `/trocar-senha` | R2 B history:41; R3 B audit:30 |
| AJU-18 | Privacidade: seção existe no código e não aparece no menu | parcial (atual) | Ajustes › Privacidade | R3 B audit:30; `src/workspace/ajustes/sections.ts` |
| AJU-19 | Ajustes só grava ao tocar em Salvar (rascunho, barra de salvar, "Descartar alterações?") | decidido sem prova (antigo) · não declarado (atual) | todas as seções | R4 A 46 G9 (spec 46:27-32) |
| AJU-20 | Equipe, Acessos e Perfis e liberações como seções de Ajustes; a lista de seções mostra só o que a pessoa pode abrir | pronto (antigo) · pronto (atual) | Ajustes | legado spec 28-nav regra 2; R4 B 28-nav; `sections.ts` |
| AJU-21 | Menu de seções de Ajustes com ícone à esquerda e › no fim, sempre | decidido sem prova (atual; CMP-A2) | Ajustes | R1 A CMP-A2 (reg:250) |
| AJU-22 | Desenho e spec das telas "Ajustes do estúdio" e "Recibo" | falta desenhar (atual) | — | R1 D (reg:176); R2 B ICEBOX:24; ROADMAP:12 |
| AJU-23 | Prints do Fresha de Configurações do negócio (23) | referência, sem legenda | — | R3 B fr/06-configuracoes/README.md:11-33 |
| AJU-24 | Atalhos fixos no "Mais", perfil e preferências do usuário | planejado (antigo, fase multiusuário) | Mais | legado spec 29:96-100 |

## Decisões
| ID | Decisão | Situação | Origem |
|---|---|---|---|
| AJU-D01 | Seletor de forma em Ajustes › Aparência: Reto, Misto e Pílula; Misto é o padrão. Resposta dele em 17/11: "formato anterior tava melhor, pode fechar" (CAM2-01; confirmada em CMP-C1) | **a confirmar** (antes: vale) (resposta dele, 17/11/2026; pergunta de 17/11 não guardada no repositório) | R1 A CAM2-01 (reg:206) |
| AJU-D02 | Quatro níveis de tamanho: Ultra 75, Compacto 85 (padrão), Normal 100, Grande 110; sem "Extra grande" (CAM4-01) | **sugestão a confirmar** (sem frase; 17 e 18/11) | R1 A CAM4-01 (reg:214) |
| AJU-D03 | Densidade padrão: A "Compacto com o respiro do shadcn" × C "um nível só, sem escolha em Ajustes"; é pergunta aberta (P2) | **sugestão a confirmar** (aberta) | R3 D fechar:18-25 |
| AJU-D04 | Ajustes › Financeiro: desconto e gorjeta separados; "No menu ⋮" ou "Etapa própria"; motivo obrigatório no desconto (CARD-06-AJ, 19/11). O pedido dele de 07/11: "nao deve ter uma etapa de gorjeta fixa. isso deve ser inserido no configurador como opcional" | Gorjeta opcional no configurador, sem etapa fixa: **a confirmar** (antes: vale) (pedido dele de 07/11/2026, 20h00, frase ao lado) · desconto e gorjeta separados, "No menu ⋮" ou "Etapa própria", motivo obrigatório (CARD-06-AJ): **sugestão a confirmar** (aceite em lote "Minhas escolhas de 19/11 valem") | R1 A CARD-06-AJ (reg:272); R3 B falas:130 |
| AJU-D05 | Etapas do atendimento devem ser configuráveis pela empresa, não regra fixa. Pedido dele em 06/11, 23:37: "Essas etapas de confirmado, cliente chegou, iniciar atendimento devem ser configuráveis de fluxo de empresas e não regra padrão." Sobre a descrição de cada etapa (07/11): "a descrição do que significa o usuario quem deve preencher no configurador." | **a confirmar** (antes: vale) (pedido dele com as próprias palavras, 06/11/2026, 23h37, e 07/11/2026, 17h37; a spec 54 P4 diz "aprovado 07/11" sem frase) | R3 B falas:87,96; legado spec 54:138-153; R4 A 54 P4 |
| AJU-D06 | Opções de cancelamento são do configurador do sistema: "essas opções de cancelamento devem ser configuradas no configurador do sistema. mas ficou ok ai a estrutura." (08/11, 16:46) | **a confirmar** (antes: vale) (pedido dele com as próprias palavras, 08/11/2026, 16h46) | R3 B falas:187 |
| AJU-D07 | Sem bloqueio fiscal em nenhum ponto; o comprovante é interno, sem valor fiscal ("decisão de 28 out") | **sugestão a confirmar** (sem frase) | legado spec 33:24-26 |
| AJU-D08 | Só proprietária e administração salvam os Ajustes; o NIF não valida o dígito (só orienta); textos com limite (rodapé 300, políticas 1000) | **sugestão a confirmar** (sem prova) | legado spec 33:36-41 |
| AJU-D09 | Tudo em `organizations.settings` (jsonb), mesclado sem apagar outras chaves, sem migration nova | **sugestão a confirmar** (sem prova) | legado spec 33:28-34 |
| AJU-D10 | Preferência é por pessoa e por estúdio; celular e computador separados; o aparelho vem do navegador; `?view=` na URL sempre vence; valor inválido volta ao padrão. Pedido do responsável (28/10): "customizar o perfil com itens fixos e visão padrão, seja no celular ou em outra visão" | Perfil com itens fixos e visão padrão por aparelho: **a confirmar** (antes: vale) (pedido dele de 28/10/2026, frase citada na spec 31 do antigo) · regras técnicas (`?view=`, valor inválido, por pessoa e estúdio): **sugestão a confirmar** | legado spec 31:3-7,17-30; R4 A 31 |
| AJU-D11 | Ajustes só grava ao salvar (rascunho + barra de salvar) (G9) | **sugestão a confirmar** (sem prova) | R4 A 46 G9 (spec 46:27-32) |
| AJU-D12 | Menu de seções (Ajustes, Perfil, Editar cliente): ícone à esquerda e › no fim, sempre, no computador e no celular (CMP-A2, 19/11) | **sugestão a confirmar** (sem frase; contraria a recomendação do comparativo) | R1 A CMP-A2 (reg:250); R1 F-4 |
| AJU-D13 | Equipe, Acessos e Perfis moram em Ajustes; a lista mostra só o que a pessoa pode abrir | **sugestão a confirmar** (sem prova) | legado spec 28-nav regra 2 |
| AJU-D14 | Link de pagamento: a cliente só envia comprovante se estiver ligado em Ajustes › Pagamentos (L-1111-06) | **sugestão a confirmar** (sem prova) | R1 A L-1111-06; ver `cob-cobrancas.md` |
| AJU-D15 | Aparência por aparelho (localStorage): tema, forma, tamanho, claro/escuro, botões | **sugestão a confirmar** (sem prova) | legado spec 46:18-24 |

## Regras de negócio
- Salvar Ajustes nunca troca o fuso, a moeda nem outra chave que a pessoa não mexeu.
- Só proprietária e administração alteram os Ajustes do estúdio; cada pessoa só altera as próprias preferências.
- Uma pessoa não lê nem grava preferência de outra, nem a proprietária.
- Seção "em breve" ou sem permissão não aparece na lista.
- Preferência inválida volta ao padrão; sem a tabela nova, tudo funciona com os padrões.
- O comprovante interno nunca pretende ser documento fiscal.
- Nome e descrição das etapas do atendimento são escritos pela empresa, com limite de tamanho.

## Pendências e perguntas
| Pergunta ou pendência | Origem |
|---|---|
| Gorjeta aparece em dois lugares: opção em Atendimento (já feita) e em Ajustes › Financeiro (desenhada, não aplicada). Qual é a casa dela? | legado spec 54:138-153; R1 A CARD-06-AJ |
| Recibo próprio (tela) e cupom/recibo (P1 do antigo) não têm item na fila nem spec | R2 B ICEBOX:24; R5 B revisao-30-10:30 |
| Plano: botões desligados e "precisa decidir planos e cobrança"; nome do produto aberto | R3 B audit:30; R2 B ICEBOX:29 |
| Dados (importar/exportar) é só tela; Importação da Fresha (spec 34) não existe no crm-agenda | R2 B ICEBOX:30; R4 B README |
| "Privacidade" existe no código e não aparece; contas de privacidade ainda sem decisão | R3 B audit:30 |
| Aparência: claro/escuro pendente; Reto ainda com botão em pílula (CAM2-02); Barbearia e Essencial sem uso | R4 B 46; R1 A CAM2-02; R2 B STATUS:41 |
| Densidade padrão e respiro (P2): A ou C? | R3 D fechar:18-25 |
| Ajustes regravava `organizations.settings` inteiro no antigo (dívida); no atual há migration `ajustes_writes` | R5 F revisao-profunda:62-63; `supabase/migrations/20261114060100_ajustes_writes.sql` |
| Etapas configuráveis (M7): manter "Chegou"? nome e descrição por empresa | R3 D fechar:193-199 |
| O teste de ponta a ponta de Ajustes (`ajustes-gravacao.spec.ts`) tem uma cópia própria da função de login | docs/BACKLOG.md item 14 |
| Auditoria de módulos "seção 10, itens 3 e 5" (go-live) citada na spec 33 do antigo e não encontrada | legado spec 33:5-6 (R4 D) |

## Referências
- Legado: `docs/produto/legado/specs/33-studio-settings-receipt.md`, `31-user-preferences.md`, `46-padrao-fresha-aprovado.md`, `54-novo-agendamento-pendencias.md`, `28-navegacao-marketing-ajustes.md`, `29-access-roles-modules.md` (Plano).
- Atual: `docs/decisoes/historico/registro-ate-2026-11-24.md` (CAM2-01, CAM4-01, CARD-06-AJ, CMP-A2); `docs/design/design-system/regras-vigentes.md:25,39,88`; `docs/specs/plans/2026-11-23-fechar-design-system.md` (P2); `docs/specs/plans/2026-11-23-falas-do-dono-por-tema.md`; `docs/fresha-prints-referencia/06-configuracoes/`.
- Banco: `supabase/migrations/20261114060100_ajustes_writes.sql`; legado: migration `20261108000000_attendance_settings.sql`.

Regra: só vale decisão registrada em `docs/decisoes/` (molde de pergunta). Tudo desta tabela é **a confirmar**; a situação antiga fica entre parênteses só como histórico e volta a ser perguntada quando o módulo for trabalhado (resposta 15a do dono, 24/11/2026).
