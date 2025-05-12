#!/bin/bash

# 실험 설정
START_COUNT=5000
END_COUNT=100000
STEP=5000
PARALLEL_REQUESTS=20
TIME_LIMIT=60
REPEAT_PER_BATCH=3
INDEX_NAME="logscope-rate-test-$(date +%Y.%m.%d)"
SOURCE_TAG="rate-test"

# 최종 성공 기록
LAST_SUCCESS_COUNT=0
LAST_SUCCESS_INDEX_SIZE=0

for LOG_COUNT in $(seq $START_COUNT $STEP $END_COUNT); do
  echo "=== ${LOG_COUNT} logs 전송 시도 (${REPEAT_PER_BATCH}회 반복) ==="
  ALL_SUCCESS=true

  for TRY in $(seq 1 $REPEAT_PER_BATCH); do
    echo "--- [시도 ${TRY}/${REPEAT_PER_BATCH}] 로그 전송 시작 ---"

    START_TIME=$(date +%s)

    seq $LOG_COUNT | xargs -I{} -P $PARALLEL_REQUESTS bash -c '
      ts=$(date -u +"%Y-%m-%dT%H:%M:%S")
      ms=$(shuf -i 0-999 -n 1)
      timestamp="${ts}.$(printf "%03d" $ms)Z"
      uuid=$(cat /proc/sys/kernel/random/uuid)
      json="{\"message\":\"Load test call {} - $uuid\",\"timestamp\":\"$timestamp\",\"source\":\"'"$SOURCE_TAG"'\"}"

      curl --http1.1 --retry 2 --connect-timeout 1 \
        -H "Content-Type: application/json" \
        -H "Connection: keep-alive" \
        -d "$json" http://localhost:5000 -o /dev/null -s
    '
    wait

    END_TIME=$(date +%s)
    TIME_TAKEN=$((END_TIME - START_TIME))

    echo "전송 완료 (${TIME_TAKEN}s 소요), Elasticsearch 반영 대기 중..."
    sleep 10

    DOC_COUNT=$(curl -s "localhost:9200/${INDEX_NAME}/_count?q=source:$SOURCE_TAG" | grep -o '"count":[0-9]*' | grep -o '[0-9]*')
    INDEX_SIZE=$(curl -s "localhost:9200/${INDEX_NAME}/_stats/store" | grep -o '"size_in_bytes":[0-9]*' | grep -o '[0-9]*' | head -1)

    if [[ -z "$DOC_COUNT" || -z "$INDEX_SIZE" ]]; then
      echo "Elasticsearch 응답 오류. 실험 중단."
      exit 1
    fi

    if [[ "$TIME_TAKEN" -gt "$TIME_LIMIT" ]]; then
      echo "시간 초과 (${TIME_TAKEN}s). 반복 실패."
      ALL_SUCCESS=false
      break
    fi

    if [[ "$DOC_COUNT" -lt "$LOG_COUNT" ]]; then
      echo "누락 발생: 기대 $LOG_COUNT / 수집 $DOC_COUNT. 반복 실패."
      ALL_SUCCESS=false
      break
    fi

    echo "정상 수집 완료! 수: $DOC_COUNT / 시간: ${TIME_TAKEN}s / 인덱스 크기: ${INDEX_SIZE} bytes"
  done

  if $ALL_SUCCESS; then
    echo "=== ${LOG_COUNT} logs: 모든 반복 성공 ==="
    LAST_SUCCESS_COUNT=$LOG_COUNT
    LAST_SUCCESS_INDEX_SIZE=$INDEX_SIZE
  else
    echo "=== ${LOG_COUNT} logs: 반복 실패. 실험 중단 ==="
    break
  fi
done

echo
echo "==== 실험 종료 ===="
echo "1분 이내 최대 처리 가능 로그 수: $LAST_SUCCESS_COUNT"
echo "해당 시점 index 용량: $LAST_SUCCESS_INDEX_SIZE bytes"
echo "인덱스명: $INDEX_NAME"
