// Camadas por cima (spec RC-13 a RC-16, RA-5; DESIGN.md §5, §6, §8, §8b; ADR 0004 · D2).
// Menu: padrão "Menu Button" do WAI-ARIA APG. Janelinha, folha e painel: <dialog> nativo com showModal()
// (página de trás inerte, Esc fecha); o foco volta a quem abriu. Texto recebido pronto (RC-23).
import { useEffect, useId, useRef, useState, type KeyboardEvent, type ReactNode } from 'react'
import { Botao, BotaoIcone } from './botao'
import { Icone } from './icone'

export interface ItemMenu {
  id: string
  rotulo: string
  /** Excluir: texto vermelho */
  perigo?: boolean
  onSelecionar?: () => void
}

export interface MenuAcoesProps {
  /** "Opções" (computador: botão claro "Opções ▾"; celular e linha: ⋮ com este nome) */
  nome: string
  gatilho: 'botao' | 'icone'
  itens: readonly ItemMenu[]
  /** lado do botão em que o menu se alinha: 'inicio' (botão à esquerda) ou 'fim' (⋮ no fim da linha, barra do topo) */
  alinhar?: 'inicio' | 'fim'
}

export function MenuAcoes({ nome, gatilho, itens, alinhar = 'inicio' }: Readonly<MenuAcoesProps>) {
  const [aberto, setAberto] = useState(false)
  const idMenu = useId()
  const botao = useRef<HTMLButtonElement>(null)
  const raiz = useRef<HTMLDivElement>(null)
  const refs = useRef<Array<HTMLButtonElement | null>>([])

  useEffect(() => {
    if (!aberto) return
    refs.current[0]?.focus()
    function fora(evento: MouseEvent) {
      if (raiz.current && !raiz.current.contains(evento.target as Node)) setAberto(false)
    }
    document.addEventListener('mousedown', fora)
    return () => document.removeEventListener('mousedown', fora)
  }, [aberto])

  function fechar(devolverFoco: boolean) {
    setAberto(false)
    if (devolverFoco) botao.current?.focus()
  }

  function tecladoMenu(evento: KeyboardEvent<HTMLDivElement>) {
    const atual = refs.current.findIndex((el) => el === document.activeElement)
    const ultimo = itens.length - 1
    const destino: Record<string, number> = {
      ArrowDown: atual >= ultimo ? 0 : atual + 1,
      ArrowUp: atual <= 0 ? ultimo : atual - 1,
      Home: 0,
      End: ultimo,
    }
    if (evento.key === 'Escape') {
      evento.preventDefault()
      fechar(true)
      return
    }
    if (evento.key === 'Tab') {
      fechar(false)
      return
    }
    const alvo = destino[evento.key]
    if (alvo === undefined) return
    evento.preventDefault()
    refs.current[alvo]?.focus()
  }

  function tecladoBotao(evento: KeyboardEvent<HTMLButtonElement>) {
    if (evento.key === 'ArrowDown' || evento.key === 'ArrowUp') {
      evento.preventDefault()
      setAberto(true)
    }
  }

  const comum = {
    ref: botao,
    'aria-haspopup': 'menu' as const,
    'aria-expanded': aberto,
    'aria-controls': idMenu,
    onClick: () => setAberto((a) => !a),
    onKeyDown: tecladoBotao,
  }

  return (
    <div className="ds-menu" ref={raiz}>
      {gatilho === 'botao' ? (
        <Botao {...comum} variante="claro" seta>
          {nome}
        </Botao>
      ) : (
        <BotaoIcone {...comum} nome={nome} icone="ellipsis-vertical" />
      )}
      <div id={idMenu} role="menu" aria-label={nome} className={`ds-menu__lista ds-menu__lista--${alinhar}`} hidden={!aberto} onKeyDown={tecladoMenu}>
        {itens.map((item, indice) => (
          <button
            key={item.id}
            ref={(el) => {
              refs.current[indice] = el
            }}
            type="button"
            role="menuitem"
            tabIndex={-1}
            className={item.perigo ? 'ds-menu__item ds-menu__item--perigo' : 'ds-menu__item'}
            onClick={() => {
              item.onSelecionar?.()
              fechar(true)
            }}
          >
            {item.rotulo}
          </button>
        ))}
      </div>
    </div>
  )
}

export interface RotulosAcoesLinha {
  editar: string
  duplicar: string
  arquivar: string
  excluir: string
}

export interface MenuAcoesLinhaProps {
  /** "Opções de <item>" */
  nome: string
  rotulos: RotulosAcoesLinha
  onSelecionar?: (acao: keyof RotulosAcoesLinha) => void
  /** no fim da linha (padrão) o menu se alinha ao fim */
  alinhar?: 'inicio' | 'fim'
}

/** ⋮ da linha: Editar · Duplicar · Arquivar · Excluir, nesta ordem; Excluir em vermelho (DESIGN.md §6) */
export function MenuAcoesLinha({ nome, rotulos, onSelecionar, alinhar = 'fim' }: Readonly<MenuAcoesLinhaProps>) {
  const ordem = ['editar', 'duplicar', 'arquivar', 'excluir'] as const
  const itens = ordem.map((acao) => ({
    id: acao,
    rotulo: rotulos[acao],
    perigo: acao === 'excluir',
    onSelecionar: () => onSelecionar?.(acao),
  }))
  return <MenuAcoes nome={nome} gatilho="icone" itens={itens} alinhar={alinhar} />
}

type TipoCamada = 'janelinha' | 'folha' | 'painel'

