# ADR 0001 · Repositório novo, mesmo banco (formato MADR)
Status: aceita · Data: 2026-11-27 · Decisores: dono (P-E5·4) e IA (a parte técnica)

## Contexto e problema
O `crm-agenda` acumulou camadas de regra, documentos e telas no design antigo (v1). A reorganização (Etapa 5) escreveu uma base nova (constituição neutra, guias, `DESIGN.md` 6ª edição). Revirar o antigo arquivo por arquivo custaria mais e manteria o legado misturado. O dono pediu um projeto novo, do zero, que "só liga no banco".

## Fatores da decisão
- O banco de desenvolvimento já roda com as migrations do antigo e tem dados de teste; recomeçar o banco perderia isso e as provas de isolamento.
- As travas e o fluxo (spec aprovada, merge autorizado) precisam valer desde o primeiro commit.
- Dois repositórios aplicando migration no mesmo banco geram conflito.

## Opções consideradas
1. Repositório novo, mesmo banco (migrations copiadas como estão).
2. Repositório novo com banco novo.
3. Continuar a virada dentro do `crm-agenda`.

## Decisão e motivo
Opção 1. O repositório novo nasce da base nova; o banco continua o mesmo, e as migrations do antigo entram aqui sem mudança, para o histórico do banco bater com os arquivos.
- **Antigo congelado:** o `crm-agenda` fica só para leitura e cópia de recursos; nada se apaga lá.
- **Uma fonte de migration por vez:** até a virada, este repositório não aplica migration nem se liga ao banco real (sem chaves, sem rotina de migrations ativa); a CI usa banco local do zero. **A ligação ao banco real só acontece na virada**, por spec própria, com a autorização do dono; a partir daí só este repositório aplica migration.
- **Módulos por spec própria**, já no design novo, copiando do antigo o que funciona (regras, banco, testes).

## Prós e contras de cada opção
- 1: base limpa sem perder banco nem dados; exige disciplina de uma fonte de migration só (contra: duas cópias das migrations até a virada).
- 2: limpeza total; perde dados de teste e provas, e obriga migração de dados depois.
- 3: um repositório só; mantém o legado misturado e a virada fica longa (o que o dono recusou).

## Consequências
- Endereços de prévia, nomes do Worker e chaves da CI ainda são os do antigo nos fatos de `docs/reference/`; mudam quando a publicação for ligada aqui.
- Migration nova, antes da virada, só no repositório que estiver aplicando (hoje o antigo, congelado: portanto nenhuma).

## Confirmação (como se confere que a decisão foi cumprida: teste, revisor, trava)
- `supabase/migrations/` daqui igual à do antigo no momento da cópia (conferência na spec da fundação).
- Trava `.claude/hooks/guarda.mjs` barra aplicar migration no banco remoto e editar migration já integrada (`.claude/hooks/TRAVAS.md` §3).
- Revisor `risk-auditor` na spec da virada.

## Aprovação do dono
`docs/decisoes/2026-11-27-projeto-novo.md` (P-E5·4). Este ADR fica em `docs/adr/`.
