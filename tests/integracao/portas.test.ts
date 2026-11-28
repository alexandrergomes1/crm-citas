// CA-04 · Sem sessão, nada passa: percorre o catálogo inteiro sem cookie, com sessão encerrada e com sessão vencida.
// CA-15 · Sessão vence em 12 h desde a entrada e em 1 h parada (E39·3·B): relógio empurrado para trás no banco local.
import { beforeAll, describe, expect, it } from 'vitest'
import { acoesDoCatalogo } from '@/server/portas/catalogo'
import '@/server/sessao/acoes'
import { Navegador, bancoPronto, criarEstudio, criarPessoa, emailFicticio, sql, uuid, vincular } from './preparo'

const ORG_QUALQUER = '11111111-2222-4333-8444-555555555555'
const SENHA = 'senha-ficticia-de-teste-3'
const def = (nome: string) => acoesDoCatalogo().find((d) => d.nome === nome)!
const corpo = (sessao: string) => (sessao === 'estudio' ? { estudioDaTela: ORG_QUALQUER, dados: {} } : { dados: {} })
const comSessao = () => acoesDoCatalogo().filter((d) => d.sessao === 'estudio' || d.sessao === 'pessoa')

/** Impressão de cada tabela dos esquemas app e public: muda se alguma linha nasce, muda ou some. */
function impressao(): Record<string, string> {
  const linhas = sql<{ tabela: string; marca: string }>(
    `select n.nspname || '.' || c.relname as tabela,
            (xpath('/row/m/text()', query_to_xml(format(
               'select md5(coalesce(string_agg(t::text, %L order by t::text), %L)) as m from %I.%I t',
               chr(10), '', n.nspname, c.relname), false, true, '')))[1]::text as marca
       from pg_catalog.pg_class c join pg_catalog.pg_namespace n on n.oid = c.relnamespace
      where c.relkind in ('r', 'p') and n.nspname in ('app', 'public')
      order by 1`,
  )
  return Object.fromEntries(linhas.map((l) => [l.tabela, l.marca]))
}

function mudadas(antes: Record<string, string>, depois: Record<string, string>): string[] {
  const nomes = new Set([...Object.keys(antes), ...Object.keys(depois)])
  return [...nomes].filter((t) => antes[t] !== depois[t]).sort()
}

const ultimoRegistro = () => Number(sql<{ id: string | null }>('select max(id)::text as id from app.registro')[0]?.id ?? 0)

async function entrar(email: string): Promise<Navegador> {
  const n = new Navegador()
  const r = await n.chamar(def('sessao.entrar'), { dados: { email, senha: SENHA } })
  expect(r.resultado).toEqual({ ok: true, valor: { destino: 'inicio' } })
  return n
}

/** A sessão viva da pessoa (uma só por vez nestes testes). */
function sessaoViva(usuario: string): string {
  const [linha, ...outras] = sql<{ session_id: string }>(
    `select session_id::text from app.sessoes where user_id = ${uuid(usuario)} and encerrada_em is null`,
  )
  expect(outras).toEqual([])
  return linha!.session_id
}

const motivoDoFim = (sessao: string) =>
  sql<{ motivo_fim: string | null }>(`select motivo_fim from app.sessoes where session_id = ${uuid(sessao)}`)[0]?.motivo_fim

