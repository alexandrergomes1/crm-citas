# Avaliação do antigo · Segurança do banco (2ª leitura, final)

- **Escrito por:** Engenheiro de segurança · **Norma:** OWASP ASVS 4.0.3, RGPD, LGPD
- **Pedido do dono (28/11/2026, E43·A):** "veja se tem mais regras e coisas.. segurança, etc. para ja matar essa questao
  do BD do anterior" (`docs/decisoes/2026-11-27-fundacao.md`).
- **Situação:** só leitura de `crm-agenda/supabase` (sem o seed) e de `src/server`, `src/data` e `src/lib/messaging`
  onde tocam o banco. Nada copiado. Não foi achado segredo. Não repete `permissoes-e-pin.md` nem `regras-do-banco.md`.
- **Veredito:** a segurança do banco antigo está **esgotada**; o que sobra são detalhes de produto.

| # | Achado ou ideia | Onde no antigo | Novo | Saída | Motivo e norma |
|---|---|---|---|---|---|
| 1 | Limite de tentativas dos links públicos no banco: por IP, por link e por erro do IP; cota separada para abrir e para assinar | `20261114100000_public_links_base.sql`, `20261114100100_public_anamnese.sql` | não tem (só a entrada por senha) | **aproveitar** | V11.1.4, V2.2.1 |
| 2 | IP e e-mail guardados como SHA-256 sem chave (IPv4 se recupera por força bruta) | `src/server/client-ip.server.ts` | cobre melhor (HMAC com chave do servidor) | descartar | RGPD art. 4(5); V6.2.1 |
| 3 | Link inválido, vencido, usado ou bloqueado: mesma resposta | `public_anamnese_open`, `public_payment_open` | não tem ainda | **aproveitar** | V7.4.1 |
| 4 | Páginas públicas chamam o banco com a chave de serviço | `src/data/anamnese/public-form.ts`, `src/data/payment-requests/public.ts` | não tem (ADR 0018 proíbe) | **alerta** | a spec dos links precisa de função estreita, não da chave que passa a trava; V4.1.3, V1.4.3 |
| 5 | Fotos de saúde sem política no Storage; o código confere só o prefixo do caminho | `20261114040000_anamnese_scope.sql`, `src/data/clients/client-photos.ts` | não tem | **alerta** | a liberação precisa ser conferida no banco; V4.1.3, V4.2.1 |
| 6 | Endereço da foto vale 300 s, gerado só para o que a leitura liberada devolveu | `src/data/anamnese/mutations.ts` | não tem | **aproveitar** | V8.3.4; RGPD art. 32 |
| 7 | Arquivos: área privada, tamanho e tipos limitados, tipo conferido pelos primeiros bytes, nome gerado pelo servidor, envio em 2 passos, teto de arquivos | `20261029020000_payment_requests.sql`, `20261114100200` | não tem | **aproveitar** | V12.1.1, V12.2.1, V12.3.1 |
| 8 | Política dos comprovantes com estúdio tirado do caminho | `20261029020000`, `20261030150000` | cobre melhor | descartar | V4.2.1 |
| 9 | Teste estático de RLS, `search_path` e `anon` | `tests/10_security_checks.sql` | cobre melhor (teste 010) | já coberto | V1.14, V14.2 |
| 10 | Tabelas expostas por padrão, protegidas só pela RLS | `20261028210000` | cobre (teste 010), sem revogação padrão | alerta leve | o teste deve seguir varrendo toda tabela nova; V4.1.3 |
| 11 | `search_path` frouxo ou ausente | `20260622143743`, `20260601000001` e outras | cobre melhor | descartar | V5.3 |
| 12 | Auditoria com dados antigos e novos, IP e aparelho, apagada com o estúdio | `20260601000001`, `20261114060200` e outras | cobre melhor | descartar | V7.1.1, V7.3.3; RGPD art. 5(1)(c) |
| 13 | Evento de segurança no registro sem segredo (bloqueio, link reemitido, assinatura) | `20261114100100`, `20261114100200` | cobre em parte | **aproveitar a ideia** | V7.2.1, V7.2.2 |
| 14 | "Esqueci a senha": 5 por hora por IP, 3 por e-mail, mesma resposta | `public_password_reset_allowed` | não tem (E39·1·B: depois) | **aproveitar** | V2.5, V2.2.1 |
| 15 | Conta da colega com senha provisória conhecida por quem criou | `src/data/auth/accounts.ts` | não tem | **alerta** | convite por link de uso único e curto; V2.3.1 |
| 16 | Quem cria o acesso gera o link de recuperação da colega e manda por WhatsApp | `createPasswordLink` | não tem | alerta, descartar a forma | pode tomar a conta; V2.5 |
| 17 | Trocar a própria senha exige a senha atual | `changeOwnPassword` | não tem (`secure_password_change: false`) | **aproveitar** | V2.1.6 |
| 18 | Configuração do Auth fora do repositório | — | cobre melhor (`supabase/config.jsonc`), mas com senha mínima 6, sem regras e sem confirmação de e-mail | **alerta** | antes do cadastro e convite: V2.1.1 (12 caracteres), V2.1.7 (senhas vazadas) |
| 19 | Ficha e assinatura sem cifra | `20260610_004_anamnese.sql` | cobre melhor (E5·2, E40·B) | descartar | V6.1.2; RGPD art. 9 |
| 20 | Apagar a cliente deixa a ficha com nome e respostas; não há apagar nem anonimizar | `20260610_004_anamnese.sql` | não tem | **alerta** | RGPD art. 17; LGPD art. 16 e 18 |
| 21 | Arquivos apagados depois do banco, fora da transação: sobram arquivos | `20261114040700` | não tem | **alerta** | faxina conferível; V8.3.8 |
| 22 | Envios do WhatsApp guardam telefone e texto inteiro, sem prazo | `20261101100000_messaging_connections.sql` | não tem | **alerta** | RGPD art. 5(1)(e); V8.3.8 |
| 23 | Webhook da Meta: assinatura conferida no corpo cru em tempo constante; situação só avança | `src/lib/messaging/signature.server.ts`, `src/data/messaging/webhook.ts` | não tem | **aproveitar** | V13.1; idempotência |
| 24 | Faxina do contador sorteada em 2 % dos pedidos | `public_link_throttle_internal` | cobre melhor | descartar | ISO 31000 |
| 25 | Funções do link liam o token em claro, executáveis por `anon` (até 14/11) | `20260610_004`, `20261030400000`, `20261030400100` | cobre melhor | descartar | V4.1.3 |

## Resumo
- **Mais valiosas:** #1 com #3 (links públicos), #7 (arquivos), #23 (webhook), #14 (esqueci a senha), #17 (senha atual).
- **Riscos para o novo:** #4 e #5 (as specs dos links e das fotos vão querer a chave de serviço: precisa de decisão
  escrita); #18 (regras de senha fracas do Supabase, antes do cadastro); #20 a #22 (apagamento e prazo de guarda são
  decisão do dono e entram antes de clientes reais e de mensagens).

## Não verificado
Configuração do Auth e do Storage no projeto remoto do antigo; o seed; parte das migrations varrida por busca, não
linha a linha; nenhum teste rodado; código fora das pastas citadas; `auto_expose_new_tables` no projeto remoto do novo.
