import { createFileRoute, notFound } from '@tanstack/react-router'
import { Vitrine } from '@/app/paginas/vitrine'

// Vitrine do design system (spec RV-1 a RV-3; plan.md §6.2; ADR 0004 · D8).
// PONTO A MUDAR (E25·1, em aberto; segue a recomendação A): só em desenvolvimento e na prévia
// (VITE_VITRINE=ligada no build dela); em produção responde "não encontrado". Com E25·1·B, sai o beforeLoad.
export const Route = createFileRoute('/vitrine')({
  beforeLoad: () => {
    if (!import.meta.env.DEV && import.meta.env.VITE_VITRINE !== 'ligada') {
      throw notFound()
    }
  },
  head: () => ({
    meta: [{ name: 'robots', content: 'noindex' }, { title: 'Vitrine · crm-citas' }],
  }),
  component: Vitrine,
})
