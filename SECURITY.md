# Política de segurança do crm-citas

> Rascunho para o dono aprovar (E14). Escrito por: Engenheiro de segurança · Revisado por: (a preencher) ·
> Norma: OWASP ASVS 4.0.3 (nível 2 no sistema; nível 3 no módulo da ficha de saúde), RGPD e LGPD.
> Fonte: `AGENTS.md`, `ARCHITECTURE.md` e `docs/decisoes/2026-11-27-fundacao.md`. Este arquivo não cria regra nova.

## 1. Como avisar uma falha de segurança
- Avise em particular, pela aba Security do GitHub: **Report a vulnerability**. O aviso chega só ao dono.
- Não abra issue pública, não comente em PR e não publique a falha antes de ela ser corrigida.
- No aviso, nunca coloque dado pessoal, dado de saúde, senha, chave ou token.

## 2. Segredos
- Senha, chave e token nunca no código, no chat, em registro ou no repositório (`AGENTS.md` §6).
- Segredos ficam só em cofres: os painéis do GitHub, da Cloudflare e do Supabase, e o gerenciador de senhas
  (`ARCHITECTURE.md` §7).
- A chave da cifra da ficha de saúde fica fora do banco, num cofre de segredo, com troca planejada (`ARCHITECTURE.md` §7).
- A chave de serviço do banco, que passa por cima da trava, só em tarefas internas listadas (`ARCHITECTURE.md` §4).

## 3. Acesso e isolamento entre estúdios
- Todo pedido passa pelas 6 portas, nesta ordem (`ARCHITECTURE.md` §4): quem é (login válido) · de qual estúdio
  (vem da sessão, nunca do pedido) · o que pode (papel no estúdio) · dados certos (validação com esquema) · banco
  com trava (RLS por estúdio, com a sessão da pessoa) · registro (auditoria sem dado pessoal, que não pode ser
  alterado e tem prazo de guarda).
- O navegador nunca fala direto com o banco, mesmo com a trava.
- Um banco só; toda tabela do estúdio tem `org_id` e trava RLS, e cada tabela tem teste automático que prova que um
  estúdio nunca vê o outro (`ARCHITECTURE.md` §5).
- Um estúdio não atrapalha os outros: limite de pedidos por estúdio, listas paginadas, limite de idas ao banco por tela.
- Cada pessoa tem um papel em cada estúdio (dona, recepção, profissional) (`ARCHITECTURE.md` §6).
- Painel admin: área separada, login próprio e dupla verificação (E4·2).
- Avisos de parceiros (pagamento, mensagem) têm a assinatura conferida e são processados uma vez só (`ARCHITECTURE.md` §10).
- O banco só muda por migration aplicada pela CI; a IA nunca publica nem aplica mudança no banco remoto (`AGENTS.md` §1).

## 4. Dado pessoal e ficha de saúde
- Todos os dados na União Europeia (E5·1). Cópias e fornecedores também na UE, ou com contrato de tratamento de
  dados (DPA) e base para a transferência.
- Dado pessoal e de saúde nunca em registro de erro, endereço (URL) ou notificação.
- Respostas da ficha de saúde cifradas no banco (E5·2; ASVS V6.1.2).
- Ficha de saúde, entra por spec: consentimento explícito da cliente (RGPD art. 9; LGPD art. 11); avaliação de
  impacto (DPIA, RGPD art. 35); o estúdio é o responsável pelos dados e a plataforma é a operadora, com contrato.
- Vida do estúdio: exportar, cancelar e apagar os dados, com prazo de guarda; pedidos de "apagar os meus dados"
  (RGPD e LGPD).

## 5. Exceções declaradas pelo dono
Valem como estão; não se corrigem nem se contornam sem nova decisão do dono (`AGENTS.md` §6).
- **E4·2b (troca):** a entrada do dono num estúdio não é registrada em lugar nenhum. Resposta: "E a ordem é pra não
  gravar registro do dono".
- **E6·1:** dentro do estúdio, nada do que o dono faz fica registrado (nem a entrada nem as mudanças). Resposta: "E61b".
- **E6·2:** no modo "entrar como o estúdio", o dono pode abrir as fichas de saúde. Resposta: "e62b".
- Risco aceito pelo dono: a ASVS e o dever de prova do RGPD (art. 5(2)) pedem registro de acesso a dado sensível;
  o estúdio pode atribuir a uma funcionária uma mudança feita pelo suporte, e não há prova de acesso à ficha de saúde
  nesse modo (`ARCHITECTURE.md` §6).

## 6. Incidente e prazos de aviso
- Roteiro de incidente escrito (`ARCHITECTURE.md` §9).
- Vazamento: aviso à autoridade em até 72 h na UE (RGPD art. 33) e em até 3 dias úteis no Brasil (ANPD); aviso às
  pessoas afetadas quando o risco é alto.
- Produção: perda máxima de 24 h de dados e até 4 h fora do ar (E5·3), com cópia diária cifrada e restauração testada.

## 7. Pendências antes da produção
Nada disto está construído; cada item entra por spec própria (`ARCHITECTURE.md`).
- [ ] As 6 portas e o teste de isolamento por estúdio em cada tabela.
- [ ] Cifra da ficha de saúde e cofre da chave, com troca planejada.
- [ ] Consentimento, DPIA e contrato estúdio–plataforma para a ficha de saúde.
- [ ] Fornecedores na UE ou com DPA.
- [ ] Roteiro de incidente escrito.
- [ ] Cópia diária cifrada e restauração testada.
- [ ] Exportar, cancelar e apagar dados; pedidos de "apagar os meus dados".
- [ ] Monitoramento sem dado pessoal (Sentry e UptimeRobot, como proposta E2b, confirmados com o dono na vez deles).
