import { defineConfig } from 'vitest/config';

// Separate from vite.config.ts (whose root is the renderer): tests cover the
// core + main-process logic and run in a plain node environment.
export default defineConfig({
  test: {
    include: ['tests/**/*.test.ts'],
    environment: 'node',
  },
});
