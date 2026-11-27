# Spec 43 · WhatsApp: três frentes (API oficial, MCP da Meta e QR)

Status: implementado como base (30/10/2026) · Pedido da Karenn: "começar já pela possibilidade do QR code, como se fosse um navegador web, e ir amadurecendo o módulo".
Rota: `/[org]/mensagens/canais` · Permissão: `mensagens.configure`.

## 0. As três frentes (mapa)

| Frente | O que é | Servidor próprio | Estado |
|---|---|---|---|
| **API oficial (Cloud API)** | O sistema envia e recebe avisos pela Meta. Código em `src/lib/messaging/meta-cloud.ts` e webhook `/api/webhooks/whatsapp` (assinado, atualiza entregue/lido/falhou no registro). | Não (roda na Vercel) | Implementada; liga com variáveis de ambiente. Conta de teste da Meta: grátis, até 5 telefones. |
| **MCP da Meta** (beta desde 15/09/2026) | Ferramenta para configurar: criar conta, registrar número, modelos, webhook, enviar teste. Não é o canal do sistema. | Não | Uso por mim/pela dona via Claude durante a configuração. Exige admin da empresa e do app, termos da API aceitos. |
| **QR (WAHA)** | Sessão tipo WhatsApp Web. | Sim, 24 h | Implementada (seções abaixo); opcional. |

Coexistência (app Business + API no mesmo número, Brasil e Espanha) é a forma de ligar o número já usado pela Karenn à API oficial; confirmada por número no onboarding da Meta. `messaging_connections.provider` guarda a frente ativa do estúdio (`meta_cloud` | `waha_qr`).

Variáveis da API oficial: `WHATSAPP_CLOUD_TOKEN`, `WHATSAPP_PHONE_NUMBER_ID`, `WHATSAPP_VERIFY_TOKEN`, `WHATSAPP_APP_SECRET`, opcional `META_GRAPH_VERSION`.

## 1. Escopo da frente QR

- Conectar o número do estúdio lendo um código no celular (Aparelhos conectados › Conectar aparelho).
- Mostrar o estado em tempo quase real: Não conectado · Iniciando · Aguardando leitura · Conectado · Falhou.
- Desconectar e gerar outro código.
- Enviar uma mensagem de teste; todo envio grava uma linha em `messaging_provider_log` (sucesso ou falha).
- Sem servidor configurado, a tela explica e continua funcionando (botão de WhatsApp da cliente abre o app no celular).

Fora do escopo agora: caixa de conversas (receber mensagens), lembretes automáticos pela sessão, campanhas em massa, envio de mídia.

## 2. Arquitetura

O WhatsApp Web mantém uma conexão longa e viva. A Vercel (funções sem estado, curtas) não consegue hospedar isso. Por isso o sistema fala com um **servidor WAHA** (WhatsApp HTTP API, código aberto) que roda à parte, 24 h, e guarda a sessão.

```
Navegador ─ Server Action ─▶ src/lib/messaging/waha.ts ─ HTTPS + X-Api-Key ─▶ WAHA ─▶ WhatsApp
                 └─▶ Supabase: messaging_connections, messaging_provider_log
```

- A chave e o endereço ficam só no servidor: `WAHA_URL`, `WAHA_API_KEY`, `WAHA_SESSION_MODE` (`single` padrão | `per_org`).
- O navegador nunca fala com o WAHA. O QR chega como imagem (data URL) pela Server Action.
- Falha de rede vira estado "Falhou" com mensagem; nada na agenda, checkout ou clientes depende do WhatsApp.
- `messaging_connections` guarda só o estado (status, telefone, nome, horários). Uma linha por estúdio e canal. RLS por `org_id`.

### Sessão única ou por estúdio
`single`: uma sessão (`default`) serve o único estúdio atual (Karenn). `per_org`: nome da sessão derivado do `org_id`, para quando o sistema atender várias clínicas. O nome é calculado em `sessionNameFor` (domínio, testado).

## 3. Fluxo da tela

1. Escolher "QR, tipo WhatsApp Web" em Canais.
2. **Gerar código**: a ação inicia a sessão (cria se não existir) e o painel passa a consultar o estado a cada 3 s.
3. Estado **Aguardando leitura**: o servidor devolve o QR; ele vale ~20 s (o primeiro, 60 s) e é renovado pela própria consulta.
4. Ao ler, o estado vira **Conectado**: mostra número e nome, selo verde, campo de teste e **Desconectar**.
5. Sair da tela para a consulta. Voltar lê o estado salvo e atual.

Cópia obrigatória na tela: "Não é a conexão oficial: o WhatsApp pode bloquear o número…" (`WHATSAPP_QR_WARNING`).

## 4. Riscos e regras

- **Não oficial.** A Meta pode restringir ou banir números que usam automação. Recomendação: número exclusivo do estúdio (WhatsApp Business), envio só a clientes que já conversam com o estúdio, sem mensagens em massa, volume baixo, celular com internet.
- Números do Brasil: o identificador de conversa deve vir da verificação de número (`check exists`) por causa do nono dígito; `whatsappChatId` cobre o formato internacional geral e a verificação entra junto com o envio automático.
- Dados: o conteúdo enviado fica em `messaging_provider_log` (retenção e consentimento seguem a spec de privacidade).
- Caminho oficial depois: WhatsApp Business Platform (Cloud API) ou coexistência com o app. A tabela já tem `provider` (`waha_qr` | `meta_cloud`) para trocar sem perder histórico.

## 5. O que a Karenn precisa providenciar

1. Um servidor para o WAHA (VPS pequeno, 1 GB já serve; Docker). O WAHA Core grátis atende uma sessão.
2. Definir na Vercel: `WAHA_URL` (https), `WAHA_API_KEY`, opcional `WAHA_SESSION_MODE`.
3. Um número de WhatsApp Business dedicado ao estúdio.

## 6. Testes

- Vitest: `messaging-provider.test.ts` (mapa de estados, nome de sessão, telefone internacional).
- pgTAP 147: RLS e unicidade de `messaging_connections`.
- E2E: a tela de Canais abre sem servidor configurado (estado "Não conectado", opção Oficial visível).

## 7. Próximos passos de maturidade

Receber mensagens (webhook) e caixa de conversas · lembretes de agendamento pela sessão com limite diário · verificação de número · mídia · alerta quando a sessão cair · migração para a API oficial.
