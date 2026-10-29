#!/bin/bash

PATH=/opt/homebrew/bin/:$PATH

# Formatting and linting are developer conveniences: on CI they would rewrite or scan the Swift
# packages that xcodebuild clones into the workspace and break the build.
if [ -n "$CI" ]; then
  echo "SwiftFormat skipped on CI"
  exit 0
fi

if which swiftformat >/dev/null; then
  swiftformat .
else
  echo "warning: SwiftFormat not installed, download from https://github.com/nicklockwood/SwiftFormat"
fi