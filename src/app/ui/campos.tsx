// Campos, buscas, caixinha e interruptor (spec RC-7, RC-8, RC-9; DESIGN.md §5, §8, §8b).
// Rótulo acima; obrigatório com * cinza; erro com contorno vermelho e mensagem com ícone embaixo.
import {
  useId,
  type InputHTMLAttributes,
  type ReactNode,
  type SelectHTMLAttributes,
  type TextareaHTMLAttributes,
} from 'react'
import { Icone } from './icone'
import { BotaoIcone, type BotaoIconeProps } from './botao'

interface MolduraProps {
  id: string
  idErro: string
  rotulo: string
  obrigatorio?: boolean
  erro?: string
  children: ReactNode
}

function Moldura({ id, idErro, rotulo, obrigatorio, erro, children }: Readonly<MolduraProps>) {
  return (
    <div className="ds-campo">
      <label htmlFor={id} className="ds-campo__rotulo">
        {rotulo}
        {obrigatorio ? (
          <span className="ds-campo__obrigatorio" aria-hidden="true">
            {' *'}
          </span>
        ) : null}
      </label>
      {children}
      {erro ? (
        <p id={idErro} className="ds-campo__erro">
          <Icone nome="circle-alert" tamanho="16" />
          {erro}
        </p>
      ) : null}
    </div>
  )
}

interface CampoBase {
  rotulo: string
  obrigatorio?: boolean
  erro?: string
}

type AtributosInput = Omit<InputHTMLAttributes<HTMLInputElement>, 'className' | 'style' | 'id' | 'required'>

function useIdsDoCampo(erro?: string) {
  const id = useId()
  const idErro = `${id}-erro`
  return { id, idErro, descrito: erro ? idErro : undefined }
}

export interface CampoTextoProps extends CampoBase, AtributosInput {}

export function CampoTexto({ rotulo, obrigatorio, erro, type = 'text', ...resto }: Readonly<CampoTextoProps>) {
  const { id, idErro, descrito } = useIdsDoCampo(erro)
  return (
    <Moldura id={id} idErro={idErro} rotulo={rotulo} obrigatorio={obrigatorio} erro={erro}>
      <input
        {...resto}
        id={id}
        type={type}
        required={obrigatorio}
        aria-invalid={erro ? true : undefined}
        aria-describedby={descrito}
        className="ds-campo__controle"
      />
    </Moldura>
  )
}

export interface CampoMultilinhaProps
  extends CampoBase,
    Omit<TextareaHTMLAttributes<HTMLTextAreaElement>, 'className' | 'style' | 'id' | 'required'> {}

export function CampoMultilinha({ rotulo, obrigatorio, erro, rows = 3, ...resto }: Readonly<CampoMultilinhaProps>) {
  const { id, idErro, descrito } = useIdsDoCampo(erro)
  return (
    <Moldura id={id} idErro={idErro} rotulo={rotulo} obrigatorio={obrigatorio} erro={erro}>
      <textarea
        {...resto}
        id={id}
        rows={rows}
        required={obrigatorio}
        aria-invalid={erro ? true : undefined}
        aria-describedby={descrito}
        className="ds-campo__controle ds-campo__controle--multi"
      />
    </Moldura>
  )
}

export interface OpcaoSelecao {
  valor: string
  rotulo: string
}

export interface CampoSelecaoProps
  extends CampoBase,
    Omit<SelectHTMLAttributes<HTMLSelectElement>, 'className' | 'style' | 'id' | 'required' | 'children'> {
  opcoes: readonly OpcaoSelecao[]
}

