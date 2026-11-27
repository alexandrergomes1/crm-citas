# Spec 47 — Login e autenticação (estudo + tela no padrão Fresha)

Status: estudo concluído e fase 0 implementada (31/10/2026). Fases 1 a 3 dependem de credenciais do responsável.
Fontes: documentação oficial do Supabase (Auth, passkeys, MFA, limites, preços), Clerk, Resend e Better Auth, lidas em 31/10/2026. **Preços, limites e estado "experimental" mudam: confira cada número abaixo na página oficial antes de decidir ou contratar.**
Decisão anterior preservada: `docs/architecture/security-baseline.md` §2 manda manter o Supabase Auth.

## 1. Como está hoje

- E-mail + senha (`signInWithPassword`) em `app/(auth)/login/actions.ts`: validação Zod no servidor, mensagem fixa
  "E-mail ou senha incorretos" (não revela se o e-mail existe), aviso de excesso de tentativas, destino `next` filtrado
  por `safeNextPath` (sem open redirect), depois vai para a tela inicial escolhida em Ajustes.
- `proxy.ts` renova a sessão (`getClaims`) e protege tudo menos `/login`, `/reset-password`, `/logout` e os links públicos.
- Não existe cadastro público: o acesso nasce por convite da responsável do estúdio. "Esqueci a senha" é um link enviado
  pela equipe (`/reset-password?token_hash=`), consumido só ao enviar o formulário (prévia do WhatsApp não gasta o link).
- Sem SMTP próprio (Resend só tem o adaptador de e-mails de negócio) e sem credenciais Google/Apple.

## 2. Opções e decisão

| Opção | Como funciona no Supabase | Prós | Contras / custo | Decisão |
|---|---|---|---|---|
| E-mail + senha (atual) | `signInWithPassword` | Já funciona, sem e-mail enviado, sem custo, gerenciador de senhas | Senha fraca/reutilizada; reset precisa de e-mail ou da equipe | **Manter como método principal** |
| Código de 6 dígitos por e-mail (como o Fresha) | `signInWithOtp` + `verifyOtp(type:'email')`; template "Magic Link" com `{{ .Token }}` | Sem senha para lembrar, igual ao Fresha | **Exige SMTP próprio** (padrão do Supabase: 2 e-mails/hora); 1 e-mail por login (Resend grátis: 100/dia, 3.000/mês); `shouldCreateUser:false` revela a conta inexistente, então a tela deve sempre dizer "se o e-mail tiver acesso, enviamos o código" | **Fase 1**, opcional, depois do SMTP |
| Link mágico | Mesmo `signInWithOtp`, template com link | Um toque | Abre em outro app/navegador no celular (WhatsApp, e-mail embutido) e perde a sessão; scanners de e-mail consomem o link | **Não** (o código é melhor no celular) |
| Google | OAuth; Client ID/Secret do Google Cloud | Um toque, sem senha, sem SMTP | Exige projeto e tela de consentimento no Google (precisa de URL de privacidade/termos); só entra quem já tem `user_roles` | **Fase 2** |
| Apple | OAuth; Services ID + chave .p8 | Exigido pela Apple se houver app iOS com login social | Apple Developer Program (pago); o segredo JWT **vence a cada 6 meses** | **Fase 2**, só se houver app iOS ou demanda |
| Passkeys / WebAuthn | `signInWithPasskey`, opt-in no cliente (`experimental.passkey`) | Melhor UX e segurança | Documentação diz "experimental, a API pode mudar sem aviso"; exige supabase-js ≥ 2.105; trocar o RP ID invalida todas as passkeys | **Acompanhar**, não usar em produção ainda |
| MFA TOTP | `mfa.enroll/challenge/verify`, AAL2; gratuito em todos os projetos | Não depende de e-mail nem de terceiros; combina com a regra de segurança já aprovada (dona, admin, financeiro) | Precisa de telas (cadastro, desafio, recuperação) e política de quem é obrigado | **Fase 3** (pode vir antes da fase 1) |
| Clerk | JWT de terceiro aceito pelo Supabase | UI pronta, passkeys, organizações | Hobby grátis até 50 mil usuários retidos/mês, mas MFA só no Pro (US$ 20-25/mês); o Supabase ainda cobra US$ 0,00325 por MAU de terceiro acima da cota e **não deixa desligar o Supabase Auth**; `sub` do Clerk não é UUID (reescrever políticas RLS que usam `auth.uid()`); dados de login fora do nosso banco (LGPD: operador adicional e transferência internacional) | **Não agora** |
| Auth0 / WorkOS / Cognito | Mesmo mecanismo (OIDC) | Recursos corporativos (SSO) | Mais caro e complexo; só vale com cliente enterprise pedindo SSO | **Não** |
| Better Auth | Biblioteca TypeScript própria, usuários em tabelas nossas | Sem custo por usuário, passkey e 2FA em plugins | Troca de fundação: refazer `proxy.ts`, `user_roles`, RLS (o Postgres deixaria de enxergar `auth.uid()` sem emitir JWT próprio) e assumir a segurança de sessão | **Não** |

