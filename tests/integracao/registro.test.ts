// CA-09 e CA-09a · Registro (porta 6) com o Auth e o banco locais (plan.md §9; RF-23 a RF-26).
// Linhas com os campos de RF-24 e as formas de RF-24a; nenhum e-mail, nome, senha ou IP do teste no registro;
// o contador de tentativas fica fora do registro e a linha vencida é apagada. Dados fictícios, criados a cada rodada.
import { beforeAll, describe, expect, it } from 'vitest'
import { acoesDoCatalogo } from '@/server/portas/catalogo'
import '@/server/sessao/acoes'
import { chavesDaTentativa } from '@/server/sessao/tentativas'
import {
  Navegador,
  ambiente,
  bancoPronto,
  criarEstudio,
  criarPessoa,
  ehBancoLocal,
  emailFicticio,
  sql,
  ultimoPedido,
  uuid,
  vincular,
} from './preparo'

// Revisão de segurança R2: `sql` só fala com o banco da própria máquina. Não precisa do banco de pé.
describe('alvo das consultas diretas', () => {
  it.each([
    'postgresql://postgres:x@127.0.0.1:54322/postgres',
    'postgresql://postgres:x@localhost:54322/postgres',
    'postgres://postgres:x@[::1]:54322/postgres',
  ])('aceita o banco local (%#)', (endereco) => {
    expect(ehBancoLocal(endereco)).toBe(true)
  })

  it.each([
    'postgresql://postgres:x@db.exemplo.supabase.co:5432/postgres',
    'postgresql://postgres:x@127.0.0.1.exemplo.test:5432/postgres',
    'postgresql://postgres:x@10.0.0.5:5432/postgres',
    'https://127.0.0.1:54322/postgres',
    'não é endereço',
    undefined,
    null,
  ])('recusa o que não é local ou não se lê (%#)', (endereco) => {
    expect(ehBancoLocal(endereco)).toBe(false)
  })
})

const def = (nome: string) => acoesDoCatalogo().find((d) => d.nome === nome)!
const SENHA = 'senha-ficticia-de-teste-4'
const SENHA_ERRADA = 'senha-errada-ficticia-4'

type Linha = {
  evento: string
  resultado: string
  usuario_id: string | null
  org_id: string | null
  objetos: string[] | null
  recente: boolean
}

/** Linhas do registro de um pedido, com "quando" conferido pelo relógio do banco (UTC, timestamptz). */
function linhasDoPedido(pedido: string): Linha[] {
  return sql<Linha>(
    `select evento, resultado, usuario_id::text, org_id::text, objetos::text[],
            (quando between now() - interval '5 minutes' and now()) as recente
       from app.registro where pedido_id = ${uuid(pedido)} order by id`,
  )
}

/** Texto como literal SQL (aspas dobradas); só textos fictícios do teste entram aqui. */
const literal = (texto: string) => `'${texto.replaceAll("'", "''")}'`

type Tabela = 'app.registro' | 'app.sessoes' | 'app.tentativas_entrada'

/** Para cada texto, quantas linhas da tabela inteira o contêm (sem diferença de maiúsculas). Uma consulta só. */
function achados(tabela: Tabela, textos: readonly string[]): number[] {
  const linhas = sql<{ i: number; n: number }>(
    `select x.i::int as i, (select count(*)::int from ${tabela} t where strpos(lower(t::text), lower(x.texto)) > 0) as n
       from unnest(array[${textos.map(literal).join(', ')}]::text[]) with ordinality as x (texto, i) order by x.i`,
  )
  return linhas.map((l) => l.n)
}

const hex = (chave: string) => chave.replace(/^\\x/, '')

function contador(tipo: 'ip' | 'conta', chave: string): number {
  return sql<{ n: number }>(
    `select count(*)::int as n from app.tentativas_entrada where tipo = ${literal(tipo)}` +
      ` and chave = decode(${literal(hex(chave))}, 'hex')`,
  )[0]!.n
}

