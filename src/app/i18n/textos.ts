// Textos do idioma da tela (ADR 0006 · D1; ADR 0018 · D15). Antes de entrar: Accept-Language; depois: estudios.idioma
// (o idioma chega pronto de sessao.ler; spec RF-34, RF-35).
import type { Idioma } from '@/domain/idioma'
import { en } from './en'
import { es } from './es'
import { pt, type Textos } from './pt'

export type { Textos }

export const TEXTOS: Readonly<Record<Idioma, Textos>> = { pt, es, en }

export function textosDe(idioma: Idioma): Textos {
  return TEXTOS[idioma]
}
