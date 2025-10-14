#!/usr/bin/env node
const { build } = require('tsup');

async function main() {
  await build({
    entry: ['packages/react-native-vision-rtc/src/index.ts'],
    format: ['cjs', 'esm'],
    sourcemap: true,
    clean: true,
    dts: false,
    outDir: 'packages/react-native-vision-rtc/dist',
    target: 'es2020',
    minify: false,
    splitting: false,
    treeshake: false,
    external: ['react', 'react-native']
  });
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});

