# Módulo: Clientes (CLI)

> O cadastro único de cada cliente do estúdio: contato, documento, notas, alertas, saldo, fotos e histórico.
> Agenda, comanda, ficha de saúde e mensagens usam este cadastro.

**Telas e rotas:** `/{org}/clientes` (lista) · `/{org}/clientes/{clientId}` (perfil) · **Código:** `src/workspace/clientes`, `src/workspace/client-notes`, `src/workspace/client-note-actions*.ts` · **Spec(s):** sem spec no crm-agenda (só a auditoria). No legado: `docs/produto/legado/specs/06-client-crm-360.md`, `client-01-international-identity.md`, `client-02-cidade-imagem-mesclagem-importacao.md`, `28-client-notes-edit-checkout-context.md`.

Siglas da coluna Origem: `R1` a `R5` = relatórios em `docs/reorganizacao/levantamento/` (letra = seção, depois fonte). `reg:N` = linha N de `docs/decisoes/historico/registro-ate-2026-11-24.md`. "antigo" = Beauty System; "atual" = crm-agenda.

## Recursos
| ID | Recurso | Estado | Onde | Origem |
|---|---|---|---|---|
| CLI-01 | Lista, filtros, criar, editar, perfil e exportar | pronto (antigo) · pronto (atual); testes `clientes-v25` nunca rodam | `/clientes`, `/clientes/{id}` | R4 B spec 06; R5 B scope-master:50; R2 B STATUS:28; R3 B audit:23 |
| CLI-02 | Perfil carrega em 2 chamadas ao banco | pronto (atual) | `/clientes/{id}` | R2 B STATUS:28 |
| CLI-03 | Consentimento de marketing: só quem disse SIM; o sistema avisa quantas clientes não autorizaram | pronto (atual) | cadastro, Marketing | R2 B STATUS:28; R2 A regras-de-produto #3 (adr/2026-11-19-regras-de-produto.md:8) |
| CLI-04 | Cadastro internacional: nome e telefone obrigatórios, documento por tipo (DNI, NIE, NIF, passaporte, CPF, outro), sem validação rígida de CPF; CPF antigo preservado | pronto (antigo) · planejado (atual, G8) | formulário de cliente | R4 B client-01; R5 B roadmap:108-111, agenda-operational-scope:165-174; R3 B fase1:120 |
| CLI-05 | Telefone por país (DDI) com `libphonenumber-js` e campo próprio; número novo ou alterado; cadastros antigos não revalidados | pronto (antigo) | formulário de cliente | R4 B spec 52:283-307 |
| CLI-06 | Regra de telefone ainda duplicada em importação (≥6 dígitos), reserva online (≥6) e `ClientSchema.phone` (min 3) | planejado (antigo, depende do dono) | `client-import.ts`, `public-booking.ts` | R4 B spec 52:308-311 |
| CLI-07 | Cidade e estado/província no formulário, perfil, busca e CSV | pronto (antigo) | formulário (Mais dados), perfil (Detalhes) | R4 B client-02:5-7 |
| CLI-08 | Consentimento de uso de imagem: carimbado pelo banco (quem e quando), auditoria `IMAGE_CONSENT_GRANTED/REVOKED`, selo "Divulgação permitida/não permitida" nas fotos; divulgação só com autorização | pronto (antigo) | formulário, cartão "Uso de imagem", seção Fotos | R4 B client-02:9-17 |
| CLI-09 | Fotos da cliente são dado clínico: só com `clientes.view_clinical`; endereços assinados por 1 hora | pronto (antigo) | perfil › Fotos | R4 A client-02:17 |
| CLI-10 | Mesclagem atômica de duplicados (move tudo, soma saldo e pontos, ficha repetida fica Inativa com `merged_into`; repetir devolve `already_merged`) | pronto (antigo) · duplicados pronto (atual) | painel Clientes duplicados (`ClientDuplicatesPanel`) | R4 B client-02:19-27; R1 B own:14 |
| CLI-11 | Importar clientes por CSV: prévia (entram, já existem, recusadas), limite 2.000 linhas, lotes de 200, repetir não duplica | pronto (antigo) | Opções › Importar clientes (`ClientImportDialog`) | R4 B client-02:29-33 |
| CLI-12 | Exportação CSV auditada (`CLIENTS_EXPORTED`: quem, quando, quantos, filtro) | pronto (antigo) · atual: "auditoria da exportação" na fila (ICEBOX 42); menu promete CSV ou Excel e só sai CSV | `export-actions` | R4 B client-02:35-37; R2 D ICEBOX:35; R3 B audit:23 |
| CLI-13 | "Nova visão" (visões salvas da lista) | planejado (antigo) · "em breve" (atual) | lista | R4 B client-02:39-40; R3 B audit:23 |
| CLI-14 | Notas em linha do tempo: nota do cliente, nota de atendimento e nota fixa | pronto (antigo) · pronto (atual) | perfil, comanda, agendamento | R4 B spec 26:60-115, spec 28; R5 B implementation-gap-map:41,74-88; R1 B inv:58 |
| CLI-15 | Editar nota (1 a 5.000 caracteres, RPC atômica, auditoria sem copiar o texto); textos longos recolhidos com "Ver mais/Ver menos" | pronto (antigo, aprovado) | perfil, painel de notas | R4 B spec 28:42-51; legado spec 28:24-51 |
| CLI-16 | Notas na comanda: fixas e do atendimento no contexto inicial; gerais só como contador; painel lateral (computador) ou folha (celular) com abas Cliente e Atendimentos | pronto (antigo, aprovado) | comanda (`/checkout/{id}`) | R4 B spec 28:32-40 |
| CLI-17 | Notas antigas (`clients.notes`, `clients.fixed_notes`) preservadas, só leitura, dentro da linha do tempo | pronto (antigo) | perfil | R4 A spec 28:53-58; R5 B implementation-gap-map:74-88 |
| CLI-18 | Excluir ou restaurar nota, anexos, edição em tempo real | adiado (fora do escopo, antigo) | — | R4 B spec 28:71-77 |
| CLI-19 | Notas fixas, alertas clínicos ou estéticos e etiquetas (VIP, Fiel, Novo, Inativo, Alérgico) | pronto (antigo) | perfil, agenda | R5 B scope-master:51; R5 B archive/dev-scope:33-46 |
| CLI-20 | Alertas múltiplos históricos e alergias (com abas: medicamentosa, não medicamentosa, sem alergias conhecidas) | planejado (antigo e referência Fresha) | perfil | R4 B spec 06:25; R5 B roadmap:112-116; R5 B 520 (Fresha 09/11) |
| CLI-21 | Texto do alerta da cliente chega a quem vê a agenda mesmo sem permissão de ver clientes | pendência (fato atual, vai ao dono) | agenda | R3 B agd:160 |
| CLI-22 | Bloqueio de reserva da cliente, com motivo, autor, auditoria e liberação; não é o mesmo que inativar ou excluir | planejado (spec 06) · parcial (spec 24: "bloquear" pronto) · "em breve" no inventário (atual) | Ações ▾ da cliente | R4 B spec 06:25, spec 24:104-114; R1 B inv:72; R3 B agd:29 |
| CLI-23 | Ações ▾ da cliente (Editar dados, Alergia, Etiqueta, Bloquear, Alerta de equipe) | "em desenvolvimento" (antigo) · planejado (atual) | agendamento e comanda | R4 B spec 24:50-52, spec 52, 54; R5 B product-vision-detail:46-47; R1 B inv:72 |
| CLI-24 | Anonimização e exclusão com retenção (RGPD); hoje só arquivar | planejado (antigo) · "Excluir cliente" saiu da tela (atual) | perfil | R4 B spec 06:5-15,25; R5 B roadmap:112-116; R4 C spec 54 |
| CLI-25 | Histórico consolidado numa linha do tempo (atendimentos, vendas, benefícios, formulários) | planejado (antigo) · "Atividade" no perfil pronto em parte | perfil | R4 B spec 06:25-26; R5 B roadmap:112-116; R4 B spec 46:112-117 |
| CLI-26 | Histórico de atendimentos | pronto (antigo) | perfil | R5 B scope-master:53 |
| CLI-27 | Histórico financeiro | parcial (antigo) | perfil | R5 B scope-master:54 |
| CLI-28 | Benefícios de pacotes e planos (`client_entitlements`), aba Pacotes | pronto (antigo) | perfil | R5 B scope-master:55 |
| CLI-29 | Fidelidade (pontos) na ficha da cliente | parcial (antigo) | perfil | R5 B scope-master:56 |
| CLI-30 | Saldo de crédito ou débito com extrato (ledger) com origem, referência e saldo depois; reversão só de entradas elegíveis; seção "Movimentos de saldo" | pronto no banco e na tela (antigo) · parcial: relatórios de reversão pendentes | perfil › Movimentos de saldo; lista em `/financeiro/saldos` (spec 41:64-67); spec 06:13 | R5 B implementation-gap-map:44-45; R5 B archive/delivery-review-2026-06-16 (ledger e front); R5 B scope-master:52 |
| CLI-31 | Aviso de saldo em aberto na comanda e ao agendar (não impede); abatimento do crédito opcional | parcial (antigo: aviso e chave prontos; origem de cada movimento faltava) | agendamento, comanda | R5 B product-vision-detail:8-12 |
| CLI-32 | Consentimentos da cliente (via anamnese) | parcial (antigo) | perfil | R5 B scope-master:57 |
| CLI-33 | Cartão da cliente no agendamento com e-mail, "Desde" e país | planejado (atual); exige migration de banco, nível C, com autorização do dono | cartão da cliente | R1 B own:14; R2 B STATUS:8; R3 B agd:25 |
| CLI-34 | Editar cliente com vários endereços e telefones, avisos e marketing item a item; perfil sem duplicação (G10) | planejado (atual) | formulário, perfil | R3 B fase1:122; R1 A G10 |
| CLI-35 | "Sem retorno" = 60 dias sem voltar (G6) | planejado (atual) | etiqueta e filtro | R3 B fase1:118; R1 A G6 |
| CLI-36 | Teste de contato (`client_patch_tests`: serviço ou produto, aplicado em, leitura em, resultado, validade, profissional) | planejado P2 (antigo, "ausente") | perfil | R4 B spec 24:53,108,160-164,203 |
| CLI-37 | Etiquetas na lista (última coluna) e filtros F1 (Ordenar, Situação, Etiquetas e origem, Última visita, Saldo) | pronto/planejado, sem estado explícito (antigo) | lista | R4 B spec 46:112-117; R1 A L-1111-09 |
| CLI-38 | Etiquetas automáticas e segmentos por regra (Alto consumo, Cliente recorrente), "Gerenciar tags", selo no perfil | referência Fresha e Booksy (sem decisão) | lista, perfil | R3 B fr/04-clientes/notas-etiquetas-09-11:8-26, M/booksy:141-155; R5 B 520 |
| CLI-39 | Modelo de tags de cliente | planejado (pendência da spec 54) | — | R4 B spec 54:24-31 |
| CLI-40 | Ficha da cliente no celular sem abas (pessoa, ações, lista de seções com contador); linha do tempo de atendimentos; "tudo que lista abre algo" | pronto (antigo, ajustes de 30/10) | perfil no celular | R4 B spec 45:28-35 |
| CLI-41 | Cadastro e edição funcionais no celular 390 px (rolar até o fim, rodapé sem bloquear, sem rolagem lateral) | parcial (antigo) | formulário | R5 B agenda-operational-scope:147-163 |
| CLI-42 | Idioma da cliente (alimenta o idioma da ficha) | planejado (antigo) | cadastro | R4 B spec 54:24-31; R4 B spec 12:97-99 |
| CLI-43 | Contato antes de mensagem automática: telefone obrigatório, DDI, número normalizado, estado de permissão, canal preferido, opt-out | parcial (antigo) | cadastro, Mensagens | R5 B messaging-flow:90-103 |
| CLI-44 | Galeria antes/depois: comparador, linha do tempo por sessão, exportação que respeita o consentimento de imagem | planejado, sem dono ("prioridade nº 1 do negócio") | perfil › Fotos | R5 B revisao-30-10:24; R5 F.2-4; R1 B (consolidado §3.B) |
| CLI-45 | Auditoria de toda alteração sensível e E2E de cadastro, edição, saldo e bloqueio | planejado (antigo, critérios `[ ]`) | — | R4 B spec 06:32-33 |
| CLI-46 | Painel lateral do módulo e segunda coluna (Clientes) | sem decisão confirmada: CMP-A1 tirou a coluna, o legado mantém painel de 248 px | lista | R1 A CMP-A1; R1 F-28, F-31 |
| CLI-47 | Referência de mercado: grupos automáticos (mais fiéis, novos, aniversário), Trusted Client, atalho de WhatsApp, cartão fidelidade digital, e-mail em massa só a quem aceitou, teste de alergia por serviço | referência (sem decisão) | — | R3 B M/booksy:141-155, M/treatwell:126-132; R5 B 482, 487 |
| CLI-48 | CORE-NOTES-01: alerta de alergia e nota de sinal com o mesmo ícone âmbar; notas e alertas pedem redesenho | planejado (antigo) | perfil e agendamento | R5 B core-delivery-control:181 |

