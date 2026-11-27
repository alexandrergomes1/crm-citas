# Agenda Operational Scope — Escopo Operacional Completo

Status: active operational scope / pending user validation
Owner: Alexandre + ChatGPT orchestration
Last updated: 2026-06-15

Este documento registra o escopo completo do fluxo operacional centrado na Agenda para que nenhuma decisão, observação ou pendência se perca entre conversas, Codex, Claude e validações manuais.

Ele complementa `docs/core-delivery-control.md`; não substitui o controle técnico canônico do projeto.

> Regra de uso: este arquivo é fonte de escopo operacional. Nenhum executor deve receber todo este documento como tarefa única. As tarefas devem ser quebradas em etapas curtas, com commit/push ao final de cada etapa.

---

## 1. Objetivo central

Finalizar e estabilizar o fluxo principal do sistema:

```txt
Agenda -> Agendamento -> Cliente -> Anamnese -> Ficha Cliente -> Ficha Profissional -> Comanda -> Financeiro -> Mensageria / Pós-atendimento
```

A Agenda deve funcionar como o cockpit operacional do negócio. Tudo que envolve um agendamento precisa ser confiável, fluido, premium, responsivo e coerente: cliente, anamnese, ficha profissional, comanda, checkout, pós-atendimento e mensagens.

O objetivo imediato não é criar módulos paralelos nem iniciar integrações grandes. O objetivo é terminar corretamente o fluxo da Agenda e organizar o backlog para que nada seja perdido.

---

## 2. Princípios obrigatórios de execução

1. **Não enviar escopo gigante para executor.** Claude e Codex devem receber etapas curtas, objetivas e validáveis.
2. **Commit pequeno por etapa.** Cada conclusão deve gerar commit e push. Isso evita perder trabalho quando expira janela de execução/tokens.
3. **Não misturar naturezas diferentes no mesmo commit.** Separar UX, backend, migrations, regras financeiras, legal/privacy, mensageria e integrações.
4. **Nada de remendo.** Toda instrução deve ser analisada com visão senior antes de execução.
5. **Visual premium e padronizado.** Design, fonte, paleta, menus, botões, cards, tabelas, modais e drawers devem parecer um produto único, não telas soltas.
6. **Mobile 390px e desktop 1440px são critérios mínimos de validação visual.**
7. **Preservar contexto de navegação.** O usuário deve voltar para onde estava, não ser jogado para telas iniciais.
8. **Pesquisa legal/fiscal antes de implementar.** Termos de privacidade, consentimentos, pagamentos e sinal antecipado não devem ser implementados como definitivos sem validação prévia.
9. **Não desperdiçar Claude com organização.** ChatGPT mantém o escopo; Claude executa UX/UI; Codex executa código técnico/backend/testes.

---

## 3. Responsabilidades por executor

### ChatGPT / Orquestração

- Organizar escopo completo.
- Quebrar em fases.
- Preparar prompts curtos para Codex/Claude.
- Validar coerência de produto antes de execução.
- Fazer pesquisas legais/fiscais quando necessário.
- Apontar riscos, decisões pendentes e recomendações de contorno.
- Manter este documento atualizado quando surgirem novas decisões.

### Codex

Usar para:

- backend;
- migrations;
- RPC;
- data model;
- validações;
- regras de negócio;
- navegação/estado técnico;
- testes;
- integrações;
- mensageria técnica;
- pagamentos, apenas após decisão.

### Claude

Usar para:

- UX/UI;
- layout premium;
- design system;
- responsividade;
- padronização visual;
- repaginação de telas;
- organização de menus, cards, seções e fluxos visuais.

Claude não deve receber escopo gigante misturado. Deve receber uma fase curta, com objetivo visual claro e validação.

---

## 4. Vocabulário obrigatório do produto

Usar estes termos no sistema, em prompts e em documentação:

- **Anamnese**: objeto clínico vinculado ao atendimento/agendamento/comanda.
- **Ficha Cliente**: parte da anamnese preenchida e assinada pelo cliente.
- **Ficha Profissional**: parte profissional da mesma anamnese, habilitada ou desabilitada na gestão/criação da ficha.
- **Comanda**: contexto de venda/checkout vinculado ao atendimento.
- **Atendimento / Agendamento**: evento operacional na Agenda.

