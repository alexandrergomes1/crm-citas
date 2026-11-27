# Spec 28 — CLIENT-NOTES-EDIT-CHECKOUT-CONTEXT

Status: approved
Owner: frontend-engineer + database-engineer
Last updated: 2026-06-22

## Objetivo

Completar a experiência operacional das notas já entregues pela AGENDA-CORE-02:

- permitir editar notas históricas persistidas com autorização e audit log;
- manter textos longos legíveis sem dominar a tela;
- sinalizar e abrir as notas no contexto do cliente da comanda;
- preservar integralmente `clients.notes`, `clients.fixed_notes` e alertas clínicos legados.

As referências do Fresha orientam localização, hierarquia e descoberta. A execução visual deve usar apenas o design system e os tokens V3 do KA Beauty OS.

## Direção de UX

### Tese visual

Notas são contexto secundário acionável: visíveis por indicador compacto, legíveis em painel temporário e nunca expandidas permanentemente na comanda.

### Perfil do cliente

- manter criação de nota no início da aba;
- separar notas do cliente/fixas e notas de atendimento;
- limitar notas longas a três linhas com `Ver mais`/`Ver menos`;
- oferecer `Editar` apenas para notas persistidas e roles operacionais;
- notas legadas permanecem identificadas e somente leitura nesta timeline.

### Comanda

- posicionar o acesso no lado esquerdo, junto ao contexto do cliente;
- exibir notas fixas e notas vinculadas ao atendimento atual diretamente no contexto inicial, com leitura compacta;
- representar notas gerais do cliente apenas por uma notificação discreta com contador;
- manter o painel completo acessível para leitura e edição;
- abrir `SideSheet` no desktop e bottom sheet no mobile;
- separar `Cliente` e `Atendimentos` dentro do painel;
- reutilizar a mesma leitura recolhível e edição do perfil.

## Contrato de edição

- mesma matriz de roles da criação: `owner`, `admin`, `manager`, `receptionist`, `professional`;
- nota, cliente e organização devem coincidir;
- corpo obrigatório entre 1 e 5000 caracteres;
- edição altera apenas corpo, data da nota e `updated_at`;
- operação usa RPC atômica `update_client_note_atomic`;
- audit log `CLIENT_NOTE_UPDATED` não armazena o corpo clínico;
- `anon`, `PUBLIC`, `finance` e `viewer` não recebem permissão de escrita;
- exclusão continua fora do escopo.

## Preservação de legado

- nenhuma coluna ou conteúdo de `clients.notes` e `clients.fixed_notes` é alterado;
- itens virtuais legados continuam compondo a timeline;
- notas legadas não chamam a RPC de edição;
- `alert_text` e `alert_type` continuam exibidos independentemente da timeline.

## Critérios de aceite

- criar e editar nota do cliente;
- criar e editar nota vinculada a atendimento;
- edição atualiza a tela sem navegação destrutiva;
- textos longos iniciam recolhidos e podem ser expandidos;
- comanda mostra indicador no contexto do cliente e abre painel de notas;
- desktop 1440px e mobile 390px validados;
- migration, domínio, typecheck, lint, build, Vitest e fluxo Playwright passam;
- nenhum AppShell, Financeiro, Anamnese, Catálogo ou componente visual do design system é alterado.

## Fora do escopo

- exclusão ou restauração de notas;
- anexos;
- colaboração em tempo real;
- redesenho global da Agenda ou da comanda;
- edição dos campos legados diretamente pela timeline.
