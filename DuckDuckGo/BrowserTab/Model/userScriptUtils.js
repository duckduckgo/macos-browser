export function getTopLevelURL () {
    try {
        // FROM: https://stackoverflow.com/a/7739035/73479
        // FIX: Better capturing of top level URL so that trackers in embedded documents are not considered first party
        if (window.location !== window.parent.location) {
            return new URL(window.location.href !== 'about:blank' ? document.referrer : window.parent.location.href)
        } else {
            return new URL(window.location.href)
        }
    } catch (error) {
        return new URL(location.href)
    }
}

export function parseNewLineList (stringVal) {
    return stringVal.split('\n').map(v => v.trim())
}

export function isUnprotectedDomain (featureList, userList) {
    let unprotectedDomain = false
    const topLevelUrl = getTopLevelURL()
    const domainParts = topLevelUrl && topLevelUrl.host ? topLevelUrl.host.split('.') : []

    // walk up the domain to see if it's unprotected
    while (domainParts.length > 1 && !unprotectedDomain) {
        const partialDomain = domainParts.join('.')

        unprotectedDomain = featureList.filter(domain => domain === partialDomain).length > 0

        domainParts.shift()
    }

    if (!unprotectedDomain && topLevelUrl.host != null) {
        unprotectedDomain = userList.filter(domain => domain === topLevelUrl.host).length > 0
    }
    return unprotectedDomain
}
