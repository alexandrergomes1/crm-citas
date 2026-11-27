# Spec 28 — Navegação: Fechar em toda tela, Marketing único e Ajustes com equipe

## Goal
Menus previsíveis: toda tela tem Fechar e Voltar, cada assunto mora num único lugar e a Agenda age direto no horário.

## Regras
1. **Fechar em toda tela (celular):** `MobileHeader` mostra X ("Fechar e voltar": volta ao histórico; sem histórico, vai à Agenda) além do voltar `leading` das telas internas. Só a Agenda (casa do app) fica sem X. Guard no E2E de layout.
2. **Ajustes reúne a equipe:** Profissionais, Acessos e Perfis e liberações são seções de Ajustes (`/configuracoes/equipe|acessos|perfis`); "Equipe" sai do menu principal; as URLs antigas `/equipe*` redirecionam.
3. **Marketing é um só menu:** áreas **Mensagens** (conversas, modelos, automações, histórico, canais — WhatsApp e e-mail), **Campanhas**, **Avaliações** e **Fidelidade**. Cada área mantém a rota (`/mensagens`, `/marketing/campanhas`, `/marketing/avaliacoes`, `/fidelidade`); `/marketing` abre a primeira área liberada. Painel (≥1280): grupo das áreas + grupo das seções da área aberta; celular/tablet: controle das áreas + chips das seções. Áreas respeitam módulo do plano e permissão. O atalho antigo "Mensagens" da barra inferior vira "Marketing".
4. **Produtos e planos moram no Catálogo:** Serviços, Pacotes, Produtos, Combos e Planos são seções do Catálogo (painel e celular). "Produtos e planos" sai do menu "Anterior".
5. **Agenda age no horário:** seletor de profissionais na barra (Dia: várias ou "Toda a equipe"; Semana e 3 dias: uma); clique/toque num horário vazio abre **Novo agendamento** ou **Bloquear horário** (já com dia, hora e profissional); botão **Bloquear horário** visível (no celular, chip "Bloquear"). Em notebook estreito, "Bloquear horário" e a busca da barra somem para "Novo agendamento" caber (continuam no menu Opções e no horário vazio).

6. **Perfis personalizados (Lote 3):** em Ajustes › Perfis e liberações a dona cria perfis do estúdio ("Recepção sênior") baseados num perfil do sistema, liga/desliga liberações por perfil e apaga o perfil (quem o tinha volta a valer pelo perfil-base). Em Ajustes › Acessos cada pessoa troca de perfil (sistema ou do estúdio); o novo acesso também oferece os perfis do estúdio. Modelo: tabelas `org_profiles` e `org_profile_permissions` (RLS por `org_id`), `user_roles.profile_id`; o papel-base continua gravado em `user_roles.role`, então as políticas RLS por papel seguem valendo. As exceções do perfil valem onde `has_permission()` é usado (mesma limitação das liberações por papel). Administração só é concedida por proprietária/administração; ninguém troca o próprio perfil.

## Fora desta spec
Fidelidade completa (`docs/product/fidelidade-mapa-futuro.md`), multi-idioma (`docs/architecture/i18n-multiidioma.md`).

## Aceite
- [x] Toda tela do celular (menos Agenda) tem "Fechar e voltar".
- [x] Equipe/Acessos/Perfis só dentro de Ajustes.
- [x] Marketing único com as quatro áreas; menu principal sem Mensagens/Fidelidade/Campanhas soltos.
- [x] Catálogo com Produtos/Combos/Planos no celular.
- [x] Perfis personalizados: criar, configurar, apagar e atribuir (teste de banco 142).
- [x] Agenda: seletor, ações no horário e botão de bloqueio; Novo agendamento visível em 1024/1280/1366.
