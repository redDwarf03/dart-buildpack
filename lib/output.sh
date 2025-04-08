#!/usr/bin/env bash

# Output formatting functions for the buildpack
# This file contains functions for formatting and displaying messages

# TODO: Merge these with the output helpers in buildpack-stdlib:
# https://github.com/heroku/buildpack-stdlib

# @description Prints a message in a specific color
# @param {string} color - The color to use (red, green, yellow, blue, magenta, cyan)
# @param {string} message - The message to print
# @return {void} - Prints the colored message to stdout
print_color() {
  local color="$1"
  local message="$2"
  local code=""
  
  case "$color" in
    red)     code="31" ;;
    green)   code="32" ;;
    yellow)  code="33" ;;
    blue)    code="34" ;;
    magenta) code="35" ;;
    cyan)    code="36" ;;
  esac
  
  echo -e "\033[${code}m${message}\033[0m"
}

# @description Prints a message in bold
# @param {string} message - The message to print
# @return {void} - Prints the bold message to stdout
print_bold() {
  echo -e "\033[1m$1\033[0m"
}

# @description Prints a message with an indent
# @param {string} message - The message to print
# @param {number} [level=1] - The indentation level (default: 1)
# @return {void} - Prints the indented message to stdout
print_indent() {
  local message="$1"
  local level="${2:-1}"
  local indent=""
  
  for ((i=0; i<level; i++)); do
    indent="  $indent"
  done
  
  echo "${indent}${message}"
}

# @description Prints an informational message
# @param {string} message - The message to print
# @return {void} - Prints the info message to stdout
info() {
  echo "       $*"
}

# format output and send a copy to the log
output() {
  local logfile="$1"

  while IFS= read -r LINE;
  do
    # do not indent headers that are being piped through the output
    if [[ "$LINE" =~ ^-----\>.* ]]; then
      echo "$LINE" || true
    else
      echo "       $LINE" || true
    fi
    echo "$LINE" >> "$logfile" || true
  done
}

# @description Prints a header message
# @param {string} message - The message to print
# @return {void} - Prints the header message to stdout
header() {
  echo "-----> $*"
}

bright_header() {
  echo "" || true
  echo -e "\033[1;33m-----> $* \033[0m"
}

header_skip_newline() {
  echo "-----> $*" || true
}

# @description Prints a warning message in yellow
# @param {string} message - The warning message to print
# @return {void} - Prints the warning message to stdout in yellow
warning() {
  print_color "yellow" "WARNING: $*" >&2
}

# @description Prints an error message in red and exits with code 1
# @param {string} message - The error message to print
# @return {void} - Prints the error message to stderr in red and exits
error() {
  print_color "red" "ERROR: $*" >&2
  exit 1
}

# @description Prints a debug message if BUILDPACK_DEBUG is set
# @param {string} message - The message to print
# @return {void} - Prints the debug message to stderr if BUILDPACK_DEBUG is set
puts_debug() {
  if [ -n "${BUILDPACK_DEBUG}" ]; then
    print_color "cyan" "DEBUG: $*" >&2
  fi
}
