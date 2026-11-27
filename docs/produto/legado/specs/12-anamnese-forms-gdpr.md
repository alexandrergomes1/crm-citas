# Spec 12 - Anamnese, formulários e GDPR

## Status

Parcialmente implementada. Backend e contratos clínicos precedem o polimento
visual.

## Goal

Oferecer formulários configuráveis, preenchimento seguro pelo cliente e uma
única anamnese por atendimento/template. A parte do cliente e a parte
profissional pertencem à mesma anamnese, com histórico, pendências,
consentimento e evidências auditáveis.

## Blocos do template

- cabeçalho com dados do cliente e do atendimento;
- título e texto informativo sem resposta;
- resposta sim/não;
- texto curto ou longo;
- seleção única e múltipla;
- pergunta condicional com justificativa;
- termo de consentimento;
- assinatura;
- checklist e notas privadas do profissional.

## Vínculos

- Serviço pode sugerir ou exigir um template como configuração de entrada.
- A anamnese criada nunca pertence ao serviço: ela pertence ao atendimento e
  ao template. Não existe entidade ou vínculo clínico profissional separado
  por serviço.
- Ficha preenchida pertence ao cliente e, quando criada para atendimento, ao
  `appointment_id`.
- A ocorrência canônica do atendimento é `anamneses.appointment_id` +
  `template_id`; `appointments.linked_anamnese_id` existe apenas para
  compatibilidade legada e não decide os gates.
- Cada `appointment_item` preserva o snapshot de `requires_anamnese` e
  `anamnese_template_id` vigente quando o serviço entra no atendimento.
- A parte profissional pertence à mesma linha de `anamneses`, controlada por
  `requires_professional`, `professional_data` e
  `professional_completed_at`.
- Templates usados geram snapshot imutável para preservar a versão assinada.

## Main Flow

1. Atendimento seleciona serviço que exige formulário.
2. Sistema cria ou vincula ficha pendente.
3. Link manual ou automático é enviado antes do atendimento.
4. Cliente responde e assina.
5. Servidor registra consentimento, versão, data, IP e user-agent confiáveis.
6. Profissional consulta a ficha e registra notas do atendimento.
7. Ausência de nota profissional pode gerar pendência operacional.

## Business Rules

- Bloco informativo nunca gera resposta vazia.
- Token público é opaco, expirável, revogável e limitado por taxa.
- Dados clínicos não entram em payloads genéricos de analytics.
- Evidência assinada é imutável; apenas campos privados posteriores do
  profissional podem evoluir.
- Parte profissional pendente pode ser editada e salva como rascunho.
- Conclusão da parte profissional é explícita e auditada.
- Reabertura de parte profissional concluída é restrita à gestão, exige ação
  explícita e gera auditoria.
- Ficha do cliente assinada não é editada diretamente. Retificação ou nova
  versão deve preservar integralmente a evidência anterior.
- Ficha assinada não pode ser excluída. Exclusão operacional é restrita a ficha
  pendente e gera audit log.
- Acesso, assinatura e alteração de nota profissional geram `audit_logs`.
- Retenção, anonimização e exclusão seguem política GDPR da organização.
- Nota fixa do cliente e nota profissional por atendimento são entidades
  diferentes.
- Serviço obrigatório com template configurado cria uma única ficha pendente
  por atendimento e template, de forma idempotente.
- Atendimento não inicia enquanto uma ficha vinculada estiver sem assinatura
  do cliente.
- Checkout parcial ou final não conclui enquanto houver assinatura do cliente
  ou ficha profissional obrigatória pendente.
- `requires_professional` é escolhido ao criar a anamnese. Alterar a exigência
  depois da assinatura ou da finalização da comanda exige uma spec própria;
  dados profissionais existentes nunca são apagados implicitamente.
- Espanhol é o idioma padrão quando o modelo não declara idioma no título.
  A escolha usa o modelo selecionado, não o idioma do navegador.
- Serviço marcado como obrigatório sem template pode ser agendado, mas o início
  é bloqueado com erro explícito de configuração do catálogo.

## Estado atual

- Builder possui `yes_no`, `text`, `multiple_choice` e `info`.
- Viewer, assinatura, token, snapshot e notas profissionais existem.
- Serviço pode exigir anamnese e apontar template.
- Criação manual e automática, início e checkout consultam a mesma ocorrência
  canônica, com enforcement também no banco.
- Cinco serviços atuais exigem anamnese, mas ainda precisam receber um template
  no catálogo antes do uso operacional.
- Faltam cabeçalhos/seções estruturadas, múltipla seleção explícita,
  retificação/versionamento formal de evidência assinada, idioma preferido no
  cadastro do cliente, rate limiting e política de retenção.

## Acceptance Criteria