Modelo correto:

```txt
Anamnese vinculada ao atendimento/comanda
├─ Ficha Cliente
└─ Ficha Profissional, se habilitada
```

Regras conceituais:

- Não tratar Ficha Profissional como entidade solta.
- Não tratar Ficha Profissional como item criado pela Comanda.
- A opção de habilitar Ficha Profissional pertence à gestão/criação da anamnese, na tela de Anamnese.
- A Comanda apenas consulta se há pendência obrigatória antes de finalizar.
- Se houver Ficha Cliente com Ficha Profissional habilitada, ambas pertencem à anamnese vinculada ao atendimento/comanda.
- Sempre separar visualmente e textualmente os termos **Ficha Cliente** e **Ficha Profissional**.

---

## 5. Registro completo das observações e requisitos do Alexandre

Esta seção registra tudo que foi apontado para não se perder.

### 5.1 Organização e execução

- O escopo precisa estar documentado antes de enviar etapas para Claude ou Codex.
- Não enviar prompts longos demais para Claude, porque há risco de execução resumida, parcial ou desorganizada.
- ChatGPT deve agir como orquestrador, ditando etapas depois.
- Claude deve ser preservado para desenvolvimento/UX/UI real, não para organizar backlog.
- Como agora há créditos no Codex novamente, Codex pode ser usado quando a tarefa for técnica.
- Cada etapa de Claude/Codex deve ser curta, com commit/push após conclusão.
- Se a janela de execução expirar, deve haver commit parcial coerente para validação.
- Antes de qualquer próxima execução, validar se tudo está documentado.

### 5.2 Padrão visual global do sistema

Observação:

- As telas do sistema têm menus e formatos diferentes.
- Falta um padrão único, premium e consistente.
- Isso deve ficar registrado para evolução futura e não acumular bagunça.

Requisitos:

- Todos os menus das telas devem seguir um padrão visual/comportamental único.
- Botões, CTAs, cards, headings, tabelas, filtros, drawers, modais e footers devem seguir o mesmo design system.
- A Agenda é exceção de layout por ser calendário, mas deve obedecer paleta, fonte, densidade, menus e hierarquia para não virar um “circo”.
- Usar visão premium: limpo, elegante, profissional, sem poluição, sem excesso de cores, sem padrões conflitantes.
- Toda instrução visual deve ser validada com visão senior para evitar remendos.

### 5.3 Cliente / cadastro / edição

Observações:

- Tela de cliente ficou sem rolagem no mobile.
- Tela de edição de cliente ainda teve quebra visual.
- Cadastro atual ainda parece pouco adaptado à Europa/Espanha.
- Campo CPF isolado não serve como padrão global.
- Telefone precisa considerar país/DDI.

Requisitos:

- Tela de criar/editar cliente deve funcionar integralmente no mobile 390px.
- Modal/drawer precisa ter rolagem até o final.
- Footer não pode bloquear campos.
- Não pode haver overflow horizontal.
- Nome obrigatório.
- Telefone obrigatório.
- Documentação pessoal deve ser adaptada para região:
  - DNI;
  - NIE;
  - NIF;
  - Pasaporte;
  - CPF;
  - Outro.
- Ideal: campo `tipo de documento` + campo `número do documento`.
- Telefone deve ter país/DDI separado ou seletor com padrão +34 Espanha, mas permitir outros países.
- O sistema deve considerar Espanha/Europa como região primária atual, mas ser adaptável a Portugal, Brasil e futuro uso global.

### 5.4 Dados da Ficha Cliente versus cadastro do cliente

Observação:

- Nos PDFs de anamnese são pedidos dados como documento pessoal, endereço, telefone, nome e outros, inclusive por segurança clínica.
- O cliente pode preencher dados errados.
- Não é seguro refletir automaticamente tudo no cadastro do cliente.

Requisitos:

