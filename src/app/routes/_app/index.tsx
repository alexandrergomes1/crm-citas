import { createFileRoute } from '@tanstack/react-router'
import { Inicio } from '@/app/paginas/inicio'

export const Route = createFileRoute('/_app/')({
  component: Inicio,
})
