# Produto

O crm-citas é um sistema de gestão por assinatura (SaaS) para estúdios de estética, feito para a dona, a recepção e as profissionais, pensado primeiro para o celular.

Cada arquivo traz a lista candidata de recursos do módulo; o que entra em cada um se decide na spec daquele módulo. A ordem segue a E21·1.

## Módulos

### 1. Núcleo da primeira versão (E3·2)
- [Agenda](agenda.md): Mostra os horários do estúdio e de cada profissional, para ver o dia e organizar os atendimentos.
- [Agendamento](agendamento.md): É a marcação de um atendimento, do primeiro passo até o fim.
- [Clientes](clientes.md): Cadastro das clientes do estúdio, com o histórico de cada uma.
- [Formulários](formularios.md): Fichas que a cliente preenche e assina, inclusive a ficha de saúde (anamnese), que fica aqui e não é módulo próprio (E21·2·A).
- [Catálogo](catalogo.md): Tudo o que o estúdio oferece: serviços, pacotes, planos e produtos, com as regras de cada serviço.
- [Checkout](checkout.md): Fecha a conta do atendimento ou de uma venda avulsa e registra como a cliente pagou.
- [Caixa](caixa.md): Controla o dinheiro do balcão em cada turno, da abertura ao fechamento.

### 2. Depois do núcleo, um por vez (E3·2; E21·1)
A ordem entre eles segue a fila (`docs/BACKLOG.md`), quando chegar a vez.

- [Financeiro](financeiro.md): Mostra quanto entra e quanto sai do estúdio, com relatórios para acompanhar o mês.
- [Estoque](estoque.md): Acompanha os produtos que o estúdio usa e vende, e as compras feitas aos fornecedores.
- [Mensagens](mensagens.md): Reúne a conversa com as clientes e os envios automáticos do estúdio.
- [Marketing](marketing.md): Ajuda o estúdio a chamar as clientes de volta, sempre só quem autorizou receber.
- [Fidelidade](fidelidade.md): Premia a cliente que volta, com pontos que viram recompensas.
- [Equipe](equipe.md): As pessoas que trabalham no estúdio e o que cada uma pode ver e fazer.
- [Ajustes](ajustes.md): O lugar onde o estúdio e cada pessoa configuram o sistema do seu jeito.
- [Importação e exportação](importacao-e-exportacao.md): Traz os dados de outro sistema para cá e permite levar os dados do estúdio para fora.
- [Central de ajuda](central-de-ajuda.md): Respostas às dúvidas comuns dentro do próprio sistema, e um chamado quando elas não bastam.
- [Assistente de IA](assistente-de-ia.md): Um assistente que conversa com quem usa o sistema, tira dúvidas e faz tarefas a pedido.
- [Impulsionamento](impulsionamento.md): Ferramentas para o estúdio se tornar mais conhecido e atrair clientes novas.

### 3. Partes do sistema, depois dos "um por vez" (E21·1)
Nesta ordem entre si; a API pública só quando precisarem (E4·1).

- [Painel admin](painel-admin.md): Área à parte, com login próprio e dupla verificação, de onde o dono da plataforma cuida de todos os estúdios (`ARCHITECTURE.md` §6).
- [Cadastro de estúdio e assinatura](cadastro-de-estudio-e-assinatura.md): Como um estúdio novo entra na plataforma e paga por ela.
- [Portal público do estúdio](portal-publico-do-estudio.md): A página do estúdio na internet, onde a cliente marca horário sozinha.
- [Marketplace](marketplace.md): Um lugar aberto a todos para achar estúdios e serviços.
- [API pública](api-publica.md): A porta pela qual outros sistemas conversam com o crm-citas.
