#!/usr/bin/env bash

# Function to monitor memory usage of a process
monitor_memory_usage() {
  local output_file="$1"

  # drop the first argument, and leave other arguments in place
  shift

  # Run the command in the background
  "${@:-}" &

  # save the PID of the running command
  pid=$!

  # if this process is SIGTERM'd, kill the background process
  trap 'kill -TERM $pid' TERM

  # Initialize peak memory usage to 0
  peak="0"

  while true; do
    sleep .1

    # Check memory usage of the process
    sample="$(ps -o rss= $pid 2> /dev/null)" || break

    if [[ $sample -gt $peak ]]; then
      peak=$sample
    fi
  done

  # Convert from KB to MB for easier reading
  echo "$((peak / 1024))" > "$output_file"

  # Wait for the background process to finish and capture the exit code
  wait $pid

  # Wait again in case a TERM signal was sent to ensure proper termination
  # Reference: http://veithen.github.io/2014/11/16/sigterm-propagation.html
  wait $pid

  # Return the exit code of the command
  return $?
}

# Function to execute a command and monitor memory usage and execution time
monitor() {
  local peak_mem_output start
  local command_name=$1
  shift
  local command=( "$@" )

  # Create a temporary file to store peak memory usage
  peak_mem_output=$(mktemp)
  start=$(nowms)

  # Execute the subcommand while monitoring its memory usage
  monitor_memory_usage "$peak_mem_output" "${command[@]}"

  # Log the execution time and memory usage
  mtime "exec.$command_name.time" "$start"
  mmeasure "exec.$command_name.memory" "$(cat "$peak_mem_output")"

  # Store the execution time and memory usage in metadata
  meta_time "$command_name-time" "$start"
  meta_set "$command_name-memory" "$(cat "$peak_mem_output")"
}
