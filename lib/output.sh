#!/usr/bin/env bash

# Function to print a general information message
info() {
  echo "       $*" || true
}

# Function to format output, and log it to a specified file
output() {
  local logfile="$1"

  while IFS= read -r LINE;
  do
    # If the line starts with "----->", it is considered a header and is not indented
    if [[ "$LINE" =~ ^-----\>.* ]]; then
      echo "$LINE" || true
    else
      echo "       $LINE" || true
    fi
    # Append the line to the log file
    echo "$LINE" >> "$logfile" || true
  done
}

# Function to output a header message (standard formatting)
header() {
  echo "" || true
  echo "-----> $*" || true
}

# Function to output a bright-colored header message
bright_header() {
  echo "" || true
  echo -e "\033[1;33m-----> $* \033[0m"
}

# Function to output a header message without a newline at the beginning
header_skip_newline() {
  echo "-----> $*" || true
}

# Function to output an error message
error() {
  echo " !     $*" >&2 || true
  echo "" || true
}
