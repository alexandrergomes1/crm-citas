// Ações de sessão da lista fechada (plan.md §3.1 a §3.4; catalogo.ts · MODOS_SEM_ESTUDIO).
// Erros só por código; "sem_login" é a frase única de entrar (e-mail errado, senha errada, sem conta, sem estúdio; RF-02).
import { z } from 'zod'
import { codigoDe } from '@/data/erros'
import type { Idioma } from '@/domain/idioma'
import { acao, acaoGet, acaoPost } from '../portas/acao'
import { Recusa } from '../portas/erros'
import type { ContextoOpcional, ContextoSemSessao } from '../portas/tipos'
import { chavesDaTentativa } from './tentativas'

/** Para onde a tela vai depois de entrar (RF-11). */
export type DestinoDepoisDeEntrar = 'inicio' | 'escolher_estudio'

// Senha sem cortar nem alterar, até 128 caracteres (RF-32, CA-18a; ASVS V2.1.2); e-mail até 254 (RFC 5321).
export const entradaDeEntrar = z.strictObject({
  email: z.string().min(1).max(254),
  senha: z.string().min(1).max(128),
})

/** Fluxo de entrar (plan.md §3.1), sem framework, para o teste de unidade. */
export async function trabalhoDeEntrar(
  ctx: ContextoSemSessao,
  { email, senha }: z.output<typeof entradaDeEntrar>,
): Promise<{ destino: DestinoDepoisDeEntrar }> {
  const { conexao } = ctx

  // RF-05: a sessão anterior deste navegador é encerrada antes de nascer outra.
  if (ctx.temCookieDeSessao) {
    if (await conexao.quemE()) {
      try {
        await conexao.encerrarSessao()
      } catch {
        // segue: signOut local e cookie apagado de qualquer jeito (ADR 0018 · D4)
      }
    }
    await conexao.sairLocal()
  }

  // Limite (D8): chaves HMAC; o banco nunca vê IP nem e-mail.
  const { chaveIp, chaveConta } = await chavesDaTentativa(ctx.segredoTentativas, ctx.ip, email)
  let pode: boolean
  try {
    pode = await conexao.conferirTentativa(chaveIp, chaveConta)
  } catch (erro) {
    throw new Recusa(codigoDe(erro) === 'limite' ? 'limite' : 'erro_interno')
  }
  if (!pode) throw new Recusa('limite')

  const senhaConferida = await conexao.entrarComSenha(email, senha)
  if (!senhaConferida.ok) {
    if (senhaConferida.codigo === 'sem_login') {
      await conexao.registrarTentativaFalha()
      throw new Recusa('sem_login')
    }
    throw new Recusa(senhaConferida.codigo === 'limite' ? 'limite' : 'erro_interno')
  }

  // Linha da sessão (D4): recusa session_id já visto e entrada por senha antiga; conta os estúdios ativos.
  let estudios: number
  try {
    estudios = await conexao.iniciarSessao()
  } catch (erro) {
    await conexao.sairLocal()
    if (codigoDe(erro) === 'sem_login') {
      // session_id já visto ou entrada por senha antiga: conta como falha de entrar (RF-24a, CA-09a).
      await conexao.registrarTentativaFalha()
      throw new Recusa('sem_login')
    }
    throw new Recusa('erro_interno')
  }

  // Sem estúdio ativo: mesma resposta de senha errada, sessão encerrada (RF-11).
  if (estudios === 0) {
    await conexao.sairLocal()
    await conexao.registrarTentativaFalha()
    throw new Recusa('sem_login')
  }

  if (estudios === 1) {
    const [unico, ...outros] = await conexao.meusEstudios()
    if (unico && outros.length === 0) {
      await escolherAoEntrar(ctx, unico.orgId)
      return { destino: 'inicio' }
    }
    return { destino: 'escolher_estudio' }
  }

  // Mais de um: já escolhido e ativo segue nele, com a escolha registrada nesta sessão (ASVS V7.1.3);
  // senão, Escolher estúdio.
  const sessao = await conexao.contexto()
  if (!sessao.orgId) return { destino: 'escolher_estudio' }
  await escolherAoEntrar(ctx, sessao.orgId)
  return { destino: 'inicio' }
}

