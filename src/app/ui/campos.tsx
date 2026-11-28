// Campos, buscas, caixinha e interruptor (spec RC-7, RC-8, RC-9; DESIGN.md §5, §8, §8b).
// Rótulo acima; obrigatório com * cinza; erro com contorno vermelho e mensagem com ícone embaixo.
import {
  useId,
  useRef,
  useState,
  type KeyboardEvent,
  type InputHTMLAttributes,
  type ReactNode,
  type Ref,
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

export interface CampoSenhaProps extends CampoBase, Omit<AtributosInput, 'type' | 'maxLength'> {
  /** nome do olho para o leitor: "Mostrar senha" e "Esconder senha" (DESIGN.md §6) */
  rotuloMostrar: string
  rotuloEsconder: string
  /** enviando: campo só leitura e olho travado (DESIGN.md §8, ficha E41·3·A) */
  travado?: boolean
  ref?: Ref<HTMLInputElement>
}

/**
 * Senha com o botão do olho dentro do campo, à direita (DESIGN.md §5; ficha E41·2·A). Sem maxlength (o navegador
 * cortaria o que se cola; RF-32) e colar permitido (WCAG 3.3.8). O olho muda o nome, sem aria-pressed (WCAG 4.1.2).
 */
export function CampoSenha({ rotulo, obrigatorio, erro, rotuloMostrar, rotuloEsconder, travado = false, ref, ...resto }: Readonly<CampoSenhaProps>) {
  const { id, idErro, descrito } = useIdsDoCampo(erro)
  const [mostrando, setMostrando] = useState(false)
  return (
    <Moldura id={id} idErro={idErro} rotulo={rotulo} obrigatorio={obrigatorio} erro={erro}>
      <span className="ds-campo__caixa">
        <input
          autoComplete="current-password"
          {...resto}
          ref={ref}
          id={id}
          type={mostrando ? 'text' : 'password'}
          readOnly={travado || resto.readOnly}
          required={obrigatorio}
          aria-invalid={erro ? true : undefined}
          aria-describedby={descrito}
          className="ds-campo__controle ds-campo__controle--senha"
        />
        <span className="ds-campo__olho">
          <BotaoIcone
            nome={mostrando ? rotuloEsconder : rotuloMostrar}
            icone={mostrando ? 'eye-off' : 'eye'}
            aria-controls={id}
            aria-disabled={travado ? true : undefined}
            onClick={() => {
              if (!travado) setMostrando((m) => !m)
            }}
          />
        </span>
      </span>
    </Moldura>
  )
}

export interface ErroFormularioProps {
  /** frase pronta; vazia, a linha não aparece */
  mensagem?: string
}

/**
 * Erro que não pode dizer qual campo falhou: numa linha acima da ação, com ícone e palavra, sem contorno vermelho
 * (DESIGN.md §8; ficha E41·3·A). Anunciado ao leitor (role="alert").
 */
export function ErroFormulario({ mensagem }: Readonly<ErroFormularioProps>) {
  if (!mensagem) return null
  return (
    <p role="alert" className="ds-campo__erro ds-campo__erro--formulario">
      <Icone nome="circle-alert" tamanho="20" />
      <span>{mensagem}</span>
    </p>
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

/**
 * Data por extenso no idioma do estúdio, como na imagem 06 ("sex, 4 dez 2026"), pelo Intl.
 * Recebe e devolve a data no formato ISO (AAAA-MM-DD); a conta é em UTC para não trocar o dia pelo fuso.
 */
export function dataPorExtenso(iso: string, idioma: string): string {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(iso)
  if (!m) return ''
  const data = new Date(Date.UTC(Number(m[1]), Number(m[2]) - 1, Number(m[3])))
  // cada parte sozinha: junta, o Intl troca o mês por número em alguns idiomas (ex.: pt-PT)
  const parte = (opcoes: Intl.DateTimeFormatOptions) =>
    new Intl.DateTimeFormat(idioma, { ...opcoes, timeZone: 'UTC' }).format(data).replace(/\.$/, '')
  return `${parte({ weekday: 'short' })}, ${parte({ day: 'numeric' })} ${parte({ month: 'short' })} ${parte({ year: 'numeric' })}`
}

export interface CampoDataProps extends CampoBase {
  /** idioma do estúdio, ex.: "pt", "es-ES" (ARCHITECTURE.md §11) */
  idioma: string
  /** data inicial em ISO (AAAA-MM-DD) */
  valorInicial?: string
  /** texto quando vazio, recebido pronto (RC-23) */
  textoVazio?: string
  disabled?: boolean
  onMudar?: (iso: string) => void
}

/** Campo de data em pílula com o calendário; o calendário do navegador abre ao tocar ou com Enter, Espaço ou ↓ */
export function CampoData({ rotulo, obrigatorio, erro, idioma, valorInicial = '', textoVazio, disabled, onMudar }: Readonly<CampoDataProps>) {
  const { id, idErro, descrito } = useIdsDoCampo(erro)
  const [valor, setValor] = useState(valorInicial)
  const nativo = useRef<HTMLInputElement>(null)

  function abrirCalendario() {
    if (disabled) return
    try {
      nativo.current?.showPicker()
    } catch {
      nativo.current?.focus()
    }
  }

  function teclado(evento: KeyboardEvent<HTMLInputElement>) {
    if (evento.key === 'Enter' || evento.key === ' ' || evento.key === 'ArrowDown') {
      evento.preventDefault()
      abrirCalendario()
    }
  }

  return (
    <Moldura id={id} idErro={idErro} rotulo={rotulo} obrigatorio={obrigatorio} erro={erro}>
      <span className="ds-campo__caixa">
        <input
          id={id}
          type="text"
          readOnly
          value={dataPorExtenso(valor, idioma)}
          placeholder={textoVazio}
          disabled={disabled}
          required={obrigatorio}
          aria-invalid={erro ? true : undefined}
          aria-describedby={descrito}
          className="ds-campo__controle ds-campo__controle--com-icone ds-campo__controle--data"
          onClick={abrirCalendario}
          onKeyDown={teclado}
        />
        <Icone nome="calendar-days" tamanho="18" className="ds-campo__icone-fim" />
        {/* calendário do navegador: só abre o seletor; fica fora da ordem de foco e do leitor */}
        <input
          ref={nativo}
          type="date"
          tabIndex={-1}
          aria-hidden="true"
          value={valor}
          disabled={disabled}
          className="ds-campo__nativo"
          onChange={(e) => {
            setValor(e.target.value)
            onMudar?.(e.target.value)
          }}
        />
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
