#!/bin/bash

for i in {1..100000}; do
    curl -s http://localhost:8080/log > /dev/null &
    sleep 0.01
done
wait