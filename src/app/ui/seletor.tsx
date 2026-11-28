// Seletor com papel de abas (spec RC-6, RA-5; DESIGN.md §5, §8b, §9).
// Padrão "Tabs" do WAI-ARIA Authoring Practices: tablist/tab/tabpanel, foco itinerante, setas, Home e End.
import { useId, useRef, useState, type KeyboardEvent, type ReactNode } from 'react'
import { Contador } from './contador'

export interface AbaSeletor {
  id: string
  rotulo: string
  total?: number
  pendente?: number
  /** texto do contador para o leitor, recebido pronto (RC-23) */
  rotuloContador?: string
  conteudo: ReactNode
}

export interface SeletorProps {
  /** nome acessível do conjunto de abas */
  nome: string
  abas: readonly AbaSeletor[]
  inicial?: string
  /** quando não cabe: rola com esmaecido na ponta (DESIGN.md §5) */
  rolavel?: boolean
}

export function Seletor({ nome, abas, inicial, rolavel = false }: Readonly<SeletorProps>) {
  const base = useId()
  const [escolhida, setEscolhida] = useState(inicial ?? abas[0]?.id ?? '')
  const refs = useRef<Array<HTMLButtonElement | null>>([])

  function irPara(indice: number) {
    const aba = abas[indice]
    if (!aba) return
    setEscolhida(aba.id)
    refs.current[indice]?.focus()
  }

  function teclado(evento: KeyboardEvent<HTMLButtonElement>, indice: number) {
    const ultimo = abas.length - 1
    const destino: Record<string, number> = {
      ArrowRight: indice === ultimo ? 0 : indice + 1,
      ArrowLeft: indice === 0 ? ultimo : indice - 1,
      Home: 0,
      End: ultimo,
    }
    const alvo = destino[evento.key]
    if (alvo === undefined) return
    evento.preventDefault()
    irPara(alvo)
  }

  return (
    <div className="ds-seletor">
      <div className={rolavel ? 'ds-seletor__rolagem ds-seletor__rolagem--rola' : 'ds-seletor__rolagem'}>
        <div role="tablist" aria-label={nome} className="ds-seletor__trilho">
          {abas.map((aba, indice) => {
            const ativa = aba.id === escolhida
            return (
              <button
                key={aba.id}
                ref={(el) => {
                  refs.current[indice] = el
                }}
                type="button"
                role="tab"
                id={`${base}-aba-${aba.id}`}
                aria-selected={ativa}
                aria-controls={`${base}-painel-${aba.id}`}
                tabIndex={ativa ? 0 : -1}
                className="ds-seletor__aba"
                onClick={() => setEscolhida(aba.id)}
                onKeyDown={(e) => teclado(e, indice)}
              >
                <span className="ds-seletor__desenho">
                  {aba.rotulo}
                  {aba.total ? (
                    <Contador total={aba.total} pendente={aba.pendente} rotulo={aba.rotuloContador} />
                  ) : null}
                </span>
              </button>
            )
          })}
        </div>
      </div>
      {abas.map((aba) => (
        <div
          key={aba.id}
          role="tabpanel"
          id={`${base}-painel-${aba.id}`}
          aria-labelledby={`${base}-aba-${aba.id}`}
          hidden={aba.id !== escolhida}
          tabIndex={0}
          className="ds-seletor__painel"
        >
          {aba.conteudo}
        </div>
      ))}
    </div>
  )
}
