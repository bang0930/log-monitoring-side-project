#!/bin/bash
TOTAL_REQUESTS=100
PARALLEL_REQUESTS=10

for i in $(seq 1 $TOTAL_REQUESTS); do
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  echo "{\"level\":\"INFO\",\"message\":\"Load test call $i\",\"timestamp\":\"$timestamp\"}" | nc localhost 5000 &
  sleep 0.01
  if (( $i % $PARALLEL_REQUESTS == 0 )); then
    wait
  fi
done