export function CampoSelecao({ rotulo, obrigatorio, erro, opcoes, ...resto }: Readonly<CampoSelecaoProps>) {
  const { id, idErro, descrito } = useIdsDoCampo(erro)
  return (
    <Moldura id={id} idErro={idErro} rotulo={rotulo} obrigatorio={obrigatorio} erro={erro}>
      <span className="ds-campo__caixa">
        <select
          {...resto}
          id={id}
          required={obrigatorio}
          aria-invalid={erro ? true : undefined}
          aria-describedby={descrito}
          className="ds-campo__controle ds-campo__controle--com-icone"
        >
          {opcoes.map((o) => (
            <option key={o.valor} value={o.valor}>
              {o.rotulo}
            </option>
          ))}
        </select>
        <Icone nome="chevron-down" tamanho="18" className="ds-campo__icone-fim" />
      </span>
    </Moldura>
  )
}

export interface CampoDataProps extends CampoBase, Omit<AtributosInput, 'type'> {}

export function CampoData({ rotulo, obrigatorio, erro, ...resto }: Readonly<CampoDataProps>) {
  const { id, idErro, descrito } = useIdsDoCampo(erro)
  return (
    <Moldura id={id} idErro={idErro} rotulo={rotulo} obrigatorio={obrigatorio} erro={erro}>
      <span className="ds-campo__caixa">
        <input
          {...resto}
          id={id}
          type="date"
          required={obrigatorio}
          aria-invalid={erro ? true : undefined}
          aria-describedby={descrito}
          className="ds-campo__controle ds-campo__controle--com-icone ds-campo__controle--data"
        />
        <Icone nome="calendar-days" tamanho="18" className="ds-campo__icone-fim" />
      </span>
    </Moldura>
  )
}

export interface BuscaTelaProps extends Omit<AtributosInput, 'type' | 'aria-label'> {
  /** nome acessível e texto do campo: "Buscar <coisa>" (DESIGN.md §6) */
  rotulo: string
  /** no celular: o funil ao lado (DESIGN.md §5) */
  filtro?: BotaoIconeProps
}

export function BuscaTela({ rotulo, filtro, placeholder, ...resto }: Readonly<BuscaTelaProps>) {
  return (
    <div className="ds-busca-tela">
      <span className="ds-busca">
        <Icone nome="search" tamanho="18" className="ds-busca__lupa" />
        <input {...resto} type="search" aria-label={rotulo} placeholder={placeholder ?? rotulo} className="ds-busca__campo" />
      </span>
      {filtro ? (
        <span className="ds-busca-tela__filtro">
          <BotaoIcone {...filtro} />
        </span>
      ) : null}
    </div>
  )
}

export interface BuscaGeralProps extends Omit<AtributosInput, 'type' | 'aria-label'> {
  /** "Buscar no sistema" */
  rotulo: string
  /** atalho mostrado à direita: "⌘K" */
  atalho: string
}

export function BuscaGeral({ rotulo, atalho, placeholder, ...resto }: Readonly<BuscaGeralProps>) {
  return (
    <span className="ds-busca ds-busca--geral">
      <Icone nome="search" tamanho="16" className="ds-busca__lupa" />
      <input {...resto} type="search" aria-label={rotulo} placeholder={placeholder ?? rotulo} className="ds-busca__campo" />
      <kbd className="ds-busca__atalho" aria-hidden="true">
        {atalho}
      </kbd>
    </span>
  )
}

export interface CaixinhaProps extends Omit<AtributosInput, 'type'> {
  rotulo: string
}

export function Caixinha({ rotulo, ...resto }: Readonly<CaixinhaProps>) {
  return (
    <label className="ds-marcavel">
      <input {...resto} type="checkbox" className="ds-caixinha" />
      <span>{rotulo}</span>
    </label>
  )
}

export interface InterruptorProps extends Omit<AtributosInput, 'type' | 'role'> {
  rotulo: string
}

export function Interruptor({ rotulo, ...resto }: Readonly<InterruptorProps>) {
  return (
    <label className="ds-marcavel">
      <input {...resto} type="checkbox" role="switch" className="ds-interruptor" />
      <span>{rotulo}</span>
    </label>
  )
}
