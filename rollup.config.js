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
    }
]
