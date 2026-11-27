# Módulo: Importação e exportação (IMP)

> Trazer clientes de outro sistema (planilha ou Fresha) e tirar dados do sistema em planilha, sempre com registro de quem fez.
> Hoje há importação e exportação de **clientes** dentro da tela Clientes; a tela Ajustes › Importar e exportar está com os botões desligados; a importação do **Fresha** não existe.

**Telas e rotas:** Clientes › Opções › Importar clientes e Exportar; Ajustes › Importar e exportar (`/{org}/configuracoes`, seção `dados`, botões desligados); Agenda › ⋮ › Exportar CSV · **Código:** `src/workspace/clientes/ClientImportDialog.tsx`, `import-actions.ts`, `import-actions.server.ts`, `list-actions.server.ts` (exportar), `src/domain/client-import.ts`, `src/workspace/ajustes/DataSection.tsx`, `src/workspace/agenda/_board/OptionsMenu.tsx` · **Spec(s):** sem spec no atual. No legado: `docs/produto/legado/specs/client-02-cidade-imagem-mesclagem-importacao.md` (seções Importação por CSV e Exportação auditada); a spec 34 (importação do Fresha) vive no PR #15 do sistema antigo e não está nesta pasta.

Como ler a coluna Origem: "legado client-02:30-33" = `docs/produto/legado/specs/client-02-cidade-imagem-mesclagem-importacao.md` linhas 30 a 33. "R4 B client-02" = relatório R4, seção B.

