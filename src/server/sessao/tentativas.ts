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

const SEM_IP = 'sem-ip'

/** IPv4 em decimal com pontos, 4 partes de 0 a 255, sem zero à esquerda (evita leitura octal ambígua). */
function partesIpv4(texto: string): number[] | null {
  const partes = texto.split('.')
  if (partes.length !== 4) return null
  const numeros: number[] = []
  for (const parte of partes) {
    if (!/^(0|[1-9][0-9]{0,2})$/.test(parte)) return null
    const numero = Number(parte)
    if (numero > 255) return null
    numeros.push(numero)
  }
  return numeros
}

/** IPv6 (RFC 4291 §2.2) nos 8 grupos de 16 bits; aceita `::`, IPv4 no fim e zona (`%eth0`, ignorada). */
function gruposIpv6(texto: string): number[] | null {
  const semZona = texto.split('%')[0] ?? ''
  if (!semZona.includes(':')) return null
  const metades = semZona.split('::')
  if (metades.length > 2) return null
  const lerMetade = (metade: string, ultima: boolean): number[] | null => {
    if (metade === '') return []
    const pedacos = metade.split(':')
    const grupos: number[] = []
    for (const [indice, pedaco] of pedacos.entries()) {
      if (ultima && indice === pedacos.length - 1 && pedaco.includes('.')) {
        const v4 = partesIpv4(pedaco)
        if (!v4) return null
        grupos.push(((v4[0] ?? 0) << 8) | (v4[1] ?? 0), ((v4[2] ?? 0) << 8) | (v4[3] ?? 0))
        continue
      }
      if (!/^[0-9a-f]{1,4}$/.test(pedaco)) return null
      grupos.push(Number.parseInt(pedaco, 16))
    }
    return grupos
  }
  if (metades.length === 1) {
    const grupos = lerMetade(semZona, true)
    return grupos && grupos.length === 8 ? grupos : null
  }
  const inicio = lerMetade(metades[0] ?? '', false)
  const fim = lerMetade(metades[1] ?? '', true)
  if (!inicio || !fim || inicio.length + fim.length > 7) return null
  return [...inicio, ...Array<number>(8 - inicio.length - fim.length).fill(0), ...fim]
}

/**
 * IP para o limite (ASVS V2.2.1): IPv4, inclusive mapeado em IPv6 (`::ffff:a.b.c.d`), fica o próprio IPv4;
 * IPv6 vira o prefixo /64 (`ip6:2001:db8:1:2::/64`), porque um atacante tem o bloco /64 inteiro; o resto, `sem-ip`.
 */
export function normalizarIp(ip: string | null): string {
  if (ip === null) return SEM_IP
  const texto = ip.trim().toLowerCase()
  const v4 = partesIpv4(texto)
  if (v4) return v4.join('.')
  const grupos = gruposIpv6(texto)
  if (!grupos) return SEM_IP
  const mapeado = grupos.slice(0, 5).every((grupo) => grupo === 0) && grupos[5] === 0xffff
  if (mapeado) {
    const [alto = 0, baixo = 0] = grupos.slice(6)
    return [alto >> 8, alto & 0xff, baixo >> 8, baixo & 0xff].join('.')
  }
  return `ip6:${grupos
    .slice(0, 4)
    .map((grupo) => grupo.toString(16))
    .join(':')}::/64`
}

export type ChavesDaTentativa = { readonly chaveIp: string; readonly chaveConta: string }

/**
 * Prefixos diferentes para IP e conta: a mesma cadeia nunca dá a mesma chave nos dois papéis.
 * O IP passa por `normalizarIp` antes. Sem IP conhecido ou válido, todos caem numa chave só ("sem-ip"), que o limite por IP (30 em 15 min) segura.
 */
export async function chavesDaTentativa(segredo: string, ip: string | null, email: string): Promise<ChavesDaTentativa> {
  const [chaveIp, chaveConta] = await Promise.all([
    hmac(segredo, `ip:${normalizarIp(ip)}`),
    hmac(segredo, `conta:${normalizarEmail(email)}`),
  ])
  return { chaveIp, chaveConta }
}
