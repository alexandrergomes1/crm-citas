import { describe, expect, it } from 'vitest'
import { renderToString } from 'react-dom/server'
import { Inicio } from './inicio'

describe('Inicio', () => {
  it('mostra o texto crm-citas', () => {
    expect(renderToString(<Inicio />)).toContain('crm-citas')
  })
})
