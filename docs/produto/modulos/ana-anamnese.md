# Módulo: Anamnese (ANA)

> A ficha de saúde da cliente: modelos, link para preencher, assinatura, parte da profissional, fotos e correção.
> **É dado de saúde (RGPD, art. 9).** As regras de privacidade estão em "Regras de negócio", primeira parte.

**Telas e rotas:** `/{org}/anamnese` (visão geral) · `/{org}/anamnese/fichas` e `/fichas/{id}` · `/{org}/anamnese/modelos` e `/modelos/{id}` · `/{org}/anamnese/termos` · `/{org}/anamnese-tablet` (Modo estúdio) · `/forms/{token}` (página pública da cliente) e `/forms/{token}/calendar` (arquivo `.ics`) · Ajustes › Ficha de saúde (`/{org}/configuracoes`) · **Código:** `src/workspace/anamnese`, `src/routes/forms.$token.*`, `src/routes/$orgSlug_.anamnese-tablet.tsx` · **Spec(s):** `docs/specs/ficha-correcao.md` (só a correção). No legado: `docs/produto/legado/specs/12-anamnese-forms-gdpr.md` e `27-anamnese-legal-language-audit-roadmap.md`.

Siglas da coluna Origem: `R1` a `R5` = relatórios em `docs/reorganizacao/levantamento/` (letra = seção, depois fonte). `reg:N` = linha N de `docs/decisoes/historico/registro-ate-2026-11-24.md`. "antigo" = Beauty System; "atual" = crm-agenda.

