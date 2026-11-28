// Prova automática do lint de camadas (CA4; plan.md §4). Usa caminhos falsos: nenhum arquivo é criado.
import { describe, expect, it } from 'vitest'
import { ESLint } from 'eslint'

const eslint = new ESLint({ cwd: import.meta.dirname })

async function erros(codigo: string, caminho: string): Promise<string[]> {
  const [resultado] = await eslint.lintText(codigo, { filePath: caminho })
  return (resultado?.messages ?? [])
    .filter((m) => m.ruleId === 'no-restricted-imports' || m.ruleId === 'no-restricted-syntax')
    .map((m) => m.message)
}

describe('lint de camadas', () => {
  it('src/domain importando @/data falha', async () => {
    expect(await erros("export { y } from '@/data/y'\n", 'src/domain/x.ts')).toHaveLength(1)
  })

  it('src/domain importando ../data falha', async () => {
    expect(await erros("export { y } from '../data/y'\n", 'src/domain/x.ts')).toHaveLength(1)
  })

  it('src/domain com import estático de @/data falha', async () => {
    expect(await erros("import { y } from '@/data/y'\nexport const z = y\n", 'src/domain/x.ts')).toHaveLength(1)
  })

  it('src/domain com import() dinâmico de @/data falha', async () => {
    expect(await erros("export const z = () => import('@/data/y')\n", 'src/domain/x.ts')).toHaveLength(1)
  })

  it('src/domain com import() dinâmico de ../data falha', async () => {
    expect(await erros("export const z = () => import('../data/y')\n", 'src/domain/x.ts')).toHaveLength(1)
  })

  it('src/app com import() dinâmico do cliente do banco falha', async () => {
    expect(
      await erros("export const z = () => import('@supabase/supabase-js')\n", 'src/app/x.tsx'),
    ).toHaveLength(1)
  })

  it('src/app com import() dinâmico de @/domain passa', async () => {
    expect(await erros("export const z = () => import('@/domain/exemplo')\n", 'src/app/x.tsx')).toEqual([])
  })

  it('src/domain importando framework falha', async () => {
    expect(await erros("export { useState } from 'react'\n", 'src/domain/x.ts')).toHaveLength(1)
  })

  it('src/app importando o cliente do banco falha', async () => {
    expect(
      await erros("export { createClient } from '@supabase/supabase-js'\n", 'src/app/x.tsx'),
    ).toHaveLength(1)
  })

  it('src/app importando @/data falha', async () => {
    expect(await erros("export { y } from '@/data/y'\n", 'src/app/x.tsx')).toHaveLength(1)
  })

  it('src/app importando src/domain passa', async () => {
    expect(await erros("export { somar } from '@/domain/exemplo'\n", 'src/app/x.tsx')).toEqual([])
  })
})
