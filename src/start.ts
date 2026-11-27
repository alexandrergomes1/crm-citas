import { createStart } from '@tanstack/react-start';

/**
 * SSR desligado por padrão: o servidor manda só o casco HTML; telas e dados carregam no navegador (ARCHITECTURE.md).
 * Os middlewares de pedido (src/server/) entram com a spec que os trouxer.
 */
export const startInstance = createStart(() => ({
  defaultSsr: false,
}));