## Recursos
| ID | Recurso | Estado | Onde | Origem |
|---|---|---|---|---|
| ANA-01 | Fichas, modelos, termos, link, assinatura e fotos | pronto (antigo) · pronto (atual) | `/anamnese`, `/fichas`, `/modelos`, `/termos` | R4 B spec 12; R5 B scope-master:100-108; R2 B STATUS:31; R3 B audit:27 |
| ANA-02 | Editor de modelo (builder) com blocos: cabeçalho, informativo, sim/não, texto curto ou longo, seleção única e múltipla, pergunta condicional com justificativa, termo, assinatura, checklist e notas privadas | parcial (antigo: hoje só `yes_no`, `text`, `multiple_choice`, `info`; faltam seções e múltipla seleção explícita) | `/modelos/{id}` | R4 B spec 12:15-25,88-99; R5 B scope-master:100-102, product-vision-detail:16,20-22 |
| ANA-03 | Uma anamnese por atendimento e modelo; parte da cliente e parte da profissional na mesma linha; modelo copiado (snapshot) para a ficha; criação sem repetir | pronto (antigo) | agendamento, `/fichas` | R4 B spec 12:27-44,74-75,93-94 |
| ANA-04 | Serviço pode sugerir ou exigir um modelo; 5 serviços atuais exigem ficha mas ainda sem modelo | pronto (vínculo) · pendência (5 serviços sem modelo) | Catálogo › serviço | R4 B spec 12:29,95-96; R5 B scope-master:66, product-vision-detail:15,20 |
| ANA-05 | Página pública da cliente por link: opaco, com validade, revogável; ficha assinada ou vencida não devolve respostas | parcial (antigo: limite de pedidos e retenção faltam; endurecer leitura de ficha assinada expirada) | `/forms/{token}` | R4 B spec 12:49-51,58,97-99,123-129; R5 B scope-master:103 |
| ANA-06 | Validade do link: 24 h, 3, 7, 15 ou 30 dias; padrão do estúdio (7 dias); "Reenviar link" renova ou encurta | pronto (antigo) | Ajustes › Ficha de saúde; "Enviar ficha" | R4 B spec 12:160-169,233 |
| ANA-07 | "Adicionar ao calendário": arquivo `.ics` gerado no servidor; 404 se o link venceu ou não há atendimento | pronto (antigo) | `/forms/{token}/calendar` | R4 B spec 12:172-173 |
| ANA-08 | Registro de envio e abertura (enviada, aberta, renovada; canais WhatsApp, QR, estúdio, cópia); abertura ignora robôs de pré-visualização; "Atividade recente" e "Andamento" | pronto (antigo) | visão geral, detalhe da ficha | R4 B spec 12:177-189,234 |
| ANA-09 | Assinatura conferida no servidor (termos, respostas obrigatórias, canal); erros em es, en e pt; dados pessoais (nome, nascimento, telefone, e-mail, maioridade) ainda não conferidos no banco | parcial (antigo) | `/forms/{token}` | R4 B spec 12:191-199,235 |
| ANA-10 | Guardar só o IP truncado (IPv4 sem o último número; IPv6 só a rede /48), mostrado como "IP (anonimizado)" | pronto (antigo) | ficha assinada | R4 A spec 12:201-205 |
| ANA-11 | Ficha assinada imutável (o banco impede alterar ou apagar), vista e impressa com o conteúdo escapado; recibo de consentimento | pronto (antigo) | `/fichas/{id}` | R4 B spec 12:60-69,103-106; R5 B scope-master:104-107 |
| ANA-12 | Corrigir ficha assinada, opção 1: "Reenviar para a cliente corrigir" (ficha nova, ligada à mesma cliente e atendimento, com respostas anteriores; a anterior vira "substituída"; a trava do checkout passa a usar a nova) | pronto (atual: STATUS e history) · planejado (atual: spec "aprovada em 14/11", sem prova) · retificação "faltam" (antigo) | `/fichas/{id}` (`correction-actions`) | R2 B history:43, STATUS:31; R3 B ficha-correcao:5-10; R4 B spec 12:66-69,97-99 |
| ANA-13 | Corrigir ficha assinada, opção 2: profissional "Corrige respostas" com motivo (até 500 caracteres); versão nova, original guardada ("Ver original assinada"), aviso "Editada pela profissional após a assinatura"; auditoria sem copiar respostas | pronto (atual: history:43) · planejado (spec) | `/fichas/{id}` | R2 B history:43; R3 B ficha-correcao:12-17 |
| ANA-14 | Regras da correção: respeita o alcance da profissional, no máximo 2 idas ao banco, testes SQL e E2E das duas opções | planejado (spec) | — | R3 B ficha-correcao:19-22 |
| ANA-15 | Parte da profissional: rascunho, conclusão explícita e reabertura (só gestão) auditados; nota fixa da cliente separada da nota do atendimento | pronto (antigo) | `/fichas/{id}` | R4 B spec 12:62-73,107,110-111 |
| ANA-16 | Ficha Profissional habilitada ao criar a ficha da cliente (opção da gestão); abas Ficha Cliente e Ficha Profissional; profissional acessa a sua sem rolar até o fim | planejado (antigo) | gestão de anamnese | R5 B agenda-operational-scope:196-234 |
| ANA-17 | Trava: sem assinatura da cliente, o atendimento não inicia; sem a ficha profissional obrigatória, a comanda não fecha | pronto (antigo, banco e app) · parcial | agendamento, `/checkout/{id}` | R4 B spec 12:76-79; R5 B scope-master:110 |
| ANA-18 | Liberar o fechamento sem a avaliação da profissional, com motivo de 5 a 300 caracteres, por quem tem `anamnese.override_checkout_gate` (padrão: dona, administração, gestão); assinatura pendente nunca se libera | planejado/parcial (antigo: critérios de teste `[ ]`) · "pronto no banco" (item 6 da revisão de 29/10) | checkout, Configurações › Perfis | R4 B spec 12:131-154; R5 A 89 |
| ANA-19 | Travas configuráveis em Ajustes › Ficha de saúde › Travas do atendimento ("exigir para iniciar", "exigir para cobrar") | em andamento · pronto no banco (antigo, PR #83, teste 143) | Ajustes › Ficha de saúde | R5 B painel-da-jornada:90 |
| ANA-20 | Modo estúdio (antes "Tablet"): opção ligável em Ajustes; PIN do estúdio de 4 a 6 números no servidor (5 erros bloqueiam 5 minutos); trava de uso, não de segurança forte | pronto (antigo: PIN `[x]`; E2E `[ ]`) · pronto (atual) | `/{org}/anamnese-tablet` | R4 B spec 12:216-238; R5 B v26-auditoria-fluxos:14-18; R1 B v26-auditoria-fluxos:14-21 |
| ANA-21 | Recepção vê só o status da ficha (sem respostas, assinatura nem dados da profissional) | pronto (antigo) · atual: menu mostra Anamnese a quem não pode | menu, agenda | R4 A spec 12:123-129, spec 29 §4c; R3 B audit:27 |
| ANA-22 | Leitura da ficha por papel no banco (SELECT por papel: hoje o app oculta, o banco ainda entrega a linha) | pendência (antigo) | banco | R4 A spec 12:129; R4 D |
| ANA-23 | Pendências da cliente e da profissional consultáveis na agenda, no cliente e na gestão | pronto (antigo) | agenda, perfil, `/anamnese` | R4 B spec 12:112-113 |
| ANA-24 | Trilha de auditoria de consentimento e de acesso (abrir ficha completa já grava `CLINICAL_READ`) | planejado (antigo, critério `[ ]`) · `CLINICAL_READ` pronto | banco | R4 B spec 12:114,127-128 |
| ANA-25 | Versão do modelo (sobe sozinha ao mudar) e país (padrão ES) gravados em cada ficha nova; ficha enviada nunca muda | pronto (antigo) | lista de Modelos ("v3 · Espanha"), detalhe da ficha | R4 B spec 12:207-214,236 |
| ANA-26 | Termos por país e idioma: Espanha agora; Portugal, Brasil e outros depois; um modelo por idioma e país (Opção A); tradução automática não substitui versão validada | planejado (antigo, backlog) | `/modelos`, `/termos` | R4 B spec 27:13-31,69-110; R5 B roadmap:128-132 |
| ANA-27 | Vários termos e consentimentos na ficha (geral, procedimento, dados, imagem separado, pré e pós, por procedimento), com aceite e versão | planejado (antigo) | `/forms/{token}` | R4 B spec 27:33-51 |
| ANA-28 | Consentimento de imagem separado (Sim/Não), nunca implícito; recusa não bloqueia o serviço; "Uso de imagem autorizado/não autorizado" na ficha | planejado (antigo) | ficha da cliente e da profissional | R5 B agenda-operational-scope:281-298; R5 A 7.1; R4 B spec 27:46-51 |
| ANA-29 | Consentimento por finalidade (10): administração do serviço, segurança clínica, notas da profissional, assinatura, imagem interna, imagem pública, WhatsApp operacional, marketing, Google Reviews, pagamento/sinal | planejado (antigo, "decidido sem prova") | ficha | R5 B legal/privacy-consent-risk-register:52-73 |
| ANA-30 | Termo em camadas: resumo curto visível e "Ver termo completo" (acordeão, janela ou folha); a cliente lê tudo antes de aceitar | planejado (antigo) | `/forms/{token}` | R4 B spec 27:53-67; R5 A (privacy-consent-risk-register:75-84) |
| ANA-31 | Ficha assinada visível para auditoria: nome, data e hora, versão, idioma e país, respostas, termos, assinatura, IP, atendimento | parcial (antigo: versão, país e IP entregues) | `/fichas/{id}` | R4 B spec 27:112-126 |
| ANA-32 | Cabeçalho da ficha como bloco fixo real, sem texto rolando por trás; separar respostas da cliente, avaliação profissional, sessões, fotos e pendências | planejado (antigo) | `/fichas/{id}` | R4 B spec 27:128-154; R5 B implementation-gap-map:107-119 |
| ANA-33 | Recibo completo da Ficha Cliente (dados, documento, respostas clínicas, consentimentos, imagem, assinatura, data, idioma, vínculo) | planejado (antigo) | impressão | R5 B agenda-operational-scope:259-279; R5 B roadmap:128-132 |
| ANA-34 | Nome na assinatura ligado à cliente; dados já conhecidos pré-preenchidos | planejado (antigo) | `/forms/{token}` | R5 B agenda-operational-scope:300-314 |
| ANA-35 | Dados da ficha não sobrescrevem o cadastro sem validação da profissional; apontar faltas e diferenças | planejado (antigo) | perfil | R5 A agenda-operational-scope:176-194; R4 A client-01:17 |
| ANA-36 | Editar ficha: pendente = livre; assinada = editar com motivo, retificar, nova versão ou arquivar; comanda finalizada = regra mais restrita | planejado (antigo, "a validar tecnicamente") | gestão | R5 B agenda-operational-scope:316-335 |
| ANA-37 | Menu lateral "Anamnese" vira "Formulários", com tipos dentro (Anamnese, outras fichas) | planejado (spec própria) | menu | R1 B reg:262; R3 B falas:180-181, fechar:333-339 |
| ANA-38 | Ícone de ficha com sinal verde (ok) ou amarelo (pendente) | planejado (pedido de 07/11; proposta C3·A) | agenda | R3 B falas:26, fechar:117-123 |
| ANA-39 | Controle da ficha no atendimento só aparece se o serviço exige ou há ficha vinculada; indicador discreto | planejado (antigo) · referência (opm) | agendamento | R5 B operational-ux-gap-map:85-107; R3 B opm:79-81,160 |
| ANA-40 | Enviar a ficha antes ou durante o atendimento; decidir se envia ao salvar ou só depois | planejado/em aberto | agendamento | R5 B product-vision-detail:17; R4 D spec 54:15 |
| ANA-41 | Idioma da ficha: espanhol por padrão quando o modelo não declara idioma; idioma preferido no cadastro da cliente | pronto (padrão) · planejado (idioma no cadastro) | cadastro, modelo | R4 B spec 12:83-84,97-99 |
| ANA-42 | Fotos da cliente: enviadas direto ao Storage por endereço assinado; cópia das fotos no backup | pronto (fotos) · planejado, precisa de spec (backup) | ficha, perfil | R5 C infra:134,216; R2 B ICEBOX:21 |
| ANA-43 | Faxina diária das fotos órfãs | planejado (bloqueada por decisão; vai com a virada) | rotina | R2 B ICEBOX:34, go-live:31 |
| ANA-44 | Política de retenção, direitos de acesso, apagamento e portabilidade, cifra da ficha | planejado (antigo e atual: "não coberto ainda") | banco | R4 B spec 12:97-99; R2 D database.md:51-53 |
| ANA-45 | Limite de pedidos em `/forms`; capturar IP e user-agent no servidor (não do formulário); registrar acesso e assinatura clínica em `audit_logs` | planejado (P1 de privacidade; limite precisa do OK do Alexandre) | `/forms/{token}` | spec 22:74-78 (legado/specs/22-operational-integrity-and-audit.md); R5 D revisao-profunda:149-152; spec 12:97-99 |
| ANA-46 | Testes ponta a ponta: criar, enviar, assinar, ver, nota; Modo estúdio com PIN (falta fixture) | planejado (antigo, `[ ]`) · E2E Agenda→Ficha→Comanda pronto | — | R4 B spec 12:116,238; R5 B roadmap:127 |
| ANA-47 | "Receber cópia por e-mail" | descartado até haver provedor de e-mail ("Guardar uma cópia" por impressão continua) | `/forms/{token}` | R4 A spec 12:174-175 |
| ANA-48 | Futuro configurador de termos (por país e procedimento, versionar, ligar consentimento de imagem, obrigatório ou opcional, idioma padrão) | planejado (antigo) | Ajustes | R4 B spec 27:156-165 |
| ANA-49 | Próxima frente `ANAMNESE-LEGAL-01`: termos versionados por país e idioma e consentimento de imagem separado | planejado (antigo; só depois do visual aprovado) | — | R4 B spec 27:176-186 |
| ANA-50 | Referências: Custom Forms e Consent Forms (Booksy), Consultation forms e teste de alergia obrigatório (Treatwell) | referência de mercado (sem decisão) | — | R3 B M/booksy:183-187, M/treatwell:151 |
| ANA-51 | Fora do escopo imediato: parecer jurídico final, tradução automática validada, anexo completo, motor multi-país, assinatura digital avançada, assinatura externa | adiado | — | R4 B spec 27:167-174 |

"Estado" é o que os documentos dizem; o código é conferido quando o módulo entra em trabalho. Conferido só para "Onde": as rotas `anamnese` (fichas, modelos, termos), `anamnese-tablet`, `forms.$token` e a pasta `src/workspace/anamnese` existem.

## Decisões
| ID | Decisão | Situação | Origem |
|---|---|---|---|
| ANA-D01 | Ficha assinada pode ser corrigida sem perder o original (reenviar à cliente ou profissional edita com motivo) | **sugestão a confirmar** (só "aprovada pelo Alexandre em 14/11/2026", sem frase) · regras-de-produto #1 | R2 A regras-de-produto #1; R3 A ficha-correcao:1-17 |
| ANA-D02 | Ficha de saúde segue as permissões e travas que já existem; sem camadas novas sem motivo concreto | **sugestão a confirmar** (14/11, sem frase) · regras-de-produto #2 | R2 A regras-de-produto #2 (history.md:67) |
| ANA-D03 | Link da ficha guardado só como hash; "Reenviar link" gera novo e invalida o anterior | **sugestão a confirmar** (sem prova) · regras-de-produto #7 | R2 A regras-de-produto #7 (server.md:40) |
| ANA-D04 | Na ficha do cliente, vale "Formulário" e não "Ficha"; menu "Formulários" com vários tipos fica para depois (spec própria). Frase achada: "Só o nome por enquanto" (19/11) | **a confirmar** (antes: vale) (resposta dele "Só o nome por enquanto", 19/11/2026, 10h43, à pergunta E2 escrita por inteiro: "o menu lateral 'Anamnese' passa a se chamar 'Formulários'… No agendamento fica 'Formulário pendente' e 'Abrir formulário'"; vale o nome nos textos; o menu "Formulários" com vários tipos fica para spec própria; o livro antigo com "Ficha Cliente" é anterior e não é fala dele) · CMP-E2 | R1 A CMP-E2 (reg:262); R3 A G11 (falas:181); R5 C PASSAGEM-2026-11-13:55 |
| ANA-D05 | Assinatura da cliente é trava dura para iniciar; para fechar a comanda, a avaliação da profissional pendente pode ser liberada com motivo escrito, por quem tem a liberação | **sugestão a confirmar** (29/10, "Decisão do Alexandre" sem frase) | R4 A spec 12:24, 131-148; R5 A 89 |
| ANA-D06 | Recepção vê só o status da ficha; notas e dados da profissional só owner, admin, manager e profissional; abrir a ficha completa grava `CLINICAL_READ` | **sugestão a confirmar** (sem prova) | R4 A spec 12:123-129, spec 29 §4c:120-131; R5 A 88 |
| ANA-D07 | Modo estúdio com PIN no servidor; rota e canal `tablet` mantidos; só uma trava de uso | **sugestão a confirmar** (30/10, sem prova) | R4 A spec 12:216-229 |
| ANA-D08 | Só IP truncado na prova de assinatura | **sugestão a confirmar** (sem prova) | R4 A spec 12:201-205 |
| ANA-D09 | Validade do link: 24 h, 3, 7, 15 ou 30 dias, padrão do estúdio 7 dias | **sugestão a confirmar** (30/10, sem prova) | R4 A spec 12:160-169 |
| ANA-D10 | Espanhol é o idioma padrão do modelo sem idioma declarado; Espanha é a jurisdição principal; modelo por idioma e país (Opção A) | **sugestão a confirmar** (sem prova; a spec 27 diz "recomendação atual") | R4 A spec 12:83-84, spec 27:3-12,78-110 |
| ANA-D11 | Imagem usada principalmente para avaliar o caso; uso em marketing só quando a profissional julgar; uso público é opcional, autorizado à parte (Sim/Não); recusa fica destacada e não bloqueia o serviço | **sugestão a confirmar** ("decisão de produto atual", sem frase) · item 7.1 | R5 A 7.1 (privacy-consent-risk-register:250-262) |
| ANA-D12 | Consentimento granular: não usar um único caixa; separar anamnese essencial, imagem, marketing, Google Reviews; só campo clinicamente necessário bloqueia o fluxo | **sugestão a confirmar** (sem prova) | R5 A (privacy-consent-risk-register:52-73) |
| ANA-D13 | Anamnese pertence ao atendimento e ao modelo, nunca ao serviço; Ficha Cliente e Ficha Profissional são partes da mesma anamnese; a comanda só consulta a pendência | **sugestão a confirmar** (sem frase) | R4 A spec 12:29-44; R5 A agenda-operational-scope:87-118 |
| ANA-D14 | Dados da ficha não sobrescrevem o cadastro sem validação | **sugestão a confirmar** (sem prova) | R5 A agenda-operational-scope:176-194; R4 A client-01:17 |
| ANA-D15 | Receber cópia por e-mail não existe até haver provedor de e-mail | **sugestão a confirmar** (sem prova) | R4 A spec 12:174-175 |
| ANA-D16 | Um especialista em proteção de dados confere o sistema antes de abrir a clientes (5·A, em lote). A ICEBOX 9 ainda pergunta: (A) especialista ou (B) a proteção atual basta? | **sugestão a confirmar** (aceite em lote) | R1 A.2 bloco 4 (5·A); R2 D ICEBOX:9 |
| ANA-D17 | Ficha de saúde é dado de saúde (RGPD): nunca em log, endereço ou ferramenta de erro; nunca vista por outro estúdio | **sugestão a confirmar** (regra do projeto, "SEM" frase do dono) | R2 C21, C63 |
| ANA-D18 | Bloco Formulários aparece também com formulário exigido não assinado ("Falta assinar", "Enviar formulário"); Notas e Formulários só aparecem quando têm conteúdo; o ícone da Anamnese ao lado de "Ver perfil" sai | **sugestão a confirmar** ("Sim" em lote, 23/11 e 19/11) · AGS3, AGT23, AG7 | R1 A AGS3, AGT23; reg:45 |

Regra: só vale decisão registrada em `docs/decisoes/` (molde de pergunta). Tudo desta tabela é **a confirmar**; a situação antiga fica entre parênteses só como histórico e volta a ser perguntada quando o módulo for trabalhado (resposta 15a do dono, 24/11/2026).

## Regras de negócio

**Privacidade (dado de saúde, RGPD)**
- A ficha é dado de saúde de residentes da UE (art. 9): nunca em log, endereço, ferramenta de erro ou resposta para quem não deve ler. (R2 C21, C63)
- Clientes de um estúdio nunca são vistas por outro: `org_id`, RLS e testes de isolamento. (R2 C63)
- Só owner, admin, manager e profissional leem `anamneses` e fotos; a recepção usa só funções de status. Visualizadora e financeiro não leem nem o status. (R4 A spec 29 §4c; R5 A 88)
- Abrir a ficha completa grava `CLINICAL_READ`. Acesso, assinatura e alteração de nota profissional geram `audit_logs`. (R4 A spec 12:70,127-128)
- O link público é guardado só como hash, tem validade e pode ser renovado; o novo link invalida o anterior. Link inválido, vencido ou usado mostra a mesma tela "não encontrada". Depois de assinado ou vencido, o link não devolve respostas nem assinatura. (R2 C69; R4 A spec 12:125-126)
- As páginas sem login (`/forms/{token}`, `/pagar/{token}`, Modo estúdio) levam `Cache-Control: private, no-store`, `noindex` e `Referrer-Policy: same-origin`. (R2 C70)
- Só o IP truncado é guardado; fica mascarado na tela. Dado clínico nunca entra em análises genéricas. (R4 A spec 12:63,201-205)
- Ferramenta de erro (Sentry) na região UE, sem dado pessoal, nunca com dado de anamnese. (R2 C71)
- Foto: nunca por Server Action; direto ao Storage por endereço assinado (1 hora) e comprimida no aparelho. Foto é dado clínico (`clientes.view_clinical`). (R5 C infra:134,216; R4 A client-02:17)
- Consentimentos separados: não juntar anamnese, imagem pública, marketing e pagamento num só aceite; recusar imagem ou marketing não bloqueia o serviço; não usar respostas da ficha em marketing; não sobrescrever o cadastro sem validação; não implementar texto legal final sem validação de jurisdição; não atender menores sem modelo de responsável. (R5 C privacy-consent-risk-register:348-357; docs/legal/README.md:5-16)
- Provedor que toca dado de saúde precisa de DPA (RGPD art. 28); `docs/legal` com os DPAs ainda não existe. (R5 C infra:47-48,232; R2 F-18)
- Retenção, direitos de acesso, apagamento e portabilidade e cifra da ficha ainda não estão cobertos. (R2 D database.md:51-53)
- Alterar este módulo que mexa em acesso, sessão, vazamento, página pública ou dado de saúde é nível C: passa por `risk-auditor`, também sobre a spec. (CLAUDE.md, Revisores)

**Funcionamento**
- Evidência assinada nunca muda nem se apaga; correção cria nova ficha ou nova versão e guarda o original.
- Ficha assinada não pode ser excluída; só ficha pendente, com auditoria.
- Serviço obrigatório com modelo cria uma única ficha pendente por atendimento e modelo.
- O atendimento não inicia com ficha sem assinatura da cliente; a comanda não fecha com assinatura ou ficha profissional obrigatória pendente (a avaliação profissional pode ser liberada com motivo; a assinatura, nunca).
- Serviço marcado como obrigatório sem modelo pode ser agendado, mas o início é bloqueado com erro de configuração do catálogo.
- Editar o modelo nunca muda fichas já enviadas (cada ficha guarda a versão e o país).
- Bloco informativo nunca gera resposta vazia.
- Reabrir a parte profissional concluída é só da gestão, com ação explícita e auditoria.
- Falta decidir (ANA-D16, ANA-44): especialista de proteção de dados antes de abrir a clientes.

## Pendências e perguntas
| Pergunta ou pendência | Origem |
|---|---|
| Qual nome vale na tela: Formulário, Ficha ou Anamnese? | consolidado §4 item 9; R1 F-1, F-26; R3 F-11 |
| Corrigir ficha assinada: o STATUS diz "pronto", a spec diz "planejado" e a spec 12 diz "retificação faltam": qual é a verdade? | R3 F-23; R2 B history:43; R4 B spec 12:97-99 |
| (A) especialista em proteção de dados antes de abrir a clientes ou (B) a proteção atual basta? | R2 D ICEBOX:9; R1 A.2 |
| 8 perguntas legais abertas: quais procedimentos exigem ficha obrigatória; quais exigem foto interna; jurisdição no lançamento; controlador e processador; provedores; prazo de retenção de ficha, fotos e notas; como a cliente pede acesso; opt-in do WhatsApp | R5 D (privacy-consent-risk-register) |
| 8 decisões abertas de 15/06: editar ficha assinada; validar dados antes de atualizar o cadastro; jurisdição; texto legal ES, PT e BR; pagamento do sinal; mensageria; navegação contextual | R5 D agenda-operational-scope:633-642 |
| Vincular modelo e serviço pela aba do serviço ou pela anamnese? | R5 D product-vision-detail:19 |
| 5 serviços exigem ficha mas não têm modelo | R4 D spec 12:95-96 |
| Menu mostra Anamnese a quem não tem permissão; Modo estúdio sem E2E; erros viram mensagem genérica | R3 B audit:27 |
| Banco ainda entrega a linha da ficha a quem o app oculta (RLS de SELECT por papel) | R4 D spec 12:129 |
| Testes de banco da liberação do fechamento; E2E do Modo estúdio; teste instável `96_anamnese_gate.sql` | R4 D spec 12:152-154,238; R2 D ICEBOX:39 |
| Link de correção leva as respostas anteriores (risco aceito, validade padrão 7 dias) | R2 C67; R2 D STATUS:59 |
| Texto do alerta da cliente (inclusive alergia) chega a quem vê a agenda sem ver clientes | R3 D agd:160 |
| Faxina de fotos órfãs e cópia das fotos no backup precisam de spec | R2 D ICEBOX:21,34 |
| Termos de exemplo "rascunhos, precisam de revisão jurídica" | R1 D (Sistema/Main, canvas.json) |
| Não usar o visual atual da Anamnese como referência de outros módulos até aceitar o padrão duplo; rolagem do viewer e cabeçalho pendentes | R5 C implementation-gap-map:119; R5 B 249 |

## Referências
- Specs do legado: `docs/produto/legado/specs/12-anamnese-forms-gdpr.md`, `27-anamnese-legal-language-audit-roadmap.md`, `29-access-roles-modules.md` (§4c), `37-perfis-liberacoes-configuraveis.md`, `54-novo-agendamento-pendencias.md`.
- Spec atual: `docs/specs/ficha-correcao.md` (aprovada em 14/11/2026 segundo a spec, sem frase do dono).
- Produto do legado: `docs/legal/privacy-consent-risk-register.md` (legado), `agenda-operational-scope.md`, `scope-master.md`, `implementation-gap-map.md`, `roadmap.md`.
- ADR: `docs/adr/2026-11-19-regras-de-produto.md` (#1, #2, #7).
- Segurança: `SECURITY.md`, `docs/reference/server.md:32-40`, `docs/reference/database.md:51-53`.
- Módulos ligados: Clientes (CLI, consentimento de imagem e fotos), Catálogo (CAT, serviço exige modelo), Comanda/Checkout (COM, trava), Equipe/Acessos, Ajustes.
