import { describe, expect, it } from 'vitest'
import { somar } from './exemplo'

describe('somar (exemplo da fundação)', () => {
  it('soma dois números', () => {
    expect(somar(2, 3)).toBe(5)
  })
})
