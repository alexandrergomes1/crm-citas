// Estúdio da sessão, troca e sair (CA-05, CA-06, CA-13, CA-18). Dados fictícios.
import { beforeAll, describe, expect, it } from 'vitest'
import { z } from 'zod'
import { clienteDoBanco } from '@/data/cliente'
import { abrirConexao } from '@/data/sessao'
import type { ChaveDe } from '@/domain/acesso/chaves'
import { alcanceNaMatriz, type LinhaDaMatriz } from '@/domain/acesso/matriz'
import { acoesDoCatalogo, conferirDefinicao } from '@/server/portas/catalogo'
import type { Chave, DefinicaoDeAcao, DefinicaoQualquer, FonteDeAlcance } from '@/server/portas/tipos'
import '@/server/sessao/acoes'
import { Navegador, ambiente, bancoPronto, criarEstudio, criarPessoa, emailFicticio, vincular } from './preparo'

const def = (nome: string) => acoesDoCatalogo().find((d) => d.nome === nome)!
const SENHA = 'senha-ficticia-de-teste-2'

// Ação de módulo só deste teste: lê o estúdio da sessão pela trava (porta 5). Chave de um catálogo de teste (o do
// sistema nasce vazio nesta spec; ADR 0020): por isso a definição não entra no catálogo real por acao(...), mas é
// conferida pelo mesmo molde, com o catálogo de teste, e chamada pelas mesmas portas (executar) com a fonte de teste.
const CATALOGO_TESTE = { teste_integracao: ['ver'] } as const
const MATRIZ_TESTE: readonly LinhaDaMatriz<ChaveDe<typeof CATALOGO_TESTE>>[] = [
  { papel: 'recepcao', chave: 'teste_integracao.ver', alcance: 'todos' },
  { papel: 'profissional', chave: 'teste_integracao.ver', alcance: 'todos' },
]
const fonteDeTeste: FonteDeAlcance = (sessao, chave) =>
  alcanceNaMatriz(CATALOGO_TESTE, MATRIZ_TESTE, sessao.papel, chave)

let trabalhou = 0
const acaoLer: DefinicaoDeAcao<z.ZodType, string[]> = {
  nome: 'teste_integracao.ler',
  metodo: 'POST',
  sessao: 'estudio',
  permissao: 'teste_integracao.ver' as unknown as Chave,
  entrada: z.strictObject({}),
  grava: false,
  trabalho: async (ctx) => {
    trabalhou++
    const { data, error } = await clienteDoBanco(ctx.banco).from('estudios').select('org_id')
    if (error) throw new Error('leitura')
    return (data ?? []).map((l) => l.org_id as string)
  },
}
const motivoDoMolde = conferirDefinicao(acaoLer as unknown as DefinicaoQualquer, CATALOGO_TESTE)
if (motivoDoMolde) throw new Error(`acao teste_integracao.ler: ${motivoDoMolde}`)
const ler = () => acaoLer

