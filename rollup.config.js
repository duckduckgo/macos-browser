const browserTabPath = 'DuckDuckGo/BrowserTab/Model/'

export default [
    {
        input: `${browserTabPath}navigatorCredentials.js`,
        output: [
            {
                file: `${browserTabPath}dist/navigatorCredentials.js`,
                format: 'iife'
            }
        ]
    },
    {
        input: 'DuckDuckGo/GPC/gpc.js',
        output: [
            {
                file: 'DuckDuckGo/GPC/dist/gpc.js',
                format: 'iife'
            }
        ]
    }
]
