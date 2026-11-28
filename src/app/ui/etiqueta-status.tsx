// Etiqueta e Status (spec RC-10, RA-4; DESIGN.md §5). Mapa fixo coisa → ícone Lucide ("um ícone por coisa").
// O texto vem pronto de quem usa (RC-23); cor só para estado, sempre com ícone e palavra.
import type { Ref } from 'react'
import { Icone, type NomeIcone } from './icone'

type Tom = 'neutro' | 'pendente' | 'ok' | 'perigo'

interface Marca {
  icone: NomeIcone
  tom: Tom
}

/** DESIGN.md §5 · Etiquetas */
export const etiquetas = {
  'primeira-visita': { icone: 'user-plus', tom: 'neutro' },
  vip: { icone: 'crown', tom: 'neutro' },
  recorrente: { icone: 'repeat', tom: 'neutro' },
  'retoque-pendente': { icone: 'brush', tom: 'pendente' },
  alergia: { icone: 'circle-alert', tom: 'neutro' },
} as const satisfies Record<string, Marca>

/** DESIGN.md §5 · Status do agendamento e situação de formulário */
export const status = {
  reservado: { icone: 'clock', tom: 'pendente' },
  confirmado: { icone: 'thumbs-up', tom: 'neutro' },
  chegou: { icone: 'door-open', tom: 'neutro' },
  iniciado: { icone: 'play', tom: 'neutro' },
  concluido: { icone: 'circle-check', tom: 'ok' },
  ausencia: { icone: 'user-x', tom: 'perigo' },
  cancelado: { icone: 'circle-x', tom: 'neutro' },
  bloqueio: { icone: 'lock', tom: 'perigo' },
  'aguardando-cliente': { icone: 'hourglass', tom: 'pendente' },
  'bloqueia-checkout': { icone: 'shield-alert', tom: 'perigo' },
  'formulario-concluido': { icone: 'circle-check', tom: 'ok' },
} as const satisfies Record<string, Marca>

export type TipoEtiqueta = keyof typeof etiquetas
export type TipoStatus = keyof typeof status

export interface EtiquetaProps {
  tipo: TipoEtiqueta
  rotulo: string
}

export function Etiqueta({ tipo, rotulo }: Readonly<EtiquetaProps>) {
  const marca: Marca = etiquetas[tipo]
  return (
    <span className={`ds-marca ds-marca--${marca.tom}`}>
      <Icone nome={marca.icone} tamanho="14" />
      {rotulo}
    </span>
  )
}

export interface StatusProps {
  tipo: TipoStatus
  /** a palavra do status: "Confirmado" */
  rotulo: string
}

/** Status nas listas: ícone + palavra */
export function Status({ tipo, rotulo }: Readonly<StatusProps>) {
  const marca: Marca = status[tipo]
  return (
    <span className={`ds-marca ds-marca--${marca.tom}`}>
      <Icone nome={marca.icone} tamanho="14" />
      {rotulo}
    </span>
  )
}

/** Status só com o ícone (cartão pequeno da Agenda): a palavra vai para o leitor */
export function StatusIcone({ tipo, rotulo }: Readonly<StatusProps>) {
  const marca: Marca = status[tipo]
  return (
    <span className={`ds-marca ds-marca--${marca.tom}`} role="img" aria-label={rotulo}>
      <Icone nome={marca.icone} tamanho="16" />
    </span>
  )
}

export interface BotaoStatusProps extends StatusProps {
  /** nome completo para o leitor, começando pela palavra visível: "Confirmado. Trocar status" */
  nome: string
  onClick?: () => void
  ref?: Ref<HTMLButtonElement>
}

/** Botão "ícone + nome ▾" do agendamento: desenho 36, toque 44 */
export function BotaoStatus({ tipo, rotulo, nome, onClick, ref }: Readonly<BotaoStatusProps>) {
  const marca: Marca = status[tipo]
  return (
    <button ref={ref} type="button" className="ds-botao-status" aria-label={nome} onClick={onClick}>
      <span className={`ds-botao-status__desenho ds-marca--${marca.tom}`}>
        <Icone nome={marca.icone} tamanho="16" />
        <span className="ds-botao-status__texto">{rotulo}</span>
        <Icone nome="chevron-down" tamanho="16" />
      </span>
    </button>
  )
}
