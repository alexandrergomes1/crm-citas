import globals from 'globals';
import tseslint from 'typescript-eslint';
import react from 'eslint-plugin-react';
import reactHooks from 'eslint-plugin-react-hooks';
import { defineConfig, globalIgnores } from 'eslint/config';

export default defineConfig([
  globalIgnores(['dist/**', '.wrangler/**', '.tanstack/**', 'node_modules/**', 'src/routeTree.gen.ts', 'worker-configuration.d.ts', 'playwright-report/**', 'test-results/**', 'docs/**']),
  ...tseslint.configs.recommended,
  {
    files: ['**/*.{ts,tsx,js,mjs}'],
    languageOptions: { globals: { ...globals.browser, ...globals.node } },
    plugins: { react, 'react-hooks': reactHooks },
    settings: { react: { version: 'detect' } },
    rules: {
      ...reactHooks.configs.recommended.rules,
      // Botão sem tipo dentro de <form> envia o formulário (bug do seletor de itens, 29 out).
      'react/button-has-type': 'error',
      'react/jsx-key': 'error',
      'react/no-unescaped-entities': 'error',
      '@typescript-eslint/no-unused-vars': ['warn', { argsIgnorePattern: '^_', varsIgnorePattern: '^_', caughtErrorsIgnorePattern: '^_' }],
    },
  },
]);
