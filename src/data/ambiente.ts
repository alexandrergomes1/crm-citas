// Variáveis do servidor, lidas e conferidas a cada pedido (Twelve-Factor III; ADR 0018 · D9 e D16;
// guia de variáveis do TanStack Start: no Workers só existem durante o pedido). Sem prefixo VITE_: nada disto
// vai ao navegador (RF-04). Faltou ou veio errado → null, e quem chama responde erro_interno (falha fechada).
// Nunca há chave secreta ou de serviço aqui (RF-20, CA-17).

export type Ambiente = {
  readonly supabaseUrl: string
  readonly chavePublica: string
  readonly segredoTentativas: string
  readonly chaveServidor: string
}

type Fonte = Readonly<Record<string, string | undefined>>

// Segredos com pelo menos 32 caracteres (ASVS V2.9.2 e V6.2.5: chave forte, gerada a cada execução no local).
const TAMANHO_MINIMO_SEGREDO = 32

export function lerAmbiente(fonte: Fonte = process.env): Ambiente | null {
  const supabaseUrl = fonte.SUPABASE_URL?.trim()
  const chavePublica = fonte.SUPABASE_PUBLISHABLE_KEY?.trim()
  const segredoTentativas = fonte.SEGREDO_TENTATIVAS
  const chaveServidor = fonte.CHAVE_SERVIDOR_BANCO

  if (!supabaseUrl || !chavePublica || !segredoTentativas || !chaveServidor) return null
  if (segredoTentativas.length < TAMANHO_MINIMO_SEGREDO || chaveServidor.length < TAMANHO_MINIMO_SEGREDO) return null

  let url: URL
  try {
    url = new URL(supabaseUrl)
  } catch {
    return null
  }
  // HTTPS fora da máquina local; http só para o banco local (127.0.0.1 ou localhost).
  const local = url.hostname === '127.0.0.1' || url.hostname === 'localhost'
  if (url.protocol !== 'https:' && !(url.protocol === 'http:' && local)) return null

  return { supabaseUrl: url.origin, chavePublica, segredoTentativas, chaveServidor }
}