describe.skipIf(!bancoPronto)('CA-04 e CA-15 · sem sessão, nada passa (integração)', () => {
  let encerrado: Navegador
  let email: string
  let usuario: string

  beforeAll(async () => {
    const org = await criarEstudio('Portas')
    email = emailFicticio('portas')
    usuario = await criarPessoa(email, SENHA)
    await vincular(org, usuario, 'dona')
    const n = await entrar(email)
    encerrado = n.copia()
    await n.chamar(def('sessao.sair'), { dados: {} })
  })

  it('toda ação com sessão (estudio e pessoa) → sem_login, sem cookie e com sessão encerrada', async () => {
    expect(comSessao().length).toBeGreaterThan(0)
    for (const d of comSessao()) {
      expect((await new Navegador().chamar(d, corpo(d.sessao))).resultado, d.nome).toEqual({ ok: false, codigo: 'sem_login' })
      expect((await encerrado.copia().chamar(d, corpo(d.sessao))).resultado, d.nome).toEqual({ ok: false, codigo: 'sem_login' })
    }
  })

  it('sessao.ler sem sessão só diz que não há sessão', async () => {
    const d = def('sessao.ler')
    expect((await new Navegador().chamar(d, undefined)).resultado).toMatchObject({ ok: true, valor: { comSessao: false } })
  })

  it('sessão vencida (12 h e 1 h parada) → sem_login (CA-15)', async () => {
    // 12 h desde a entrada
    const n12 = await entrar(email)
    const s12 = sessaoViva(usuario)
    sql(`update app.sessoes set entrou_em = now() - interval '12 hours 1 second' where session_id = ${uuid(s12)}`)
    expect((await n12.copia().chamar(def('estudio.listar'), undefined)).resultado).toEqual({ ok: false, codigo: 'sem_login' })
    expect(motivoDoFim(s12)).toBe('tempo')
    const lida12 = await n12.chamar(def('sessao.ler'), undefined)
    expect(lida12.resultado).toMatchObject({ ok: true, valor: { comSessao: false } })
    expect(n12.lista()).toEqual([]) // o servidor apagou o cookie (plan.md §3.4)

    // 1 h parada
    const n1 = await entrar(email)
    const s1 = sessaoViva(usuario)
    sql(`update app.sessoes set ultimo_uso = now() - interval '1 hour 1 second' where session_id = ${uuid(s1)}`)
    expect((await n1.chamar(def('estudio.listar'), undefined)).resultado).toEqual({ ok: false, codigo: 'sem_login' })
    expect(motivoDoFim(s1)).toBe('parada')
    expect(n1.lista()).toEqual([])

    // Antes do limite a sessão segue (o limite não é mais curto do que o decidido)
    const nViva = await entrar(email)
    const sViva = sessaoViva(usuario)
    sql(
      `update app.sessoes set entrou_em = now() - interval '11 hours 59 minutes', ultimo_uso = now() - interval '59 minutes'` +
        ` where session_id = ${uuid(sViva)}`,
    )
    expect((await nViva.chamar(def('estudio.listar'), undefined)).resultado.ok).toBe(true)
    await nViva.chamar(def('sessao.sair'), { dados: {} })
  })

  it('contagem do registro e das tabelas igual antes e depois (CA-04)', async () => {
    // Sem cookie e com sessão encerrada: nenhuma tabela muda.
    const antes = impressao()
    expect(Object.keys(antes)).toEqual(expect.arrayContaining(['app.registro', 'app.sessoes', 'public.estudios', 'public.membros']))
    for (const d of comSessao()) {
      await new Navegador().chamar(d, corpo(d.sessao))
      await encerrado.copia().chamar(d, corpo(d.sessao))
    }
    expect(mudadas(antes, impressao())).toEqual([])

    // Com sessão vencida: só a marca do fim da sessão (plan.md §3.4: motivo `tempo` e uma linha sessao.sair com
    // resultado sem_login, no primeiro pedido); nenhuma ação lê, grava ou registra mais nada.
    const vencida = await entrar(email)
    const sessao = sessaoViva(usuario)
    sql(`update app.sessoes set entrou_em = now() - interval '12 hours 1 second' where session_id = ${uuid(sessao)}`)
    const antesDaVencida = impressao()
    const ultimo = ultimoRegistro()
    for (const d of comSessao()) {
      expect((await vencida.copia().chamar(d, corpo(d.sessao))).resultado, d.nome).toEqual({ ok: false, codigo: 'sem_login' })
    }
    expect(mudadas(antesDaVencida, impressao())).toEqual(['app.registro', 'app.sessoes'])
    expect(motivoDoFim(sessao)).toBe('tempo')
    const novas = sql<{ evento: string; resultado: string; usuario_id: string | null }>(
      `select evento, resultado, usuario_id::text from app.registro where id > ${ultimo} order by id`,
    )
    expect(novas).toEqual([{ evento: 'sessao.sair', resultado: 'sem_login', usuario_id: usuario }])

    // E de novo com a mesma sessão, já marcada: nada muda.
    const depois = impressao()
    for (const d of comSessao()) await vencida.copia().chamar(d, corpo(d.sessao))
    expect(mudadas(depois, impressao())).toEqual([])
  }, 120_000)
})
