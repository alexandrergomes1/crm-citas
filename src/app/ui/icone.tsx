// Único arquivo que importa lucide-react (plan.md §5; ADR 0004 · D3; lint em eslint.config.mjs).
// Só os ícones nomeados no DESIGN.md §5 e §8b, mais os de função da E25·2.
import {
  ArrowUpDown,
  Banknote,
  Bell,
  Briefcase,
  Brush,
  Calendar,
  CalendarDays,
  CalendarPlus,
  ChartColumn,
  ChevronDown,
  ChevronLeft,
  ChevronRight,
  ChevronUp,
  CircleAlert,
  CircleCheck,
  CircleQuestionMark,
  CircleX,
  ClipboardList,
  Clock,
  Crown,
  DoorOpen,
  EllipsisVertical,
  Eye,
  EyeOff,
  Funnel,
  Heart,
  Hourglass,
  Lock,
  Megaphone,
  MessageCircle,
  PanelLeft,
  Play,
  Plus,
  Repeat,
  Search,
  Settings,
  ShieldAlert,
  Tag,
  ThumbsUp,
  User,
  UserPlus,
  UserX,
  Users,
  Warehouse,
  X,
  type LucideIcon,
} from 'lucide-react'

/** Ícones do DESIGN.md (§5 status, situação, etiquetas, senha, Sua conta; §8b menu principal e Agendar). */
const nomeados = {
  clock: Clock,
  'thumbs-up': ThumbsUp,
  'door-open': DoorOpen,
  play: Play,
  'circle-check': CircleCheck,
  'user-x': UserX,
  'circle-x': CircleX,
  lock: Lock,
  hourglass: Hourglass,
  'shield-alert': ShieldAlert,
  'user-plus': UserPlus,
  crown: Crown,
  repeat: Repeat,
  brush: Brush,
  'circle-alert': CircleAlert,
  calendar: Calendar,
  users: Users,
  tag: Tag,
  warehouse: Warehouse,
  banknote: Banknote,
  'chart-column': ChartColumn,
  'clipboard-list': ClipboardList,
  'message-circle': MessageCircle,
  megaphone: Megaphone,
  heart: Heart,
  briefcase: Briefcase,
  settings: Settings,
  'calendar-plus': CalendarPlus,
  // Senha: Mostrar e Esconder (DESIGN.md §5; ficha E41·2·A)
  eye: Eye,
  'eye-off': EyeOff,
  // Sua conta sem e-mail: na bolinha, no lugar da inicial (DESIGN.md §5 e §8b; E47·2·A)
  user: User,
} satisfies Record<string, LucideIcon>

/**
 * Ícones de função (✕, ‹, ›, ▾, ▴, ⋮, +, funil, sininho, ajuda, painel, lupa, calendário, Ordenar).
 * PONTO A MUDAR (E25·2, em aberto): nomes do canvas aprovado, pela recomendação A.
 */
const funcao = {
  x: X,
  'chevron-left': ChevronLeft,
  'chevron-right': ChevronRight,
  'chevron-down': ChevronDown,
  'chevron-up': ChevronUp,
  'ellipsis-vertical': EllipsisVertical,
  plus: Plus,
  funnel: Funnel,
  bell: Bell,
  'circle-question-mark': CircleQuestionMark,
  'panel-left': PanelLeft,
  search: Search,
  'calendar-days': CalendarDays,
  'arrow-up-down': ArrowUpDown,
} satisfies Record<string, LucideIcon>

const icones = { ...nomeados, ...funcao }

export type NomeIcone = keyof typeof icones
export type TamanhoIcone = '14' | '16' | '18' | '20' | '24'

export const nomesIcones = Object.keys(icones) as NomeIcone[]

export interface IconeProps {
  nome: NomeIcone
  tamanho?: TamanhoIcone
  className?: string
}

/** Ícone sempre decorativo: o nome acessível fica no botão ou no texto ao lado. */
export function Icone({ nome, tamanho = '20', className }: Readonly<IconeProps>) {
  const Componente = icones[nome]
  const classes = ['ds-ic', tamanho === '20' ? '' : `ds-ic--${tamanho}`, className ?? '']
    .filter(Boolean)
    .join(' ')
  return <Componente className={classes} aria-hidden="true" focusable="false" />
}
