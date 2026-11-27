# Revisão geral — 30/10/2026

Cruza o que está entregue (código, specs, migrations) com os documentos do projeto, o sistema antigo (V3 e requisitos da Karenn) e o mercado (Fresha, Booksy). Relatórios completos dos levantamentos ficaram na sessão; este documento guarda a conclusão e a ordem de trabalho. Atualize-o quando um item fechar.

## Premissa de mercado
A operação da Karenn é em **Benalmádena / Málaga (Espanha)**, em euro, equipe brasileira. O app interno é pt-BR; clientes podem ser es/en/pt. Emissão fiscal está **fora do escopo** por decisão do dono (foco: deixar o sistema pronto para uso).

## Estado por módulo (resumo)
- **Entregue (M2):** agenda, checkout/comandas, equipe/comissões, configurações, perfis/acessos (agora com perfis do estúdio), navegação padronizada (Fechar em toda tela, Marketing único, Equipe em Ajustes).
- **Parcial:** clientes (falta LGPD/RGPD: anonimizar, exportar), catálogo (Produtos/Combos/Planos e Caixa/Relatórios/DRE ainda no desenho antigo), pagamentos (só transferência com comprovante), anamnese (cópia por e-mail, validação no banco, E2E do Modo estúdio), mensagens/marketing (telas sem motor de envio), fidelidade (só pontos/níveis), estoque (baixa no checkout, sem compras/fornecedores), admin SaaS (tabelas sem tela).
- **Só spec:** agendamento online (specs 16, 38, 39), caixa com abertura/fechamento (32). **Ausente:** Google/Meta (19).

## P0 — antes de receber clientes reais
1. **Importar da Fresha** (spec 34): só depois de tudo funcional (decisão do dono). Hoje só há CSV de clientes.
2. **Backup e restauração** do Supabase (fichas assinadas são dado de saúde; plano Free não tem backup gerenciado): rotina agendada + teste de restauração.
3. **Segurança das rotas públicas:** limite de requisições em `/forms` e `/pagar`, erros genéricos, token de anamnese só em hash, senhas vazadas no Auth.
4. **Catálogo real da Karenn:** o seed não bate com o PDF (faltam Neutralización/Revitalización labial, Diseño de cejas em 4 variantes, depilação com linha, microneedling, laser; preços divergem em Dermaplaning e Laminado). Confirmar o que está em produção.
5. **E2E dos fluxos críticos** (criar agendamento pela tela, financeiro, ficha da profissional, Modo estúdio com PIN) e RPCs de agregação (relatórios cortam em 1000 linhas).
6. **Higiene de docs:** `docs/product-scope.md` e `docs/specs/index.md` são citados e não existem; `scope-master`, gap-map e gate do roadmap estão velhos; duas specs 28; remover `/booking` do proxy até existir a rota.

## P1 — o que faz o sistema "valer" para a Karenn
1. **Motor de mensagens (WhatsApp):** go-live com envio manual e log honesto ("aberto no WhatsApp"); depois fila idempotente (confirmação, lembrete com resposta, ficha 48 h antes, cuidados pós, retoque, saudade) e caixa de conversas. Decisão aberta: API oficial da Meta direta ou BSP; e-mail; risco de banimento no modo QR. Registrar custo por mensagem desde o início (Meta cobra por mensagem).
2. **Política de sinal e falta aplicada na reserva:** janela por serviço, taxa/sinal automático, contador de faltas por cliente.
3. **Galeria antes/depois** (prioridade nº 1 do negócio): comparador, linha do tempo por sessão, exportação respeitando o consentimento de imagem.
4. **Retorno por procedimento:** intervalo mínimo entre sessões e gatilho de retoque/renovação pela durabilidade; alimenta a automação de "saudade".
5. **Lista de espera que se resolve sozinha** (cancelou → oferece por WhatsApp), em cima da lista de espera já entregue.
6. **RGPD operacional:** anonimizar/exportar/reter, consentimentos granulares (imagem em aceite separado), retificação por nova versão, tela de auditoria, revisão jurídica ES/PT dos termos.
7. **Avaliações no Google:** link, modo e regra de 90 dias.
8. **Migrar para o desenho V25:** Produtos/Combos/Planos, Caixa, Vales, Saldos, Relatórios, DRE.
9. **Financeiro:** quitar débito anterior, cupom/recibo, comissão com mais de uma profissional na comanda, fechamento de comissão por período, atomicidade de pontos/pacotes.
10. **Agenda mobile da recepção:** lista de ações, desfazer, PWA com push.
11. **Alinhar `MODULE_KEYS`** (reserva, estoque, relatórios, unidades) com o que existe de fato.

## P2 — crescimento
Agendamento online sem comissão (spec 38; precisa de `booking_source` imutável e rota `/b/[slug]`), gateway de pagamento, fidelidade com recompensas, compras/fornecedores, Google/Meta, admin SaaS e cobrança, caixa com abertura/fechamento, memberships recorrentes, multi-unidade (tabela `locations` sem UI), i18n do app interno (en/es — ver `docs/architecture/i18n-multiidioma.md`), limpar `/dev/*` e redirects legados, marketplace (spec 39).

## Diferenciais a proteger
Anamnese que bloqueia o início sem ficha assinada; perfis customizáveis com "só minha agenda" na RLS; WhatsApp como canal central; RGPD de ponta a ponta; zero comissão sobre cliente própria. Fresha cobra marketplace (~20% da 1ª visita) e fidelidade como add-on; Booksy não cita WhatsApp.

## Pontos de atenção
- Não foram lidos nesta passada: `karenn-site-*`, SEO, modelo de hospedagem/anúncios, geradores e estudo do Google. Fazer segunda passada antes de fechar o backlog de crescimento.
- Artigos da Fresha foram lidos em índice em parte dos temas; a coluna Fresha do benchmark reflete isso.