- Dados preenchidos na Ficha Cliente devem ficar registrados na anamnese.
- Esses dados não devem sobrescrever automaticamente o cadastro sem validação profissional.
- O profissional pode validar dados faltantes ou divergentes antes de concluir atendimento/comanda.
- O sistema deve apontar campos faltantes relevantes, mas sem virar um processo enorme.
- Fluxo ideal a avaliar:
  - cliente preenche dados na Ficha Cliente;
  - sistema mostra diferenças/faltas em relação ao cadastro;
  - profissional valida/aceita atualização ao concluir Ficha Profissional ou atendimento;
  - cadastro é atualizado somente após confirmação.

### 5.5 Anamnese — estrutura correta

Observações:

- A opção de Ficha Profissional citada é na criação/gestão da anamnese, não na comanda.
- Ficha Cliente e Ficha Profissional devem ser gerenciadas na tela de Anamnese.
- Se criar Ficha Cliente, pode haver flag para habilitar Ficha Profissional.
- As fichas atuais estão boas conceitualmente, mas precisam de melhor gerenciamento e navegação.

Requisitos:

- Tela de Anamnese é onde se criam e gerenciam fichas.
- Na gestão/criação da Ficha Cliente deve existir opção/flag para habilitar Ficha Profissional.
- Se habilitada, a Ficha Profissional passa a fazer parte da mesma anamnese.
- A gestão deve permitir:
  - visualizar Ficha Cliente;
  - visualizar Ficha Profissional;
  - editar Ficha Cliente quando permitido;
  - editar Ficha Profissional;
  - salvar rascunho da Ficha Profissional;
  - concluir Ficha Profissional;
  - reabrir/retificar quando permitido;
  - identificar pendências.
- A Comanda apenas verifica status/pendência para permitir ou bloquear finalização.

### 5.6 Anamnese — navegação visual Cliente/Profissional

Observação:

- Na visualização/preenchimento, o profissional precisa rolar até o final para encontrar sua parte.

Requisitos:

- A visualização da anamnese deve ter menu/abas/seções claras:
  - **Ficha Cliente**;
  - **Ficha Profissional**.
- O profissional deve acessar a Ficha Profissional rapidamente, sem rolar até o final.
- A navegação deve facilitar leitura e edição.
- A UX deve ser premium e padronizada com o restante do sistema.

### 5.7 Anamnese — idioma

Observações:

- Textos e respostas da anamnese devem ter o mesmo idioma.
- Não pode haver mistura de português, espanhol e inglês na mesma ficha.

Requisitos:

- O idioma da ficha deve controlar:
  - textos;
  - labels;
  - perguntas;
  - respostas;
  - botões;
  - recibo;
  - consentimentos.
- Exemplo: ficha em espanhol deve usar respostas em espanhol, como “Sí/No”, não “Sim/Não” ou “YES/NO”.
- Ao criar a ficha, escolher template/idioma adequado.
- Se houver idioma preferido no cliente, usar como sugestão.
- Se não houver, usar espanhol como padrão da operação atual.
- Não usar idioma do navegador como regra principal.

### 5.8 Anamnese — recibo da Ficha Cliente preenchida

Observação:

- O recibo de ficha preenchida do cliente deve conter tudo que ele preencheu.

Requisitos:

- Recibo/visualização final da Ficha Cliente deve exibir:
  - dados pessoais preenchidos;
  - documento;
  - endereço, se solicitado;
  - telefone;
  - respostas clínicas;
  - consentimentos;
  - autorização de uso de imagem;
  - assinatura;
  - data/hora;
  - idioma;
  - vínculo com cliente e agendamento/comanda quando houver.
- O recibo deve ser legível, premium e organizado.

### 5.9 Anamnese — consentimento de uso de imagem

Observação:

- Autorização de uso de imagem deve ter consentimento separado.
- Cliente às vezes marca “não”.
- Isso deve ficar destacado para o profissional.

Requisitos:

- Uso de imagem deve ter opção separada:
  - Sim;
  - Não.
- Não pode ficar implícito no termo geral.
- Se o cliente marcar “não”, isso deve aparecer como alerta ou destaque no atendimento/anamnese.
- Profissional precisa ver claramente:
  - “Uso de imagem autorizado”;
  - ou “Uso de imagem não autorizado”.

### 5.10 Anamnese — assinatura e dados vinculados

Observação:

- No final da ficha, o sistema exibe nome do cliente.
- Isso deve ser vinculado à ficha, conforme o cadastro/agendamento.
- Cliente deve preencher dados restantes necessários.

