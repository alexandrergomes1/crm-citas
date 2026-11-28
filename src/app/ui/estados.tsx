// Estados de toda tela (spec RC-17, RA-5; DESIGN.md §8, §8b): vazio, sem resultado, carregando, erro.
// O sucesso é o Aviso (camadas.tsx). Texto recebido pronto (RC-23).
import { useEffect, useState } from 'react'
import { Botao } from './botao'
import { Icone, type NomeIcone } from './icone'

export interface EstadoVazioProps {
  icone: NomeIcone
  /** "Ainda não há <itens>" */
  titulo: string
  /** uma frase do que fazer */
  frase: string
  /** "Adicionar <item>", com contorno */
  rotuloAdicionar: string
  onAdicionar?: () => void
}

export function EstadoVazio({ icone, titulo, frase, rotuloAdicionar, onAdicionar }: Readonly<EstadoVazioProps>) {
  return (
    <div className="ds-estado">
      <span className="ds-estado__icone">
        <Icone nome={icone} />
      </span>
      <p className="ds-estado__titulo">{titulo}</p>
      <p className="ds-estado__frase">{frase}</p>
      <Botao variante="contorno" icone="plus" onClick={onAdicionar}>
        {rotuloAdicionar}
      </Botao>
    </div>
  )
}

export interface SemResultadoProps {
  /** 'Nada encontrado para "lifting"' */
  titulo: string
  frase: string
  /** "Limpar filtros" */
  rotuloLimpar: string
  onLimpar?: () => void
}

export function SemResultado({ titulo, frase, rotuloLimpar, onLimpar }: Readonly<SemResultadoProps>) {
  return (
    <div className="ds-estado">
      <span className="ds-estado__icone">
        <Icone nome="search" />
      </span>
      <p className="ds-estado__titulo">{titulo}</p>
      <p className="ds-estado__frase">{frase}</p>
      <Botao variante="claro" onClick={onLimpar}>
        {rotuloLimpar}
      </Botao>
    </div>
  )
}

export interface ErroProps {
  /** "Não foi possível carregar" */
  titulo: string
  frase: string
  /** "Tentar de novo" */
  rotuloTentar: string
  onTentar?: () => void
}

export function Erro({ titulo, frase, rotuloTentar, onTentar }: Readonly<ErroProps>) {
  return (
    <div className="ds-estado">
      <span className="ds-estado__icone ds-estado__icone--erro">
        <Icone nome="circle-alert" />
      </span>
      <p className="ds-estado__titulo">{titulo}</p>
      <p className="ds-estado__frase">{frase}</p>
      <Botao variante="claro" onClick={onTentar}>
        {rotuloTentar}
      </Botao>
    </div>
  )
}

/** Lê o atraso do token --atraso-carregando (fonte única: tokens.css) */
function atrasoDoToken(): number {
  const valor = getComputedStyle(document.documentElement).getPropertyValue('--atraso-carregando').trim()
  const numero = Number.parseFloat(valor)
  if (Number.isNaN(numero)) return 0
  return valor.endsWith('ms') ? numero : numero * 1000
}

export interface CarregandoProps {
  /** texto anunciado ao leitor: "Carregando serviços" */
  rotulo: string
  /** quantas linhas cinza */
  linhas?: number
}

/** Linhas cinza só depois de 0,3 s, anunciadas ao leitor de tela */
export function Carregando({ rotulo, linhas = 3 }: Readonly<CarregandoProps>) {
  const [visivel, setVisivel] = useState(false)
  useEffect(() => {
    const espera = window.setTimeout(() => setVisivel(true), atrasoDoToken())
    return () => window.clearTimeout(espera)
  }, [])
  return (
    <div role="status" className="ds-carregando" data-visivel={visivel ? 'sim' : 'nao'}>
      {visivel ? (
        <>
          {Array.from({ length: linhas }, (_, i) => (
            <span key={i} className="ds-carregando__linha" aria-hidden="true" />
          ))}
          <span className="ds-so-leitor">{rotulo}</span>
        </>
      ) : null}
    </div>
  )
}
