// Idioma antes de entrar: cabeçalho Accept-Language → pt, es ou en; fora deles, pt
// (spec RF-34, Assumption 1; ADR 0018 · D15). TypeScript puro (ARCHITECTURE.md §3).

export const IDIOMAS = ['pt', 'es', 'en'] as const
export type Idioma = (typeof IDIOMAS)[number]

export const IDIOMA_PADRAO: Idioma = 'pt'

const ehIdioma = (valor: string): valor is Idioma => (IDIOMAS as readonly string[]).includes(valor)

// Cabeçalho maior que isto é ignorado (entrada que vem de fora: ASVS V5.1.4).
const TAMANHO_MAXIMO = 512

/**
 * Lê o Accept-Language (RFC 9110 §12.5.4) e devolve o primeiro idioma aceito, pela ordem de peso (q).
 * Peso 0 recusa o idioma. Empate mantém a ordem do cabeçalho. Nada aceito → pt.
 */
export function idiomaDoNavegador(cabecalho: string | null | undefined): Idioma {
  if (!cabecalho || cabecalho.length > TAMANHO_MAXIMO) return IDIOMA_PADRAO

  const candidatos: { idioma: Idioma; peso: number; ordem: number }[] = []
  cabecalho.split(',').forEach((parte, ordem) => {
    const [etiqueta = '', ...parametros] = parte.trim().split(';')
    const base = etiqueta.trim().toLowerCase().split('-')[0] ?? ''
    if (!ehIdioma(base)) return

    let peso = 1
    for (const parametro of parametros) {
      const [chave, valor] = parametro.trim().split('=')
      if (chave?.trim().toLowerCase() === 'q') {
        const numero = Number(valor)
        peso = Number.isFinite(numero) && numero >= 0 && numero <= 1 ? numero : 0
      }
    }
    if (peso > 0) candidatos.push({ idioma: base, peso, ordem })
  })

  candidatos.sort((a, b) => b.peso - a.peso || a.ordem - b.ordem)
  return candidatos[0]?.idioma ?? IDIOMA_PADRAO
}

/** Idioma vindo do banco (estudios.idioma): só os três; o resto vira pt. */
export function idiomaValido(valor: unknown): Idioma {
  return typeof valor === 'string' && ehIdioma(valor) ? valor : IDIOMA_PADRAO
}
