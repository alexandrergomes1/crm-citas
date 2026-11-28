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
const proibir = (proibicoes) => ({
  'no-restricted-imports': ['error', { patterns: proibicoes }],
  'no-restricted-syntax': [
    'error',
    ...proibicoes.map(({ regex, message }) => ({
      selector: `ImportExpression[source.value=/${regex.replaceAll('/', '\\x2F')}/i]`,
      message,
    })),
  ],
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
  {
    // src/domain: TypeScript puro; não importa tela, servidor, dados nem framework.
    files: ['src/domain/**'],
    rules: proibir([
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
    ]),
  },
  {
    // src/app: não fala com o banco; toda ação vai para src/server.
    files: ['src/app/**'],
    rules: proibir([
      {
        regex: camada('data'),
        message: 'src/app não importa src/data; use src/server (ARCHITECTURE.md §3).',
      },
      {
        regex: '^@supabase/',
        message: 'src/app não importa o cliente do banco (ARCHITECTURE.md §3).',
      },
    ]),
  },
)
