// Bloco, linhas de lista e de tabela, cabeçalho de grupo e resumo de valores
// (spec RC-11, RC-12, RC-22; DESIGN.md §2, §3, §4, §5, §8b). Texto recebido pronto (RC-23).
import { useId, useState, type ReactNode } from 'react'
import { Contador, type ContadorProps } from './contador'
import { Icone } from './icone'

export interface BlocoProps {
  /** título do bloco (16 forte); com ele o bloco vira uma região com nome */
  titulo?: string
  /** ação à direita do título */
  acao?: ReactNode
  /** sem folga interna: para listas que vão de ponta a ponta */
  semFolga?: boolean
  children: ReactNode
}

/** Superfície branca, canto 20. Controle nunca direto sobre o fundo (DESIGN.md §2). */
export function Bloco({ titulo, acao, semFolga = false, children }: Readonly<BlocoProps>) {
  const id = useId()
  const classes = semFolga ? 'ds-bloco ds-bloco--sem-folga' : 'ds-bloco'
  if (!titulo) return <div className={classes}>{children}</div>
  return (
    <section className={classes} aria-labelledby={id}>
      <div className="ds-bloco__cabecalho">
        <h3 id={id} className="ds-bloco__titulo">
          {titulo}
        </h3>
        {acao}
      </div>
      {children}
    </section>
  )
}

/** Categoria na ordem de criação; a 5ª volta à 1ª (DESIGN.md §3) */
export type Categoria = 1 | 2 | 3 | 4

export function categoriaDaOrdem(ordem: number): Categoria {
  return (((Math.max(1, Math.floor(ordem)) - 1) % 4) + 1) as Categoria
}

export interface LinhaListaProps {
  titulo: string
  detalhe?: string
  /** bolinha ou ícone à esquerda */
  inicio?: ReactNode
  /** valor, status ou contador à direita */
  fim?: ReactNode
  /** ⋮ no fim da linha */
  acoes?: ReactNode
  /** faixa de 4 px da categoria; o nome da categoria aparece escrito no grupo ou no detalhe */
  categoria?: Categoria
}

export function LinhaLista({ titulo, detalhe, inicio, fim, acoes, categoria }: Readonly<LinhaListaProps>) {
  const classes = categoria ? `ds-linha ds-linha--cat ds-cat-${categoria}` : 'ds-linha'
  return (
    <li className={classes}>
      {inicio}
      <span className="ds-linha__meio">
        <span className="ds-linha__titulo">{titulo}</span>
        {detalhe ? <span className="ds-linha__detalhe">{detalhe}</span> : null}
      </span>
      {fim ? <span className="ds-linha__fim">{fim}</span> : null}
      {acoes}
    </li>
  )
}

export interface ListaProps {
  /** nome da lista para o leitor */
  nome: string
  children: ReactNode
}

export function Lista({ nome, children }: Readonly<ListaProps>) {
  return (
    <ul className="ds-lista" aria-label={nome}>
      {children}
    </ul>
  )
}

export interface CabecalhoGrupoProps {
  titulo: string
  contador?: ContadorProps
}

/** 14 forte + quantidade na pílula cinza (DESIGN.md §8b); a faixa de categoria fica só nas linhas (§3) */
export function CabecalhoGrupo({ titulo, contador }: Readonly<CabecalhoGrupoProps>) {
  return (
    <h4 className="ds-grupo">
      {titulo}
      {contador ? <Contador {...contador} /> : null}
    </h4>
  )
}

export interface ColunaTabela {
  id: string
  titulo: string
  /** alinhada à direita (valores) */
  numero?: boolean
}

export interface TabelaProps {
  /** legenda da tabela (nome para o leitor) */
  nome: string
  colunas: readonly ColunaTabela[]
  linhas: ReadonlyArray<{ id: string; celulas: Readonly<Record<string, ReactNode>> }>
}

/** Tabela do computador: cabeçalho 36 (12 forte --ink3), linha 40 com texto 13 */
export function Tabela({ nome, colunas, linhas }: Readonly<TabelaProps>) {
  return (
    <div className="ds-tabela__rolagem">
      <table className="ds-tabela">
        <caption className="ds-so-leitor">{nome}</caption>
        <thead>
          <tr>
            {colunas.map((c) => (
              <th key={c.id} scope="col" className={c.numero ? 'ds-tabela__numero' : undefined}>
                {c.titulo}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {linhas.map((l) => (
            <tr key={l.id}>
              {colunas.map((c) => (
                <td key={c.id} className={c.numero ? 'ds-tabela__numero' : undefined}>
                  {l.celulas[c.id]}
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}

export interface ResumoValoresProps {
  /** "Total" */
  rotulo: string
  /** valor já formatado pelo idioma e moeda do estúdio: "250,00 €" */
  valor: string
  /** detalhe que o ▴ abre */
  detalhe: ReactNode
}

/** "Total ▴ valor"; ▴ abre o detalhe (DESIGN.md §5) */
export function ResumoValores({ rotulo, valor, detalhe }: Readonly<ResumoValoresProps>) {
  const [aberto, setAberto] = useState(false)
  const id = useId()
  return (
    <div className="ds-resumo">
      <div id={id} className="ds-resumo__detalhe" hidden={!aberto}>
        {detalhe}
      </div>
      <div className="ds-resumo__linha">
        <button
          type="button"
          className="ds-resumo__botao"
          aria-expanded={aberto}
          aria-controls={id}
          onClick={() => setAberto((a) => !a)}
        >
          {rotulo}
          <Icone nome={aberto ? 'chevron-down' : 'chevron-up'} tamanho="16" />
        </button>
        <span className="ds-resumo__valor">{valor}</span>
      </div>
    </div>
  )
}
