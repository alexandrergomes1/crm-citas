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

  it('src/app importando lucide-react fora do icone.tsx falha', async () => {
    expect(await erros("export { Clock } from 'lucide-react'\n", 'src/app/x.tsx')).toHaveLength(1)
  })

  it('src/app/ui/icone.tsx importando lucide-react passa', async () => {
    expect(await erros("export { Clock } from 'lucide-react'\n", 'src/app/ui/icone.tsx')).toEqual([])
  })

  // Entrar e camada de serviço (plan.md §8; CA-21; ADR 0018 · D9, D12)
  it('createServerFn fora de acao.ts falha (src/server)', async () => {
    expect(
      await erros("import { createServerFn } from '@tanstack/react-start'\nexport const f = createServerFn\n", 'src/server/x.ts'),
    ).toHaveLength(1)
  })

  it('createServerFn em src/app falha', async () => {
    expect(
      await erros("export { createServerFn } from '@tanstack/react-start'\n", 'src/app/routes/x.tsx'),
    ).toHaveLength(1)
  })

  it('createServerFn pelo pacote interno também falha', async () => {
    expect(
      await erros("export { createServerFn } from '@tanstack/start-client-core'\n", 'src/server/x.ts'),
    ).toHaveLength(1)
  })

  it('createServerFn em src/server/portas/acao.ts passa', async () => {
    expect(
      await erros("export { createServerFn } from '@tanstack/react-start'\n", 'src/server/portas/acao.ts'),
    ).toEqual([])
  })

  it('outros nomes do @tanstack/react-start passam em src/server', async () => {
    expect(
      await erros("export { createMiddleware } from '@tanstack/react-start'\n", 'src/server/http/x.ts'),
    ).toEqual([])
  })

  it('src/server importando o cliente do banco falha', async () => {
    expect(await erros("export { createClient } from '@supabase/supabase-js'\n", 'src/server/x.ts')).toHaveLength(1)
  })

  it('src/server com import() dinâmico do cliente do banco falha', async () => {
    expect(await erros("export const z = () => import('@supabase/ssr')\n", 'src/server/x.ts')).toHaveLength(1)
  })

  it('acao.ts importando o cliente do banco falha', async () => {
    expect(
      await erros("export { createClient } from '@supabase/supabase-js'\n", 'src/server/portas/acao.ts'),
    ).toHaveLength(1)
  })

  it('src/server importando src/data passa', async () => {
    expect(await erros("export { lerAmbiente } from '@/data/ambiente'\n", 'src/server/x.ts')).toEqual([])
  })

  it('src/data importando src/server falha', async () => {
    expect(await erros("export { y } from '@/server/y'\n", 'src/data/x.ts')).toHaveLength(1)
  })

  it('src/data importando ../app falha', async () => {
    expect(await erros("export { y } from '../app/y'\n", 'src/data/x.ts')).toHaveLength(1)
  })

  it('src/data importando createServerClient passa', async () => {
    expect(await erros("export { createServerClient } from '@supabase/ssr'\n", 'src/data/x.ts')).toEqual([])
  })

  it('createBrowserClient falha em qualquer pasta', async () => {
    expect(await erros("export { createBrowserClient } from '@supabase/ssr'\n", 'src/data/x.ts')).toHaveLength(1)
    expect(await erros("export { createBrowserClient } from '@supabase/ssr'\n", 'tests/x.ts')).toHaveLength(1)
  })

  it('getSession() falha', async () => {
    expect(
      await erros('export const f = (c: { auth: { getSession(): void } }) => c.auth.getSession()\n', 'src/data/x.ts'),
    ).toHaveLength(1)
  })
})
