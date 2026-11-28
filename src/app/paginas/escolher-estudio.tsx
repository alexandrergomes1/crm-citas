// Tela Escolher estúdio (spec RF-11 a RF-14, RF-30; ficha E41·4·A; DESIGN.md §8, §8b "Tela sem menu").
// A lista é a ação (sem botão preto); "Sair" claro no fim. O estúdio nunca vai ao endereço (RF-33).
// Carrega só ao abrir a tela e ao tocar "Tentar de novo": nenhuma consulta automática (ADR 0018 · D5).
import { useCallback, useEffect, useRef, useState } from 'react'
import { contar } from '@/app/i18n/formatar'
import type { Textos } from '@/app/i18n/textos'
import { Bloco } from '@/app/ui/bloco-lista'
import { Botao } from '@/app/ui/botao'
import { InicialEstudio } from '@/app/ui/conteudo'
import { Carregando } from '@/app/ui/estados'
import { Icone } from '@/app/ui/icone'
import type { Idioma } from '@/domain/idioma'

export type EstudioDaLista = { readonly orgId: string; readonly nome: string }

export type EstadoEscolher =
  | { readonly tipo: 'carregando' }
  | { readonly tipo: 'erro' }
  | { readonly tipo: 'lista'; readonly estudios: readonly EstudioDaLista[] }

export interface EscolherEstudioVistaProps {
  textos: Textos
  idioma: Idioma
  estado: EstadoEscolher
  /** enquanto escolhe: as linhas travam (evita envio em dobro) */
  escolhendo?: boolean
  onEscolher: (orgId: string) => void
  onTentar: () => void
  onSair: () => void
}

/** Primeira letra do nome do estúdio, para o quadrado dourado (DESIGN.md §3 · --brand). */
function inicialDe(nome: string): string {
  return Array.from(nome.trim())[0]?.toLocaleUpperCase() ?? ''
}

/**
 * Erro desta tela: só o título e "Tentar de novo", sem frase de detalhe (ficha E41, ressalvas da 2ª rodada).
 * Mesmo desenho e classes do `Erro` de `src/app/ui/estados.tsx`, que sempre desenha o parágrafo da frase (com
 * `frase=""` ficava um <p> vazio no leitor de tela e no espaço da tela). Tornar a frase opcional lá é a correção de
 * fundo, mas o arquivo está fora da lista do plan.md §10.
 */
function ErroSemFrase({ titulo, rotuloTentar, onTentar }: Readonly<{ titulo: string; rotuloTentar: string; onTentar: () => void }>) {
  return (
    <div className="ds-estado">
      <span className="ds-estado__icone ds-estado__icone--erro">
        <Icone nome="circle-alert" />
      </span>
      <p className="ds-estado__titulo">{titulo}</p>
      <Botao variante="claro" onClick={onTentar}>
        {rotuloTentar}
      </Botao>
    </div>
  )
}