"Estado" é o que os documentos dizem; o código é conferido quando o módulo entra em trabalho. Conferido só para "Onde": as rotas `/clientes` e `/clientes/$clientId` e as pastas acima existem.

## Decisões
| ID | Decisão | Situação | Origem |
|---|---|---|---|
| CLI-D01 | "Excluir cliente" sai da tela do novo agendamento (o sistema só arquiva). Resposta: "Saem da tela" | **a confirmar** (antes: vale) (22/11/2026, 16h21; só para esta exceção) · antigo: G9 / AGT19 | R1 A G9, AGT19; consolidado:69 |
| CLI-D02 | Nomes das notas: "Nota da reserva", "Nota fixa cliente", "Nota do agendamento" (não "da cliente", pois pode haver vários gêneros). Resposta literal do dono | **a confirmar** (antes: vale) (19/11/2026, 10h43) · antigo: CMP-E1 | R3 A (falas:179); R1 A.4; consolidado:71 |
| CLI-D03 | "Sem retorno" = 60 dias sem voltar | **sugestão a confirmar** (04/11, aceite em lote) · G6 | R1 A G6 (reg:122) |
| CLI-D04 | Editar cliente com vários endereços e telefones; avisos e marketing item a item; perfil sem duplicação; pagar menos vira crédito por opção; motivos de desconto configuráveis | **sugestão a confirmar** (09/11, aceite em lote) · G10 | R1 A G10 (reg:126) |
| CLI-D05 | Telefone começa Brasil, depois Portugal e Espanha; idioma por procedimento, da cliente como reserva | **sugestão a confirmar** (05/11, aceite em lote) · G8. Conflita com CLI-D06 | R1 A G8 (reg:124); R4 B spec 52:283-307 |
| CLI-D06 | DDI padrão `+34` (Espanha) e documento por tipo, sem validação rígida de CPF | **sugestão a confirmar** (sem prova; spec do antigo) · client-01 | R4 A client-01:3-17; R5 B roadmap:110-111 |
| CLI-D07 | O número de dígitos do telefone depende do país; começa por Brasil, Portugal e Espanha e cobre a Europa | **sugestão a confirmar** (a fonte cita "decisão do dono", sem frase) · spec 52 §8.1 | R4 A spec 52:283-307 |
| CLI-D08 | Etiquetas na lista de Clientes vão na última coluna | **sugestão a confirmar** (11/11, 16h09, sem frase) · L-1111-09 | R1 A L-1111-09 (reg:193); R5 A 66 |
| CLI-D09 | Menores de idade não são atendidos em princípio; sem fluxo de responsável na versão inicial | **sugestão a confirmar** (sem prova) · item 7.2 | R5 A 7.2 (docs/legal/privacy-consent-risk-register.md:264-273) |
| CLI-D10 | "Bloquear", "remover" e "excluir" cliente têm sentidos diferentes; `clients.status` não é reusado para bloquear reserva | **sugestão a confirmar** (sem prova) | R4 A spec 24:104,111-114,155-158 |
| CLI-D11 | Todo novo atendimento exige cliente cadastrado da mesma organização; o nome no atendimento é cópia derivada do cadastro; nota fixa aparece por relação, sem cópia velha | **sugestão a confirmar** (correções de 12/06/2026, sem prova) | R5 A (product-capability-audit-2026-06-12.md:12-21); R4 B spec 06:10-12 |
| CLI-D12 | Marketing só para quem disse SIM (RGPD) | **sugestão a confirmar** (só data 14/11, sem frase) · regras-de-produto #3 | R2 A history.md:65-70; adr/2026-11-19-regras-de-produto.md:8 |
| CLI-D13 | Segunda coluna sai de Agenda, Clientes e Catálogo; visões viram "Todas as clientes ▾" | **sugestão a confirmar** (19/11, ficha, sem frase) · CMP-A1 | R1 A CMP-A1 (reg:249) |
| CLI-D14 | Sem permissão de editar clientes somem Alergia, Etiqueta, Bloquear, Editar dados e o "Editar" da nota fixa; Bloquear abre a janela do perfil; Alergia abre a janela com o alerta atual | **sugestão a confirmar** ("Sim" em lote a 8 sugestões, 23/11, 00h46) · AGS5, AGS6, AGS8 | R1 A AGS5, AGS6, AGS8 |
| CLI-D15 | Notas fixas editadas pelo perfil, em outra aba | **sugestão a confirmar** ("Sim" em lote, 23/11) · AGS2 | R1 A AGS2 |
| CLI-D16 | Edição de nota só pelos papéis owner, admin, manager, recepção e profissional; exclusão fora do escopo | **sugestão a confirmar** (spec do antigo "approved", sem frase do dono) | R4 A spec 28:3-5,42-58 |
| CLI-D17 | Consentimento de imagem: divulgação (site, redes, campanhas) só com foto de quem autorizou; uso interno (prontuário) não depende | **sugestão a confirmar** (sem prova) | R4 A client-02:9-17; R5 A 7.1 |

