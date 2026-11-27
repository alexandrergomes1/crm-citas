# Spec 08 - Bundles, pacotes de sessões e memberships

## Status

Modelagem aprovada para planejamento em 2026-06-12. A UI será desenhada pelo
Claude; banco, domínio, actions e testes ficam sob responsabilidade do Codex.

## Problema de modelagem

O sistema atual usa `service_packages` para um benefício pré-pago com sessões e
validade. O print de referência mostra outro conceito: um bundle de serviços
executados juntos, em ordem, no mesmo agendamento, com preço distribuído por item.

Esses produtos não devem compartilhar a mesma entidade:

| Produto | Uso | Exemplo |
|---|---|---|
| Bundle / seleção | serviços juntos no mesmo agendamento | limpeza + dermaplaning |
| Pacote de sessões | créditos consumidos em atendimentos separados | 3 sessões de microagulhamento |
| Membership / plano | benefício recorrente por ciclo | 1 facial por mês |

## Fontes

- Anexos do responsável do produto em 2026-06-12.
- Legado: `docs/specs/catalog-packs-plans.md`.
- Fresha, bundles:
  https://www.fresha.com/help-center/knowledge-base/catalog/102084-create-service-bundles
- Fresha, disponibilidade:
  https://www.fresha.com/help-center/knowledge-base/catalog/101831-manage-service-availability
- Fresha, adicionais:
  https://www.fresha.com/help-center/knowledge-base/catalog/102085-create-service-add-ons
- Fresha, arquivar e excluir:
  https://www.fresha.com/help-center/knowledge-base/catalog/77-archive-and-delete-items-in-your-service-menu

## Catálogo de serviços

### Estado atual

| Recurso | Estado |
|---|---|
| Nome, categoria, descrição, preço e duração | pronto |
| Buffer, comissão, booking online e ativo | pronto |
| Profissionais habilitados | pronto |
| Template de anamnese | pronto |
| Tipo fixo e a partir de | pronto |
| Gratuito explícito | parcial; hoje depende de preço zero |
| Sob avaliação | pronto como extensão própria |
| Busca, filtros e ordenação | ausente |
| Ordenação de categorias e itens | ausente na operação |
| Duplicar | ausente |
| Link rápido de reserva | ausente |
| Arquivar separado de desativar | ausente |
| Exclusão permanente protegida | parcial |
| Locais | ausente no serviço |
| Recursos | tabela existe, vínculo operacional ausente |
| Adicionais | ausente |
| Imagens | ausente |
| Formulários múltiplos | parcial; existe um template padrão |
| Preço/duração por profissional ou local | ausente |

### Tipo de preço

Contrato canônico:

- `free`: gratuito e preço forçado a zero;
- `from`: exibição "a partir de";
- `fixed`: preço definido;
- `on_request`: extensão KA Beauty para avaliação prévia.

O valor persistido e a apresentação não podem divergir.

### Disponibilidade

Um serviço pode ser limitado por:

- locais permitidos;
- profissionais permitidos;
- recursos obrigatórios;
- horários/dias disponíveis para booking online;
- capacidade simultânea futura.

## Bundle

### Regras

- Reúne dois ou mais serviços executados no mesmo agendamento.
- A ordem dos itens é persistida e editável.
- Cada item guarda preço original e preço alocado no bundle.
- A soma dos preços alocados deve ser igual ao preço total do bundle.
- A duração total deriva dos itens, buffers e tempos extras.
- O snapshot do agendamento e da venda preserva nomes, ordem e valores históricos.
- Um serviço arquivado não invalida bundles e atendimentos históricos.

### Modelo recomendado

Criar entidades separadas, sem converter silenciosamente os pacotes atuais:

```text
service_bundles
  id, org_id, category_id, name, description, price,
  online_booking, active, archived_at, position

service_bundle_items
  id, org_id, bundle_id, service_id, position, quantity,
  original_price_snapshot, allocated_price,
  duration_minutes_override, staff_id_override
```

### Operações

- criar, editar, duplicar, arquivar, restaurar;
- alterar ordem dos serviços;
- distribuir desconto automaticamente ou manualmente;
- gerar link de reserva quando o booking público existir;
- exclusão permanente apenas sem referências e com confirmação forte.

## Pacote de sessões

- Compra cria `client_entitlement`.
- Sessões são consumidas em atendimentos separados.
- Deve ter validade, quantidade por serviço, saldo e histórico.
- Cancelamento e restauração de sessão geram ledger.
- Não usa preço alocado por item como regra principal.

O `service_packages` atual deve permanecer com esta semântica até uma migration
explícita.

## Membership

- Benefícios renovados por ciclo.
- Serviços elegíveis e quantidade por ciclo.
- Pode ser recorrente ou pagamento único com validade.
- Precisa de estado de cobrança separado do entitlement operacional.
- Falha de cobrança não pode apagar histórico de consumo.

## Handoff visual para Claude

O catálogo precisa comportar:

- busca por nome;
- filtro por local, status, booking e categoria;
- categorias com contagem;
- ordenação de categorias, serviços e bundles;
- menu por item: editar, duplicar, link de reserva, arquivar e excluir;
- editor de serviço dividido por contexto, sem transformar um único componente em
  manager gigante;
- editor de bundle com itens ordenáveis, preço original, preço alocado, duração
  total e totais sempre visíveis.

O Claude decide composição e layout, respeitando `src/design-system/`, limite de
300 linhas por componente de tela e screenshots 1440px/390px.

## Segurança e integridade

- Toda entidade possui `org_id` e RLS.
- Criação/edição do bundle e itens ocorre em uma transação.
- IDs dos serviços são validados na mesma organização.
- Duplicação cria novos IDs e não compartilha itens mutáveis.
- Arquivar é reversível; excluir é restrito e auditado.
- O catálogo não deve apagar snapshots de vendas ou agendamentos anteriores.

## Testes

- Unitário: soma e distribuição de preço do bundle.
- Unitário: ordem e duração total.
- Integração: rollback ao falhar um item.
- E2E: criar serviço, duplicar, arquivar e restaurar.
- E2E: criar bundle, ordenar itens e usar na agenda/checkout.
- E2E visual pelo Claude: 1440px e 390px.

## Fora de escopo imediato

- Marketplace.
- Cobrança recorrente real de memberships.
- Geração de conteúdo por IA além da descrição já existente.
- Redesenho visual pelo Codex.
