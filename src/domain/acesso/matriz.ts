// Matriz padrão de permissões: papel × chave → alcance (ADR 0020 · D3, D4, D7; spec RF-18; plan.md §5a).
// TypeScript puro (ARCHITECTURE.md §3). A dona tem tudo por regra fixa, não por linha; célula ausente = não pode.
// Esta matriz é a fonte; o banco recebe uma cópia gerada de `exportarMatriz()` e um teste compara as duas (D7, D8).
import { ALCANCES, MODULOS, chavesDe, ehChaveDe, type Alcance, type Catalogo, type Chave, type ChaveDe } from './chaves'

export const PAPEIS = ['dona', 'recepcao', 'profissional'] as const
export type Papel = (typeof PAPEIS)[number]
/** Só estes papéis têm linhas; a dona nunca (D4). */
export type PapelDaMatriz = Exclude<Papel, 'dona'>

export type LinhaDaMatriz<K extends string = Chave> = {
  readonly papel: PapelDaMatriz
  readonly chave: K
  readonly alcance: Alcance
}

/**
 * Linhas padrão. Cada spec de módulo acrescenta as suas, com a resposta do dono citada ao lado de cada linha.
 * Nesta spec (Entrar) não há linha de módulo (ADR 0020, "Custo").
 */
export const MATRIZ_PADRAO: readonly LinhaDaMatriz[] = []

/**
 * Alcance de um papel numa chave, para um catálogo e uma matriz dados. Falha fechada (ASVS V4.1.5):
 * chave fora do catálogo → null, mesmo para a dona; papel desconhecido → null; sem linha → null.
 */
export function alcanceNaMatriz<C extends Catalogo>(
  catalogo: C,
  matriz: readonly LinhaDaMatriz<ChaveDe<C>>[],
  papel: unknown,
  chave: unknown,
): Alcance | null {
  if (!ehChaveDe(catalogo, chave)) return null
  if (papel === 'dona') return 'todos'
  if (papel !== 'recepcao' && papel !== 'profissional') return null
  const linha = matriz.find((l) => l.papel === papel && l.chave === chave)
  return linha && (ALCANCES as readonly string[]).includes(linha.alcance) ? linha.alcance : null
}

/** Alcance padrão do papel na chave, pela matriz do sistema. `null` = não pode. */
export const alcancePadrao = (papel: Papel, chave: Chave): Alcance | null =>
  alcanceNaMatriz(MODULOS, MATRIZ_PADRAO, papel, chave)

/** Formato da exportação para o banco (B7): só dados, ordenados, sem nada que dependa do código. */
export type MatrizExportada = {
  /** Todas as chaves do catálogo, em ordem alfabética. */
  readonly chaves: readonly string[]
  /** Linhas de `recepcao` e `profissional`, por papel e depois chave. A dona não aparece (tem tudo). */
  readonly linhas: readonly { readonly papel: PapelDaMatriz; readonly chave: string; readonly alcance: Alcance }[]
}

/** Exporta catálogo e matriz como dados simples, em ordem estável (comparação linha a linha; ADR 0020 · D8). */
export function exportarMatrizDe<C extends Catalogo>(
  catalogo: C,
  matriz: readonly LinhaDaMatriz<ChaveDe<C>>[],
): MatrizExportada {
  const linhas = matriz
    .map(({ papel, chave, alcance }) => ({ papel, chave: chave as string, alcance }))
    .sort((a, b) => (a.papel === b.papel ? (a.chave < b.chave ? -1 : a.chave > b.chave ? 1 : 0) : a.papel < b.papel ? -1 : 1))
  return { chaves: [...chavesDe(catalogo)], linhas }
}

/** Exportação da matriz do sistema (fonte da cópia do banco). `JSON.stringify` dela é o arquivo de comparação. */
export const exportarMatriz = (): MatrizExportada => exportarMatrizDe(MODULOS, MATRIZ_PADRAO)

/** Motivos pelos quais a matriz está fora da regra; vazio = em ordem. Usado no teste de unidade (D8). */
export function conferirMatriz<C extends Catalogo>(catalogo: C, matriz: readonly LinhaDaMatriz<ChaveDe<C>>[]): string[] {
  const motivos: string[] = []
  const vistas = new Set<string>()
  for (const { papel, chave, alcance } of matriz) {
    const id = `${papel} ${chave}`
    if ((papel as string) === 'dona') motivos.push(`${id}: a dona não tem linha (tem tudo)`)
    else if (papel !== 'recepcao' && papel !== 'profissional') motivos.push(`${id}: papel desconhecido`)
    if (!ehChaveDe(catalogo, chave)) motivos.push(`${id}: chave fora do catálogo`)
    if (!(ALCANCES as readonly string[]).includes(alcance)) motivos.push(`${id}: alcance desconhecido`)
    if (vistas.has(id)) motivos.push(`${id}: linha repetida`)
    vistas.add(id)
  }
  return motivos
}
