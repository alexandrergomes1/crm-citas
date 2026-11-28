// Troca de marcadores e plural pelo Intl, sem biblioteca (ADR 0006 · D1).
import type { Idioma } from '@/domain/idioma'

/** Formas de um texto com plural: uma por categoria do Intl.PluralRules; "other" é a de reserva. */
export type Plural = { readonly other: string } & Partial<Record<Exclude<Intl.LDMLPluralRule, 'other'>, string>>

const MARCADOR = /\{(\w+)\}/g

/** Troca cada {nome} pelo valor; marcador sem valor fica como está (o teste acusa). */
export function preencher(texto: string, valores: Readonly<Record<string, string | number>>): string {
  return texto.replace(MARCADOR, (inteiro, nome: string) => {
    const valor = valores[nome]
    return valor === undefined ? inteiro : String(valor)
  })
}

/** Marcadores de um texto, em ordem e sem repetir. */
export function marcadoresDe(texto: string): string[] {
  return [...new Set([...texto.matchAll(MARCADOR)].map((m) => m[1] ?? ''))]
}

/** Número e palavra ("2 estúdios"), com o número no formato do idioma. */
export function contar(idioma: Idioma, formas: Plural, n: number): string {
  const categoria = new Intl.PluralRules(idioma).select(n)
  const forma = (categoria === 'other' ? undefined : formas[categoria]) ?? formas.other
  return preencher(forma, { n: new Intl.NumberFormat(idioma).format(n) })
}
