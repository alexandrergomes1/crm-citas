import { describe, expect, it, vi } from 'vitest'
import type { Ambiente } from './ambiente'
import { lerAmbiente } from './ambiente'
import { NOME_DO_COOKIE, OPCOES_DO_COOKIE, criarCliente, ehCookieDaSessao } from './cliente'
import { ErroDoBanco } from './erros'

// Valores fictícios, só para o teste (nenhum é chave real).
const ambiente: Ambiente = {
  supabaseUrl: 'http://127.0.0.1:54321',
  chavePublica: 'sb_publishable_ficticia_de_teste',
  segredoTentativas: 's'.repeat(32),
  chaveServidor: 'c'.repeat(32),
}
const cabecalhos = { pedidoId: '6f1c2d3e-4a5b-4c6d-8e7f-8a9b0c1d2e3f', acao: 'agenda.bloqueio.criar' }

const respostaJson = (corpo: unknown, status = 200) =>
  new Response(JSON.stringify(corpo), { status, headers: { 'content-type': 'application/json' } })

function fetchFalso() {
  return vi.fn<typeof globalThis.fetch>(async () => respostaJson(null))
}

const cabecalhoDe = (init: RequestInit | undefined, nome: string): string | null =>
  new Headers(init?.headers).get(nome)

describe('criarCliente · cabeçalhos do pedido (ADR 0018 · D16, D6)', () => {
  it('todo pedido à Data API leva x-chave-servidor, x-pedido, x-acao e x-estudio-esperado', async () => {
    const fetch = fetchFalso()
    const cliente = criarCliente({
      ambiente,
      cookies: [],
      cabecalhos: { ...cabecalhos, estudioEsperado: '11111111-2222-4333-8444-555555555555' },
      fetch,
    })
    await cliente.supabase.rpc('contexto_da_sessao')
    const [, init] = fetch.mock.calls[0]!
    expect(cabecalhoDe(init, 'x-chave-servidor')).toBe(ambiente.chaveServidor)
    expect(cabecalhoDe(init, 'x-pedido')).toBe(cabecalhos.pedidoId)
    expect(cabecalhoDe(init, 'x-acao')).toBe('agenda.bloqueio.criar')
    expect(cabecalhoDe(init, 'x-estudio-esperado')).toBe('11111111-2222-4333-8444-555555555555')
    expect(cabecalhoDe(init, 'apikey')).toBe(ambiente.chavePublica)
  })

  it('a linha de recusa vai sem x-estudio-esperado (senão o pré-pedido a recusaria)', async () => {
    const fetch = fetchFalso()
    const cliente = criarCliente({
      ambiente,
      cookies: [],
      cabecalhos: { ...cabecalhos, estudioEsperado: '11111111-2222-4333-8444-555555555555' },
      fetch,
    })
    await cliente.supabase.rpc('registrar_recusa', { p_acao: 'a.b', p_codigo: 'estudio_trocado', p_pedido: cabecalhos.pedidoId })
    const [, init] = fetch.mock.calls[0]!
    expect(cabecalhoDe(init, 'x-estudio-esperado')).toBeNull()
    expect(cabecalhoDe(init, 'x-chave-servidor')).toBe(ambiente.chaveServidor)
  })

  it('sem estúdio esperado, o cabeçalho não vai', async () => {
    const fetch = fetchFalso()
    const cliente = criarCliente({ ambiente, cookies: [], cabecalhos, fetch })
    await cliente.supabase.rpc('meus_estudios')
    expect(cabecalhoDe(fetch.mock.calls[0]![1], 'x-estudio-esperado')).toBeNull()
  })
})

describe('criarCliente · contagem de gravações (ADR 0018 · D3)', () => {
  it('nas portas, nada é contado', async () => {
    const fetch = fetchFalso()
    const cliente = criarCliente({ ambiente, cookies: [], cabecalhos, fetch })
    await cliente.supabase.rpc('contexto_da_sessao')
    await cliente.supabase.rpc('registrar_recusa', {})
    expect(fetch).toHaveBeenCalledTimes(2)
    expect(cliente.violou).toBe(false)
  })

  it('grava: true → a primeira gravação sai; a segunda é recusada sem sair', async () => {
    const fetch = fetchFalso()
    const cliente = criarCliente({ ambiente, cookies: [], cabecalhos, fetch })
    cliente.iniciarTrabalho(true)
    const primeira = await cliente.supabase.from('bloqueios').insert({ a: 1 })
    expect(primeira.error).toBeNull()
    const segunda = await cliente.supabase.rpc('outra_gravacao')
    expect(segunda.error).not.toBeNull()
    expect(fetch).toHaveBeenCalledTimes(1)
    expect(cliente.violou).toBe(true)
  })

  it('grava: false → qualquer gravação é recusada sem sair', async () => {
    const fetch = fetchFalso()
    const cliente = criarCliente({ ambiente, cookies: [], cabecalhos, fetch })
    cliente.iniciarTrabalho(false)
    await cliente.supabase.from('bloqueios').delete().eq('id', 1)
    expect(fetch).not.toHaveBeenCalled()
    expect(cliente.violou).toBe(true)
  })

  it('leitura (GET) não conta', async () => {
    const fetch = fetchFalso()
    const cliente = criarCliente({ ambiente, cookies: [], cabecalhos, fetch })
    cliente.iniciarTrabalho(false)
    await cliente.supabase.from('bloqueios').select('id')
    await cliente.supabase.rpc('ler_agenda', {}, { get: true })
    expect(fetch).toHaveBeenCalledTimes(2)
    expect(cliente.violou).toBe(false)
  })

  it('a recusa é ErroDoBanco erro_interno (o texto não muda)', async () => {
    const cliente = criarCliente({ ambiente, cookies: [], cabecalhos, fetch: fetchFalso() })
    cliente.iniciarTrabalho(false)
    const { error } = await cliente.supabase.rpc('gravar')
    expect(JSON.stringify(error)).not.toContain('bloqueios')
    cliente.terminarTrabalho()
    expect(new ErroDoBanco('erro_interno').message).toBe('erro_interno')
  })
})

