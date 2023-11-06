# PixelKit

This package is meant to provide basic support for firing pixel across different targets.

This package was designed to not really know specific pixels.  Those can be defined
individually by each target importing this package, or through more specialized
shared packages. 

This design decision is meant to make PixelKit lean and to make it possible to use it
for future apps we may decide to make, without it having to carry over all of the business
domain logic for any single app.
