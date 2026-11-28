// As 6 portas, na ordem fixa, sem framework (plan.md §3.2; ARCHITECTURE.md §4; spec RF-16 a RF-22).
// A primeira recusa para tudo (RF-17). Recebe cookies, cabeçalhos e corpo; devolve resultado, cookies e cabeçalhos.
//   1 quem é: getClaims (token válido)            → sem_login, nada no banco (RF-28)
//   - envelope { estudioDaTela, dados }            → entrada_invalida
//   1+2 contexto da sessão no banco (pré-pedido)   → sem_login (encerra) · estudio_trocado · sem_estudio
//   3 o que pode (papel)                           → sem_permissao
//   4 dados certos (zod estrito)                   → entrada_invalida, sem trabalho (CA-08)
//   5 trabalho com ctx.banco (≤ 1 gravação)        → conflito · erro_interno
//   6 registro: gravou → gatilho no banco; recusa nas etapas 2 a 5 → registrar_recusa (melhor esforço)
import { z } from 'zod'
import { ehCookieDaSessao } from '@/data/cliente'
import { codigoDe, ErroDoBanco } from '@/data/erros'
import type { Conexao, ContextoDaSessao } from '@/data/sessao'
import { idiomaDoNavegador } from '@/domain/idioma'
import { codigoDoErro, falha, sucesso, type CodigoDeErro, type Resultado } from './erros'
import type {
  ContextoEstudio,
  ContextoOpcional,
  ContextoPessoa,
  ContextoSemSessao,
  DefinicaoDeAcao,
  Infra,
  Modo,
  Papel,
  Permissao,
  PedidoHttp,
  RespostaHttp,
} from './tipos'

/** Tempo mínimo de toda resposta de entrar (ADR 0018 · D8; RF-02). */
export const TEMPO_MINIMO_SEM_SESSAO_MS = 700

const envelopeDoEstudio = z.strictObject({ estudioDaTela: z.uuid(), dados: z.unknown() })
const envelopeSemEstudio = z.strictObject({ dados: z.unknown() }).optional()

function podeOPapel(permissao: Permissao, papel: Papel | null): boolean {
  if (permissao === 'qualquer') return true
  if (papel === null) return false
  try {
    return typeof permissao === 'function' ? permissao(papel) === true : permissao.includes(papel)
  } catch {
    return false
  }
}

// Recusa nas etapas 2 a 5 grava uma linha; sem_login nunca (não há quem; RF-28).
async function registrarRecusa(conexao: Conexao, nome: string, codigo: CodigoDeErro): Promise<void> {
  if (codigo === 'sem_login') return
  try {
    await conexao.registrarRecusa(nome, codigo)
  } catch {
    // melhor esforço: se falhar, a resposta não muda (plan.md §3.2 passo 7)
  }
}

async function recusar<S>(conexao: Conexao, nome: string, codigo: CodigoDeErro): Promise<Resultado<S>> {
  await registrarRecusa(conexao, nome, codigo)
  return falha(codigo)
}

// Porta 5. `contar`: só no modo estudio o acesso ao banco conta as gravações (≤ 1; ADR 0018 · D3). As ações de
// sessão da lista fechada fazem vários pedidos por desenho (plan.md §3.1 a §3.4) e não recebem ctx.banco.
async function trabalhar<C, E extends z.ZodType, S>(
  conexao: Conexao,
  def: { grava: boolean; trabalho: (ctx: C, dados: z.output<E>) => Promise<S> },
  ctx: C,
  dados: z.output<E>,
  contar: boolean,
): Promise<Resultado<S>> {
  if (contar) conexao.iniciarTrabalho(def.grava)
  let resultado: Resultado<S>
  try {
    resultado = sucesso(await def.trabalho(ctx, dados))
  } catch (erro) {
    resultado = falha(codigoDoErro(erro))
  } finally {
    if (contar) conexao.terminarTrabalho()
  }
  // Gravou sem poder, ou duas vezes: o pedido a mais nem saiu; a resposta é erro_interno (ADR 0018 · D3).
  return conexao.violou ? falha('erro_interno') : resultado
}

type Lido = { ok: true; contexto: ContextoDaSessao } | { ok: false; codigo: CodigoDeErro }

async function lerContexto(conexao: Conexao): Promise<Lido> {
  try {
    return { ok: true, contexto: await conexao.contexto() }
  } catch (erro) {
    const codigo = erro instanceof ErroDoBanco ? codigoDe(erro) : 'erro_interno'
    // Sessão morta, vencida (12 h) ou parada (1 h): encerra no navegador também (plan.md §3.4).
    if (codigo === 'sem_login') await conexao.sairLocal()
    return { ok: false, codigo }
  }
}

