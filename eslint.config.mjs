// Lint do projeto: base recomendada + regra de camadas (ARCHITECTURE.md §3; plan.md §4; ADR 0002 · D3).
import { defineConfig, globalIgnores } from 'eslint/config'
import eslint from '@eslint/js'
import tseslint from 'typescript-eslint'
import globals from 'globals'

// Entre camadas, importar sempre por "@/" (plan.md §10, R-8).
const camada = (nomes) => `^(@/|(\\.\\./)+)(${nomes})(/|$)`

// Uma lista de proibições vale para os dois jeitos de importar:
// - estático (import/export ... from): regra nativa no-restricted-imports;
// - dinâmico (import('...') com texto fixo): no-restricted-syntax sobre ImportExpression.
// O seletor (esquery) não aceita "/" dentro da regex; vira \x2F, que a RegExp lê como "/".
// Proibição com `importNames` vale só para o import estático (o import() dinâmico não diz o nome).
const proibir = (proibicoes, sintaxe = []) => ({
  'no-restricted-imports': ['error', { patterns: proibicoes }],
  'no-restricted-syntax': [
    'error',
    ...proibicoes
      .filter(({ importNames }) => !importNames)
      .map(({ regex, message }) => ({
        selector: `ImportExpression[source.value=/${regex.replaceAll('/', '\\x2F')}/i]`,
        message,
      })),
    ...sintaxe,
  ],
})

// Regras de todo o projeto (plan.md §8; ADR 0018 · D9, D12).
const SO_NO_MOLDE = {
  regex: '^@tanstack/(react-start|start-client-core)$',
  importNames: ['createServerFn'],
  message: 'createServerFn só em src/server/portas/acao.ts: declare a ação com acao(...) (ADR 0018 · D12).',
}
const SEM_CLIENTE_NO_NAVEGADOR = {
  regex: '^@supabase/ssr$',
  importNames: ['createBrowserClient'],
  message: 'createBrowserClient nunca: o navegador não fala com o banco (ADR 0018 · D9; RF-04).',
}
const SEM_GET_SESSION = {
  selector: "MemberExpression[property.name='getSession']",
  message: 'getSession() nunca no servidor: use getClaims() (guia SSR do Supabase; ADR 0018 · D4).',
}
const comuns = [SO_NO_MOLDE, SEM_CLIENTE_NO_NAVEGADOR]

const SEM_SUPABASE = (pasta) => ({
  regex: '^@supabase/',
  message: `${pasta} não importa o cliente do banco; use src/data (ARCHITECTURE.md §3).`,
})

export default defineConfig(
  globalIgnores([
    'node_modules/',
    'dist/',
    '.output/',
    '.tanstack/',
    'test-results/',
    'playwright-report/',
    'blob-report/',
    'coverage/',
    'src/app/routeTree.gen.ts',
  ]),
  eslint.configs.recommended,
  tseslint.configs.recommended,
  {
    languageOptions: {
      globals: { ...globals.browser, ...globals.node },
    },
  },
  // Cada bloco abaixo repete as regras comuns: um bloco posterior substitui a opção do anterior para os mesmos
  // arquivos. Do mais geral ao mais específico.
  {
    // Todo o projeto (testes, e2e, scripts e configuração inclusive).
    files: ['**/*.{js,mjs,ts,tsx}'],
    rules: proibir(comuns, [SEM_GET_SESSION]),
  },
  {
    // src/domain: TypeScript puro; não importa tela, servidor, dados nem framework.
    files: ['src/domain/**'],
    rules: proibir(
      [
        ...comuns,
        {
          regex: camada('app|server|data'),
          message: 'src/domain não importa src/app, src/server nem src/data (ARCHITECTURE.md §3).',
        },
        {
          regex: '^(react|react-dom|vite)(/|$)',
          message: 'src/domain não importa framework (ARCHITECTURE.md §3).',
        },
        {
          regex: '^@(tanstack|supabase)/',
          message: 'src/domain não importa framework nem o cliente do banco (ARCHITECTURE.md §3).',
        },
      ],
      [SEM_GET_SESSION],
    ),
  },
  {
    // src/data: o único lugar que fala com o banco; não importa tela nem servidor.
    files: ['src/data/**'],
    rules: proibir(
      [
        ...comuns,
        {
          regex: camada('app|server'),
          message: 'src/data não importa src/app nem src/server (ARCHITECTURE.md §3).',
        },
      ],
      [SEM_GET_SESSION],
    ),
  },
  {
    // src/server: fala com o banco só por src/data.
    files: ['src/server/**'],
    rules: proibir([...comuns, SEM_SUPABASE('src/server')], [SEM_GET_SESSION]),
  },
  {
    // O molde: único arquivo com createServerFn.
    files: ['src/server/portas/acao.ts'],
    rules: proibir([SEM_CLIENTE_NO_NAVEGADOR, SEM_SUPABASE('src/server')], [SEM_GET_SESSION]),
  },
  {
    // src/app: não fala com o banco; toda ação vai para src/server.
    files: ['src/app/**'],
    rules: proibir(
      [
        ...comuns,
        {
          regex: camada('data'),
          message: 'src/app não importa src/data; use src/server (ARCHITECTURE.md §3).',
        },
        SEM_SUPABASE('src/app'),
        // Ícone só por src/app/ui/icone.tsx (plan.md §6.4 do item 4; ADR 0004 · D3; DESIGN.md §5).
        { regex: '^lucide-react(/|$)', message: 'Ícone só por src/app/ui/icone.tsx (DESIGN.md §5).' },
      ],
      [SEM_GET_SESSION],
    ),
  },
  {
    files: ['src/app/ui/icone.tsx'],
    rules: proibir(
      [
        ...comuns,
        {
          regex: camada('data'),
          message: 'src/app não importa src/data; use src/server (ARCHITECTURE.md §3).',
        },
        SEM_SUPABASE('src/app'),
      ],
      [SEM_GET_SESSION],
    ),
  },
)