interface CamadaProps {
  tipo: TipoCamada
  aberta: boolean
  onFechar: () => void
  titulo: string
  /** nome do ✕ ("Fechar"); a janelinha não tem ✕ */
  nomeFechar?: string
  children: ReactNode
  rodape?: ReactNode
}

function Camada({ tipo, aberta, onFechar, titulo, nomeFechar, children, rodape }: Readonly<CamadaProps>) {
  const dialogo = useRef<HTMLDialogElement>(null)
  const anterior = useRef<HTMLElement | null>(null)
  const idTitulo = useId()
  // quem chama já fechou (Cancelar, Confirmar)? então o evento "close" não chama onFechar de novo
  const abertaAgora = useRef(aberta)
  useEffect(() => {
    abertaAgora.current = aberta
  }, [aberta])

  useEffect(() => {
    const el = dialogo.current
    if (!el) return
    if (aberta && !el.open) {
      anterior.current = document.activeElement as HTMLElement | null
      el.showModal()
    } else if (!aberta && el.open) {
      el.close()
    }
  }, [aberta])

  function aoFechar() {
    // Esc ou ✕: o navegador fechou e a prop ainda diz aberta
    if (abertaAgora.current) onFechar()
    anterior.current?.focus()
  }

  return (
    <dialog ref={dialogo} className={`ds-camada ds-camada--${tipo}`} aria-labelledby={idTitulo} onClose={aoFechar}>
      {tipo === 'folha' ? <span className="ds-camada__pegador" aria-hidden="true" /> : null}
      <div className="ds-camada__cabecalho">
        <h2 id={idTitulo} className="ds-camada__titulo">
          {titulo}
        </h2>
        {nomeFechar ? <BotaoIcone nome={nomeFechar} icone="x" onClick={() => dialogo.current?.close()} /> : null}
      </div>
      <div className="ds-camada__corpo">{children}</div>
      {rodape ? <div className="ds-camada__rodape">{rodape}</div> : null}
    </dialog>
  )
}

export interface JanelinhaProps {
  aberta: boolean
  onFechar: () => void
  /** 'Excluir "Corte feminino"?' */
  titulo: string
  texto: string
  rotuloCancelar: string
  /** "Excluir": texto vermelho, sem fundo (DESIGN.md §8; não a imagem 06) */
  rotuloConfirmar: string
  onConfirmar: () => void
}

/** Janelinha de confirmação para o que não se desfaz (340) */
export function Janelinha({ aberta, onFechar, titulo, texto, rotuloCancelar, rotuloConfirmar, onConfirmar }: Readonly<JanelinhaProps>) {
  return (
    <Camada
      tipo="janelinha"
      aberta={aberta}
      onFechar={onFechar}
      titulo={titulo}
      rodape={
        <>
          <Botao variante="claro" onClick={onFechar}>
            {rotuloCancelar}
          </Botao>
          <Botao
            variante="excluir"
            onClick={() => {
              onConfirmar()
              onFechar()
            }}
          >
            {rotuloConfirmar}
          </Botao>
        </>
      }
    >
      <p className="ds-camada__texto">{texto}</p>
    </Camada>
  )
}

export interface FolhaPainelProps {
  aberta: boolean
  onFechar: () => void
  titulo: string
  nomeFechar: string
  children: ReactNode
  /** botões do rodapé; o de confirmar é o preto da camada */
  rodape?: ReactNode
}

/** Folha de baixo (celular): canto 28 no topo */
export function Folha(props: Readonly<FolhaPainelProps>) {
  return <Camada tipo="folha" {...props} />
}

/** Painel à direita (computador): 480 */
export function Painel(props: Readonly<FolhaPainelProps>) {
  return <Camada tipo="painel" {...props} />
}

export interface LinhaQueAbreProps {
  rotulo: string
  /** valor à direita: "Última visita" */
  valor?: ReactNode
  children: ReactNode
  inicialAberta?: boolean
}

/** Linha da folha ou do painel que abre com ▾/▴ */
export function LinhaQueAbre({ rotulo, valor, children, inicialAberta = false }: Readonly<LinhaQueAbreProps>) {
  const [aberta, setAberta] = useState(inicialAberta)
  const id = useId()
  return (
    <div className="ds-abre">
      <button type="button" className="ds-abre__cabecalho" aria-expanded={aberta} aria-controls={id} onClick={() => setAberta((a) => !a)}>
        <span className="ds-abre__rotulo">{rotulo}</span>
        {valor ? <span className="ds-abre__valor">{valor}</span> : null}
        <Icone nome={aberta ? 'chevron-up' : 'chevron-down'} tamanho="16" />
      </button>
      <div id={id} className="ds-abre__corpo" hidden={!aberta}>
        {children}
      </div>
    </div>
  )
}

export interface AvisoProps {
  /** "Serviço salvo"; sem mensagem, a região fica vazia (pronta para anunciar) */
  mensagem?: string
  /** "Desfazer", quando der */
  rotuloDesfazer?: string
  onDesfazer?: () => void
}

/** Aviso embaixo depois de uma ação (role=status, anunciado ao leitor) */
export function Aviso({ mensagem, rotuloDesfazer, onDesfazer }: Readonly<AvisoProps>) {
  return (
    <div role="status" className="ds-aviso-regiao">
      {mensagem ? (
        <div className="ds-aviso">
          <Icone nome="circle-check" tamanho="18" className="ds-aviso__icone" />
          <span>{mensagem}</span>
          {rotuloDesfazer ? (
            <button type="button" className="ds-aviso__desfazer" onClick={onDesfazer}>
              {rotuloDesfazer}
            </button>
          ) : null}
        </div>
      ) : null}
    </div>
  )
}
