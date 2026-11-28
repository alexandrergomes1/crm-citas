# Avaliação do antigo · Permissões e ficha no aparelho com PIN

- **Escrito por:** Engenheiro de segurança · **Norma:** OWASP ASVS 4.0.3 (V2, V3, V4, V7), RGPD, LGPD
- **Pedido do dono (28/11/2026):** ver no `crm-agenda` o que agrega aos perfis e permissões e ao modo PIN, sem copiar
  por ser maior (`docs/decisoes/2026-11-27-fundacao.md`, linhas "Pedido (perfis e permissões)" e "E29·1·A + pedido").
- **Situação:** só leitura. Nada foi copiado. Cada ideia marcada "aproveitar" volta ao dono para autorizar item por
  item (`AGENTS.md` §3 regra 4). Não foi achado segredo.

## A) Permissões

### Como o antigo fazia (`crm-agenda/supabase/migrations/`)
1. Sete papéis fixos (owner, admin, manager, receptionist, professional, finance, viewer), um vínculo por pessoa e estúdio.
2. Matriz padrão em `role_default_permissions()` (`20261029130000_configurable_role_permissions.sql`), com cerca de 22
   permissões `módulo.ação`, e uma cópia em `src/domain/access.ts` comparada por teste.
3. Exceções por estúdio em `org_role_permissions`: só se guarda o que difere do padrão.
4. Perfis personalizados (`20261031300000_custom_profiles.sql`): `org_profiles` (nome e papel-base) e
   `org_profile_permissions`.
5. `has_permission()` resolve em camadas: owner tem tudo → exceção do perfil → exceção do papel → padrão.
6. Não há ajuste por pessoa: para mudar uma pessoa só, cria-se um perfil.
7. As ações não seguem ver/criar/editar/remover; cada módulo tem verbos próprios.
8. Travas: não conceder o que não tem; acesso e admin só pela owner; ninguém altera o próprio papel; sempre uma owner
   ativa; registro de cada mudança; escrita direta em `user_roles` fechada em 14/11.

### Ideias, uma por uma

