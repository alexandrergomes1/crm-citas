# Spec 45 — Layout limpo (padrão visual)

Decisão de 30/10/2026, a partir de comparação lado a lado com Fresha e Booksy: o sistema estava pesado
(botões grandes, pílulas em todo filtro, tabelas cortando texto, fundos que quebram). Regra: **menos
destaque, menos cor, menos caixa**. Só a ação principal da tela é escura.

## Regras

1. **Botões**: 36 px no celular e 32 px no computador (área de toque de 44 px preservada por camada invisível).
   Ação secundária de contato (WhatsApp, Ligar) é **ícone** (`ib o`), não botão com texto.
2. **Filtros**: opções com caixinha de 18 px (círculo = uma escolha, quadrado com ✓ = várias), componente
   `ChoiceList`. Pílula (`Chip`) fica só para visões rápidas fora de filtros (Dia, Semana, Todos).
3. **Abas**: sublinhadas, sem fundo (`SegmentedControl variant="underline"`). A versão em pílula cinza fica
   só para trocar de visão dentro de um cartão (Lista | Grade).
4. **Equipe**: botão só com o ícone de pessoas e contador quando há recorte. Nunca texto longo na barra.
5. **Listas no lugar de tabelas** em larguras estreitas: data, texto inteiro (até 2 linhas), valor e estado
   à direita. Tabela só no computador e só com colunas que cabem.
6. **Cor**: fundo branco, linhas finas, um acento. Badge só quando muda uma decisão (pendente, atrasado).

## Aplicado nesta entrega

Agenda (filtros desktop e celular, botão Equipe), ficha do cliente no celular (ações, abas, atendimentos).

## Próximas ondas

Clientes (lista), Catálogo, Financeiro, Mensagens, Anamnese, Ajustes — mesmo padrão, uma tela por vez.

## Ajustes de 30/10/2026 (noite) — "igual ao Fresha"

7. **Ficha no celular sem abas**: primeira tela = pessoa, ações (Agendar agora + ícones de WhatsApp e ligar) e lista de seções com contador
   e ›; cada seção abre em página própria com "‹ nome da cliente" para voltar.
8. **Tudo que lista abre algo**: atendimento abre na agenda (`?ag=`), com atalhos Checkout / Ver venda / Nova reserva no cartão. Linha da
   linha do tempo = cartão com ponto, mês como título e a parte "Próximos" em destaque.
9. **Cor principal**: bronze da marca (`--primary` #7A5A22), não preto. O texto continua em `--ink`. Barbearia e Essencial mantêm a sua.
10. **Filtros**: caixinhas quadradas (marcadas = incluídas; as duas marcadas = todas). Escolha única = lista com ✓ no fim da linha, sem bolinha.
