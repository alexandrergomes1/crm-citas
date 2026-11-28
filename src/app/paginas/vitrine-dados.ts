// Dados da vitrine: só fictícios, sem nome real de pessoa e sem dado de saúde (spec RV-2; E12·3; AGENTS.md §6).
// Os textos dos botões seguem o DESIGN.md §6. Os valores dos tokens NÃO ficam aqui: a vitrine lê do tokens.css.
import type { ItemNavegacao } from '@/app/ui/estrutura'
import type { GrupoTempo } from '@/app/ui/conteudo'

/** RT-1 e RT-2: nomes dos tokens de cor (o valor é lido do tokens.css na tela) */
export const tokensCor = [
  'page', 'card', 'btn', 'track', 'line', 'ink', 'ink2', 'ink3', 'field', 'id', 'brand',
  'warn', 'warnSoft', 'ok', 'okInk', 'okSoft', 'danger', 'dangerSoft', 'c1', 'c2', 'c3', 'c4',
  'pillSoft', 'warnInk', 'selRing',
] as const

export const tokensTexto = [
  { token: 'fs-20', uso: 'título da tela', forte: true },
  { token: 'fs-18', uso: 'título de folha e janela', forte: true },
  { token: 'fs-16', uso: 'título de bloco', forte: true },
  { token: 'fs-15', uso: 'texto no celular', forte: false },
  { token: 'fs-14', uso: 'texto e botão no computador', forte: false },
  { token: 'fs-13', uso: 'detalhe, subtítulo, tabela', forte: false },
  { token: 'fs-12', uso: 'cabeçalho de tabela, etiqueta, contador', forte: false },
  { token: 'fs-11', uso: 'barra de baixo, menu recolhido, hora da grade', forte: false },
] as const

export const tokensEspaco = ['sp-4', 'sp-8', 'sp-12', 'sp-16', 'sp-20', 'sp-24', 'sp-32'] as const

export const tokensRaio = [
  'r-pilula', 'r-bloco', 'r-campo-multi', 'r-menu-recolhido', 'r-janelinha', 'r-folha', 'r-inicial', 'r-caixinha', 'r-contador',
] as const

export const tokensSombra = ['sombra-flutua', 'sombra-escolhido', 'sombra-cabecalho'] as const

export const menuPrincipal: readonly ItemNavegacao[] = [
  { id: 'agenda', rotulo: 'Agenda', icone: 'calendar' },
  { id: 'clientes', rotulo: 'Clientes', icone: 'users' },
  { id: 'catalogo', rotulo: 'Catálogo', icone: 'tag' },
  { id: 'estoque', rotulo: 'Estoque', icone: 'warehouse' },
  { id: 'caixa', rotulo: 'Caixa', icone: 'banknote' },
  { id: 'financeiro', rotulo: 'Financeiro', icone: 'chart-column' },
  { id: 'formularios', rotulo: 'Formulários', icone: 'clipboard-list' },
  { id: 'mensagens', rotulo: 'Mensagens', icone: 'message-circle' },
  { id: 'marketing', rotulo: 'Marketing', icone: 'megaphone' },
  { id: 'fidelidade', rotulo: 'Fidelidade', icone: 'heart' },
  { id: 'equipe', rotulo: 'Equipe', icone: 'briefcase' },
  { id: 'ajustes', rotulo: 'Ajustes', icone: 'settings', fixo: true },
]

export const secoesCatalogo: readonly ItemNavegacao[] = [
  { id: 'servicos', rotulo: 'Serviços', total: 11 },
  { id: 'pacotes', rotulo: 'Pacotes', total: 1 },
  { id: 'combos', rotulo: 'Combos' },
  { id: 'planos', rotulo: 'Planos de assinatura' },
  { id: 'produtos', rotulo: 'Produtos', total: 6 },
]

/** Lista de seções do celular (Formulários, nível 1): ícones só dos nomeados no DESIGN.md */
export const secoesFormularios: readonly ItemNavegacao[] = [
  { id: 'fichas', rotulo: 'Fichas', icone: 'clipboard-list', total: 21, pendente: 4, rotuloContador: '21, 4 pendentes' },
  { id: 'modelos', rotulo: 'Modelos', icone: 'tag', total: 5 },
  { id: 'termos', rotulo: 'Termos', icone: 'lock', total: 2 },
]

export const barraBaixo = [
  { id: 'agenda', rotulo: 'Agenda', icone: 'calendar' },
  { id: 'clientes', rotulo: 'Clientes', icone: 'users' },
  { id: 'catalogo', rotulo: 'Catálogo', icone: 'tag' },
  // PONTO A MUDAR: ícone do "Mais" não está no DESIGN.md (mapa L7Icones não aprovado)
  { id: 'mais', rotulo: 'Mais' },
] as const satisfies readonly ItemNavegacao[]

/** Pessoas inventadas para a vitrine */
export const clientes = [
  { id: 'c1', nome: 'Lia Moura', iniciais: 'LM', detalhe: 'Última visita há 3 dias', valor: '45,00 €' },
  { id: 'c2', nome: 'Tomás Faria', iniciais: 'TF', detalhe: 'Última visita há 2 semanas', valor: '30,00 €' },
  { id: 'c3', nome: 'Nina Seixas', iniciais: 'NS', detalhe: 'Primeira visita', valor: '60,00 €' },
] as const

export const servicos = [
  { id: 's1', nome: 'Design de sobrancelha', detalhe: 'Sobrancelhas · 40 min', valor: '25,00 €', categoria: 1 },
  { id: 's2', nome: 'Hidratação labial', detalhe: 'Lábios · 30 min', valor: '35,00 €', categoria: 2 },
  { id: 's3', nome: 'Extensão de cílios', detalhe: 'Cílios · 90 min', valor: '70,00 €', categoria: 3 },
  { id: 's4', nome: 'Limpeza simples', detalhe: 'Pele · 50 min', valor: '40,00 €', categoria: 4 },
] as const

export const linhaDoTempo: readonly GrupoTempo[] = [
  {
    id: 'hoje',
    dia: 'Hoje',
    itens: [
      { id: 't1', icone: 'calendar-plus', titulo: 'Novo agendamento', detalhe: 'Design de sobrancelha às 15:00', hora: '10:42', naoLido: true },
      { id: 't2', icone: 'circle-check', titulo: 'Ficha concluída', detalhe: 'Modelo de exemplo', hora: '09:15' },
    ],
  },
  {
    id: 'ontem',
    dia: 'Ontem',
    itens: [{ id: 't3', icone: 'banknote', titulo: 'Pagamento recebido', detalhe: '45,00 €', hora: '18:03' }],
  },
]

export const acoesLinha = { editar: 'Editar', duplicar: 'Duplicar', arquivar: 'Arquivar', excluir: 'Excluir' } as const
