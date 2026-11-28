// CA-20 (spec): pt, es e en com as mesmas chaves, nada vazio e os mesmos marcadores (ADR 0006 · D1).
import { describe, expect, it } from 'vitest'
import { IDIOMAS } from '@/domain/idioma'
import { contar, marcadoresDe, preencher } from './formatar'
import { TEXTOS, textosDe } from './textos'

type Folhas = Map<string, string>

/** Todas as folhas de texto, por caminho ("entrar.titulo"). */
function folhas(valor: unknown, caminho = '', saida: Folhas = new Map()): Folhas {
  if (typeof valor === 'string') {
    saida.set(caminho, valor)
    return saida
  }
  if (valor && typeof valor === 'object') {
    for (const [chave, filho] of Object.entries(valor)) folhas(filho, caminho ? `${caminho}.${chave}` : chave, saida)
    return saida
  }
  saida.set(caminho, `<<não é texto: ${typeof valor}>>`)
  return saida
}

const base = folhas(TEXTOS.pt)

describe('CA-20 · arquivos de idioma', () => {
  it('os três idiomas existem', () => {
    expect(Object.keys(TEXTOS).sort()).toEqual([...IDIOMAS].sort())
  })

  it('tem os blocos da base comum (ADR 0018 · D15)', () => {
    expect(Object.keys(TEXTOS.pt)).toEqual(['comum', 'erros', 'entrar', 'escolherEstudio', 'suaConta'])
  })

  it.each(IDIOMAS)('%s tem exatamente as chaves do pt', (idioma) => {
    expect([...folhas(TEXTOS[idioma]).keys()].sort()).toEqual([...base.keys()].sort())
  })

  it.each(IDIOMAS)('%s não tem texto vazio nem só espaço', (idioma) => {
    for (const [caminho, texto] of folhas(TEXTOS[idioma])) expect(texto.trim(), `${idioma}: ${caminho}`).not.toBe('')
  })

  it.each(IDIOMAS)('%s usa os mesmos marcadores do pt', (idioma) => {
    const textos = folhas(TEXTOS[idioma])
    for (const [caminho, texto] of base) {
      expect(marcadoresDe(textos.get(caminho) ?? '').sort(), `${idioma}: ${caminho}`).toEqual(marcadoresDe(texto).sort())
    }
  })

  it('há uma frase para cada código de erro da camada de serviço', async () => {
    const { CODIGOS_DE_ERRO } = await import('@/server/portas/erros')
    expect(Object.keys(TEXTOS.pt.erros).sort()).toEqual([...CODIGOS_DE_ERRO].sort())
  })

  it('os nomes aprovados no DESIGN.md §6 (E41·1·A) estão no pt como estão', () => {
    const t = textosDe('pt')
    expect(t.entrar).toMatchObject({
      titulo: 'Entrar',
      email: 'E-mail',
      senha: 'Senha',
      entrar: 'Entrar',
      entrando: 'Entrando…',
      mostrarSenha: 'Mostrar senha',
      esconderSenha: 'Esconder senha',
      erro: 'Não foi possível entrar. Confira o e-mail e a senha e tente de novo.',
    })
    expect(t.escolherEstudio.titulo).toBe('Escolher empresa')
    expect(t.escolherEstudio.carregando).toBe('Carregando empresas')
    expect(t.escolherEstudio.erroTitulo).toBe('Não foi possível carregar')
    expect(t.suaConta).toEqual({
      nome: 'Sua conta',
      minhaConta: 'Minha conta',
      preferencias: 'Preferências',
      meuFaturamento: 'Meu faturamento',
      trocarDeEstudio: 'Trocar de empresa',
      sair: 'Sair',
    })
  })
})

describe('formatar', () => {
  it('troca os marcadores e deixa o que não tem valor', () => {
    expect(preencher('{n} de {m}', { n: 1 })).toBe('1 de {m}')
  })

  it.each([
    ['pt', 1, '1 empresa'],
    ['pt', 2, '2 empresas'],
    ['es', 1, '1 empresa'],
    ['es', 2, '2 empresas'],
    ['en', 1, '1 business'],
    ['en', 2, '2 businesses'],
  ] as const)('contar em %s: %d → %s', (idioma, n, esperado) => {
    expect(contar(idioma, textosDe(idioma).escolherEstudio.quantos, n)).toBe(esperado)
  })

  it('categoria sem forma própria usa "other" (ex.: "many" do es em milhão)', () => {
    expect(contar('es', { other: '{n} x' }, 1_000_000)).toBe(`${new Intl.NumberFormat('es').format(1_000_000)} x`)
  })
})