Regra: só vale decisão registrada em `docs/decisoes/` (molde de pergunta). Tudo desta tabela é **a confirmar**; a situação antiga fica entre parênteses só como histórico e volta a ser perguntada quando o módulo for trabalhado (resposta 15a do dono, 24/11/2026).

## Regras de negócio
- Todo novo atendimento tem cliente cadastrado, da mesma organização. Registros antigos sem cliente continuam legíveis.
- Toda tabela de cliente tem `org_id` e RLS; cliente de um estúdio nunca aparece em outro.
- Nome e telefone são obrigatórios nos cadastros novos; clientes antigos podem não ter telefone ou DDI.
- Saldo muda só por lançamento no extrato, com origem, referência e saldo depois; reverter gera novo lançamento.
- Bloquear reserva não é inativar nem excluir a cliente.
- Mesclar duplicados é uma operação única: ou move tudo ou nada. Consentimento de imagem fica só se as duas autorizaram.
- Foto da cliente é dado clínico: só quem tem `clientes.view_clinical` vê; divulgação só com autorização.
- Marketing só para quem disse SIM.
- Dados da ficha de saúde não mudam o cadastro sozinhos (ver Anamnese, ANA).
- Nota não guarda o texto na auditoria (só que foi criada ou editada).
- Exportar clientes só entrega o arquivo depois de gravar quem, quando, quantos e o filtro.
- Exclusão segue retenção e anonimização do RGPD; hoje só se arquiva.
- Dado pessoal nunca em log.