export async function executar<E extends z.ZodType, S, M extends Modo>(
  def: DefinicaoDeAcao<E, S, M>,
  pedido: PedidoHttp,
  infra: Infra,
): Promise<RespostaHttp<S>> {
  const inicio = infra.agora()
  const pedidoId = infra.novoPedidoId()
  const sem = (codigo: CodigoDeErro): RespostaHttp<S> => ({ resultado: falha(codigo), cookies: [], cabecalhos: {} })

  if (pedido.metodo.toUpperCase() !== def.metodo) return sem('erro_interno')
  const ambiente = infra.ambiente()
  if (!ambiente) return sem('erro_interno')
  const segredoTentativas = ambiente.segredoTentativas

  const comEstudio = def.sessao === 'estudio'
  const envelope = comEstudio ? envelopeDoEstudio.safeParse(pedido.corpo) : envelopeSemEstudio.safeParse(pedido.corpo)
  const lidoDoEstudio = comEstudio && envelope.success ? envelopeDoEstudio.safeParse(envelope.data) : null
  const estudioDaTela = lidoDoEstudio?.success ? lidoDoEstudio.data.estudioDaTela : undefined
  const dadosBrutos = envelope.success ? (envelope.data?.dados ?? {}) : undefined

  const conexao = infra.abrirConexao({
    ambiente,
    cookies: pedido.cookies,
    cabecalhos: { pedidoId, acao: def.nome, ...(estudioDaTela ? { estudioEsperado: estudioDaTela } : {}) },
  })
  const responder = (resultado: Resultado<S>): RespostaHttp<S> => ({ resultado, ...conexao.saida() })

  let resultado: Resultado<S>
  try {
    resultado = await portas()
  } catch {
    resultado = falha('erro_interno')
  }
  if (def.sessao === 'nenhuma') await infra.esperar(Math.max(0, inicio + TEMPO_MINIMO_SEM_SESSAO_MS - infra.agora()))
  return responder(resultado)

  async function portas(): Promise<Resultado<S>> {
    switch (def.sessao) {
      case 'estudio':
      case 'pessoa':
        return comSessao()
      case 'opcional':
        return opcional()
      default:
        return semSessao()
    }
  }

  // Modos `estudio` e `pessoa` (plan.md §3.2).
  async function comSessao(): Promise<Resultado<S>> {
    // Porta 1: assinatura e validade do token; nada no banco.
    if (!(await conexao.quemE())) return falha('sem_login')
    if (!envelope.success) return recusar(conexao, def.nome, 'entrada_invalida')

    // Portas 1 e 2 no banco: sessão viva, tempo, estúdio esperado (pré-pedido, mesma transação).
    const lido = await lerContexto(conexao)
    if (!lido.ok) return recusar(conexao, def.nome, lido.codigo)
    const sessao = lido.contexto

    if (comEstudio && (sessao.orgId === null || sessao.papel === null)) return recusar(conexao, def.nome, 'sem_estudio')
    // Porta 3.
    if (!podeOPapel(def.permissao as Permissao, sessao.papel)) {
      return recusar(conexao, def.nome, sessao.papel === null ? 'sem_estudio' : 'sem_permissao')
    }
    // Porta 4: depois das portas 1 a 3 (D13).
    const dados = def.entrada.safeParse(dadosBrutos)
    if (!dados.success) return recusar(conexao, def.nome, 'entrada_invalida')

    const idioma = sessao.idioma ?? idiomaDoNavegador(pedido.cabecalho('accept-language'))
    let resultado: Resultado<S>
    if (comEstudio) {
      if (sessao.orgId === null || sessao.papel === null || !sessao.fuso || !sessao.moeda) {
        return recusar(conexao, def.nome, 'erro_interno')
      }
      const ctx: ContextoEstudio = {
        pedidoId,
        usuarioId: sessao.usuarioId,
        orgId: sessao.orgId,
        papel: sessao.papel,
        idioma,
        fuso: sessao.fuso,
        moeda: sessao.moeda,
        banco: conexao.banco,
      }
      resultado = await trabalhar(conexao, def as DefinicaoDeAcao<E, S, 'estudio'>, ctx, dados.data, true)
    } else {
      const ctx: ContextoPessoa = {
        pedidoId,
        usuarioId: sessao.usuarioId,
        orgId: sessao.orgId,
        papel: sessao.papel,
        idioma,
        conexao,
      }
      resultado = await trabalhar(conexao, def as DefinicaoDeAcao<E, S, 'pessoa'>, ctx, dados.data, false)
    }
    // Porta 6: gravou → o gatilho já registrou na mesma transação; recusa → linha de recusa.
    if (!resultado.ok) await registrarRecusa(conexao, def.nome, resultado.codigo)
    return resultado
  }

  // `sessao.ler`: sem sessão devolve só o idioma do navegador.
  async function opcional(): Promise<Resultado<S>> {
    let sessao: ContextoDaSessao | null = null
    if (await conexao.quemE()) {
      const lido = await lerContexto(conexao)
      if (lido.ok) sessao = lido.contexto
      else if (lido.codigo !== 'sem_login') return falha(lido.codigo)
    }
    if (!envelope.success) return falha('entrada_invalida')
    const dados = def.entrada.safeParse(dadosBrutos)
    if (!dados.success) return falha('entrada_invalida')
    const ctx: ContextoOpcional = {
      pedidoId,
      idiomaDoNavegador: idiomaDoNavegador(pedido.cabecalho('accept-language')),
      sessao,
      conexao,
    }
    return trabalhar(conexao, def as DefinicaoDeAcao<E, S, 'opcional'>, ctx, dados.data, false)
  }

  // `sessao.entrar`: sem sessão; o trabalho registra a própria falha (RF-24a).
  async function semSessao(): Promise<Resultado<S>> {
    if (!envelope.success) return falha('entrada_invalida')
    const dados = def.entrada.safeParse(dadosBrutos)
    if (!dados.success) return falha('entrada_invalida')
    const ctx: ContextoSemSessao = {
      pedidoId,
      temCookieDeSessao: pedido.cookies.some(({ nome }) => ehCookieDaSessao(nome)),
      ip: pedido.ip,
      segredoTentativas,
      conexao,
    }
    return trabalhar(conexao, def as DefinicaoDeAcao<E, S, 'nenhuma'>, ctx, dados.data, false)
  }
}
