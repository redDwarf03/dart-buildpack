#!/usr/bin/env bash

# Monitoring functions for the buildpack
# This file contains functions for monitoring system resources and command execution

# @description Starts monitoring memory usage
# @param {string} label - Label to identify this monitoring session
# @return {void}
start_memory_monitor() {
  local label="${1:-default}"
  echo "Starting memory monitor for: $label"
  while true; do
    ps -o rss,command ax | grep -v grep | grep "$label" >> "$BUILD_DIR/.memory_usage"
    sleep 1
  done &
  MONITOR_PID=$!
}

# @description Stops the memory monitoring process
# @return {void}
stop_memory_monitor() {
  if [ -n "$MONITOR_PID" ]; then
    kill $MONITOR_PID
    wait $MONITOR_PID 2>/dev/null
  fi
}

# @description Measures the execution time of a command
# @param {string} command - The command to execute and measure
# @return {number} The execution time in seconds
measure_execution_time() {
  local start_time=$(date +%s)
  "$@"
  local end_time=$(date +%s)
  echo $((end_time - start_time))
}

# @description Gets the current memory usage of a process
# @param {number} pid - Process ID to check
# @return {number} Memory usage in KB
get_memory_usage() {
  local pid="$1"
  ps -o rss= -p "$pid"
}

monitor_memory_usage() {
  local output_file="$1"

  # drop the first argument, and leave other arguments in place
  shift

  # Run the command in the background
  "${@:-}" &

  # save the PID of the running command
  pid=$!

  # if this build process is SIGTERM'd
  trap 'kill -TERM $pid' TERM

  # set the peak memory usage to 0 to start
  peak="0"

  while true; do
    sleep .1

    # check the memory usage
    sample="$(ps -o rss= $pid 2> /dev/null)" || break

    if [[ $sample -gt $peak ]]; then
      peak=$sample
    fi
  done

  # ps gives us kb, let's convert to mb for convenience
  echo "$((peak / 1024))" > "$output_file"

  # After wait returns we can get the exit code of $command
  wait $pid

  # wait a second time in case the trap was executed
  # http://veithen.github.io/2014/11/16/sigterm-propagation.html
  wait $pid

  # return the exit code of $command
  return $?
}

monitor() {
  local peak_mem_output start
  local command_name=$1
  shift
  local command=( "$@" )

  peak_mem_output=$(mktemp)
  start=$(nowms)

  # execute the subcommand and save the peak memory usage
  monitor_memory_usage "$peak_mem_output" "${command[@]}"

  mtime "exec.$command_name.time" "${start}"
  mmeasure "exec.$command_name.memory" "$(cat "$peak_mem_output")"

  meta_time "$command_name-time" "$start"
  meta_set "$command_name-memory" "$(cat "$peak_mem_output")"
}
