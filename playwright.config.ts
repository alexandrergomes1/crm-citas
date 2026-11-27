import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './e2e',
  fullyParallel: false,
  forbidOnly: !!process.env['CI'],
  retries: process.env['CI'] ? 2 : 0,
  // Os E2E usam a mesma conta e o mesmo banco remoto. Logins e mutations
  // concorrentes invalidam refresh tokens e tornam os resultados não determinísticos.
  workers: 1,
  // Na CI: anotações no PR (o relatório HTML fica no artefato).
  reporter: process.env['CI'] ? [['github'], ['list'], ['html', { open: 'never' }]] : 'html',
  use: {
    baseURL: 'http://localhost:3000',
    trace: 'on-first-retry',
  },
  projects: [
    {
      name: 'desktop-chrome',
      use: { ...devices['Desktop Chrome'], viewport: { width: 1440, height: 900 } },
    },
    {
      name: 'mobile-chrome',
      use: { ...devices['Pixel 5'], viewport: { width: 390, height: 844 } },
    },
  ],
  webServer: {
    // Na CI do E2E: build do Worker e prévia local (E2E_WEB_COMMAND="pnpm build && pnpm preview").
    command: process.env['E2E_WEB_COMMAND'] ?? 'pnpm dev',
    url: 'http://localhost:3000',
    reuseExistingServer: !process.env['CI'],
    timeout: 180_000,
  },
});
