// Catálogo único das ações e lista fechada dos modos sem estúdio (ADR 0018 · D12; spec RF-16, RF-21, CA-21).
// Toda ação entra aqui ao ser declarada por acao(...); o teste "sem sessão, nada passa" percorre o catálogo (CA-04).
import type { DefinicaoQualquer, Modo, NomeDaAcao } from './tipos'

/** Únicas ações fora do modo `estudio` (plan.md §3). Nova entrada só por spec. */
export const MODOS_SEM_ESTUDIO: Readonly<Record<string, Exclude<Modo, 'estudio'>>> = {
  'sessao.entrar': 'nenhuma',
  'sessao.ler': 'opcional',
  'sessao.sair': 'pessoa',
  'estudio.listar': 'pessoa',
  'estudio.escolher': 'pessoa',
}

// Mesma regra do evento em app.registro: só [a-z_.], até 64, com ao menos um ponto (plan.md §6 M1).
const FORMA_DO_NOME = /^[a-z][a-z_]*(\.[a-z][a-z_]*)+$/
const TAMANHO_MAXIMO_DO_NOME = 64

const acoes = new Map<NomeDaAcao, DefinicaoQualquer>()

/** Motivo da recusa da definição, ou null se está no molde. */
export function conferirDefinicao(def: DefinicaoQualquer): string | null {
  if (!FORMA_DO_NOME.test(def.nome) || def.nome.length > TAMANHO_MAXIMO_DO_NOME) return 'nome fora da forma'
  if (def.metodo !== 'GET' && def.metodo !== 'POST') return 'método fora da lista'
  if (def.grava && def.metodo !== 'POST') return 'ação que grava usa POST'
  const modoFixo = MODOS_SEM_ESTUDIO[def.nome]
  if (def.sessao === 'estudio') {
    if (modoFixo) return 'ação da lista fechada fora do seu modo'
    if (def.permissao === 'qualquer') return 'modo estudio pede permissão por papel'
  } else if (modoFixo !== def.sessao) {
    return 'modo sem estúdio fora da lista fechada'
  }
  return null
}

/** Põe a ação no catálogo. Fora do molde: erro ao carregar o módulo (falha cedo, nos testes e no build). */
export function registrar(def: DefinicaoQualquer): void {
  const motivo = conferirDefinicao(def)
  if (motivo) throw new Error(`acao ${def.nome}: ${motivo}`)
  // Recarregar o módulo (HMR) troca a definição; nome repetido entre arquivos é pego por molde.test.ts.
  acoes.set(def.nome, def)
}

export function acoesDoCatalogo(): readonly DefinicaoQualquer[] {
  return [...acoes.values()]
}
