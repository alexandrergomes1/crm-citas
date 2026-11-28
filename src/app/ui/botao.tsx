// Botões (spec RC-1, RC-2, RC-3; DESIGN.md §5, §6, §8). Texto sempre recebido pronto (RC-23).
import { useId, type ButtonHTMLAttributes, type ReactNode, type Ref } from 'react'
import { Icone, type NomeIcone } from './icone'
import { Contador, type ContadorProps } from './contador'

export type VarianteBotao = 'principal' | 'claro' | 'contorno' | 'excluir'

type AtributosBotao = Omit<ButtonHTMLAttributes<HTMLButtonElement>, 'children' | 'className' | 'style'>

export interface BotaoProps extends AtributosBotao {
  /** principal = preto (uma por tela); claro = --btn; contorno = "+ Adicionar" do celular; excluir = texto vermelho */
  variante?: VarianteBotao
  /** ícone à esquerda (Filtros, Ordenar, modo de ver, "+") */
  icone?: NomeIcone
  /** ▾ à direita (Opções ▾, Filtros ▾, Ordenar: … ▾) */
  seta?: boolean
  /** pílula de contador dentro do botão (Filtros 2) */
  contador?: ContadorProps
  /** texto ao lado do botão desativado, ex.: "em desenvolvimento" (DESIGN.md §8) */
  nota?: string
  /** ocupa a largura toda (rodapé de folha) */
  cheio?: boolean
  ref?: Ref<HTMLButtonElement>
  children: ReactNode
}

export function Botao({
  variante = 'claro',
  icone,
  seta = false,
  contador,
  nota,
  cheio = false,
  type = 'button',
  ref,
  children,
  ...resto
}: Readonly<BotaoProps>) {
  const idNota = useId()
  const classes = ['ds-botao', `ds-botao--${variante}`, cheio ? 'ds-botao--cheio' : ''].filter(Boolean).join(' ')
  const botao = (
    <button
      {...resto}
      ref={ref}
      type={type}
      className={classes}
      aria-describedby={nota ? idNota : resto['aria-describedby']}
    >
      {icone ? <Icone nome={icone} tamanho="18" /> : null}
      <span className="ds-botao__texto">{children}</span>
      {contador ? <Contador {...contador} /> : null}
      {seta ? <Icone nome="chevron-down" tamanho="16" /> : null}
    </button>
  )
  if (!nota) return botao
  return (
    <span className="ds-botao-com-nota">
      {botao}
      <span id={idNota} className="ds-botao-com-nota__nota">
        {nota}
      </span>
    </span>
  )
}

export interface BotaoIconeProps extends Omit<AtributosBotao, 'aria-label'> {
  /** nome acessível obrigatório (RA-5): "Fechar", "Voltar", "Opções", "Ajuda", "Notificações", "Filtros" */
  nome: string
  icone: NomeIcone
  /** ícone + pílula no mesmo botão (funil + 2; sininho + 3), DESIGN.md §5 */
  contador?: ContadorProps
  /** fundo claro (funil com filtro ligado, no celular) */
  claro?: boolean
  ref?: Ref<HTMLButtonElement>
}

export function BotaoIcone({ nome, icone, contador, claro = false, type = 'button', ref, ...resto }: Readonly<BotaoIconeProps>) {
  const temContador = Boolean(contador && contador.total > 0)
  const classes = [
    'ds-botao-icone',
    temContador ? 'ds-botao-icone--contador' : '',
    claro ? 'ds-botao-icone--claro' : '',
  ]
    .filter(Boolean)
    .join(' ')
  return (
    <button {...resto} ref={ref} type={type} className={classes} aria-label={nome}>
      <Icone nome={icone} />
      {temContador && contador ? <Contador {...contador} decorativo /> : null}
    </button>
  )
}