/**
 * Escolhe o estúdio ao entrar pela mesma função de `estudio.escolher` (grava o registro no banco).
 * Falhou: encerra a sessão em melhor esforço e faz signOut local antes do erro (ASVS V3.3.1).
 */
async function escolherAoEntrar({ conexao }: ContextoSemSessao, orgId: string): Promise<void> {
  try {
    await conexao.escolherEstudio(orgId)
  } catch {
    try {
      await conexao.encerrarSessao()
    } catch {
      // segue para o signOut (ADR 0018 · D4)
    }
    await conexao.sairLocal()
    throw new Recusa('erro_interno')
  }
}

export const entrar = acaoPost.handler(
  acao({
    nome: 'sessao.entrar',
    metodo: 'POST',
    sessao: 'nenhuma',
    permissao: 'qualquer',
    entrada: entradaDeEntrar,
    grava: true,
    trabalho: trabalhoDeEntrar,
  }),
)

/**
 * O que a tela sabe da sessão. Único traço pessoal: a inicial do e-mail para a bolinha Sua conta (DESIGN.md §8b),
 * nunca o e-mail inteiro (AGENTS.md §6). `null` sem sessão ou quando o token não traz e-mail.
 */
export type SessaoLida = {
  readonly comSessao: boolean
  readonly comEstudio: boolean
  readonly idioma: Idioma
  readonly inicial: string | null
}

/** Trabalho de `sessao.ler`, sem framework, para o teste de unidade. */
export async function trabalhoDeLerSessao(ctx: ContextoOpcional): Promise<SessaoLida> {
  // A inicial vem da leitura do token da porta 1, entregue no contexto (o token não é lido de novo; nada se guarda).
  return {
    comSessao: ctx.sessao !== null,
    comEstudio: ctx.sessao?.orgId != null,
    idioma: ctx.sessao?.idioma ?? ctx.idiomaDoNavegador,
    inicial: ctx.sessao === null ? null : ctx.inicial,
  }
}

export const lerSessao = acaoGet.handler(
  acao({
    nome: 'sessao.ler',
    metodo: 'GET',
    sessao: 'opcional',
    permissao: 'qualquer',
    entrada: z.strictObject({}),
    grava: false,
    trabalho: trabalhoDeLerSessao,
  }),
)

export const sair = acaoPost.handler(
  acao({
    nome: 'sessao.sair',
    metodo: 'POST',
    sessao: 'pessoa',
    permissao: 'qualquer',
    entrada: z.strictObject({}),
    grava: true,
    // Marca a sessão como encerrada (sem apagar) e chama signOut local MESMO se a marcação falhar (D4; R-16).
    trabalho: async ({ conexao }) => {
      try {
        await conexao.encerrarSessao()
      } catch {
        // segue para o signOut
      }
      await conexao.sairLocal()
      return null
    },
  }),
)

export const listarEstudios = acaoGet.handler(
  acao({
    nome: 'estudio.listar',
    metodo: 'GET',
    sessao: 'pessoa',
    permissao: 'qualquer',
    entrada: z.strictObject({}),
    grava: false,
    // Só estúdios com papel ativo da pessoa, por nome, até 50 (RF-13).
    trabalho: async ({ conexao }) => conexao.meusEstudios(),
  }),
)

export const escolherEstudio = acaoPost.handler(
  acao({
    nome: 'estudio.escolher',
    metodo: 'POST',
    sessao: 'pessoa',
    permissao: 'qualquer',
    entrada: z.strictObject({ orgId: z.uuid() }),
    grava: true,
    // Escolher e trocar (RF-12, RF-14): sem vínculo ativo → sem_permissao, nada muda (CA-05).
    trabalho: async ({ conexao }, { orgId }) => {
      await conexao.escolherEstudio(orgId)
      return null
    },
  }),
)
