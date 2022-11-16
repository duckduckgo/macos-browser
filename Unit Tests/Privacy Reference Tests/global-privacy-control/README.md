# Global Privacy Control Tests

Privacy Feature: https://app.asana.com/0/1198207348643509/1199115248606508/f

## Goals

This set of tests verifies implementation of Global Privacy Control signal. In particular it focuses on verifying that:

- that the GPC header appears on all requests
- that `navigator.globalPrivacyControl` API is available in all frames
- that the right thing happens when user opts out of GPC and
- that excluded domains, as defined in the privacy remote configuration, are taken into account.

## Structure

Test suite specific fields:

- `siteURL` - string - currently loaded website's URL (as seen in the URL bar)
- `frameURL` - string - URL of an iframe in which the feature is operating (optional - if not set assume main frame context)
- `requestType` - mostly "image" or "main_frame" (navigational request), but can be any of https://developer.mozilla.org/en-US/docs/Mozilla/Add-ons/WebExtensions/API/webRequest/ResourceType - type of the resource being fetched
- `gpcUserSettingOn` - boolean - if user controlled GPC setting is on or off (optional - if not set assume on)
- `expectGPCAPI` - boolean - if we expect GPC API to be available in given conditions
- `expectGPCAPIValue` - "true", "false" or "undefined" - stringified expected value of `Navigator.prototype.globalPrivacyControl`
- `expectGPCHeader` - boolean - if we expect GPC header to be included with given request
- `expectGPCHeaderValue` - string - expected value of the `Sec-GPC` header

## Pseudo-code implementation

```
loadReferenceConfig('config_reference.json')

for $testSet in test.json

  for $test in $testSet
    if $test.exceptPlatforms includes 'current-platform'
        skip

    setSetting('GPC', $test.gpcUserSettingOn or true)

    if $test has 'expectGPCHeader'
        $headers = getHeaders($test.siteURL, $test.frameURL, $test.requestType)
        $enabled = $headers has 'Sec-GPC'

        expect($enabled === $test.expectGPCHeader)

        if $test has 'expectGPCHeaderValue'
            expect(headerValue($headers, 'Sec-GPC') === $test.expectGPCHeaderValue)

    else if $test has 'expectGPCAPI'
        $gpcAPIInjected = isGPCInjected($test.siteURL, $test.frameURL)

        expect($gpcAPIInjected === $test.expectGPCAPI)

        if $test has 'expectGPCAPIValue'
            expect(getJSPropertyValue('Navigator.prototype.globalPrivacyControl') === $test.expectGPCAPIValue)

```
