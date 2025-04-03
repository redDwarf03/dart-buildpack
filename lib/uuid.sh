#!/usr/bin/env bash

# Fallback method for generating a UUID if no proper method is available
uuid_fallback() {
    local N B C='89ab'

    for (( N=0; N < 16; ++N ))
    do
        B=$(( RANDOM%256 ))

        case $N in
            6)
                printf '4%x' $(( B%16 ))   # Version 4 UUID
                ;;
            8)
                printf '%c%x' ${C:$RANDOM%${#C}:1} $(( B%16 ))  # Random character in the UUID
                ;;
            3 | 5 | 7 | 9)
                printf '%02x-' $B    # Hyphenate specific positions for UUID format
                ;;
            *)
                printf '%02x' $B    # Standard hexadecimal part
                ;;
        esac
    done

    echo
}

# Function to generate a UUID, using platform-specific methods if available
uuid() {
  # If /proc/sys/kernel/random/uuid exists (common in Linux environments), use it
  if [[ -f /proc/sys/kernel/random/uuid ]]; then
    cat /proc/sys/kernel/random/uuid
  # On macOS, use the `uuidgen` command if available
  elif [[ -x "$(command -v uuidgen)" ]]; then
    uuidgen | tr "[:upper:]" "[:lower:]"  # Convert to lowercase to match UUID format
  # If no method is found, fallback to a basic, less reliable UUID generation
  else
    uuid_fallback
  fi
}
