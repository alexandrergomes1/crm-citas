// Sua conta (spec RF-14, RF-30; ficha E41; DESIGN.md §6, §8, §8b "Sua conta"): a barra com a bolinha da pessoa e o
// menu (computador) ou a folha (celular). Itens na ordem do §8b; Minha conta, Preferências e Meu faturamento
// esmaecidos com "em desenvolvimento" (aria-disabled); "Trocar de empresa" só com mais de uma empresa.
import { useEffect, useId, useLayoutEffect, useRef, useState, type KeyboardEvent, type Ref } from 'react'
import type { Textos } from '@/app/i18n/textos'
import { Folha } from '@/app/ui/camadas'
import { Icone } from '@/app/ui/icone'

export type ItemSuaConta = {
  readonly id: 'minhaConta' | 'preferencias' | 'meuFaturamento' | 'trocarDeEstudio' | 'sair'
  readonly rotulo: string
  /** função que ainda não existe: esmaecida, com "em desenvolvimento" (DESIGN.md §8) */
  readonly emDesenvolvimento: boolean
}

/** Itens na ordem do DESIGN.md §8b. */
export function itensDaConta(textos: Textos, quantosEstudios: number): ItemSuaConta[] {
  const t = textos.suaConta
  const itens: ItemSuaConta[] = [
    { id: 'minhaConta', rotulo: t.minhaConta, emDesenvolvimento: true },
    { id: 'preferencias', rotulo: t.preferencias, emDesenvolvimento: true },
    { id: 'meuFaturamento', rotulo: t.meuFaturamento, emDesenvolvimento: true },
  ]
  if (quantosEstudios > 1) itens.push({ id: 'trocarDeEstudio', rotulo: t.trocarDeEstudio, emDesenvolvimento: false })
  itens.push({ id: 'sair', rotulo: t.sair, emDesenvolvimento: false })
  return itens
}

/** O desenho escolhido pelo tokens.css (ponto único de troca; E25·3): o computador mostra o menu. */
function ehComputador(): boolean {
  return getComputedStyle(document.documentElement).getPropertyValue('--mostra-computador').trim() !== 'none'
}

/**
 * Bolinha 40 de Sua conta: a inicial da pessoa ou, sem ela, o ícone `user` (DESIGN.md §5 e §8b; E47·2·A). O nome no
 * leitor é sempre "Sua conta" (aria-label); a letra e o ícone são enfeite. Mesmo desenho e classes da peça `SuaConta`
 * de `src/app/ui/conteudo.tsx`, que só aceita a inicial em texto; aceitar o ícone lá é a correção de fundo, mas o
 * arquivo está fora da lista do plan.md §10 (igual ao `ErroSemFrase` de escolher-estudio.tsx).
 */
export function BolinhaDaConta({
  nome,
  inicial,
  onClick,
  ref,
}: Readonly<{ nome: string; inicial: string; onClick?: () => void; ref?: Ref<HTMLButtonElement> }>) {
  return (
    <button ref={ref} type="button" className="ds-sua-conta" aria-label={nome} onClick={onClick}>
      <span className="ds-bolinha" aria-hidden="true">
        {inicial === '' ? <Icone nome="user" /> : inicial}
      </span>
    </button>
  )
}

export interface MenuSuaContaProps {
  textos: Textos
  /** primeira letra do e-mail da própria pessoa (DESIGN.md §8b); vazia → ícone `user` (E47·2·A) */
  inicial: string
  quantosEstudios: number
  onTrocar: () => void
  onSair: () => void
  /** só para o teste por renderToString: abre num dos desenhos */
  abertoInicial?: 'menu' | 'folha'
}

