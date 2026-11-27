# Arquitetura do crm-citas

> **Aprovado pelo dono em 27/11/2026 (E6).** Escrito pelo Arquiteto de software e pelo Engenheiro de segurança.
> Mudança só com nova aprovação do dono.
> Normas seguidas: AWS Well-Architected (guia SaaS), OWASP ASVS 4.0.3, modelo C4 (desenho em camadas), Twelve-Factor App, WCAG 2.2.
> Cada decisão aqui vem de uma resposta do dono (`docs/decisoes/2026-11-27-fundacao.md`) ou de uma norma acima.
> Hoje nada disto está construído: cada parte entra por spec própria (`specs/`).

## 1. O sistema em uma frase
Sistema de gestão (SaaS) para estúdios de estética, usado pela dona, pela recepção e pelas profissionais, com o
celular em primeiro lugar. Idiomas de uso: português, espanhol e inglês. Idioma de desenvolvimento: português.

## 2. As partes do sistema

| Parte | Quem usa | Quando entra |
|---|---|---|
| App do estúdio | dona, recepção, profissionais | primeira versão (núcleo) |
| Painel admin da plataforma | o dono do sistema | depois do núcleo |
| Cadastro de estúdio e cobrança da assinatura | estúdios novos | depois do painel admin |
| Portal público do estúdio (reserva online) | clientes do estúdio | depois da cobrança |
| Marketplace (encontrar estúdios) | público em geral | depois da reserva online |
| API pública | marketplace e parceiros que chamam o sistema | só quando precisarem (E4·1) |

**Sistemas externos** que o sistema chama: WhatsApp, e-mail, pagamentos, cópia do banco, monitoramento.

Ordem de entrada: decisão E4·3. Núcleo da primeira versão (E3·2): Agenda, Agendamento, Clientes, Formulários,
Catálogo, Checkout e Caixa. Os outros módulos entram depois, um por vez.

## 3. Camadas do código

```
telas (src/app)  ──►  servidor (src/server)  ──►  regras (src/domain)
                              │
                              ▼
                       dados (src/data)  ──►  banco (supabase/)
```

| Pasta | O que mora ali | Nunca |
|---|---|---|
| `src/app/` | telas e componentes; seguem o `DESIGN.md` | falar com o banco; ter regra de negócio |
| `src/server/` | a camada única de serviço: toda ação passa pelas 6 portas (§4) | pular uma porta |
| `src/domain/` | regras do negócio em TypeScript puro, com teste | importar tela, banco ou framework |
| `src/data/` | o único lugar que fala com o banco | ser chamado direto pela tela |
| `supabase/` | migrations, políticas de acesso (RLS) e testes do banco | mudar banco fora de migration |

## 4. A camada única de serviço: as 6 portas (E4·1)
Todo pedido (das telas, do painel admin, do portal, de parceiros) passa por estas portas, nesta ordem:

1. **Quem é:** login válido.
2. **De qual estúdio:** o estúdio vem da sessão, nunca do pedido.
3. **O que pode:** a permissão do papel da pessoa no estúdio.
4. **Dados certos:** validação de tudo o que chega, com esquema.
5. **Banco com trava:** toda leitura e gravação passa pela trava por estúdio (RLS: o banco só devolve linhas do
   estúdio da sessão). O servidor fala com o banco com a sessão da pessoa; a chave de serviço do banco, que passa por
   cima da trava, só em tarefas internas listadas.
6. **Registro:** quem fez o quê e quando (auditoria), sem dado pessoal no texto; o registro não pode ser alterado e
   tem prazo de guarda. Exceção: as entradas do dono no painel admin (§6).

**CRUD** (criar, ler, alterar, apagar) tem o mesmo molde em todo módulo e passa sempre pelas 6 portas.
É proibido o navegador falar direto com o banco (CRUD automático), mesmo com a trava.
A **API pública** usa a mesma camada e abre só quando o marketplace ou um parceiro precisar (E4·1).

## 5. Estúdios isolados (multiestúdio)
- Um banco só; toda tabela do estúdio tem a coluna do estúdio (`org_id`) e a trava RLS.
- Cada tabela tem um teste automático que prova que um estúdio nunca vê o outro.
- Um estúdio não atrapalha os outros: limite de pedidos por estúdio, listas sempre paginadas, limite de idas ao
  banco por tela.
- O sistema fica preparado (pela norma) para planos ligarem e desligarem módulos e para medir o uso de cada
  estúdio; quais planos e preços é decisão futura do dono.

