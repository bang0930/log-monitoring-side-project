# #!/bin/bash

# TOTAL_REQUESTS=100
# PARALLEL_REQUESTS=10

# echo "[INFO] Sending $TOTAL_REQUESTS requests to Logstash via curl (http://localhost:5000)"

# for i in $(seq 1 $TOTAL_REQUESTS); do
#   timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
#   curl -s -X POST http://localhost:5000 \
#     -H "Content-Type: application/json" \
#     -d "{\"level\":\"INFO\",\"message\":\"Load test call $i\",\"timestamp\":\"$timestamp\",\"source\":\"curl-load-test\"}" > /dev/null &

#   if (( $i % $PARALLEL_REQUESTS == 0 )); then
#     sleep 0.1
#     wait
#   fi
# done

# wait
# echo "[DONE] Load test 완료 (curl)"

#!/bin/bash

TOTAL_REQUESTS=100
PARALLEL_REQUESTS=10

echo "[INFO] Sending $TOTAL_REQUESTS requests to Logstash via curl (http://localhost:5000)"
START=$(date +%s)

for i in $(seq 1 $TOTAL_REQUESTS); do
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  json="{\"message\":\"Load test call $i\",\"timestamp\":\"$timestamp\",\"source\":\"curl-load-test\"}"

  curl --http1.1 --retry 3 --connect-timeout 2 \
       -H "Content-Type: application/json" \
       -H "Connection: keep-alive" \
       -d "$json" http://localhost:5000 > /dev/null &

  if (( $i % $PARALLEL_REQUESTS == 0 )); then
    sleep 0.1
    wait
  fi
done

wait
END=$(date +%s)
echo "[DONE] Load test 완료 (curl) | Duration: $((END - START)) sec"
