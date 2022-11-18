# Broken Site Reporting Tests

Privacy Feature: https://app.asana.com/0/1198207348643509/1200191185434196/f

## Goals

This set of tests verifies implementation of broken site reporting. In particular it focuses on verifying that the report generated is sent to a correct url and includes all data needed (which differs between platforms).

## Structure

Test suite specific fields:

- `siteURL` - string - currently loaded website's URL (as seen in the URL bar)
- `wasUpgraded` - bool - if request was upgraded to HTTPS by us or not
- `category` - string - user picked breakage category e.g. 'content', 'images', 'paywall', 'login'
- `blockedTrackers` - array of strings - array of hostnames of trackers that were blocked
- `surrogates` - array of strings - array of hostnames of trackers that were replaced with a surrogate
- `atb` - string - ATB cohort
- `blocklistVersion` - string - version of the blocklist
- `manufacturer` - string - name of the device manufacturer (native apps only)
- `model` - string - name of the device model (native apps only)
- `os` - string - operating system name (native apps only)
- `gpcEnabled` - boolean - if GPC is enabled or not (native apps only) - GPC can be disabled by user or by remote config
- `expectReportURLPrefix` - string - resulting report URL should be prefixed with this string
- `expectReportURLParams` - Array of `{name: '', value: ''}` objects - resulting report URL should have the following set of URL parameters with matching values

## Pseudo-code implementation

```
for $testSet in test.json

  for $test in $testSet
    if $test.exceptPlatforms includes 'current-platform'
        skip

    $url = getReportURL(
        siteURL=$test.siteURL,
        wasUpgraded=$test.wasUpgraded,
        reportCategory=$test.category,
        blockedTrackers=$test.blockedTrackers,
        surrogates=$test.surrogates,
        atb=$test.atb,
        blocklistVersion=$test.blocklistVersion,
        manufacturer=$test.manufacturer,
        model=$test.model,
        os=$test.os,
        gpcEnabled=$test.gpcEnabled
    )

    if $test.expectReportURLPrefix
        expect($url.startsWith($test.expectReportURLPrefix))
    
    if $test.expectReportURLParams
        for $param in $test.expectReportURLParams
            expect($url.matchesRegex(/[?&] + $param.name + '=' + $param.value + [&$]/))
```