export function MenuSuaConta({ textos, inicial, quantosEstudios, onTrocar, onSair, abertoInicial }: Readonly<MenuSuaContaProps>) {
  const [aberto, setAberto] = useState<'menu' | 'folha' | null>(abertoInicial ?? null)
  const botao = useRef<HTMLButtonElement>(null)
  const raiz = useRef<HTMLDivElement>(null)
  const refs = useRef<Array<HTMLButtonElement | null>>([])
  const lista = useRef<HTMLDivElement>(null)
  const idMenu = useId()
  const itens = itensDaConta(textos, quantosEstudios)
  const nome = textos.suaConta.nome

  // A bolinha (desenho da peça SuaConta, item 4) não recebe atributos ARIA: o estado do botão é posto aqui (padrão Menu Button do APG)
  useEffect(() => {
    const el = botao.current
    if (!el) return
    el.setAttribute('aria-haspopup', ehComputador() ? 'menu' : 'dialog')
    el.setAttribute('aria-expanded', aberto ? 'true' : 'false')
    if (aberto === 'menu') el.setAttribute('aria-controls', idMenu)
    else el.removeAttribute('aria-controls')
  }, [aberto, idMenu])

  // O menu aberto fica dentro da tela, a --margem de cada borda (DESIGN.md §4), como o MenuAcoes de
  // src/app/ui/camadas.tsx: desloca só o que sobrar (revisão de código 2)
  useLayoutEffect(() => {
    const el = lista.current
    if (aberto !== 'menu' || !el) return
    el.style.setProperty('--desloca-menu', '0')
    const margem = Number.parseFloat(getComputedStyle(el).getPropertyValue('--margem')) || 0
    const r = el.getBoundingClientRect()
    const largura = document.documentElement.clientWidth
    let desloca = 0
    if (r.right > largura - margem) desloca = largura - margem - r.right
    if (r.left + desloca < margem) desloca = margem - r.left
    el.style.setProperty('--desloca-menu', `${desloca}px`)
  }, [aberto])

  // Seta para baixo ou para cima no botão abre o menu no primeiro item (padrão Menu Button do APG; igual ao
  // MenuAcoes). A bolinha não recebe onKeyDown: a escuta vai direto no botão. No celular o botão
  // abre uma folha (diálogo), que não usa setas.
  useEffect(() => {
    const el = botao.current
    if (!el) return
    function tecla(evento: globalThis.KeyboardEvent) {
      if ((evento.key === 'ArrowDown' || evento.key === 'ArrowUp') && ehComputador()) {
        evento.preventDefault()
        setAberto('menu')
      }
    }
    el.addEventListener('keydown', tecla)
    return () => el.removeEventListener('keydown', tecla)
  }, [])

  useEffect(() => {
    if (aberto !== 'menu') return
    refs.current[0]?.focus()
    function fora(evento: MouseEvent) {
      if (raiz.current && !raiz.current.contains(evento.target as Node)) setAberto(null)
    }
    document.addEventListener('mousedown', fora)
    return () => document.removeEventListener('mousedown', fora)
  }, [aberto])

  function fechar(devolverFoco: boolean) {
    setAberto(null)
    if (devolverFoco) botao.current?.focus()
  }

  function escolher(item: ItemSuaConta) {
    if (item.emDesenvolvimento) return
    setAberto(null)
    if (item.id === 'trocarDeEstudio') onTrocar()
    if (item.id === 'sair') onSair()
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

  return (
    <div className="ds-menu" ref={raiz}>
      <BolinhaDaConta
        ref={botao}
        nome={nome}
        inicial={inicial}
        onClick={() => setAberto((a) => (a ? null : ehComputador() ? 'menu' : 'folha'))}
      />
      <div
        ref={lista}
        id={idMenu}
        role="menu"
        aria-label={nome}
        className="ds-menu__lista ds-menu__lista--fim"
        hidden={aberto !== 'menu'}
        onKeyDown={tecladoMenu}
      >
        {itens.map((item, indice) => (
          <button
            key={item.id}
            ref={(el) => {
              refs.current[indice] = el
            }}
            type="button"
            role="menuitem"
            tabIndex={-1}
            aria-disabled={item.emDesenvolvimento ? true : undefined}
            className={item.emDesenvolvimento ? 'ds-menu__item sua-conta__item sua-conta__item--em-desenvolvimento' : 'ds-menu__item sua-conta__item'}
            onClick={() => escolher(item)}
          >
            <span className="sua-conta__rotulo">{item.rotulo}</span>
            {item.emDesenvolvimento ? <span className="sua-conta__nota">{textos.comum.emDesenvolvimento}</span> : null}
          </button>
        ))}
      </div>
      <Folha aberta={aberto === 'folha'} onFechar={() => setAberto(null)} titulo={nome} nomeFechar={textos.comum.fechar}>
        <ul className="ds-lista sua-conta__folha" aria-label={nome}>
          {itens.map((item) => (
            <li key={item.id} className="sua-conta__linha">
              <button
                type="button"
                aria-disabled={item.emDesenvolvimento ? true : undefined}
                className={item.emDesenvolvimento ? 'sua-conta__botao sua-conta__item--em-desenvolvimento' : 'sua-conta__botao'}
                onClick={() => escolher(item)}
              >
                <span className="sua-conta__rotulo">{item.rotulo}</span>
                {item.emDesenvolvimento ? <span className="sua-conta__nota">{textos.comum.emDesenvolvimento}</span> : null}
              </button>
            </li>
          ))}
        </ul>
      </Folha>
    </div>
  )
}

export type BarraSuaContaProps = MenuSuaContaProps

/** A barra da área com sessão: só Sua conta, à direita (ficha: "só a barra com a bolinha"). */
export function BarraSuaConta(props: Readonly<BarraSuaContaProps>) {
  return (
    <header className="sua-conta__barra">
      <MenuSuaConta {...props} />
    </header>
  )
}
