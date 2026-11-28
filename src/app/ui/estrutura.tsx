// Estrutura das telas (spec RC-5, RC-18, RC-19; DESIGN.md §5, §8b). Só peça visual com itens recebidos
// por propriedade: rotas e mapa de navegação ficam para as specs de módulo (Assumption 4 da spec).
import { useState, type ReactNode } from 'react'
import { BotaoIcone } from './botao'
import { BuscaGeral, type BuscaGeralProps } from './campos'
import { Contador } from './contador'
import { Icone, type NomeIcone } from './icone'

export interface AgendarProps {
  /** "Agendar" */
  rotulo: string
  onClick?: () => void
}

/** Agendar da barra de baixo: círculo 52 preto, calendar-plus branco, nome 11 forte */
export function Agendar({ rotulo, onClick }: Readonly<AgendarProps>) {
  return (
    <button type="button" className="ds-agendar" onClick={onClick}>
      <span className="ds-agendar__circulo">
        <Icone nome="calendar-plus" tamanho="24" />
      </span>
      <span className="ds-agendar__nome">{rotulo}</span>
    </button>
  )
}

export interface BarraTopoProps {
  titulo: string
  subtitulo?: string
  busca: BuscaGeralProps
  /** Opções ▾ */
  opcoes?: ReactNode
  /** a ação principal (preta) */
  acao?: ReactNode
  /** ajuda · notificações · Sua conta, nesta ordem */
  topo: ReactNode
}

/** Barra do topo do computador (64, linha de 1 px): título · busca geral · Opções · ação · divisor · topo */
export function BarraTopo({ titulo, subtitulo, busca, opcoes, acao, topo }: Readonly<BarraTopoProps>) {
  return (
    <header className="ds-barra-topo">
      <div className="ds-barra-topo__titulo">
        <h2 className="ds-barra-topo__nome">{titulo}</h2>
        {subtitulo ? <p className="ds-barra-topo__sub">{subtitulo}</p> : null}
      </div>
      <BuscaGeral {...busca} />
      <div className="ds-barra-topo__acoes">
        {opcoes}
        {acao}
        <span className="ds-barra-topo__divisor" aria-hidden="true" />
        {topo}
      </div>
    </header>
  )
}

export interface ItemNavegacao {
  id: string
  rotulo: string
  icone?: NomeIcone
  total?: number
  pendente?: number
  rotuloContador?: string
  /** Ajustes: fixo embaixo */
  fixo?: boolean
}

export interface MenuPrincipalProps {
  /** nome da navegação: "Menu principal" */
  nome: string
  itens: readonly ItemNavegacao[]
  atual: string
  rotuloAbrir: string
  rotuloRecolher: string
  inicialRecolhido?: boolean
}

/** Menu principal do computador: aberto 232, recolhido 84; atual em fundo claro com ícone --id */
export function MenuPrincipal({ nome, itens, atual, rotuloAbrir, rotuloRecolher, inicialRecolhido = false }: Readonly<MenuPrincipalProps>) {
  const [recolhido, setRecolhido] = useState(inicialRecolhido)
  const item = (i: ItemNavegacao) => (
    <li key={i.id}>
      <button
        type="button"
        className="ds-menu-principal__item"
        aria-current={i.id === atual ? 'page' : undefined}
      >
        {i.icone ? <Icone nome={i.icone} /> : null}
        <span className="ds-menu-principal__nome">{i.rotulo}</span>
      </button>
    </li>
  )
  return (
    <nav aria-label={nome} className={recolhido ? 'ds-menu-principal ds-menu-principal--recolhido' : 'ds-menu-principal'}>
      <div className="ds-menu-principal__topo">
        <BotaoIcone
          nome={recolhido ? rotuloAbrir : rotuloRecolher}
          icone="panel-left"
          aria-expanded={!recolhido}
          onClick={() => setRecolhido((r) => !r)}
        />
      </div>
      <ul className="ds-menu-principal__lista">{itens.filter((i) => !i.fixo).map(item)}</ul>
      <ul className="ds-menu-principal__lista ds-menu-principal__lista--fixo">{itens.filter((i) => i.fixo).map(item)}</ul>
    </nav>
  )
}

