// Chaves do limite de tentativas (ADR 0018 · D8): HMAC-SHA-256 (WebCrypto, Node e Workers) do IP e do e-mail
// normalizado, com o segredo do servidor. O banco nunca vê IP nem e-mail (RGPD art. 5(1)(c)); sem o segredo, não
// dá para achar o IP por tentativa e erro. Saída em hexadecimal no formato bytea do Postgres (`\x...`).

const codificador = new TextEncoder()

async function hmac(segredo: string, mensagem: string): Promise<string> {
  const chave = await crypto.subtle.importKey('raw', codificador.encode(segredo), { name: 'HMAC', hash: 'SHA-256' }, false, [
    'sign',
  ])
  const assinatura = new Uint8Array(await crypto.subtle.sign('HMAC', chave, codificador.encode(mensagem)))
  return `\\x${Array.from(assinatura, (byte) => byte.toString(16).padStart(2, '0')).join('')}`
}

/** E-mail como o Auth compara: sem espaço nas pontas e em minúsculas. */
export const normalizarEmail = (email: string): string => email.trim().toLowerCase()

export type ChavesDaTentativa = { readonly chaveIp: string; readonly chaveConta: string }

/**
 * Prefixos diferentes para IP e conta: a mesma cadeia nunca dá a mesma chave nos dois papéis.
 * Sem IP conhecido, todos caem numa chave só ("sem-ip"), que o limite por IP (30 em 15 min) segura.
 */
export async function chavesDaTentativa(segredo: string, ip: string | null, email: string): Promise<ChavesDaTentativa> {
  const [chaveIp, chaveConta] = await Promise.all([
    hmac(segredo, `ip:${ip ?? 'sem-ip'}`),
    hmac(segredo, `conta:${normalizarEmail(email)}`),
  ])
  return { chaveIp, chaveConta }
}
