#!/bin/bash

START_BATCH=100
END_BATCH=10000
STEP=100
PARALLEL_REQUESTS=20
INDEX_NAME="logscope-$(date +%Y.%m.%d)"
RESULT_FILE="find_max_batch_parameter_tuned.txt"

echo "batch_size,index_size_bytes,success_count,expected_count,kibana_hits,hit_rate_percent,status" > $RESULT_FILE

for BATCH_SIZE in $(seq $START_BATCH $STEP $END_BATCH); do
  echo "$BATCH_SIZE logs 전송 시작"

  seq $BATCH_SIZE | xargs -I{} -P $PARALLEL_REQUESTS bash -c '
    ts=$(date -u +"%Y-%m-%dT%H:%M:%S")
    ms=$(shuf -i 0-999 -n 1)
    timestamp="${ts}.$(printf "%03d" $ms)Z"
    uuid=$(cat /proc/sys/kernel/random/uuid)
    json="{\"message\":\"Load test call {} - $uuid\",\"timestamp\":\"$timestamp\",\"source\":\"bash-max-batch\"}"

    response=$(curl --http1.1 --retry 2 --connect-timeout 1 \
      -H "Content-Type: application/json" \
      -H "Connection: keep-alive" \
      -d "$json" http://localhost:5000 -w "%{http_code}" -o /dev/null -s)

    if [[ "$response" != "200" ]]; then
      echo "실패한 요청: {} 응답 $response" >> curl_errors.log
    fi
  '

  echo "Elasticsearch 반영 대기 중..."
  sleep 10

  for try in {1..5}; do
    DOC_COUNT=$(curl -s "localhost:9200/${INDEX_NAME}/_count?q=source:bash-max-batch" | grep -o '"count":[0-9]*' | grep -o '[0-9]*')
    [[ "$DOC_COUNT" -ge "$BATCH_SIZE" ]] && break
    sleep 2
  done

  INDEX_SIZE=$(curl -s --max-time 10 "localhost:9200/${INDEX_NAME}/_stats/store" | grep -o '"size_in_bytes":[0-9]*' | head -1 | grep -o '[0-9]*')
  KIBANA_HITS=$(curl -s "localhost:9200/${INDEX_NAME}/_search?q=source:bash-max-batch&size=0" | grep -o '"hits":{"total":{"value":[0-9]*' | grep -o '[0-9]*')

  if [[ -z "$INDEX_SIZE" || -z "$DOC_COUNT" || -z "$KIBANA_HITS" ]]; then
    echo "$BATCH_SIZE,ERROR" >> $RESULT_FILE
    echo "데이터 수집 실패"
    break
  fi

  HIT_RATE=$(awk "BEGIN {printf \"%.2f\", ($KIBANA_HITS / $DOC_COUNT) * 100}")

  if [[ "$DOC_COUNT" -lt "$BATCH_SIZE" ]]; then
    STATUS="FAILED"
    echo "$BATCH_SIZE,$INDEX_SIZE,$DOC_COUNT,$BATCH_SIZE,$KIBANA_HITS,$HIT_RATE,$STATUS" >> $RESULT_FILE
    echo "누락 발생 ($KIBANA_HITS hits / $DOC_COUNT docs)"
    break
  else
    STATUS="OK"
    echo "$BATCH_SIZE,$INDEX_SIZE,$DOC_COUNT,$BATCH_SIZE,$KIBANA_HITS,$HIT_RATE,$STATUS" >> $RESULT_FILE
    echo "$BATCH_SIZE logs 전송 성공 (hit율: $HIT_RATE%)"
  fi
done

echo "실험 완료! 결과는 $RESULT_FILE 에 저장됨"
