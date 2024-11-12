#!/bin/bash

FEATURE_PATH=$1

docker build -t "$(basename "$FEATURE_PATH")" -f ./Dockerfile "$FEATURE_PATH"