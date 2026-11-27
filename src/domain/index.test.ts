import { describe, expect, it } from 'vitest';
import { APP_NAME } from './index';

describe('domínio', () => {
  it('expõe o nome do app', () => {
    expect(APP_NAME).toBe('crm-citas');
  });
});
