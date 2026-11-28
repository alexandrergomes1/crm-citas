// Molde único e catálogo (ADR 0018 · D12; CA-17, CA-21). Lê o código de src/ como texto; nada é criado.
import { readFileSync, readdirSync, statSync } from 'node:fs'
import { join, relative } from 'node:path'
import { beforeAll, describe, expect, it } from 'vitest'
import { z } from 'zod'
import { MODULOS, ehChave } from '@/domain/acesso/chaves'
import { MODOS_SEM_ESTUDIO, acoesDoCatalogo, conferirDefinicao, registrar } from './catalogo'
import type { Chave, DefinicaoQualquer } from './tipos'

// Catálogo de chaves fictício (o do sistema nasce vazio nesta spec; ADR 0020).
const CHAVES_TESTE = { agenda: ['ver', 'criar'], caixa: ['ver'] } as const
const chave = (texto: string) => texto as unknown as Chave

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
  permissao: chave('agenda.criar'),
  entrada: z.strictObject({}),
  grava: true,
  trabalho: async () => null,
}

// Todo arquivo de src/ que declara ação com acao({ (acao.ts só o cita no comentário do molde). Carregá-los põe as
// ações no catálogo.
const comAcao = codigo.filter(({ caminho, texto }) => caminho !== 'server/portas/acao.ts' && texto.includes('acao({'))
const modulos: Record<string, unknown>[] = []

describe('catálogo (CA-21)', () => {
  beforeAll(async () => {
    for (const { caminho } of comAcao) modulos.push((await import(join(RAIZ, caminho))) as Record<string, unknown>)
  })

  it('as ações de sessão estão no catálogo, cada uma no seu modo da lista fechada', () => {
    const noCatalogo = new Map<string, string>(acoesDoCatalogo().map((def) => [def.nome, def.sessao]))
    for (const [nome, modo] of Object.entries(MODOS_SEM_ESTUDIO)) expect(noCatalogo.get(nome)).toBe(modo)
  })

  it('cada ação exportada usa o construtor do seu método (todo arquivo de src/ com acao({)', () => {
    expect(modulos.length).toBeGreaterThan(0)
    const exportadas: { method: string; definicaoDaAcao: DefinicaoQualquer }[] = []
    for (const modulo of modulos) {
      for (const valor of Object.values(modulo)) {
        if (typeof valor === 'function' && 'definicaoDaAcao' in valor && 'method' in valor) {
          exportadas.push(valor as unknown as { method: string; definicaoDaAcao: DefinicaoQualquer })
        }
      }
    }
    const declaradas = comAcao.reduce((total, { texto }) => total + (texto.match(/\bacao\(\{/g)?.length ?? 0), 0)
    expect(exportadas).toHaveLength(declaradas)
    for (const fn of exportadas) expect(fn.method).toBe(fn.definicaoDaAcao.metodo)
  })

  it('definição no molde passa', () => {
    expect(conferirDefinicao(valida, CHAVES_TESTE)).toBeNull()
  })

  it('toda ação do modo estudio no catálogo tem chave do catálogo de chaves, do mesmo módulo (ADR 0020 · D8)', () => {
    for (const def of acoesDoCatalogo()) {
      if (def.sessao === 'estudio') {
        expect(ehChave(def.permissao), def.nome).toBe(true)
        expect(conferirDefinicao(def, MODULOS), def.nome).toBeNull()
      } else {
        expect(def.permissao, def.nome).toBe('qualquer')
      }
    }
  })

  it('GET passa só em opcional/pessoa com strictObject({}) vazio', () => {
    const get = { ...valida, permissao: 'qualquer', metodo: 'GET', grava: false, entrada: z.strictObject({}) } as const
    expect(conferirDefinicao({ ...get, nome: 'sessao.ler', sessao: 'opcional' } as DefinicaoQualquer, CHAVES_TESTE)).toBeNull()
    expect(conferirDefinicao({ ...get, nome: 'estudio.listar', sessao: 'pessoa' } as DefinicaoQualquer, CHAVES_TESTE)).toBeNull()
  })

  it.each<[string, Partial<DefinicaoQualquer>]>([
    ['nome sem ponto', { nome: 'criar' as DefinicaoQualquer['nome'] }],
    ['nome com maiúscula', { nome: 'Agenda.criar' }],
    ['nome longo demais', { nome: `a.${'b'.repeat(70)}` as DefinicaoQualquer['nome'] }],
    ['grava por GET', { metodo: 'GET' }],
    ['GET no modo estudio, mesmo sem gravar', { metodo: 'GET', grava: false }],
    ['GET no modo nenhuma', { nome: 'sessao.entrar', sessao: 'nenhuma', permissao: 'qualquer', metodo: 'GET', grava: false }],
    ['GET com campo na entrada', { nome: 'estudio.listar', sessao: 'pessoa', permissao: 'qualquer', metodo: 'GET', grava: false, entrada: z.strictObject({ q: z.string() }) }],
    ['GET com entrada não estrita', { nome: 'estudio.listar', sessao: 'pessoa', permissao: 'qualquer', metodo: 'GET', grava: false, entrada: z.object({}) }],
    ['GET com entrada solta', { nome: 'sessao.ler', sessao: 'opcional', permissao: 'qualquer', metodo: 'GET', grava: false, entrada: z.looseObject({}) }],
    ['GET com entrada que não é objeto', { nome: 'sessao.ler', sessao: 'opcional', permissao: 'qualquer', metodo: 'GET', grava: false, entrada: z.string() }],
    ['modo sem estúdio fora da lista', { sessao: 'pessoa' }],
    ['modo nenhuma fora da lista', { sessao: 'nenhuma' }],
    ['ação da lista no modo estudio', { nome: 'sessao.sair' }],
    ['ação da lista em outro modo', { nome: 'sessao.ler', sessao: 'pessoa' }],
    ['permissão "qualquer" no modo estudio', { permissao: 'qualquer' }],
    ['chave fora do catálogo', { permissao: chave('agenda.remover') }],
    ['módulo fora do catálogo', { permissao: chave('clientes.ver') }],
    ['chave de outro módulo que o do nome', { permissao: chave('caixa.ver') }],
    ['chave sem ponto', { permissao: chave('agenda') }],
    ['papel no lugar da chave', { permissao: ['dona'] as unknown as Chave }],
    ['função no lugar da chave', { permissao: (() => true) as unknown as Chave }],
    ['chave num modo sem estúdio', { nome: 'sessao.sair', sessao: 'pessoa', permissao: chave('agenda.ver') }],
  ])('fora do molde: %s → recusada ao carregar', (_nome, mudar) => {
    const def = { ...valida, ...mudar } as DefinicaoQualquer
    expect(conferirDefinicao(def, CHAVES_TESTE)).not.toBeNull()
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