| # | Ideia | Onde no antigo | Decisão | Motivo e norma |
|---|---|---|---|---|
| 1 | Padrão no código, só exceções no banco | `role_default_permissions`, `org_role_permissions` | Aproveitar a ideia | Pouca linha por estúdio; "voltar ao padrão" é apagar a exceção. ASVS V4.1.3 |
| 2 | Perfis com nome criados pelo estúdio | `org_profiles` | Aproveitar, reescrito | É o pedido do dono. Sem papel-base escondido: o perfil nasce como cópia de um papel padrão |
| 3 | Resolução em 3 camadas | `has_permission` | Descartar | Difícil saber o que vale de fato; o ADR 0005 T7 já descartou. ASVS V4.1.5 |
| 4 | A dona tem tudo e não muda | `has_permission`, `assign_user_profile` | Aproveitar | Atende "a dona sempre mantém acesso total" |
| 5 | Sempre uma dona ativa, com trava contra corrida | `tg_user_roles_guard` | Aproveitar a ideia | Ninguém fica sem acesso ao estúdio; parte já está no ADR 0005 T3 |
| 6 | Ninguém mexe no próprio papel | `tg_user_roles_guard`, `assign_user_profile` | Aproveitar | ASVS V4.1.3 e V4.2.1 |
| 7 | Não conceder o que não tem | `set_role_permission`, `set_profile_permission` | Aproveitar e ampliar | No antigo valia ao editar o perfil, não ao atribuir (ver #8) |
| 8 | **Defeito:** atribuir perfil não confere se o perfil dá mais que o ator tem | `assign_user_profile` | Corrigir no novo | Quem gerencia a equipe põe a colega num perfil com acesso total. ASVS V4.1.3 e V4.2.1 |
| 9 | **Defeito:** escrita direta em `user_roles` até 14/11 | políticas de `user_roles` | O novo já cobre | ADR 0005 T3 |
| 10 | **Defeito:** modelo misto; migrations novas ainda usam lista fixa de papéis | `cash_sessions`, `client_profile`, `agenda_writes`, `anamnese_scope` | Descartar | A tela mostrava uma liberação que o banco não seguia. ASVS V4.1.1 |
| 11 | Lista efetiva da pessoa para esconder botões | `my_permissions` | Aproveitar só para a tela | Esconder botão não protege; a checagem fica na porta 3 e no banco. ASVS V4.1.1 |
| 12 | Permissão separada para ver dado de saúde | matriz padrão | Aproveitar | RGPD art. 9 e 32; LGPD art. 11 |
| 13 | Registro com antes e depois de cada mudança de acesso | `audit_logs` | Aproveitar a ideia | Cabe na porta 6. ASVS V7.1.3 e V7.2.2 |
| 14 | O estúdio vem do pedido (`p_org_id`) | todas as funções | Descartar | No novo vem da sessão (RF-03, ADR 0005 T5). ASVS V4.2.1 |
| 15 | Duas fontes da matriz comparadas por teste | `access.ts` e teste | Aproveitar a ideia | Uma fonte só, ou teste na CI que trava se divergirem |

### Modelo proposto para o novo (o que a segurança exige; a forma é do Engenheiro de dados e do Arquiteto)
1. **Módulo × ação:** catálogo fechado no código: ver, criar, editar, remover, e ações sensíveis à parte (ver ficha de
   saúde, estornar, exportar, gerenciar acessos). Fora do catálogo, recusa.
2. **Papéis padrão** (dona, recepção, profissional) com a matriz do código. O estúdio duplica um papel e cria um perfil
   com nome, que guarda a matriz inteira, sem camadas. "Restaurar padrão" copia de novo.
3. **Ajuste por pessoa:** uma camada só, por cima do perfil (dar ou tirar uma ação), com motivo e prazo opcional; a tela
   mostra a lista efetiva.
4. **A dona** não é perfil: tem tudo, não é editada nem rebaixada, e o estúdio tem sempre pelo menos uma.
5. **Ninguém se dá mais do que tem**, ao editar perfil, atribuir perfil ou ajustar pessoa; ninguém mexe em si.
   "Gerenciar acessos" e "ver ficha de saúde" só a dona concede.
6. **Onde se confere:** no servidor (porta 3) e no banco, pela mesma regra, com estúdio e pessoa da sessão.
7. **Falhar fechado:** sem perfil, ação desconhecida ou perfil apagado → não.
8. **Registro** de toda mudança (quem, quem foi afetado, antes, depois), sem dado pessoal, imutável. A exceção do modo
   suporte (`ARCHITECTURE.md` §6) vale também aqui? → pergunta ao dono.
9. **Testes na CI:** escalonamento por atribuição (#8), dona intocável, isolamento, servidor e banco iguais.
10. A matriz padrão de cada papel é decisão de acesso: pergunta ao dono, nunca "Assumptions". As respostas de
    28/11 (E26, E28 a E32) já são essa matriz padrão.

## B) Ficha no aparelho do estúdio com PIN

### Como o antigo fazia
(`20261030400200_studio_mode_pin.sql`, `src/studio-mode/actions.server.ts`, `src/domain/studio-mode.ts`,
`src/server/request-middleware.ts`, `src/data/auth/session.ts`)
1. Um PIN por estúdio, de 4 a 6 números, guardado como hash, definido por quem gerencia ajustes.
2. Cinco erros travam o PIN por 5 min no estúdio inteiro.
3. "Entregar o aparelho": o servidor confere modo ligado, PIN definido e ficha pendente no prazo, e grava um cookie
   httpOnly válido por 12 h.
4. Travado, as páginas voltam para a ficha; as ações do servidor são recusadas, menos as do modo.
5. Sem ficha aberta, nenhum nome de cliente; sair exige o PIN.
6. A trava vale só para quem entregou o aparelho; a assinatura grava IP e navegador. O próprio código diz que não
   barra quem limpa os dados do navegador.

### O que aproveitar e os riscos
- **Aproveitar:** PIN só como hash, limite de tentativas, trava decidida no servidor em toda ação, nenhum nome de
  cliente com a tela travada, PIN nunca no registro.
- **Risco 1 (o principal):** a sessão da funcionária continua viva no aparelho na mão da cliente; quem apaga o cookie
  recupera essa sessão. **Proposta:** ao entregar, trocar por uma sessão nova, curta e presa àquela ficha; voltar só com
  senha ou PIN pessoal. ASVS V3.2.1, V3.3, V4.1.3.
- **Risco 2:** PIN único do estúdio: não se sabe quem destravou. PIN pessoal, ou PIN do estúdio mais o registro da
  pessoa da sessão. ASVS V7.1.3; RGPD art. 5(2).
- **Risco 3:** a cliente trava a equipe em todos os aparelhos com 5 erros; 4 dígitos se esgotam em poucos dias.
  Bloqueio crescente por aparelho e por estúdio, mínimo 6 dígitos. ASVS V2.2.1.
- **Risco 4:** o endereço leva o id da ficha; no novo nenhum dado da cliente vai no endereço. IP e navegador na
  assinatura pedem base legal e prazo escritos (RGPD art. 5(1)(c) e 9(2)(a); LGPD art. 11); no novo não se gravam (RF-08).

## Não verificado
`plan.md` do Entrar e do item 3 não lidos nesta avaliação; `src/domain/access.ts` e as telas do antigo não lidas;
funções `studio_enter`, `studio_open_ficha` e `studio_sign_ficha` não lidas; nenhum teste rodado.