Requisitos:

- Nome exibido na assinatura deve estar ligado ao cliente/ficha correspondente.
- Se o cliente já existe, pré-preencher dados conhecidos.
- Se faltam dados obrigatórios para segurança clínica, o cliente deve completar.
- Se o cliente preencher divergente do cadastro, não atualizar automaticamente sem validação.
- Ficha deve preservar o que foi preenchido no momento da assinatura.

### 5.11 Anamnese — edição de ficha preenchida

Observação:

- Ficha de anamnese preenchida deve poder ser corrigida se houver erro.
- Evitar obrigar cliente/profissional a criar nova ficha do zero para erro simples.
- Evitar acúmulo de fichas erradas sem controle do motivo.

Requisitos/recomendação a validar tecnicamente:

- Ficha Cliente pendente: edição livre.
- Ficha Cliente assinada: permitir correção com regra segura, como:
  - editar com motivo/auditoria;
  - retificar;
  - criar nova versão;
  - arquivar/cancelar ficha errada com motivo.
- Não apagar evidência clínica sem rastro.
- Ficha Profissional em rascunho: editável.
- Ficha Profissional concluída: reabrir/editar apenas por ação explícita e preferencialmente com registro.
- Se comanda já finalizada, alteração deve ter regra mais restritiva.

### 5.12 Proteção de dados / termos legais

Observações:

- O termo LGPD é do Brasil.
- Para Espanha/Europa, deve-se avaliar nome e regra adequada.
- Sistema está sendo usado primeiro na Europa/Espanha, mas deve ser adaptável a Espanha, Portugal, Brasil e futuramente global.
- Se houver diferenças por país, deve haver versão de termo por país/jurisdição.
- Antes de repassar para execução, ChatGPT deve validar e apontar mudanças/riscos para decisão.

Requisitos:

- Não usar “LGPD” como termo global padrão.
- Prever termos por jurisdição:
  - Espanha/União Europeia: RGPD/GDPR + legislação espanhola aplicável;
  - Portugal/União Europeia: RGPD/GDPR + eventuais ajustes locais;
  - Brasil: LGPD;
  - Global/futuro: template configurável por jurisdição.
- Consentimentos devem ser separados por finalidade quando necessário.
- Dados de saúde/estética clínica devem ser tratados como sensíveis ou de cuidado reforçado conforme jurisdição aplicável.
- Termo longo deve ter melhor UX:
  - resumo curto visível;
  - expandir/recolher;
  - ou clique abre/fecha detalhes.
- ChatGPT deve fazer pesquisa legal atualizada antes de recomendar texto final.
- Nenhum texto legal final deve ser implementado “às cegas”.

### 5.13 Comanda / checkout / layout Fresha

Observações:

- Comanda atual está poluída.
- Cliente, comanda, itens adicionais, ajustes e checkout estão misturados visualmente.
- Preferência: layout estilo Fresha dos prints, com cliente/contexto de um lado e comanda/pagamento do outro.
- Checkout tem muita informação e está desorganizado visualmente.

Requisitos:

- Comanda deve ser fluida, premium e organizada.
- Separar visualmente:
  - cliente/contexto;
  - Ficha Cliente/Ficha Profissional/anamnese;
  - itens da comanda;
  - produtos/adicionais;
  - descontos/gorjeta/taxa;
  - pagamento;
  - total;
  - ações.
- Desktop inspirado no Fresha:
  - cliente/contexto à esquerda;
  - comanda/itens/pagamento à direita.
- Mobile deve ser claro e utilizável.
- Ação primária deve ser óbvia.
- Ações secundárias em menu padronizado.
- Não alterar regra financeira ao fazer UX.

### 5.14 Navegação e preservação de contexto

Observações:

- Botão voltar às vezes volta para telas iniciais, prejudicando navegabilidade.
- Ao clicar em “editar parte profissional” na comanda, abre anamnese redirecionando para tela de anamnese; deveria permanecer em modo comanda ou voltar para comanda.
- Sistema deve manter registro do último passo/retorno.

Requisitos:

