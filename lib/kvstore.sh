#!/usr/bin/env bash

# Function to create a key-value store file
kv_create() {
  local f=$1
  mkdir -p "$(dirname "$f")"
  touch "$f"
}

# Function to clear the contents of the key-value store file
kv_clear() {
  local f=$1
  echo "" > "$f"
}

# Function to set a key-value pair in the store
kv_set() {
  if [[ $# -eq 3 ]]; then
    local f=$1
    if [[ -f $f ]]; then
      echo "$2=$3" >> "$f"
    fi
  fi
}

# Function to get the value of a key from the store
kv_get() {
  if [[ $# -eq 2 ]]; then
    local f=$1
    if [[ -f $f ]]; then
      grep "^$2=" "$f" | sed -e "s/^$2=//" | tail -n 1
    fi
  fi
}

# Function to get the value and wrap it in quotes if it contains spaces
kv_get_escaped() {
  local value
  value=$(kv_get "$1" "$2")
  if [[ $value =~ [[:space:]]+ ]]; then
    echo "\"$value\""
  else
    echo "$value"
  fi
}

# Function to get all the keys from the store
kv_keys() {
  local f=$1
  local keys=()

  if [[ -f $f ]]; then
    # Iterate over each line, splitting on the '=' character
    while IFS="=" read -r key value || [[ -n "$key" ]]; do
      # Skip empty lines
      if [[ -n $key ]]; then
        keys+=("$key")
      fi
    done < "$f"

    # Return sorted unique keys
    echo "${keys[@]}" | tr ' ' '\n' | sort -u
  fi
}

# Function to list all key-value pairs from the store
kv_list() {
  local f=$1

  kv_keys "$f" | while read -r key; do
    if [[ -n $key ]]; then
      echo "$key=$(kv_get_escaped "$f" "$key")"
    fi
  done
}
