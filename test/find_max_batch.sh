#!/bin/bash

# 실험 파라미터
START_BATCH=100
END_BATCH=5000
STEP=100
PARALLEL_REQUESTS=10
INDEX_NAME="logscope-$(date +%Y.%m.%d)"  # logstash pipeline index 기준

RESULT_FILE="max_batch_test_results.txt"
echo "batch_size,index_size_bytes,success_count,expected_count,status" > $RESULT_FILE

for BATCH_SIZE in $(seq $START_BATCH $STEP $END_BATCH); do
  echo "==== $BATCH_SIZE logs 전송 시작 ===="

  for i in $(seq 1 $BATCH_SIZE); do
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    json="{\"message\":\"Load test call $i\",\"timestamp\":\"$timestamp\",\"source\":\"bash-max-batch\"}"

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

  sleep 3  # Elasticsearch 반영 시간 대기

  # 인덱스 크기 확인
  INDEX_SIZE=$(curl -s --max-time 10 "localhost:9200/${INDEX_NAME}/_stats/store" | grep -o '"size_in_bytes":[0-9]*' | head -1 | grep -o '[0-9]*')

  # 저장된 document 수 확인
  DOC_COUNT=$(curl -s --max-time 10 "localhost:9200/${INDEX_NAME}/_count?q=source:bash-max-batch" | grep -o '"count":[0-9]*' | grep -o '[0-9]*')

  # 실패 체크
  if [[ -z "$INDEX_SIZE" || -z "$DOC_COUNT" ]]; then
    echo "$BATCH_SIZE,ERROR" >> $RESULT_FILE
    echo "에러: 인덱스 크기나 문서 수 확인 실패. 중단."
    break
  fi

  if [[ "$DOC_COUNT" -lt "$BATCH_SIZE" ]]; then
    STATUS="FAILED"
    echo "$BATCH_SIZE,$INDEX_SIZE,$DOC_COUNT,$BATCH_SIZE,$STATUS" >> $RESULT_FILE
    echo "⚠️ 누락 발생! 예상보다 적은 로그 저장됨 ($DOC_COUNT / $BATCH_SIZE)"
    break
  else
    STATUS="OK"
    echo "$BATCH_SIZE,$INDEX_SIZE,$DOC_COUNT,$BATCH_SIZE,$STATUS" >> $RESULT_FILE
    echo "==== $BATCH_SIZE logs 전송 성공 (index size: $INDEX_SIZE bytes) ===="
  fi
done

echo "최대 처리 batch 탐색 실험 완료! 결과는 $RESULT_FILE 에 저장됨"