Conclusão: **continuar no Supabase Auth.** Os pedidos do responsável (código por e-mail, Google, Apple) são todos
suportados nele; a única peça que falta é infraestrutura de e-mail e credenciais, não troca de provedor.
Trocar agora custaria reescrever RLS e sessões sem ganho que o Supabase não ofereça.

## 3. Recomendação em fases

**Fase 0 (feita, sem credenciais).** Tela de login no layout do Fresha, 2 etapas (e-mail, depois senha), tema pelo seletor
(Estética claro/bronze, Barbearia escuro/cobre), `AuthCard` com slot `alternatives` pronto. Mesma lógica de servidor.

**Fase 1 (depende de SMTP).** Resend como SMTP do Supabase (Authentication, SMTP), templates em pt-BR, "Esqueci minha
senha" por e-mail de verdade (`resetPasswordForEmail`, hoje a linha só explica como pedir à responsável) e botão
"Continuar com código por e-mail" no slot `alternatives` (código de 6 dígitos, validade curta de 10 min em vez da hora
padrão, reenvio a cada 60 s, mensagem sempre neutra). Ligar CAPTCHA nos endpoints de login/reset.

**Fase 2 (depende de contas).** "Continuar com Google" e, se fizer sentido, Apple, no mesmo slot. O login social só
aceita quem já foi convidado (sem criar conta nova; o convite continua sendo a porta de entrada).

**Fase 3 (sem credenciais externas).** MFA TOTP obrigatório para dona, admin e financeiro (`security-baseline.md` §2),
com exigência de AAL2 nas telas sensíveis. Passkeys só quando saírem do modo experimental.

Antes de clientes reais (qualquer fase): plano Pro do Supabase para a proteção contra senhas vazadas (não existe no
Free) e limites de taxa ajustados; política de senha (hoje 10+ no criar senha, 6+ no login).

## 4. O que o responsável precisa fornecer

1. **Decisão**: manter senha como principal e acrescentar código por e-mail e Google (recomendado) ou outro conjunto.
2. **Resend**: conta, domínio de envio (ex.: `acesso@seudominio`) com SPF/DKIM/DMARC verificados, e a chave/credenciais
   SMTP. Eu não crio contas nem coloco segredos; a configuração é no painel do Supabase (SMTP) e no Resend.
3. **URLs**: domínio de produção (Site URL) e a lista de redirecionamentos permitidos (produção, previews da Vercel,
   `http://localhost:3000`). Desligar o cadastro público (já é a regra em `security-baseline.md`).
4. **Textos dos e-mails**: aprovar os modelos pt-BR (código de acesso, redefinir senha, convite). Eu redijo.
5. **Google**: projeto no Google Cloud com tela de consentimento e um OAuth Client ID/Secret do tipo Web, com o redirect
   `https://<ref-do-projeto>.supabase.co/auth/v1/callback`.
6. **Apple** (opcional): Apple Developer Program, Team ID, Key ID, Services ID e a chave `.p8`; alguém para renovar o
   segredo a cada 6 meses.
7. **Política de Privacidade e Termos de uso**: endereços públicos. Hoje não existem páginas, por isso o rodapé do login
   não os cita; o Google também exige essas URLs na tela de consentimento.
8. **CAPTCHA** (opcional): chaves Cloudflare Turnstile ou hCaptcha.
9. **Plano do Supabase** e **região** do projeto confirmados (LGPD: onde ficam os dados de login).
10. **Política de MFA**: quem é obrigado (sugestão: dona, admin, financeiro) e prazo da sessão.

## 5. Tela de login (fase 0), padrão Fresha

- Seta de voltar no topo (só na etapa 2), marca, título e subtítulo centralizados, campo "E-mail" com rótulo, botão
  grande em pílula **bronze** ("Continuar"), alvos de 44-48 px. Celular: tela cheia sem cartão. Desktop: cartão centralizado.
- Etapa 1 só valida o formato (nada vai ao servidor, então nada revela se o e-mail existe). Etapa 2: e-mail somente leitura
  no MESMO formulário (gerenciador de senhas salva o par certo), senha com mostrar/ocultar, "Esqueci minha senha"
  (abre o aviso de como pedir novo link), botão "Entrar" com carregamento. Foco vai para a senha e volta ao e-mail.
- Erros em pt-BR: formato do e-mail, senha vazia, credencial incorreta (fixa), excesso de tentativas, sem acesso à organização.
- **Omitido de propósito**: "Te enviaremos um código de verificação", divisor "ou" e botões Google/Apple/código do Fresha:
  seriam botões sem backend. Entram pelo slot `alternatives` do `AuthCard` na fase 1/2. Rodapé de privacidade/termos: omitido
  até existirem as páginas.
- Mantidos: `actions.ts` sem alteração, `next` com `safeNextPath`, redirecionamento por tela inicial.
- Testes: `app/(auth)/login/email-step.test.ts` (validação da etapa 1) e E2E de login ajustados (`Continuar` antes da senha).
