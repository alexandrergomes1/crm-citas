// Entrar com o Auth e o banco locais (CA-01, CA-14, CA-16, CA-18a). Dados fictícios, criados a cada rodada.
import { createClient } from '@supabase/supabase-js'
import { beforeAll, describe, expect, it } from 'vitest'
import { acoesDoCatalogo } from '@/server/portas/catalogo'
import '@/server/sessao/acoes'
import { Navegador, ambiente, bancoPronto, criarEstudio, criarPessoa, emailFicticio, vincular } from './preparo'

const def = (nome: string) => acoesDoCatalogo().find((d) => d.nome === nome)!
const SENHA = 'senha-ficticia-de-teste-1'

const mediana = (valores: number[]) => [...valores].sort((a, b) => a - b)[Math.floor(valores.length / 2)]!

describe.skipIf(!bancoPronto)('sessao.entrar (integração)', () => {
  let comEstudio: string
  let semEstudio: string
  let orgA: string

  beforeAll(async () => {
    orgA = await criarEstudio('Estúdio Fictício A')
    comEstudio = emailFicticio('com-estudio')
    semEstudio = emailFicticio('sem-estudio')
    await vincular(orgA, await criarPessoa(comEstudio, SENHA), 'dona')
    await criarPessoa(semEstudio, SENHA)
  })

  it('CA-01: e-mail e senha certos criam a sessão; o cookie é HttpOnly, Secure, Lax', async () => {
    const navegador = new Navegador()
    const resposta = await navegador.chamar(def('sessao.entrar'), { dados: { email: comEstudio, senha: SENHA } })
    expect(resposta.resultado).toEqual({ ok: true, valor: { destino: 'inicio' } })
    for (const c of resposta.cookies) expect(c.opcoes).toMatchObject({ httpOnly: true, secure: true, sameSite: 'lax', path: '/' })
    const lida = await navegador.chamar(def('sessao.ler'), undefined)
    expect(lida.resultado).toEqual({ ok: true, valor: { comSessao: true, comEstudio: true, idioma: 'pt' } })
  })

  it('CA-01: senha errada, sem conta e sem estúdio dão a mesma resposta, com tempo parecido', async () => {
    // Conta própria para a senha errada: o limite (10 por conta em 15 min) não pode pegar as outras.
    const outra = emailFicticio('senha-errada')
    await vincular(orgA, await criarPessoa(outra, SENHA), 'dona')
    const casos = {
      senhaErrada: { email: outra, senha: 'outra-senha' },
      semConta: { email: emailFicticio('ninguem'), senha: SENHA },
      semEstudio: { email: semEstudio, senha: SENHA },
    }
    const tempos: Record<string, number[]> = {}
    for (const [nome, dados] of Object.entries(casos)) {
      tempos[nome] = []
      const navegador = new Navegador()
      for (let i = 0; i < 10; i++) {
        const inicio = performance.now()
        const resposta = await navegador.chamar(def('sessao.entrar'), { dados })
        tempos[nome].push(performance.now() - inicio)
        expect(resposta.resultado).toEqual({ ok: false, codigo: 'sem_login' })
        expect(navegador.lista()).toEqual([])
      }
    }
    const medianas = Object.values(tempos).map(mediana)
    expect(Math.max(...medianas) - Math.min(...medianas)).toBeLessThan(100)
  }, 120_000)

  it('CA-14: a 11ª tentativa da mesma conta → limite', async () => {
    const email = emailFicticio('limite')
    await criarPessoa(email, SENHA)
    const codigos: string[] = []
    for (let i = 0; i < 11; i++) {
      const r = await new Navegador().chamar(def('sessao.entrar'), { dados: { email, senha: 'errada' } })
      codigos.push(r.resultado.ok ? 'ok' : r.resultado.codigo)
    }
    expect(codigos.slice(0, 10).every((c) => c === 'sem_login')).toBe(true)
    expect(codigos[10]).toBe('limite')
  }, 60_000)

  it('CA-18a: senha de 64 caracteres entra; a de 128 passa da porta 4 sem cortar', async () => {
    const senha64 = 'a1-'.repeat(21) + 'xy'
    const email = emailFicticio('senha-64')
    await vincular(orgA, await criarPessoa(email, senha64), 'recepcao')
    expect((await new Navegador().chamar(def('sessao.entrar'), { dados: { email, senha: senha64 } })).resultado.ok).toBe(true)

    // Limite do Supabase Auth: 72 bytes, confirmado em supabase/auth (master) internal/api/password.go
    // (MaxPasswordLength = 72; conta bytes). A de 128 caracteres (256 bytes) chega ao Auth inteira (porta 4 aceita
    // até 128) e a resposta é a frase única, não entrada_invalida.
    const r = await new Navegador().chamar(def('sessao.entrar'), { dados: { email, senha: 'ç'.repeat(128) } })
    expect(r.resultado).toEqual({ ok: false, codigo: 'sem_login' })
  })

  it('CA-16: ninguém cria conta pelo Auth (cadastro aberto desligado)', async () => {
    const publico = createClient(ambiente!.supabaseUrl, ambiente!.chavePublica, { auth: { persistSession: false } })
    const { data, error } = await publico.auth.signUp({ email: emailFicticio('cadastro'), password: SENHA })
    expect(error).not.toBeNull()
    expect(data.user).toBeNull()
  })
})
