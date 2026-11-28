// Normalização do IP para o limite de tentativas (ASVS V2.2.1): IPv4 inteiro, IPv6 pelo prefixo /64.
import { describe, expect, it } from 'vitest'
import { chavesDaTentativa, normalizarIp } from './tentativas'

const SEGREDO = 'segredo-ficticio-de-teste-com-32-caracteres'
const EMAIL = 'pessoa@exemplo.test'

describe('normalizarIp', () => {
  it('IPv4 fica o próprio endereço', () => {
    expect(normalizarIp('203.0.113.7')).toBe('203.0.113.7')
    expect(normalizarIp(' 198.51.100.1 ')).toBe('198.51.100.1')
  })

  it('IPv4 mapeado em IPv6 vira o IPv4', () => {
    expect(normalizarIp('::ffff:203.0.113.7')).toBe('203.0.113.7')
    expect(normalizarIp('::FFFF:cb00:7107')).toBe('203.0.113.7')
    expect(normalizarIp('0:0:0:0:0:ffff:203.0.113.7')).toBe('203.0.113.7')
  })

  it('IPv6 completo vira o /64', () => {
    expect(normalizarIp('2001:0db8:0001:0002:0003:0004:0005:0006')).toBe('ip6:2001:db8:1:2::/64')
  })

  it('IPv6 comprimido e em maiúsculas vira o /64', () => {
    expect(normalizarIp('2001:DB8:1:2::1')).toBe('ip6:2001:db8:1:2::/64')
    expect(normalizarIp('2001:db8::1')).toBe('ip6:2001:db8:0:0::/64')
    expect(normalizarIp('::1')).toBe('ip6:0:0:0:0::/64')
    expect(normalizarIp('::')).toBe('ip6:0:0:0:0::/64')
  })

  it('zona é ignorada', () => {
    expect(normalizarIp('fe80::1%eth0')).toBe('ip6:fe80:0:0:0::/64')
    expect(normalizarIp('2001:db8:1:2::9%25')).toBe('ip6:2001:db8:1:2::/64')
  })

  it('texto que não é IP cai em sem-ip', () => {
    for (const lixo of [
      null,
      '',
      'lixo',
      '256.1.1.1',
      '1.2.3',
      '01.2.3.4',
      '1.2.3.4.5',
      '2001:db8::1::2',
      '2001:db8:1:2:3:4:5:6:7',
      '2001:db8:1:2:3:4:5',
      '12345::1',
      'g::1',
      '::ffff:999.1.1.1',
      '1:2:3:4:5:6:7::8',
    ]) {
      expect(normalizarIp(lixo)).toBe('sem-ip')
    }
  })
})

describe('chave do IP', () => {
  it('dois endereços do mesmo /64 dão a mesma chave', async () => {
    const a = await chavesDaTentativa(SEGREDO, '2001:db8:1:2::1', EMAIL)
    const b = await chavesDaTentativa(SEGREDO, '2001:db8:1:2:ffff:eeee:dddd:cccc', EMAIL)
    expect(a.chaveIp).toBe(b.chaveIp)
  })

  it('/64 diferentes dão chaves diferentes', async () => {
    const a = await chavesDaTentativa(SEGREDO, '2001:db8:1:2::1', EMAIL)
    const b = await chavesDaTentativa(SEGREDO, '2001:db8:1:3::1', EMAIL)
    expect(a.chaveIp).not.toBe(b.chaveIp)
  })

  it('IPv4 mapeado e IPv4 dão a mesma chave; lixo e sem IP também', async () => {
    const v4 = await chavesDaTentativa(SEGREDO, '203.0.113.7', EMAIL)
    const mapeado = await chavesDaTentativa(SEGREDO, '::ffff:203.0.113.7', EMAIL)
    expect(mapeado.chaveIp).toBe(v4.chaveIp)
    const lixo = await chavesDaTentativa(SEGREDO, 'lixo', EMAIL)
    const semIp = await chavesDaTentativa(SEGREDO, null, EMAIL)
    expect(lixo.chaveIp).toBe(semIp.chaveIp)
  })
})