## Pendências e perguntas
| Pergunta ou pendência | Origem |
|---|---|
| Qual é o DDI padrão do cadastro: +34 (spec client-01) ou +55 Brasil (spec 52, G8)? Muda cadastro e fichas | consolidado §4 item 14; R4 F |
| E-mail, "Desde" e país no cartão da cliente precisam de migration nível C: o dono autoriza? | R1 D own:14; R3 D agd:177 |
| Texto do alerta da cliente chega a quem vê a agenda mas não vê clientes: aceita ou restringe? | R3 D agd:160 |
| Política de exclusão de cliente (RGPD) e modelo de tags; idioma da cliente; validade da ficha | R4 D spec 54:19-31 |
| Alertas múltiplos, bloqueio de reserva, timeline consolidada, anonimização, auditoria de alteração sensível | R4 D spec 06:25-26,32-33 |
| Painel lateral do módulo e segunda coluna: CMP-A1 tirou, PGuia e V25 mantêm o painel de 248 px | R1 F-28, F-31; consolidado §4 item 16 |
| Menu promete CSV ou Excel e só sai CSV; desfazer arquivamento falha em silêncio; nota usa lista fixa de funções; teste `clientes-v25` não roda | R3 B audit:23 |
| Fotos do Fresha com nome e telefone de clientes reais: tirar do repositório e do histórico? | R3 D fase1:133 (N2·A em lote) |
| Galeria antes/depois ("prioridade nº 1") ainda sem dono | R5 F.2-4 |
| Ficha do cliente com vários cartões: "Cartão da cliente" do livro de 11/11 em revisão | R5 D registro.md:70 |
| Gênero dos textos: "Nova cliente" (feminino, v26) contra neutro (PASSAGEM 13/11) | consolidado §4 item 22 |
| Itens da fila: auditoria da exportação CSV (ICEBOX 42), abrir a clientes só após especialista de proteção de dados (ICEBOX 9) | R2 D ICEBOX:9,35 |
| Fixture local para o registro de auditoria da reversão de saldo (antigo, histórico) | R5 D finance-core-scenarios-2026-06-17:80-90 |

## Referências
- Specs do legado: `docs/produto/legado/specs/06-client-crm-360.md`, `client-01-international-identity.md`, `client-02-cidade-imagem-mesclagem-importacao.md`, `28-client-notes-edit-checkout-context.md`, `26-agenda-status-notes-core.md`, `24-agenda-fresha-parity-handoff.md`, `45-layout-limpo.md`, `46-padrao-fresha-aprovado.md`, `52-guia-de-agendamento.md`, `54-novo-agendamento-pendencias.md`.
- Produto do legado: `docs/produto/legado/produto/scope-master.md`, `roadmap.md`, `revisao-30-10.md`.
- Fresha: `fr/04-clientes/` (prints sem legenda, 15 itens "a descrever"; notas e etiquetas de 09/11).
- Registro de design: `docs/decisoes/historico/registro-ate-2026-11-24.md` (G6, G8, G10, L-1111-09, CMP-A1, CMP-E1).
- Módulos ligados: Anamnese (ANA), Agendamento, Comanda/Checkout (COM), Fidelidade, Mensagens.