## Recursos
| ID | Recurso | Estado | Onde | Origem |
|---|---|---|---|---|
| IMP-01 | Importar clientes por planilha CSV: Nome e Telefone obrigatórios; E-mail, Cidade, Estado, Nascimento, Origem, Etiquetas e Observações opcionais; exige `clientes.manage` | pronto (antigo) · código existe (atual); "planejado, botões desligados" no ICEBOX | Clientes › Opções › Importar clientes (`ClientImportDialog.tsx`) | legado client-02:30-31,33; R4 B client-02; R2 B ICEBOX item 23 (`ICEBOX.md:30`) |
| IMP-02 | Prévia antes de gravar: quantos entram, quantos já existem (mesmo telefone ou e-mail), linhas recusadas | pronto | `ClientImportDialog.tsx`; `src/domain/client-import.ts` | legado client-02:32 |
| IMP-03 | Limite de 2.000 linhas; lotes de 200 atômicos; repetir a importação não duplica | pronto | `src/domain/client-import.ts` (`IMPORT_MAX_ROWS`) | legado client-02:33 |
| IMP-04 | Exportar clientes (CSV ou Excel) só depois de gravar o registro (`CLIENTS_EXPORTED`: quem, quando, quantos, filtro); exige `clientes.view` | pronto (antigo) · botão "Exportar" e "Exportar esta lista" existem (atual) | Clientes (`ClientToolbar.tsx`, `ClientOptionsMenu.tsx`) | legado client-02:35-37; R4 B client-02 |
| IMP-05 | Exportar a agenda em CSV | pronto | Agenda › ⋮ | R3 B ag:50 |
| IMP-06 | Tela Ajustes › Importar e exportar (PAjustesDados): hoje avisa "ainda não disponíveis; o suporte faz a migração" e deixa os botões desligados | pronto como tela, desligada | `DataSection.tsx` | R3 B audit:30,46; R2 B ICEBOX item 23; `DataSection.tsx` |
| IMP-07 | Importar clientes do Fresha (spec 34): só depois de tudo funcional; hoje só existe CSV | planejado (PR #15 do antigo, rascunho, fora da fila de merge) · planejado, precisa de spec (atual) | sem tela | `docs/produto/legado/specs/README.md:71-72`; R5 B revisao-30-10:14; R5 B core-delivery-control:143-145; R2 B ICEBOX item 41 (`ICEBOX.md:24`); R1 B reg:176 |
| IMP-08 | Telas que faltam desenhar para o lançamento: Entrar e acesso, Equipe básica, Ajustes do estúdio, Importação do Fresha, Recibo, Mensagens manuais | planejado, sem item na fila | — | R1 B reg:176; `docs/decisoes/historico/registro-ate-2026-11-24.md:176`; R2 B ICEBOX item 41 |
| IMP-09 | Importar produtos e planos em lote | planejado | Catálogo | legado catalog-02:57-60; R4 D |
| IMP-10 | Telefone na importação com regra própria (DDI padrão, formato) | pendente | `client-import.ts` | legado 52:308-311; R4 D 52 |
| IMP-11 | Auditoria da exportação e da importação: quem, quando, quantos | pronto (exportar) · a conferir (importar) | banco (`log_clients_export`) | legado client-02:36-37; `supabase/migrations/20261030300000_clientes_cidade_imagem_mesclagem.sql` |
| IMP-12 | Sistema em paralelo com o Fresha por 2 semanas depois da virada | planejado | processo de virada | `docs/runbooks/go-live.md:32`; R2 E |
| IMP-13 | Catálogo real da Karenn (PDF): o seed não bate com o PDF; conferir antes da virada | pendência | Catálogo | R5 B painel-da-jornada.html:131-138; R5 D |

"Estado" é o que os documentos dizem; o código é conferido quando o módulo entra em trabalho.

## Decisões
| ID | Decisão | Situação | Origem |
|---|---|---|---|
| IMP-D01 | Importar do Fresha (spec 34) só depois de tudo funcional ("decisão do dono") | **sugestão a confirmar** (sem frase; fonte atribui ao dono) | R5 A revisao-30-10:14 |
| IMP-D02 | Primeiro sistema pronto, testado e validado; só depois a migração do Fresha ("decisão do responsável do produto, 29 out") | **sugestão a confirmar** (sem frase) | R5 A core-delivery-control:143-145 |
| IMP-D03 | A spec 34 fica isolada no PR #15, fora da fila de merge, até o sistema estar validado | **sugestão a confirmar** | `docs/produto/legado/specs/README.md:71-72` |
| IMP-D04 | Importar e exportar adiados de propósito (fila "depois", junto com o motor de envio e os idiomas) | **sugestão a confirmar** (plano de recuperação aceito em lote, "aceito todas", 22/11) | R3 B audit:46; `docs/BACKLOG.md:19` |
| IMP-D05 | "Dados" (importar e exportar) fica visível e desligado com aviso, até existir de verdade (G9) | **sugestão a confirmar** (lote) | R1 A G9; `docs/specs/plans/2026-11-22-fase1-lista-unica.md:121`; `DataSection.tsx` |
| IMP-D06 | Importação de clientes lê a planilha no navegador, mostra prévia, grava em lotes atômicos e não duplica | **sugestão a confirmar** (spec do antigo, sem frase) | legado client-02:30-33 |

## Regras de negócio
- Nada é gravado antes da prévia; repetir a importação não cria cliente duplicado (mesmo telefone ou e-mail). Origem: legado client-02:32-33.
- Importar exige `clientes.manage`; exportar exige `clientes.view`. Origem: legado client-02:33,36.
- A exportação só devolve o arquivo depois de gravar o registro de quem exportou. Origem: legado client-02:36-37.
- Dado pessoal de cliente nunca vai para log. Origem: `CLAUDE.md` (regras que não se discutem).
- Cada importação tem limite (2.000 linhas) e é feita em lotes atômicos de 200. Origem: legado client-02:33.
- Antes de importar do Fresha, o sistema precisa estar validado; o Fresha continua em paralelo por 2 semanas na virada. Origem: R5 A core-delivery-control:143-145; `docs/runbooks/go-live.md:32`.
- Dados reais de clientes do Fresha (nomes, telefones) não ficam no repositório. Origem: R3 B audit:171; R1 A N2·A.

## Pendências e perguntas
| Pergunta ou pendência | Origem |
|---|---|
| A spec 34 (importação do Fresha) está só no PR #15 do antigo e fora da fila: trazer para o crm-agenda, refazer ou desistir? Precisa de ficha, spec e código | R4 F; R2 B ICEBOX item 41 |
| Importar e exportar da tela Ajustes (hoje desligados) × importar e exportar já funcionando em Clientes: ligar ou apagar a tela Ajustes › Dados? | R2 B ICEBOX item 23; `DataSection.tsx` |
| Quando a importação do Fresha entra na ordem? Depende da virada, que não tem data (R5, 23/11/2026) | `docs/reorganizacao/03-decisoes.md` |
| O que mais se importa do Fresha além de clientes: histórico de atendimentos, saldos, pacotes, fichas? Nenhuma fonte diz | R4 F |
| Telefone na importação (DDI padrão +55 ou +34) | legado 52:308-311; R3 B fase1:120 |
| Fotos do Fresha com nome e telefone de clientes reais: tirar do repositório e do histórico (Fase 4, N2) | R3 B audit:171; R1 A N2·A |
| Exportação auditada também da agenda e dos financeiros? | R3 B ag:50 |
| Importar produtos e planos em lote | legado catalog-02:57-60 |

## Referências
- Specs do legado: `docs/produto/legado/specs/client-02-cidade-imagem-mesclagem-importacao.md`, `README.md` (linhas 71-72), `catalog-02-produtos-combos-planos.md` (57-60), `52-guia-de-agendamento.md` (308-311).
- Documentos do antigo (via R5): `product/revisao-30-10.md:14`, `core-delivery-control.md:143-145`.
- Lançamento: `docs/runbooks/go-live.md` (Fresha em paralelo por 2 semanas); fila: `docs/ICEBOX.md` itens 23 e 41.
- Prints e fotos do Fresha de referência: `docs/fresha-prints-referencia/` (com dados reais; ver N2).
- Módulos vizinhos: Clientes (importar e exportar clientes), Catálogo, Agenda (exportar CSV).

Regra: só vale decisão registrada em `docs/decisoes/` (molde de pergunta). Tudo desta tabela é **a confirmar**; a situação antiga fica entre parênteses só como histórico e volta a ser perguntada quando o módulo for trabalhado (resposta 15a do dono, 24/11/2026).
