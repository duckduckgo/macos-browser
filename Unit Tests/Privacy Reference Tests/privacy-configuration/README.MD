# Privacy Configuration Tests

Privacy Feature: https://app.asana.com/0/1198207348643509/1199981227466169/f

## Goals

This set of tests verifies implementation of privacy configuration. In particular it focuses on verifying that:

- features are correctly enabled / disabled according to the global setting ("state"),
- exceptions are taken into account ("exceptions", "unprotectedTemporary") and url matching is according to the spec ("domain"),
- features are correctly injected, or not, into iframes ("aboutBlank", "aboutBlankSites"),
- features are correctly disabled for specific scripts ("script"),
- features missing from the config are disabled and don't cause a crash.

## Structure

There are multiple sets of tests in `tests.json` and multiple config files. Each set defines what configuration file (`configX_reference.json`) is expected to be loaded via "referenceConfig" field.

Test suite specific fields:

- featureName - string - name of the privacy feature as defined in the config
- siteURL - string - currently loaded website's URL (as seen in the URL bar)
- frameURL - string - URL of an iframe in which the feature is operating (optional - if not set assume main frame context)
- scriptURL - string - URL of script that is trying to use a protected feature (optional - if not set assume no script URL)
- expectFeatureEnabled - bool - if feature is expected to be disabled or not

## Pseudo-code implementation

```
for $testSet in test.json
  loadRemoteConfig($testSet.referenceConfig)

  for $test in $testSet
    $enabled = isEnabled(
        feature=$test.featureName,
        url=$test.siteURL,
        frame=$test.frameURL,
        script=$test.scriptURL
    )

    expect($enabled === $test.expectFeatureEnabled)
```