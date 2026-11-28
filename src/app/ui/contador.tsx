// Pílula de contador (spec RC-4; DESIGN.md §5, §8b; E13·1, E13·3).
// Sempre o total; âmbar suave quando há pendência dentro; zero não aparece.

export interface ContadorProps {
  total: number
  /** quantos estão pendentes dentro do total; > 0 deixa a pílula âmbar suave */
  pendente?: number
  /** texto para o leitor, recebido pronto (RC-23), ex.: "21, 4 pendentes" (RA-4: nada só por cor) */
  rotulo?: string
  /** dentro de um botão que já tem o nome completo: a pílula fica escondida do leitor */
  decorativo?: boolean
}

export function Contador({ total, pendente = 0, rotulo, decorativo = false }: Readonly<ContadorProps>) {
  if (total <= 0) return null
  const comPendencia = pendente > 0
  const classes = comPendencia ? 'ds-contador ds-contador--pendente' : 'ds-contador'
  if (decorativo) {
    return (
      <span className={classes} aria-hidden="true">
        {total}
      </span>
    )
  }
  if (rotulo) {
    return (
      <span className={classes}>
        <span aria-hidden="true">{total}</span>
        <span className="ds-so-leitor">{rotulo}</span>
      </span>
    )
  }
  return <span className={classes}>{total}</span>
}
