// CA-04 · Sem sessão, nada passa: percorre o catálogo inteiro sem cookie e com sessão encerrada.
import { beforeAll, describe, expect, it } from 'vitest'
import { acoesDoCatalogo } from '@/server/portas/catalogo'
import '@/server/sessao/acoes'
import { Navegador, bancoPronto, criarEstudio, criarPessoa, emailFicticio, vincular } from './preparo'

const ORG_QUALQUER = '11111111-2222-4333-8444-555555555555'
const SENHA = 'senha-ficticia-de-teste-3'
const corpo = (sessao: string) => (sessao === 'estudio' ? { estudioDaTela: ORG_QUALQUER, dados: {} } : { dados: {} })

describe.skipIf(!bancoPronto)('CA-04 · sem sessão, nada passa (integração)', () => {
  let encerrado: Navegador

  beforeAll(async () => {
    const org = await criarEstudio('Portas')
    const email = emailFicticio('portas')
    await vincular(org, await criarPessoa(email, SENHA), 'dona')
    const n = new Navegador()
    await n.chamar(acoesDoCatalogo().find((d) => d.nome === 'sessao.entrar')!, { dados: { email, senha: SENHA } })
    encerrado = n.copia()
    await n.chamar(acoesDoCatalogo().find((d) => d.nome === 'sessao.sair')!, { dados: {} })
  })

  it('toda ação com sessão (estudio e pessoa) → sem_login, sem cookie e com sessão encerrada', async () => {
    const comSessao = acoesDoCatalogo().filter((d) => d.sessao === 'estudio' || d.sessao === 'pessoa')
    expect(comSessao.length).toBeGreaterThan(0)
    for (const d of comSessao) {
      expect((await new Navegador().chamar(d, corpo(d.sessao))).resultado, d.nome).toEqual({ ok: false, codigo: 'sem_login' })
      expect((await encerrado.copia().chamar(d, corpo(d.sessao))).resultado, d.nome).toEqual({ ok: false, codigo: 'sem_login' })
    }
  })

  it('sessao.ler sem sessão só diz que não há sessão', async () => {
    const d = acoesDoCatalogo().find((x) => x.nome === 'sessao.ler')!
    expect((await new Navegador().chamar(d, undefined)).resultado).toMatchObject({ ok: true, valor: { comSessao: false } })
  })

  // Sessão vencida (12 h / 30 min) e contagem do registro antes e depois pedem acesso SQL ao banco local,
  // que o preparo ainda não tem (tarefa D1): ficam no pgTAP 070_ e 060_ até lá.
  it.todo('sessão vencida (12 h e 30 min) → sem_login (CA-15)')
  it.todo('contagem do registro e das tabelas igual antes e depois (CA-04)')
})
