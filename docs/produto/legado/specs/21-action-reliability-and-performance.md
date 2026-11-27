# Spec 21 - Confiabilidade e performance das actions

## Goal

Eliminar falhas de UUID e reduzir a latencia dos fluxos operacionais que salvam
dados, sem alterar telas ou layout.

## Scope

- Checkout de registros históricos com ou sem cliente vinculado.
- Novos agendamentos exigem cliente cadastrado.
- Criacao e edicao de clientes.
- Criacao e edicao de servicos, produtos, categorias e pacotes.
- Validacao compartilhada de identificadores persistidos em colunas PostgreSQL
  `uuid`.
- Reuso de autenticacao e acesso a organizacao dentro da mesma renderizacao.

## Root Cause

O PostgreSQL aceita UUIDs no formato hexadecimal `8-4-4-4-12` sem exigir
versao e variant RFC. Os dados demo existentes usam identificadores desse tipo.
O `z.string().uuid()` do Zod 4 aplica validacao RFC estrita e rejeita esses
registros antes da chamada ao banco.

## Business Rules

- Identificadores de banco devem aceitar qualquer UUID valido para o tipo
  PostgreSQL, mantendo rejeicao de strings vazias e formatos malformados.
- Campos opcionais vindos de `FormData` devem converter `''`, `undefined` e
  `null` para `null`.
- O checkout deve obter `client_id`, `client_name` e `staff_id` do agendamento
  persistido, e nao confiar nesses campos enviados pelo navegador.
- Toda Server Action de checkout deve revalidar autenticacao e acesso a
  organizacao.
- Leituras independentes do checkout devem executar em paralelo.
- Escritas independentes posteriores a criacao da venda devem executar em
  paralelo e todos os erros devem ser verificados.
- Revalidacao deve usar a rota concreta da organizacao quando o slug estiver
  disponivel.

## Performance Targets

- Abrir checkout demo em menos de 3 segundos no ambiente local conectado ao
  Supabase remoto, desconsiderando a primeira compilacao.
- Finalizar checkout demo sem espera causada por validacao invalida e sem
  chamadas sequenciais desnecessarias.
- Evitar repeticao de `requireOrgAccess()` entre layout e pagina na mesma
  renderizacao.

## Evidência atual - 2026-06-14

- `pg_stat_statements`: leituras operacionais principais entre 0,2 ms e 1,8 ms
  em média; criação atômica de agendamento em aproximadamente 22 ms.
- `next start`, login real, primeira rodada de cinco amostras:
  - Agenda p95 1.230 ms;
  - Clientes p95 1.080 ms;
  - Catálogo p95 1.074 ms;
  - Financeiro p95 993 ms;
  - Anamnese p95 1.101 ms.
- uma segunda rodada curta confirmou variabilidade de transporte/renderização:
  Agenda 1.393 ms, Catálogo 1.482 ms, Financeiro 1.394 ms e Anamnese
  1.361 ms, mas Clientes teve um outlier de 4.176 ms;
- a consulta SQL de Clientes permaneceu abaixo de 13 ms no pior registro
  observado, portanto o outlier não autoriza criar índice por suposição;
- builds frios/contendidos variaram entre 59-65 s de compilação e 62-77 s de
  TypeScript; após aquecimento e liberação de recursos, a rodada final caiu
  para 19,7 s e 33,6 s, respectivamente.
- benchmark do filesystem: 500 arquivos pequenos levaram aproximadamente
  1.029 ms para escrita, 485 ms para leitura e 564 ms para exclusão.
- máquina com 11,9 GB de RAM e apenas 2,5 GB livres durante a medição; Kaspersky
  inspecionando o repositório.

O PostgreSQL não é o gargalo dominante no volume atual. Ações prioritárias:

1. instrumentar tempo de resposta RSC/Supabase por rota e separar TTFB,
   serialização e hidratação;
2. remover carregamentos por `useEffect` das abas Financeiro e da ficha do
   cliente, entregando dados iniciais pelo Server Component;
3. reduzir o payload inicial de Catálogo e Anamnese e carregar detalhes sob
   demanda;
4. consolidar políticas RLS permissivas duplicadas após `REL-DB-01`;
5. manter imports diretos do design system para reduzir o grafo de compilação;
6. excluir somente a pasta do repositório da inspeção em tempo real do
   antivírus, sem desativar a proteção global;
7. manter ao menos 4 GB de RAM livres durante `next dev`;
8. medir produção com `pnpm perf:core` após `pnpm build && pnpm start`.

### Bundler de desenvolvimento

- Next.js 16 usa Turbopack por padrão, mas este projeto mantém
  `next dev --webpack` de forma deliberada.
- Em 2026-06-14, Turbopack compilou o primeiro `/login` em 32,6 s e a rota
  dinâmica `checkout/[appointmentId]` retornou 404.
- Na mesma comanda, Webpack retornou HTTP 200 e DOM carregado em 1.083 ms.
- A troca de bundler só pode ocorrer após um teste autenticado das rotas
  dinâmicas de agenda, cliente e checkout. Cache não pode mascarar 404.

## Tests

- UUID RFC comum e UUID legado do seed sao aceitos.
- UUID malformado e string vazia obrigatoria sao rejeitados.
- UUID opcional vazio vira `null`.
- Payload de checkout aceita IDs PostgreSQL legados em itens.
- Checkout histórico não depende de `client_id` enviado pelo navegador.
- Agenda rejeita criação ou edição sem cliente cadastrado.

## Acceptance Criteria

- [x] Checkout de registro histórico sem cliente finaliza sem `Invalid UUID`.
- [x] Criacao de cliente funciona na organizacao demo.
- [x] Criacao de servico e produto funciona na organizacao demo.
- [x] Catalogo nao dispara erro de chaves duplicadas ao abrir formularios.
- [x] Typecheck, lint e Vitest passam.
- [x] Build final desta rodada passa.
- [x] Benchmark repetível das rotas core disponível em `pnpm perf:core`.
- [x] Benchmark informa TTFB, resposta, DOM e tempo total sem a espera
  artificial de `networkidle`.
- [ ] Fluxos reais autenticados possuem E2E automatizado.

## Out Of Scope

- Alteracoes visuais ou de layout.
- Redesenho dos formularios.
- Migracao destrutiva dos UUIDs demo existentes.
- Substituicao do checkout por RPC transacional nesta entrega.
