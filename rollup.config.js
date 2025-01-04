import { nodeResolve } from '@rollup/plugin-node-resolve';
import commonjs from '@rollup/plugin-commonjs';
import { terser } from 'rollup-plugin-terser';
import typescript from '@rollup/plugin-typescript';

export default {
    input: 'src/index.ts', // Use source TypeScript file
    output: [
        {
            file: 'dist/esm/index.js',
            format: 'esm',
            sourcemap: true,
            inlineDynamicImports: true,
        },
        {
            file: 'dist/cjs/index.js',
            format: 'cjs',
            sourcemap: true,
            inlineDynamicImports: true,
        },
        {
            file: 'dist/plugin.js',
            format: 'iife',
            name: 'capacitorSocialShare', // Replace with your plugin name
            globals: {
                '@capacitor/core': 'capacitorExports',
            },
            sourcemap: true,
            inlineDynamicImports: true,
        },
    ],
    external: ['@capacitor/core'], // Avoid bundling @capacitor/core
    plugins: [
        nodeResolve(),
        commonjs(),
        typescript(),
        terser(), // Minify the output
    ],
};