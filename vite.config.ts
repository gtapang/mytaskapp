import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// Renderer build only; the Electron main + preload processes are compiled
// separately by tsc (tsconfig.main.json).
export default defineConfig({
  root: 'src/renderer',
  base: './',
  plugins: [react()],
  build: {
    outDir: '../../dist/renderer',
    emptyOutDir: true,
  },
});