/** O desenho da tela, sem estado próprio (testado por renderToString). */
export function EscolherEstudioVista({ textos, idioma, estado, escolhendo = false, onEscolher, onTentar, onSair }: Readonly<EscolherEstudioVistaProps>) {
  const t = textos.escolherEstudio
  return (
    <main className="tela-sem-menu">
      <div className="tela-sem-menu__bloco escolher">
        <Bloco semFolga>
          <div className="escolher__topo">
            <h1 className="tela-sem-menu__titulo">{t.titulo}</h1>
            {estado.tipo === 'lista' ? <p className="escolher__sub">{contar(idioma, t.quantos, estado.estudios.length)}</p> : null}
          </div>
          {estado.tipo === 'carregando' ? (
            <div className="escolher__estado">
              <Carregando rotulo={t.carregando} linhas={2} />
            </div>
          ) : null}
          {estado.tipo === 'erro' ? <ErroSemFrase titulo={t.erroTitulo} rotuloTentar={textos.comum.tentarDeNovo} onTentar={onTentar} /> : null}
          {estado.tipo === 'lista' ? (
            <ul className="ds-lista escolher__lista" aria-label={t.titulo}>
              {estado.estudios.map((estudio) => (
                <li key={estudio.orgId} className="escolher__item">
                  <button
                    type="button"
                    className="ds-linha escolher__linha"
                    aria-disabled={escolhendo ? true : undefined}
                    onClick={() => {
                      if (!escolhendo) onEscolher(estudio.orgId)
                    }}
                  >
                    {/* quadrado e › são enfeite: o nome da linha é o nome do estúdio (ficha) */}
                    <span aria-hidden="true" className="escolher__enfeite">
                      <InicialEstudio inicial={inicialDe(estudio.nome)} nome={estudio.nome} />
                    </span>
                    <span className="ds-linha__meio">
                      <span className="ds-linha__titulo">{estudio.nome}</span>
                    </span>
                    <Icone nome="chevron-right" tamanho="18" className="escolher__seta" />
                  </button>
                </li>
              ))}
            </ul>
          ) : null}
          <div className="escolher__fim">
            <Botao variante="claro" onClick={onSair}>
              {textos.comum.sair}
            </Botao>
          </div>
        </Bloco>
      </div>
    </main>
  )
}

/** Resposta de uma ação, como a tela a usa (só o código do erro; RF-22). */
export type RespostaDaAcao<S> = { readonly ok: true; readonly valor: S } | { readonly ok: false; readonly codigo: string }

export interface EscolherEstudioProps {
  textos: Textos
  idioma: Idioma
  /** estudio.listar */
  listar: () => Promise<RespostaDaAcao<readonly EstudioDaLista[]>>
  /** estudio.escolher */
  escolher: (orgId: string) => Promise<RespostaDaAcao<unknown>>
  /** depois de escolher: a área com sessão, recarregada (RF-35: idioma do estúdio) */
  aoEscolher: () => void
  /** sessão vencida ou parada (sem_login) */
  aoPerderSessao: () => void
  onSair: () => void
}

export function EscolherEstudio({ textos, idioma, listar, escolher, aoEscolher, aoPerderSessao, onSair }: Readonly<EscolherEstudioProps>) {
  const [estado, setEstado] = useState<EstadoEscolher>({ tipo: 'carregando' })
  const [escolhendo, setEscolhendo] = useState(false)

  // As funções recebidas ficam numa ref: trocar a função não dispara nova carga (só a abertura e "Tentar de novo")
  const recebidas = useRef({ listar, aoPerderSessao })
  recebidas.current = { listar, aoPerderSessao }

  const carregar = useCallback(async () => {
    setEstado({ tipo: 'carregando' })
    try {
      const resposta = await recebidas.current.listar()
      if (resposta.ok) setEstado({ tipo: 'lista', estudios: resposta.valor })
      else if (resposta.codigo === 'sem_login') recebidas.current.aoPerderSessao()
      else setEstado({ tipo: 'erro' })
    } catch {
      setEstado({ tipo: 'erro' })
    }
  }, [])

  // Uma vez, ao abrir a tela (carga pedida pela pessoa); sem recarga periódica nem ao focar (ADR 0018 · D5)
  useEffect(() => {
    void carregar()
  }, [carregar])

  async function aoTocar(orgId: string) {
    setEscolhendo(true)
    try {
      const resposta = await escolher(orgId)
      if (resposta.ok) {
        aoEscolher()
        return
      }
      if (resposta.codigo === 'sem_login') {
        aoPerderSessao()
        return
      }
      // sem vínculo ativo (sem_permissao) ou falha: a lista volta do servidor
      setEscolhendo(false)
      await carregar()
    } catch {
      setEscolhendo(false)
      setEstado({ tipo: 'erro' })
    }
  }

  return (
    <EscolherEstudioVista
      textos={textos}
      idioma={idioma}
      estado={estado}
      escolhendo={escolhendo}
      onEscolher={(orgId) => void aoTocar(orgId)}
      onTentar={() => void carregar()}
      onSair={onSair}
    />
  )
}
