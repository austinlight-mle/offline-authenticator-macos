#!/bin/bash

# Common SwiftLint run script for all projects

# Adds support for Apple Silicon brew directory
export PATH="$PATH:/opt/homebrew/bin"

# Formatting and linting are developer conveniences: on CI they would rewrite or scan the Swift
# packages that xcodebuild clones into the workspace and break the build.
if [ -n "$CI" ]; then
  echo "SwiftLint skipped on CI"
  exit 0
fi

if which swiftlint >/dev/null; then
  swiftlint
else
  echo "warning: SwiftLint not installed, download from https://github.com/realm/SwiftLint"
fi