- O sistema deve preservar contexto de navegação.
- “Voltar” deve retornar para onde o usuário estava.
- “Fechar” deve ser ação separada quando fechar drawer/modal/comanda.
- Casos obrigatórios:
  - Comanda -> Ficha Profissional -> voltar para Comanda;
  - Agenda -> Anamnese -> voltar para Agendamento;
  - Agenda -> Comanda -> voltar interno sem sair da Comanda;
  - Recibo -> voltar para Comanda em modo leitura, não fechar direto para Agenda;
  - Cliente -> nova reserva -> manter cliente/contexto.
- Sempre que possível, abrir em painel/modal/drawer contextual em vez de navegar para tela geral.
- Se for necessário navegar, passar `returnTo` ou estado equivalente.

### 5.15 WhatsApp / envio de anamnese

Observação:

- Na Comanda ou fluxo de atendimento, deve haver opção de enviar ficha de anamnese por WhatsApp quando houver telefone preenchido.

Requisitos:

- Botão/ação “Enviar anamnese por WhatsApp” quando telefone existir.
- Deve usar telefone do cliente com DDI correto.
- Se telefone não existir, orientar cadastrar telefone.
- Se botão for placeholder, deixar claro que não envia de verdade.
- Futuramente integrar com módulo de mensageria.

### 5.16 Mensageria futura

Observação:

- Avaliar se já existe ou não escopo de mensageria.
- Organizar devidamente.

Mensagens desejadas:

- mensagem de agendamento feito;
- lembrete de agendamento;
- parametrização de quanto tempo antes enviar lembrete;
- agradecimento de atendimento concluído;
- agradecimento com ou sem link de avaliação;
- link integrado ao Google Reviews;
- mensagem de aniversário;
- recuperação de clientes inativos;
- mensagens de oferta/campanha;
- outras mensagens operacionais futuras.

Requisitos:

- Mensageria deve ser módulo próprio futuro, integrado à Agenda/Cliente/Comanda.
- Templates configuráveis.
- Parametrização de envio.
- Não enviar mensagens acidentalmente.
- Log/auditoria de envio.
- Integração Google Reviews deve ser configurável.

### 5.17 Pagamento / sinal antecipado / fiscalidade

Observação:

- Avaliar se existe escopo de integração com meio de pagamento europeu.
- Interesse em cobrar sinal antecipado.
- Deve analisar método que gere menor ou nenhuma declaração na Espanha, pois não há residência fiscal espanhola.

Requisitos:

- Não implementar agora sem pesquisa.
- ChatGPT deve pesquisar antes de recomendar.
- Avaliar opções como possibilidade, não decisão:
  - Stripe;
  - SumUp;
  - PayPal;
  - Revolut Business;
  - Wise Business;
  - transferência;
  - link de pagamento;
  - outras soluções locais/europeias.
- Avaliar:
  - disponibilidade;
  - taxa;
  - integração;
  - fiscalidade;
  - impacto na Espanha;
  - residência fiscal;
  - comprovantes;
  - vínculo com comanda;
  - risco operacional/legal.
- Não escolher fornecedor sem decisão formal.

---

## 6. Backlog por fases

### Fase 1 — Bugs bloqueantes e navegação estrutural

Executor ideal: Codex.

Escopo:

- Corrigir rolagem e layout mobile do cadastro/edição de cliente.
- Garantir 390px sem quebra.
- Nome e telefone obrigatórios.
- Corrigir voltar/fechar da Comanda.
- Preservar retorno contextual Comanda -> Ficha Profissional -> Comanda.
- Mostrar status da anamnese no painel do Agendamento sem descoberta escondida.
- Garantir status de Ficha Cliente e Ficha Profissional no painel.

Critérios de aceite:

- Cliente cria/edita no mobile até o final.
- Comanda tem “Voltar” interno e “Fechar comanda” separado.
- Ficha Profissional aberta a partir da Comanda retorna para Comanda.
- Painel do Agendamento mostra Ficha Cliente e Ficha Profissional.

### Fase 2 — UX da Anamnese / Ficha Cliente / Ficha Profissional

Executor ideal: Claude para UX; Codex se exigir regra/auditoria/backend.

Escopo:

