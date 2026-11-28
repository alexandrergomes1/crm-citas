// Matriz do código = matriz esperada pelo teste do banco (ADR 0020 · D7, D8; ADR 0019 · D21; plan.md §5a).
// A linha entre os marcadores de 110_matriz_permissoes_test.sql tem de ser exatamente JSON.stringify(exportarMatriz()).
// O pgTAP 110_ compara essa linha com app.chaves_permissao e app.matriz_permissoes depois das migrations.
// Juntos: código = 110_ = banco. Se este teste falhar, o diff mostra a linha certa para colar no 110_.
import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'
import { exportarMatriz } from '../../src/domain/acesso/matriz'

const ARQUIVO = 'supabase/tests/database/110_matriz_permissoes_test.sql'
const INICIO = '-- matriz-do-codigo:inicio'
const BLOCO = /-- matriz-do-codigo:inicio\n(.*)\n-- matriz-do-codigo:fim/

const linhaDoCodigo = (): string =>
  "select set_config('teste.matriz', $json$" + JSON.stringify(exportarMatriz()) + '$json$, true);'

describe('matriz do código × teste do banco (ADR 0020 · D8)', () => {
  const texto = readFileSync(ARQUIVO, 'utf8')

  it('o 110_ tem um bloco só, entre os marcadores', () => {
    expect(texto.split(INICIO).length).toBe(2)
    expect(BLOCO.test(texto)).toBe(true)
  })

  it('a linha do 110_ é a exportação atual do código', () => {
    expect(BLOCO.exec(texto)?.[1]).toBe(linhaDoCodigo())
  })
})