describe.skipIf(!bancoPronto)('sessão e estúdio (integração)', () => {
  let orgA: string
  let orgB: string
  let orgInativo: string
  let deAeB: string
  let soDeA: string

  beforeAll(async () => {
    orgA = await criarEstudio('A')
    orgB = await criarEstudio('B', 'es')
    orgInativo = await criarEstudio('Inativo')
    deAeB = emailFicticio('a-e-b')
    soDeA = emailFicticio('so-a')
    const p1 = await criarPessoa(deAeB, SENHA)
    await vincular(orgA, p1, 'dona')
    await vincular(orgB, p1, 'recepcao')
    await vincular(orgInativo, p1, 'dona', false)
    await vincular(orgA, await criarPessoa(soDeA, SENHA), 'profissional')
  })

  async function entrar(email: string, navegador = new Navegador()) {
    const r = await navegador.chamar(def('sessao.entrar'), { dados: { email, senha: SENHA } })
    expect(r.resultado.ok).toBe(true)
    return navegador
  }

  it('CA-18: lista só estúdios com papel ativo', async () => {
    const n = await entrar(deAeB)
    const r = await n.chamar(def('estudio.listar'), undefined)
    expect(r.resultado.ok).toBe(true)
    const ids = r.resultado.ok ? (r.resultado.valor as { orgId: string }[]).map((e) => e.orgId).sort() : []
    expect(ids).toEqual([orgA, orgB].sort())
  })

  it('CA-05: com A escolhido, pedido dizendo B → estudio_trocado, nada lido', async () => {
    const n = await entrar(deAeB)
    expect((await n.chamar(def('estudio.escolher'), { dados: { orgId: orgA } })).resultado.ok).toBe(true)
    const antes = trabalhou
    expect((await n.chamar(ler(), { estudioDaTela: orgB, dados: {} }, fonteDeTeste)).resultado).toEqual({ ok: false, codigo: 'estudio_trocado' })
    expect(trabalhou).toBe(antes)
    const certo = await n.chamar(ler(), { estudioDaTela: orgA, dados: {} }, fonteDeTeste)
    expect(certo.resultado).toEqual({ ok: true, valor: [orgA] })
  })

  it('CA-05: pessoa só de A não escolhe B; nada muda', async () => {
    const n = await entrar(soDeA)
    expect((await n.chamar(def('estudio.escolher'), { dados: { orgId: orgB } })).resultado).toEqual({ ok: false, codigo: 'sem_permissao' })
    expect((await n.chamar(ler(), { estudioDaTela: orgA, dados: {} }, fonteDeTeste)).resultado.ok).toBe(true)
  })

  it('CA-06: troca em outro aparelho → a tela antiga recebe estudio_trocado', async () => {
    const aparelho1 = await entrar(deAeB)
    await aparelho1.chamar(def('estudio.escolher'), { dados: { orgId: orgA } })
    const aparelho2 = await entrar(deAeB)
    await aparelho2.chamar(def('estudio.escolher'), { dados: { orgId: orgB } })
    expect((await aparelho1.chamar(ler(), { estudioDaTela: orgA, dados: {} }, fonteDeTeste)).resultado).toEqual({
      ok: false,
      codigo: 'estudio_trocado',
    })
  })

  it('CA-13: depois de Sair, o cookie antigo é recusado e não cria sessão nova', async () => {
    const n = await entrar(deAeB)
    await n.chamar(def('estudio.escolher'), { dados: { orgId: orgA } })
    const antigo = n.copia()
    expect((await n.chamar(def('sessao.sair'), { dados: {} })).resultado.ok).toBe(true)
    expect(n.lista()).toEqual([])

    expect((await antigo.copia().chamar(ler(), { estudioDaTela: orgA, dados: {} }, fonteDeTeste)).resultado).toEqual({ ok: false, codigo: 'sem_login' })
    expect((await antigo.copia().chamar(def('sessao.ler'), undefined)).resultado).toMatchObject({ ok: true, valor: { comSessao: false } })

    // Não ressuscita: com o cookie antigo, iniciar_sessao é recusado (session_id já visto).
    const conexao = abrirConexao({
      ambiente: ambiente!,
      cookies: antigo.lista(),
      cabecalhos: { pedidoId: crypto.randomUUID(), acao: 'sessao.entrar' },
    })
    await expect(conexao.iniciarSessao()).rejects.toMatchObject({ codigo: 'sem_login' })
  })

  it('CA-13: chamada direta à Data API com token e chave pública, sem x-chave-servidor → recusada', async () => {
    const n = await entrar(deAeB)
    const valor = n.lista().map((c) => c.valor).join('')
    const sessao = JSON.parse(Buffer.from(valor.replace(/^base64-/, ''), 'base64url').toString('utf8')) as { access_token: string }
    const resposta = await fetch(`${ambiente!.supabaseUrl}/rest/v1/rpc/meus_estudios`, {
      method: 'POST',
      headers: { apikey: ambiente!.chavePublica, authorization: `Bearer ${sessao.access_token}`, 'content-type': 'application/json' },
      body: '{}',
    })
    expect(resposta.ok).toBe(false)
    expect(await resposta.json()).toMatchObject({ code: 'sem_login' })
  })
})