## 6. Pessoas e acesso
- Cada pessoa tem um papel em cada estúdio (dona, recepção, profissional; papéis configuráveis depois).
- **Painel admin** (E4·2): área separada, login próprio e dupla verificação. O dono pode entrar como o estúdio para
  suporte, sem aviso ao estúdio (E4·2). **Exceção declarada (ordem do dono, troca do E4·2b):** essa entrada não é
  registrada em lugar nenhum, embora a ASVS e o dever de prova do RGPD (art. 5(2)) peçam registro de acesso a dado
  sensível. Alcance (E6·1 e E6·2): nada fica registrado, nem a entrada nem o que o dono muda dentro do estúdio, e
  ele pode abrir as fichas de saúde nesse modo. Risco aceito pelo dono: o estúdio pode atribuir a uma funcionária uma
  mudança feita pelo suporte, e não há prova de acesso à ficha de saúde nesse modo.

## 7. Dados e privacidade
- Todos os dados na União Europeia (E5·1); rever se o Brasil ficar lento. Cópias e fornecedores (cópia do banco,
  monitoramento, e-mail) também na UE, ou com contrato de tratamento de dados (DPA) e base para a transferência.
- Segurança: ASVS 4.0.3 nível 2 no sistema todo; requisitos de nível 3 aplicados ao módulo da ficha de saúde.
- Ficha de saúde: respostas cifradas no banco (E5·2), porque a ASVS pede (V6.1.2: dado de saúde cifrado, já no
  nível 2). A chave da cifra fica fora do banco, num cofre de segredo, com troca planejada; detalhe na spec da ficha.
- Ficha de saúde, entra por spec: consentimento explícito da cliente (RGPD art. 9; LGPD art. 11); avaliação de
  impacto (DPIA, RGPD art. 35); o estúdio é o responsável pelos dados e a plataforma é a operadora, com contrato
  entre os dois.
- Dado pessoal e de saúde nunca em registro de erro, endereço (URL) ou notificação.
- Vida do estúdio: exportar os dados, cancelar, apagar, com prazo de guarda; pedidos de "apagar os meus dados"
  (RGPD e LGPD).
- Segredos (senhas, chaves) só em cofres: os painéis do GitHub, da Cloudflare e do Supabase, e o gerenciador de
  senhas; nunca no repositório, no chat ou em registro.

## 8. Ambientes e entrega

| Ambiente | Branch | Banco | Para quê |
|---|---|---|---|
| Desenvolvimento | `tipo/area-assunto` | banco de desenvolvimento | cada tarefa, com prévia própria |
| Prévia | `previas` | banco de desenvolvimento | o dono confere antes de publicar |
| Produção | `main` | banco de produção, separado | os estúdios |

- O banco só muda por migration aplicada pela CI (testes automáticos do GitHub).
- Nada vai direto à `previas` ou à `main`: só por PR com CI verde, revisão e autorização do dono.

## 9. Recuperação e incidente
- Produção: perda máxima de 24 h de dados e até 4 h fora do ar (E5·3). Para cumprir isso: cópia diária cifrada e
  restauração testada. Desenvolvimento: sem meta.
- Roteiro de incidente escrito. Vazamento: aviso à autoridade em até 72 h na UE (RGPD art. 33) e em até 3 dias
  úteis no Brasil (ANPD); aviso às pessoas afetadas quando o risco é alto.

## 10. Mensagens, pagamentos e parceiros
- Envios (WhatsApp, e-mail, lembretes) passam por uma fila: nada se perde e nada sai duplicado.
- Avisos que chegam de parceiros (pagamento, mensagem) têm a assinatura conferida e são processados uma vez só.

## 11. Qualidade
- Idiomas, fuso horário e moeda por estúdio, preparados desde o começo.
- Acessibilidade: WCAG 2.2 nível AA.
- Desempenho: limite de idas ao banco por tela; listas longas paginadas.
- Monitoramento: erros, sistema fora do ar e custo por estúdio, sem dado pessoal nos registros.
- Testes: regras com teste de unidade; banco com teste de isolamento; telas com teste de ponta a ponta nas duas
  larguras que o `DESIGN.md` vai definir.

## 12. Stack e ferramentas
- **Stack (código):** TypeScript, React com TanStack Start, Supabase (Postgres), Cloudflare Workers, pnpm,
  Vitest e Playwright. Versões e bibliotecas extras entram por spec, depois de lida a documentação oficial.
- **Ferramentas (E2b, como proposta):** Git; GitHub, GitHub Actions e Dependabot; Spec Kit; Node e pnpm;
  Supabase (painel e linha de comando); Cloudflare Workers e Wrangler; cópia do banco em Cloudflare R2 e Backblaze
  B2; canvas Design do claude.ai para fichas visuais; Claude Code (o Cursor pode ser usado também); gitleaks;
  gerenciador de senhas. Antes de abrir a clientes: Sentry, UptimeRobot e Resend. Cada ferramenta é confirmada com
  o dono quando chegar a vez dela.
