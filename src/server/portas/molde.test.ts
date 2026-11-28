// Molde único e catálogo (ADR 0018 · D12; CA-17, CA-21). Lê o código de src/ como texto; nada é criado.
import { readFileSync, readdirSync, statSync } from 'node:fs'
import { join, relative } from 'node:path'
import { describe, expect, it } from 'vitest'
import { z } from 'zod'
import * as sessao from '@/server/sessao/acoes'
import { MODOS_SEM_ESTUDIO, acoesDoCatalogo, conferirDefinicao, registrar } from './catalogo'
import type { DefinicaoQualquer } from './tipos'

const RAIZ = join(import.meta.dirname, '..', '..')

function arquivos(pasta: string): string[] {
  return readdirSync(pasta).flatMap((nome) => {
    const caminho = join(pasta, nome)
    return statSync(caminho).isDirectory() ? arquivos(caminho) : /\.(ts|tsx)$/.test(nome) ? [caminho] : []
  })
}
const codigo = arquivos(RAIZ)
  .filter((caminho) => !/\.test\.tsx?$/.test(caminho) && !caminho.endsWith('routeTree.gen.ts'))
  .map((caminho) => ({ caminho: relative(RAIZ, caminho), texto: readFileSync(caminho, 'utf8') }))

const valida: DefinicaoQualquer = {
  nome: 'agenda.bloqueio.criar',
  metodo: 'POST',
  sessao: 'estudio',
  permissao: ['dona'],
  entrada: z.strictObject({}),
  grava: true,
  trabalho: async () => null,
}

describe('catálogo (CA-21)', () => {
  it('as ações de sessão estão no catálogo, cada uma no seu modo da lista fechada', () => {
    const noCatalogo = new Map<string, string>(acoesDoCatalogo().map((def) => [def.nome, def.sessao]))
    for (const [nome, modo] of Object.entries(MODOS_SEM_ESTUDIO)) expect(noCatalogo.get(nome)).toBe(modo)
  })

  it('cada ação exportada usa o construtor do seu método', () => {
    const exportadas = Object.values(sessao).filter(
      (valor): valor is typeof valor & { method: string; definicaoDaAcao: DefinicaoQualquer } =>
        typeof valor === 'function' && 'definicaoDaAcao' in valor,
    )
    expect(exportadas).toHaveLength(Object.keys(MODOS_SEM_ESTUDIO).length)
    for (const fn of exportadas) expect(fn.method).toBe(fn.definicaoDaAcao.metodo)
  })

  it('definição no molde passa', () => {
    expect(conferirDefinicao(valida)).toBeNull()
  })

  it.each<[string, Partial<DefinicaoQualquer>]>([
    ['nome sem ponto', { nome: 'criar' as DefinicaoQualquer['nome'] }],
    ['nome com maiúscula', { nome: 'Agenda.criar' }],
    ['nome longo demais', { nome: `a.${'b'.repeat(70)}` as DefinicaoQualquer['nome'] }],
    ['grava por GET', { metodo: 'GET' }],
    ['modo sem estúdio fora da lista', { sessao: 'pessoa' }],
    ['modo nenhuma fora da lista', { sessao: 'nenhuma' }],
    ['ação da lista no modo estudio', { nome: 'sessao.sair' }],
    ['ação da lista em outro modo', { nome: 'sessao.ler', sessao: 'pessoa' }],
    ['permissão "qualquer" no modo estudio', { permissao: 'qualquer' }],
  ])('fora do molde: %s → recusada ao carregar', (_nome, mudar) => {
    const def = { ...valida, ...mudar } as DefinicaoQualquer
    expect(conferirDefinicao(def)).not.toBeNull()
    expect(() => registrar(def)).toThrow()
  })
})

describe('molde no código (CA-21)', () => {
  it('createServerFn só em src/server/portas/acao.ts', () => {
    const com = codigo.filter(({ texto }) => /\bcreateServerFn\b/.test(texto)).map(({ caminho }) => caminho)
    expect(com).toEqual(['server/portas/acao.ts'])
  })

  it('todo .handler( é acaoGet/acaoPost.handler(acao({ ... }))', () => {
    for (const { caminho, texto } of codigo) {
      if (caminho === 'server/portas/acao.ts') continue
      const handlers = texto.match(/\.handler\(/g)?.length ?? 0
      const noMolde = texto.match(/\bacao(Get|Post)\.handler\(\s*acao\(\{/g)?.length ?? 0
      expect(`${caminho}: ${handlers}`).toBe(`${caminho}: ${noMolde}`)
    }
  })

  it('nome de ação não se repete entre arquivos', () => {
    const nomes = codigo.flatMap(({ texto }) => [...texto.matchAll(/\bacao\(\{\s*nome:\s*'([^']+)'/g)].map((m) => m[1]))
    expect(nomes.length).toBeGreaterThan(0)
    expect(new Set(nomes).size).toBe(nomes.length)
  })
})

describe('nenhuma chave secreta ou de serviço em src/ (CA-17; RF-20)', () => {
  // Montadas em pedaços para este arquivo não se acusar.
  const proibidos = [['service', '_role'], ['SERVICE', '_ROLE'], ['sb', '_secret_'], ['SUPABASE', '_SECRET'], ['createBrowser', 'Client(']]
  for (const partes of proibidos) {
    const termo = partes.join('')
    it(`"${termo}" não aparece`, () => {
      expect(codigo.filter(({ texto }) => texto.includes(termo)).map(({ caminho }) => caminho)).toEqual([])
    })
  }

  it('getSession() não aparece', () => {
    expect(codigo.filter(({ texto }) => /\.getSession\(/.test(texto)).map(({ caminho }) => caminho)).toEqual([])
  })

  it('nenhuma variável VITE_ com endereço ou chave do banco', () => {
    expect(codigo.filter(({ texto }) => /VITE_SUPABASE/.test(texto)).map(({ caminho }) => caminho)).toEqual([])
  })
})