- [x] Texto informativo é renderizado sem campo de resposta.
- [x] Ficha assinada pode ser visualizada e impressa.
- [x] Impressão escapa conteúdo controlado por usuário.
- [x] Banco impede alteração ou exclusão da evidência assinada.
- [x] Notas profissionais podem ser salvas.
- [x] Serviço pode exigir template.
- [x] Ficha profissional é vinculada inequivocamente ao atendimento (parametrizável por ficha, com estado de conclusão e bloqueio de fechamento da comanda — CORE-ANA-02).
- [x] Parte profissional usa a mesma entidade da anamnese e possui rascunho,
  conclusão e reabertura auditados.
- [x] Pendências do cliente e profissional são consultáveis na agenda,
  cliente e gestão de anamneses.
- [ ] Consentimento e acesso possuem trilha de auditoria.
- [x] Criação, início e checkout usam o mesmo vínculo de anamnese do atendimento.
- [ ] E2E cobre criação, envio, assinatura, visualização e nota profissional.

## Handoff visual

Claude define composição do builder, viewer, estados e navegação usando os
contratos desta spec. Codex valida domínio, persistência, privacidade e testes.

## Regras do banco (29 out 2026)

- Depois de assinado ou expirado, o link público (`get_anamnese_by_token`) não devolve
  respostas nem assinatura. O envio da assinatura tem limite de tamanho e exige imagem.
- Recepção vê só o status da ficha; notas e dados profissionais só por owner, admin, manager
  e profissional (RPC e RLS de UPDATE). Abrir a ficha completa grava `CLINICAL_READ`.
- Pendência: RLS de SELECT por papel (hoje o app oculta, o banco ainda entrega a linha).

## Liberar o fechamento sem a avaliação da profissional (29 out 2026)

Decisão do Alexandre (recomendação 2 da nota "Travas da ficha de anamnese"): a assinatura da
cliente continua trava dura para **iniciar**. Para **fechar a comanda**, a avaliação da
profissional pendente deixa de travar o caixa sem saída: quem tem a liberação pode liberar com
motivo escrito, registrado.