- Repaginar visualização de anamnese.
- Criar navegação Ficha Cliente / Ficha Profissional.
- Tornar Ficha Profissional fácil de acessar e editar.
- Recibo completo da Ficha Cliente.
- Consentimento separado de uso de imagem.
- Idioma consistente.
- Área/filtro de Fichas Profissionais pendentes.
- UX para edição/retificação.

Critérios de aceite:

- Profissional não precisa rolar até o final para acessar sua ficha.
- Recibo mostra tudo que cliente preencheu.
- Uso de imagem Sim/Não destacado.
- Sem idioma misturado.
- Pendências profissionais fáceis de encontrar.

### Fase 3 — Comanda premium estilo Fresha

Executor ideal: Claude.

Escopo:

- Redesenhar layout visual da Comanda.
- Separar cliente/contexto de comanda/pagamento.
- Reduzir poluição visual.
- Manter regras financeiras intactas.
- Preservar contexto de navegação.

Critérios de aceite:

- Layout desktop claro.
- Mobile utilizável.
- Cliente/contexto não se mistura com pagamento/itens.
- CTA principal evidente.
- Menus secundários padronizados.

### Fase 4 — Padronização visual global

Executor ideal: Claude.

Escopo:

- Auditar menus, botões, cards, tabelas, filtros, forms, modais e drawers.
- Padronizar telas principais.
- Manter Agenda com layout próprio, mas coerente.

Critérios de aceite:

- Sistema parece um produto único.
- Menus têm padrão único.
- Mobile consistente.
- Design premium.

### Fase 5 — Pesquisa e arquitetura de privacidade/jurisdição

Executor: ChatGPT pesquisa primeiro; depois Codex/Claude.

Escopo:

- Pesquisar regras Espanha/UE, Portugal/UE e Brasil.
- Revisar termo atual.
- Propor modelo por jurisdição.
- Separar consentimentos por finalidade.
- Definir termo adequado para proteção de dados, evitando “LGPD” como global.

Critérios de aceite:

- Riscos legais apontados antes de implementar.
- Recomendação documentada.
- Textos finais só depois de validação.

### Fase 6 — Mensageria

Executor ideal: Codex para lógica; Claude para UX.

Escopo:

- Envio de anamnese por WhatsApp.
- Confirmação de agendamento.
- Lembrete parametrizável.
- Pós-atendimento.
- Google Reviews.
- Aniversário.
- Inativos.
- Campanhas/ofertas.

Critérios de aceite:

- Templates configuráveis.
- Envio controlado.
- Log/auditoria.
- DDI/telefone correto.

### Fase 7 — Pesquisa de pagamentos/sinal antecipado

Executor: ChatGPT pesquisa primeiro; Codex só depois.

Escopo:

- Pesquisar soluções de sinal antecipado.
- Avaliar fiscalidade, residência, taxas e integração.
- Recomendar caminho antes de qualquer implementação.

Critérios de aceite:

- Nenhum provedor implementado sem decisão.
- Riscos fiscais/operacionais claros.

---

## 7. Decisões abertas

1. Como editar Ficha Cliente assinada: edição direta auditada, retificação, nova versão ou arquivamento com motivo.
2. Como validar dados preenchidos pelo cliente antes de atualizar cadastro.
3. Como configurar jurisdição/país da clínica/tenant.
4. Texto legal adequado para Espanha/UE, Portugal/UE e Brasil.
5. Solução de pagamento/sinal antecipado.
6. Provedor de mensageria/WhatsApp.
7. Padrão final de navegação contextual (`returnTo`, drawer, modal ou rota).
8. Padrão visual final para menus globais.

---

## 8. O que não fazer agora

- Não enviar este documento inteiro a Claude/Codex como tarefa única.
- Não implementar mensageria completa agora.
- Não implementar pagamento/sinal agora.
- Não finalizar termos legais sem pesquisa.
- Não redesenhar todo o sistema em uma rodada.
- Não criar novos módulos fora do fluxo Agenda.
- Não apagar evidência clínica sem regra e auditoria.

---

## 9. Próxima ação após validação deste documento

Somente depois de Alexandre validar este escopo, preparar um prompt curto da Fase 1 para o executor adequado.

Recomendação atual:

- **Codex** para Fase 1, porque envolve navegação, estado, cliente, anamnese e comanda.
- **Claude** somente depois para Fase 2/3, focado em UX/UI premium.
