#!/usr/bin/env bash

# UUID generation functions for the buildpack
# This file contains functions for generating unique identifiers

# @description Generates a random UUID v4
# @return {string} A randomly generated UUID v4
uuid_fallback()
{
  # Generate 16 random bytes and convert to hex
  # Use LC_ALL=C to ensure consistent behavior with tr
  # Format: 8-4-4-4-12 characters
  LC_ALL=C tr -dc '0-9a-f' < /dev/urandom | head -c 32 | sed -e 's/\([0-9a-f]\{8\}\)\([0-9a-f]\{4\}\)\([0-9a-f]\{4\}\)\([0-9a-f]\{4\}\)\([0-9a-f]\{12\}\)/\1-\2-\3-\4-\5/'
}

# @description Generates a random UUID v4
# @return {string} A randomly generated UUID v4
uuid() {
  # On Scalingo's stack, there is a uuid command
  if command -v uuidgen >/dev/null 2>&1; then
    uuidgen
  else
    uuid_fallback
  fi
}

# Used for generating unique identifiers for Dart builds and deployments
# If you have any issues, please report them at:
# https://github.com/Scalingo/dart-buildpack/issues/new
