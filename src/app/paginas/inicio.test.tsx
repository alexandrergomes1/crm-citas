import { describe, expect, it } from 'vitest'
import { renderToString } from 'react-dom/server'
import { Inicio } from './inicio'

describe('Inicio (DESIGN.md §8b "Tela inicial"; E47·3·A)', () => {
  it('só a região principal, vazia: sem texto solto e sem o nome do sistema', () => {
    const html = renderToString(<Inicio />)
    expect(html).toBe('<main></main>')
    expect(html).not.toContain('crm-citas')
  })
})
