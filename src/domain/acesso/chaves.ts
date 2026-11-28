// Catálogo fechado das chaves de permissão `modulo.acao` (ADR 0020 · D1, D2; spec RF-18; plan.md §5a).
// TypeScript puro (ARCHITECTURE.md §3). Chave errada não compila: o tipo `Chave` sai de `MODULOS`, `as const`.

/** Ações base de todo módulo. */
export const ACOES_BASE = ['ver', 'criar', 'editar', 'remover'] as const
/** Sensíveis, sempre à parte da base (ADR 0020 · D2). Nova só com aprovação do dono na spec do módulo. */
export const ACOES_SENSIVEIS = ['ver_saude', 'estornar', 'exportar', 'gerenciar_acessos'] as const

export type AcaoDaChave = (typeof ACOES_BASE)[number] | (typeof ACOES_SENSIVEIS)[number]

/** Valor de cada célula da matriz (ADR 0020 · D3). Ausente = não pode. */
export const ALCANCES = ['todos', 'proprios'] as const
export type Alcance = (typeof ALCANCES)[number]

/** Forma de um catálogo: módulo → ações que existem nele. */
export type Catalogo = Readonly<Record<string, readonly AcaoDaChave[]>>

/**
 * Módulos e as ações de cada um. Cada spec de módulo acrescenta o seu, com a resposta do dono citada ao lado.
 * Nesta spec (Entrar) nenhum módulo tem ação do modo `estudio`: o catálogo nasce vazio (ADR 0020, "Custo").
 */
export const MODULOS = {} as const satisfies Catalogo

/** Chaves de um catálogo, como tipo: `${modulo}.${acao}`. */
export type ChaveDe<C extends Catalogo> = {
  [M in keyof C & string]: `${M}.${C[M][number]}`
}[keyof C & string]

/** Chave do catálogo do sistema. */
export type Chave = ChaveDe<typeof MODULOS>

/** Lista das chaves de um catálogo, em ordem alfabética (estável, para comparar com o banco). */
export function chavesDe<C extends Catalogo>(catalogo: C): readonly ChaveDe<C>[] {
  const chaves: string[] = []
  for (const [modulo, acoes] of Object.entries(catalogo)) for (const acao of acoes) chaves.push(`${modulo}.${acao}`)
  return Object.freeze([...new Set(chaves)].sort()) as readonly ChaveDe<C>[]
}

/** Todas as chaves do sistema. */
export const CHAVES: readonly Chave[] = chavesDe(MODULOS)

/** Texto é chave do catálogo dado? (falha fechada: qualquer outra coisa → false) */
export function ehChaveDe<C extends Catalogo>(catalogo: C, texto: unknown): texto is ChaveDe<C> {
  return typeof texto === 'string' && chavesDe(catalogo).includes(texto as ChaveDe<C>)
}

/** Texto é chave do catálogo do sistema? */
export const ehChave = (texto: unknown): texto is Chave => ehChaveDe(MODULOS, texto)

/** Módulo da chave: o trecho antes do primeiro ponto (`agenda.ver` → `agenda`); sem ponto → null. */
export function moduloDaChave(chave: string): string | null {
  const ponto = chave.indexOf('.')
  return ponto > 0 ? chave.slice(0, ponto) : null
}
