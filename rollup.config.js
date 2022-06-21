import json from '@rollup/plugin-json'
import copy from 'rollup-plugin-copy'
import { nodeResolve } from '@rollup/plugin-node-resolve'

export default [
    {
        input: 'DuckDuckGo/Autoconsent/userscript.js',
        output: [
            {
                file: 'DuckDuckGo/Autoconsent/autoconsent-bundle.js',
                format: 'iife'
            }
        ],
        plugins: [
            nodeResolve(),
            json(),
            copy({
                targets: [
                  { src: 'node_modules/@duckduckgo/autoconsent/rules/rules.json', dest: 'DuckDuckGo/Autoconsent' },
                ]
            })
        ]
    }
]
