import { defineConfig, devices } from '@playwright/test'

// Telas em 390 px (celular) e 1440 px (computador), só Chromium (DESIGN.md §9; ADR 0002 · D11).
// Banco local (spec specs/20261128-030000-entrar-servico, plan.md §8): o servidor do app sobe por
// scripts/banco-local.mjs (variáveis do banco local, chaves novas a cada execução; sem a chave de administração);
// o globalSetup cria as contas fictícias da rodada (e2e/preparo-global.ts).
// Chromium já instalado fora do lugar padrão: PLAYWRIGHT_CHROMIUM (caminho do executável), só se vier no ambiente.
const executavel = process.env.PLAYWRIGHT_CHROMIUM

export default defineConfig({
  testDir: './e2e',
  globalSetup: './e2e/preparo-global.ts',
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 1 : 0,
  reporter: process.env.CI ? [['github'], ['html', { open: 'never' }]] : 'list',
  use: {
    baseURL: 'http://localhost:3000',
    // Idioma do navegador: Entrar aparece em português antes de escolher o estúdio (spec RF-34).
    locale: 'pt-BR',
    ...(executavel ? { launchOptions: { executablePath: executavel } } : {}),
  },
  projects: [
    {
      name: 'celular',
      use: { ...devices['Desktop Chrome'], viewport: { width: 390, height: 844 }, deviceScaleFactor: 1 },
    },
    {
      name: 'computador',
      use: { ...devices['Desktop Chrome'], viewport: { width: 1440, height: 900 }, deviceScaleFactor: 1 },
    },
  ],
  webServer: {
    command: 'node scripts/banco-local.mjs pnpm dev',
    url: 'http://localhost:3000',
    // Nunca reaproveita um servidor já de pé: ele não teria as chaves desta execução (scripts/banco-local.mjs).
    reuseExistingServer: false,
    timeout: 120_000,
  },
})