describe('criarCliente · cookie da sessão (ADR 0018 · D9; CA-02)', () => {
  it('opções fixas: __Host-, HttpOnly, Secure, SameSite=Lax, Path=/', () => {
    expect(NOME_DO_COOKIE.startsWith('__Host-')).toBe(true)
    expect(OPCOES_DO_COOKIE).toEqual({ httpOnly: true, secure: true, sameSite: 'lax', path: '/' })
  })

  it('entrar grava o cookie com as opções fixas e cabeçalhos sem cache', async () => {
    const agora = Math.floor(Date.now() / 1000)
    const fetch = vi.fn<typeof globalThis.fetch>(async () =>
      respostaJson({
        access_token: 'token.ficticio.de-teste',
        token_type: 'bearer',
        expires_in: 3600,
        expires_at: agora + 3600,
        refresh_token: 'renovacao-ficticia',
        user: { id: '0a1b2c3d-4e5f-4a6b-8c7d-9e0f1a2b3c4d', aud: 'authenticated', app_metadata: {}, user_metadata: {}, created_at: '2026-11-28T00:00:00Z' },
      }),
    )
    const cliente = criarCliente({ ambiente, cookies: [], cabecalhos, fetch })
    const { error } = await cliente.supabase.auth.signInWithPassword({ email: 'pessoa@exemplo.test', password: 'senha-de-teste' })
    expect(error).toBeNull()

    const { cookies, cabecalhos: daResposta } = cliente.saida()
    expect(cookies.length).toBeGreaterThan(0)
    for (const cookie of cookies) {
      expect(ehCookieDaSessao(cookie.nome)).toBe(true)
      expect(cookie.opcoes).toMatchObject({ httpOnly: true, secure: true, sameSite: 'lax', path: '/' })
      expect(cookie.opcoes.maxAge).toBeGreaterThan(0)
    }
    expect(daResposta['Cache-Control'] ?? '').toContain('no-store')
  })

  it('apagarCookiesDaSessao apaga os da sessão (inclusive pedaços) e deixa os outros', () => {
    const cliente = criarCliente({
      ambiente,
      cookies: [
        { nome: `${NOME_DO_COOKIE}.0`, valor: 'a' },
        { nome: `${NOME_DO_COOKIE}.1`, valor: 'b' },
        { nome: 'preferencia', valor: 'c' },
      ],
      cabecalhos,
      fetch: fetchFalso(),
    })
    cliente.apagarCookiesDaSessao()
    const nomes = cliente.saida().cookies.map((c) => [c.nome, c.opcoes.maxAge])
    expect(nomes).toEqual([
      [`${NOME_DO_COOKIE}.0`, 0],
      [`${NOME_DO_COOKIE}.1`, 0],
    ])
  })
})

describe('lerAmbiente (falha fechada)', () => {
  const completo = {
    SUPABASE_URL: 'http://127.0.0.1:54321',
    SUPABASE_PUBLISHABLE_KEY: 'sb_publishable_ficticia',
    SEGREDO_TENTATIVAS: 's'.repeat(32),
    CHAVE_SERVIDOR_BANCO: 'c'.repeat(32),
  }

  it('completo → lido', () => {
    expect(lerAmbiente(completo)).toEqual({
      supabaseUrl: 'http://127.0.0.1:54321',
      chavePublica: 'sb_publishable_ficticia',
      segredoTentativas: 's'.repeat(32),
      chaveServidor: 'c'.repeat(32),
    })
  })

  it('faltou uma variável → null', () => {
    for (const nome of Object.keys(completo)) {
      expect(lerAmbiente({ ...completo, [nome]: undefined })).toBeNull()
    }
  })

  it('segredo curto → null', () => {
    expect(lerAmbiente({ ...completo, CHAVE_SERVIDOR_BANCO: 'curta' })).toBeNull()
    expect(lerAmbiente({ ...completo, SEGREDO_TENTATIVAS: 'curto' })).toBeNull()
  })

  it('http fora da máquina local → null; https → lido', () => {
    expect(lerAmbiente({ ...completo, SUPABASE_URL: 'http://exemplo.supabase.co' })).toBeNull()
    expect(lerAmbiente({ ...completo, SUPABASE_URL: 'https://exemplo.supabase.co' })?.supabaseUrl).toBe(
      'https://exemplo.supabase.co',
    )
    expect(lerAmbiente({ ...completo, SUPABASE_URL: 'não é endereço' })).toBeNull()
  })

  it('só lê as variáveis sem VITE_ (nada vai ao navegador)', () => {
    expect(lerAmbiente({ VITE_SUPABASE_URL: completo.SUPABASE_URL })).toBeNull()
  })
})
