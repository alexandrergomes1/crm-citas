// Peças de conteúdo (spec RC-20, RC-21; DESIGN.md §3, §8b). Texto recebido pronto (RC-23).
import type { Ref } from 'react'
import { Icone, type NomeIcone } from './icone'

export interface BolinhaProps {
  /** iniciais já prontas: "MC" */
  iniciais: string
  /** lista do celular 40; tabela do computador 24 */
  tamanho?: 'lista' | 'tabela'
}

/** Bolinha da cliente: fundo --btn, iniciais --ink2 13 forte; nunca colorida (decorativa: o nome está ao lado) */
export function Bolinha({ iniciais, tamanho = 'lista' }: Readonly<BolinhaProps>) {
  return (
    <span className={tamanho === 'tabela' ? 'ds-bolinha ds-bolinha--tabela' : 'ds-bolinha'} aria-hidden="true">
      {iniciais}
    </span>
  )
}

export interface SuaContaProps {
  /** "Sua conta" */
  nome: string
  inicial: string
  onClick?: () => void
  ref?: Ref<HTMLButtonElement>
}

/** Sua conta: bolinha 40 com a inicial da pessoa */
export function SuaConta({ nome, inicial, onClick, ref }: Readonly<SuaContaProps>) {
  return (
    <button ref={ref} type="button" className="ds-sua-conta" aria-label={nome} onClick={onClick}>
      <span className="ds-bolinha" aria-hidden="true">
        {inicial}
      </span>
    </button>
  )
}

export interface InicialEstudioProps {
  inicial: string
  /** nome do estúdio para o leitor */
  nome: string
}

/** Quadrado da inicial do estúdio: dourado --brand, canto 10 */
export function InicialEstudio({ inicial, nome }: Readonly<InicialEstudioProps>) {
  return (
    <span className="ds-inicial" role="img" aria-label={nome}>
      <span aria-hidden="true">{inicial}</span>
    </span>
  )
}

export interface AcontecimentoTempo {
  id: string
  icone: NomeIcone
  titulo: string
  detalhe?: string
  /** "14:32" já formatada no fuso do estúdio */
  hora: string
  naoLido?: boolean
}

export interface GrupoTempo {
  id: string
  /** "Hoje", "Ontem" */
  dia: string
  itens: readonly AcontecimentoTempo[]
}

export interface LinhaDoTempoProps {
  grupos: readonly GrupoTempo[]
  /** texto para o leitor no ponto de não lido: "Não lido" (RA-4) */
  rotuloNaoLido: string
}

/** Linha do tempo: do mais novo ao mais antigo, por dia; bolinha 36, linha 2 px, não lido com ponto --id 8 */
export function LinhaDoTempo({ grupos, rotuloNaoLido }: Readonly<LinhaDoTempoProps>) {
  return (
    <div className="ds-tempo">
      {grupos.map((g) => (
        <div key={g.id} className="ds-tempo__grupo">
          <p className="ds-tempo__dia" aria-hidden="true">
            {g.dia}
          </p>
          <ol className="ds-tempo__lista" aria-label={g.dia}>
            {g.itens.map((i) => (
              <li key={i.id} className="ds-tempo__item">
                <span className="ds-tempo__bolinha">
                  <Icone nome={i.icone} tamanho="18" />
                </span>
                <span className="ds-tempo__meio">
                  <span className="ds-tempo__titulo">{i.titulo}</span>
                  {i.detalhe ? <span className="ds-tempo__detalhe">{i.detalhe}</span> : null}
                </span>
                <span className="ds-tempo__hora">{i.hora}</span>
                {i.naoLido ? (
                  <span className="ds-tempo__ponto">
                    <span className="ds-so-leitor">{rotuloNaoLido}</span>
                  </span>
                ) : null}
              </li>
            ))}
          </ol>
        </div>
      ))}
    </div>
  )
}