export interface SubmenuProps {
  nome: string
  itens: readonly ItemNavegacao[]
  atual: string
}

/** Submenu ao lado (216), sem repetir o nome do módulo */
export function Submenu({ nome, itens, atual }: Readonly<SubmenuProps>) {
  return (
    <nav aria-label={nome} className="ds-submenu">
      <ul className="ds-menu-principal__lista">
        {itens.map((i) => (
          <li key={i.id}>
            <button type="button" className="ds-submenu__item" aria-current={i.id === atual ? 'page' : undefined}>
              <span className="ds-menu-principal__nome">{i.rotulo}</span>
              {i.total ? <Contador total={i.total} pendente={i.pendente} rotulo={i.rotuloContador} /> : null}
            </button>
          </li>
        ))}
      </ul>
    </nav>
  )
}

export interface CabecalhoCelularProps {
  titulo: string
  subtitulo?: string
  /** nível 2: ‹ voltar com este nome */
  nomeVoltar?: string
  onVoltar?: () => void
  /** à direita: "+ Adicionar", ⋮, sininho, Sua conta */
  fim?: ReactNode
}

/** Cabeçalho do celular: 64, separado do conteúdo por sombra leve */
export function CabecalhoCelular({ titulo, subtitulo, nomeVoltar, onVoltar, fim }: Readonly<CabecalhoCelularProps>) {
  return (
    <header className="ds-cabecalho">
      {nomeVoltar ? <BotaoIcone nome={nomeVoltar} icone="chevron-left" onClick={onVoltar} /> : null}
      <div className="ds-cabecalho__titulo">
        <h2 className="ds-cabecalho__nome">{titulo}</h2>
        {subtitulo ? <p className="ds-cabecalho__sub">{subtitulo}</p> : null}
      </div>
      {fim ? <div className="ds-cabecalho__fim">{fim}</div> : null}
    </header>
  )
}

export interface BarraBaixoProps {
  nome: string
  /** Agenda, Clientes, Catálogo, Mais (o Agendar entra no meio) */
  itens: readonly [ItemNavegacao, ItemNavegacao, ItemNavegacao, ItemNavegacao]
  atual: string
  agendar: AgendarProps
}

/** Barra de baixo do celular: 72; atual em --id com ponto */
export function BarraBaixo({ nome, itens, atual, agendar }: Readonly<BarraBaixoProps>) {
  const [a, b, c, d] = itens
  const item = (i: ItemNavegacao) => (
    <li key={i.id} className="ds-barra-baixo__celula">
      <button type="button" className="ds-barra-baixo__item" aria-current={i.id === atual ? 'page' : undefined}>
        {/* PONTO A MUDAR: "Mais" ainda sem ícone; o DESIGN.md não o nomeia (mapa L7Icones não aprovado) */}
        {i.icone ? <Icone nome={i.icone} /> : <span className="ds-barra-baixo__sem-icone" aria-hidden="true" />}
        <span>{i.rotulo}</span>
      </button>
    </li>
  )
  return (
    <nav aria-label={nome} className="ds-barra-baixo">
      <ul className="ds-barra-baixo__lista">
        {item(a)}
        {item(b)}
        <li className="ds-barra-baixo__celula">
          <Agendar {...agendar} />
        </li>
        {item(c)}
        {item(d)}
      </ul>
    </nav>
  )
}

export interface ListaSecoesProps {
  nome: string
  itens: readonly ItemNavegacao[]
}

/** Lista de seções do celular (nível 1): ícone, nome, pílula e › */
export function ListaSecoes({ nome, itens }: Readonly<ListaSecoesProps>) {
  return (
    <nav aria-label={nome}>
      <ul className="ds-lista">
        {itens.map((i) => (
          <li key={i.id} className="ds-secao">
            <button type="button" className="ds-secao__botao">
              {i.icone ? <Icone nome={i.icone} /> : null}
              <span className="ds-secao__nome">{i.rotulo}</span>
              {i.total ? <Contador total={i.total} pendente={i.pendente} rotulo={i.rotuloContador} /> : null}
              <Icone nome="chevron-right" tamanho="18" />
            </button>
          </li>
        ))}
      </ul>
    </nav>
  )
}