- Nova liberação `anamnese.override_checkout_gate` ("Liberar fechamento sem avaliação da
  profissional"), editável em Configurações > Perfis. Padrão: proprietária, administração e
  gestão; recepção e profissional desligadas.
- `override_anamnese_checkout_gate(org, agendamento, motivo)`: só quando há ficha com avaliação
  profissional pendente no atendimento; motivo de 5 a 300 caracteres; grava uma linha por ficha
  em `anamnese_gate_overrides` e `ANAMNESE_GATE_OVERRIDE` em `audit_logs`.
- A trava do fechamento (`get_appointment_anamnese_gate`, etapa `checkout`) ignora a pendência
  profissional das fichas liberadas. Assinatura pendente nunca é liberada por aqui.
- A avaliação continua pendente na ficha e pode ser concluída depois.
- Tela: quando o fechamento é recusado por avaliação pendente, o checkout mostra o aviso e, para
  quem pode, o campo "Motivo" com "Liberar e concluir pagamento".

Critérios:

- [ ] Recepção sem a liberação não consegue liberar (teste de banco).
- [ ] Liberação com motivo permite concluir o pagamento; sem motivo é recusada.
- [ ] Assinatura da cliente pendente continua impedindo iniciar e fechar.

## Link configurável, envio e abertura, assinatura no servidor, versão e Modo estúdio (30 out 2026)

Migrations `20261030400000` a `20261030400200`, aditivas e compatíveis com o app anterior.

### Validade do link

- Prazos aceitos: 24 horas, 3, 7, 15 e 30 dias (o banco recusa outro valor). O padrão do estúdio fica
  em `organizations.settings.anamnese.link_days` (Ajustes › Ficha de saúde, só `ajustes.manage`, via
  `set_anamnese_settings`); sem ajuste, 7 dias, como antes.
- Um gatilho de INSERT (`anamneses_apply_defaults`) aplica o padrão a qualquer ficha criada, sem
  reescrever `create_anamnese_atomic`. Em "Enviar ficha" a recepção pode escolher outro prazo
  (`set_anamnese_link_validity`, só ficha pendente); em "Reenviar link" renova ou encurta, e link
  vencido volta a valer (registra o evento `renewed`).
- A tela da cliente mostra "o link vale até <data, hora>" no fuso do estúdio e o atendimento vinculado.
  `get_anamnese_by_token` devolve a data e o atendimento só enquanto o link vale e o atendimento não
  está cancelado; link vencido continua sem dado nenhum.
- "Adicionar ao calendário": no fim da ficha, `GET /forms/<token>/calendar` gera o `.ics` no servidor
  (horário em UTC, título e nome do arquivo no idioma da ficha). 404 se o link venceu ou não há atendimento.
- "Receber cópia por e-mail" NÃO existe: o projeto não tem envio de e-mail real (spec 13). Fica fora até haver
  provedor; o botão "Guardar uma cópia" (impressão) continua com o selo "Anterior".

### Registro de envio e abertura

- Tabela `anamnese_events` (`sent`, `opened`, `renewed`; canal `whatsapp`, `qr`, `studio`, `copy`; quem enviou).
  Leitura só com `anamnese.view_status` (RLS); ninguém escreve direto, só as funções. Colunas novas
  `anamneses.first_opened_at` e `last_opened_at`.
- `log_anamnese_send` (idempotente em 10 s) grava o envio ao criar, copiar, abrir o WhatsApp, mostrar o QR ou
  entregar no Modo estúdio. `list_anamnese_events` alimenta a "Atividade recente" da visão geral e o
  "Andamento" da ficha (enviada por, abriu o link, última abertura, renovada).
- A abertura é gravada pela sobrecarga `get_anamnese_by_token(token, true)`, que não devolve nada a mais que a
  leitura simples: marca a primeira e a última abertura (no máximo uma por minuto) e só para ficha pendente
  e dentro do prazo. A leitura de um argumento segue somente leitura (o app antigo não grava nada). A página
  pública só pede o registro quando o pedido não vem de robô de pré-visualização (WhatsApp, Telegram e
  afins), para a prévia da mensagem não contar como abertura.

### Validação da assinatura no servidor

`submit_anamnese_signature` reconfere contra o snapshot da própria ficha, antes de gravar: termo principal
aceito (quando há texto), termos obrigatórios aceitos e opcionais respondidos, perguntas obrigatórias
respondidas (e o detalhe "explique" quando a resposta o exige) e canal (`link` ou `tablet`, valor histórico
gravado). Erros devolvidos como código (`terms_required`, `answers_required`, `channel_invalid`,
`consent_required`, `signature_required`, `expired`, `already_signed`) e traduzidos em es, en e pt na tela.
Não valida os campos de dados pessoais (nome, nascimento, telefone, e-mail, maioridade): a tela os exige,
mas o banco ainda não.

**IP na prova (LGPD/RGPD).** Guardamos só o IP truncado: IPv4 sem o último octeto (`203.0.113.9` vira
`203.0.113.0`), IPv6 só com a rede /48 (`2001:db8:1234::`). Vem do primeiro valor de `x-forwarded-for`
(a Vercel preenche) e é truncado no servidor da aplicação e de novo no banco (`anonymize_ip`), então o
endereço inteiro nunca é gravado. Serve de indício da rede do ato, não identifica a pessoa sozinho, fica
com a ficha pelo prazo de guarda e aparece mascarado na tela ("IP (anonimizado)").

### Versão e país do modelo

- `anamnese_templates.version` (começa em 1) sobe sozinha por gatilho quando título, perguntas, termos,
  ficha profissional ou país mudam ao salvar; salvar sem mudança não sobe. `country` (ISO alfa-2, padrão ES)
  escolhe a norma de privacidade dos termos.
- Cada ficha nova guarda `template_version` e `template_country` no snapshot; editar o modelo nunca muda
  fichas já enviadas. A lista de Modelos mostra "v3 · Espanha" e o idioma; o detalhe da ficha mostra
  "v3 · Espanha · Español". Fichas anteriores à migration não têm versão no snapshot e mostram só país e idioma.

### Modo estúdio (antes "Tablet")

- É só uma opção: serve em celular, computador ou tablet, e o estúdio liga ou desliga em Ajustes › Ficha de
  saúde. Na interface o nome é "Modo estúdio"; a rota continua `/<estúdio>/anamnese-tablet` e o canal gravado
  nas respostas continua `tablet` (histórico das fichas e do app anterior).
- PIN da equipe: tabela `studio_mode_pins` (um por estúdio, hash bcrypt com sal, sem política: ninguém lê
  direto). `set_studio_pin` (só `ajustes.manage`, 4 a 6 números, auditado sem o PIN), `studio_pin_status` e
  `verify_studio_pin` (5 erros bloqueiam por 5 minutos; redefinir o PIN libera). O aparelho só digita; nada do
  PIN fica no navegador. Substitui o PIN guardado em `localStorage`.
- Trava: ao tocar em "Entregar", uma Server Action define o cookie httpOnly `ka-modo-estudio` (estúdio e pessoa
  que entregou) e o `proxy.ts` redireciona qualquer outra rota dessa pessoa para o Modo estúdio, exceto
  `/forms`, `/login` e `/logout`. Sair pede o PIN (verificado no servidor). Só entrega se o modo está ligado e
  há PIN. **Limite:** é uma trava de uso, não de segurança forte: quem apaga os cookies do navegador sai dela;
  o PIN protege contra a cliente, não contra quem tem o aparelho em mãos e a senha da conta.

Critérios:

- [x] Link com 24 h, 3, 7, 15 ou 30 dias, padrão do estúdio e renovação (teste de banco e Vitest).
- [x] Envio e primeira/última abertura registrados; leitura simples não registra (teste de banco).
- [x] Assinatura sem termos, sem resposta obrigatória ou com canal inválido é recusada (teste de banco).
- [x] Versão sobe ao editar o modelo e a ficha enviada não muda (teste de banco).
- [x] PIN com hash por estúdio, limite de tentativas e redefinição só por quem gerencia (teste de banco).
- [ ] E2E do Modo estúdio com PIN (entregar, sair com PIN errado e certo): falta fixture com PIN.
