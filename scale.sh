#!/bin/bash

NORMAL_REPLICAS=4
PEAK_REPLICAS=12

CURRENT_DAY=$(date +%d)

echo "=== Scale $(date) - Dia $CURRENT_DAY ==="

if [[ "$CURRENT_DAY" == "15" || "$CURRENT_DAY" == "16" ]]; then
    echo "Dia de pico detectado → $PEAK_REPLICAS PHP containers"
    docker compose up -d --scale php=$PEAK_REPLICAS
else
    echo "Dia normal → $NORMAL_REPLICAS PHP containers"
    docker compose up -d --scale php=$NORMAL_REPLICAS
fi