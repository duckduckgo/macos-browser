import { isUnprotectedDomain, parseNewLineList } from './userScriptUtils.js'

(function () {
    const featureList = parseNewLineList(`
    $CREDENTIALS_EXCEPTIONS$
    `)

    const userList = parseNewLineList(`
    $USER_UNPROTECTED_DOMAINS$
    `)

    if (!isUnprotectedDomain(featureList, userList)) {
        init()
    }
    function init () {
        const script = document.createElement('script')
        script.textContent = `(() => {
            const value = {
                get() {
                    return Promise.reject()
                }
            }
            Object.defineProperty(Navigator.prototype, 'credentials', {
                value,
                configurable: true,
                enumerable: true
            })
        })()`
        const el = document.head || document.documentElement
        el.appendChild(script)
        script.remove()
    }
})()