describe.skipIf(!bancoPronto)('CA-09 e CA-09a · registro (integração)', () => {
  let orgA: string
  let orgB: string
  let orgDeFora: string
  let emailDeDois: string
  let emailDeUm: string
  let deDois: string
  const nomes = { a: 'Estudio Registro Alfa', b: 'Estudio Registro Beta', fora: 'Estudio Registro Fora' }

  beforeAll(async () => {
    orgA = await criarEstudio(nomes.a)
    orgB = await criarEstudio(nomes.b, 'es')
    orgDeFora = await criarEstudio(nomes.fora)
    emailDeDois = emailFicticio('registro-dois')
    emailDeUm = emailFicticio('registro-um')
    deDois = await criarPessoa(emailDeDois, SENHA)
    await vincular(orgA, deDois, 'dona')
    await vincular(orgB, deDois, 'recepcao')
    await vincular(orgA, await criarPessoa(emailDeUm, SENHA), 'profissional')
  })

  it('CA-09a: entrar, escolher, trocar, sair e entrar que falha gravam as linhas de RF-24a', async () => {
    const n = new Navegador()

    // Entrar com sucesso (dois estúdios, nenhum escolhido): usuario_id e org_id vazio; o contador não escreve aqui.
    expect((await n.chamar(def('sessao.entrar'), { dados: { email: emailDeDois, senha: SENHA } })).resultado).toEqual({
      ok: true,
      valor: { destino: 'escolher_estudio' },
    })
    expect(linhasDoPedido(ultimoPedido())).toEqual([
      { evento: 'sessao.entrar', resultado: 'ok', usuario_id: deDois, org_id: null, objetos: null, recente: true },
    ])

    // Escolher: org_id do escolhido
    expect((await n.chamar(def('estudio.escolher'), { dados: { orgId: orgA } })).resultado.ok).toBe(true)
    expect(linhasDoPedido(ultimoPedido())).toEqual([
      { evento: 'estudio.escolher', resultado: 'ok', usuario_id: deDois, org_id: orgA, objetos: null, recente: true },
    ])

    // Trocar: org_id do novo
    expect((await n.chamar(def('estudio.escolher'), { dados: { orgId: orgB } })).resultado.ok).toBe(true)
    expect(linhasDoPedido(ultimoPedido())).toEqual([
      { evento: 'estudio.trocar', resultado: 'ok', usuario_id: deDois, org_id: orgB, objetos: null, recente: true },
    ])

    // Sair: org_id da sessão
    expect((await n.chamar(def('sessao.sair'), { dados: {} })).resultado.ok).toBe(true)
    expect(linhasDoPedido(ultimoPedido())).toEqual([
      { evento: 'sessao.sair', resultado: 'ok', usuario_id: deDois, org_id: orgB, objetos: null, recente: true },
    ])

    // Entrar que falha: só evento, resultado, quando e pedido (sem e-mail, IP, usuario_id nem org_id)
    const falhou = await new Navegador().chamar(def('sessao.entrar'), { dados: { email: emailDeDois, senha: SENHA_ERRADA } })
    expect(falhou.resultado).toEqual({ ok: false, codigo: 'sem_login' })
    expect(linhasDoPedido(ultimoPedido())).toEqual([
      { evento: 'sessao.entrar', resultado: 'sem_login', usuario_id: null, org_id: null, objetos: null, recente: true },
    ])
  })

  it('CA-09: recusa na porta 5 grava a linha com os campos de RF-24 (estúdio da sessão, código)', async () => {
    const n = new Navegador()
    expect((await n.chamar(def('sessao.entrar'), { dados: { email: emailDeDois, senha: SENHA } })).resultado.ok).toBe(true)
    // Entrou já no estúdio da última escolha (B): a escolha foi registrada nesta sessão.
    expect(linhasDoPedido(ultimoPedido()).map((l) => [l.evento, l.org_id])).toEqual([
      ['sessao.entrar', null],
      ['estudio.escolher', orgB],
    ])

    expect((await n.chamar(def('estudio.escolher'), { dados: { orgId: orgDeFora } })).resultado).toEqual({
      ok: false,
      codigo: 'sem_permissao',
    })
    expect(linhasDoPedido(ultimoPedido())).toEqual([
      { evento: 'estudio.escolher', resultado: 'sem_permissao', usuario_id: deDois, org_id: orgB, objetos: null, recente: true },
    ])
    await n.chamar(def('sessao.sair'), { dados: {} })
  })

  it('CA-09: o registro só tem as colunas de RF-24 e nenhum texto do teste', () => {
    const colunas = sql<{ coluna: string; tipo: string }>(
      `select column_name as coluna, data_type as tipo from information_schema.columns
        where table_schema = 'app' and table_name = 'registro' order by ordinal_position`,
    )
    // `colunas`: só nomes de colunas mudadas, nunca valores (RF-25; ADR 0019); `id`: ordem.
    expect(colunas.map((c) => c.coluna)).toEqual([
      'id', 'quando', 'evento', 'resultado', 'usuario_id', 'org_id', 'objetos', 'pedido_id', 'colunas',
    ])
    expect(colunas.find((c) => c.coluna === 'quando')?.tipo).toBe('timestamp with time zone')

    const textos = [emailDeDois, emailDeUm, SENHA, SENHA_ERRADA, nomes.a, nomes.b, nomes.fora, emailDeDois.split('@')[0]!]
    // Controle: a mesma busca acha o que está lá (o nome do evento e o id da pessoa), para o zero abaixo valer.
    expect(achados('app.registro', ['SESSAO.ENTRAR', deDois]).every((n) => n > 0)).toBe(true)
    for (const tabela of ['app.registro', 'app.sessoes', 'app.tentativas_entrada'] as const) {
      expect(achados(tabela, textos), tabela).toEqual(textos.map(() => 0))
    }
  })

  it('CA-09a: o contador de tentativas fica fora do registro e a linha vencida é apagada', async () => {
    const n = new Navegador()
    expect((await n.chamar(def('sessao.entrar'), { dados: { email: emailDeUm, senha: SENHA } })).resultado.ok).toBe(true)
    await n.chamar(def('sessao.sair'), { dados: {} })

    // A chave do contador é o HMAC do servidor; a mesma conta e o mesmo IP têm linha no contador…
    const { chaveIp, chaveConta } = await chavesDaTentativa(ambiente!.segredoTentativas, n.ip, emailDeUm)
    expect(contador('conta', chaveConta)).toBe(1)
    expect(contador('ip', chaveIp)).toBe(1)
    // …e nada dela, nem do IP, aparece no registro.
    expect(achados('app.registro', [hex(chaveConta), hex(chaveIp), n.ip])).toEqual([0, 0, 0])
    expect(
      sql<{ n: number }>(
        `select count(*)::int as n from information_schema.columns
          where table_schema = 'app' and table_name = 'registro' and data_type = 'bytea'`,
      )[0]!.n,
    ).toBe(0)

    // Vencida (15 min): a próxima conferência, de outra pessoa e outro IP, apaga a linha.
    sql(
      `update app.tentativas_entrada set janela_inicio = now() - interval '15 minutes 1 second'` +
        ` where chave in (decode(${literal(hex(chaveConta))}, 'hex'), decode(${literal(hex(chaveIp))}, 'hex'))`,
    )
    await new Navegador().chamar(def('sessao.entrar'), { dados: { email: emailFicticio('ninguem'), senha: SENHA_ERRADA } })
    expect(contador('conta', chaveConta)).toBe(0)
    expect(contador('ip', chaveIp)).toBe(0)
  })
})
