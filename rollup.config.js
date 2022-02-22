import json from '@rollup/plugin-json'
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
            nodeResolve()
        ]
    },
    {
        input: 'DuckDuckGo/Autoconsent/background.js',
        output: [
            {
                file: 'DuckDuckGo/Autoconsent/background-bundle.js',
                format: 'iife'
            }
        ],
        plugins: [json(), nodeResolve()]
    }
]
