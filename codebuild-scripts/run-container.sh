#!/bin/bash

BASE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PARSER_SCRIPT="${BASE_DIR}/set-session-token.py"

#fetch temporary session token and pass to container
RESPONSE=$(aws sts get-session-token --duration-seconds 900)
echo $RESPONSE | python $PARSER_SCRIPT

#run container with env vars
docker run --rm --name lime-compiler-default \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v `pwd`/build:/opt/build \
  -v `pwd`/archive:/opt/archive \
  -v `pwd`/conf:/opt/conf \
  -e CONFIG_PATH="$CONFIG_PATH" \
  -e BUILD_ROOT="$BUILD_ROOT" \
  -e ARCHIVE_ROOT="$ARCHIVE_ROOT" \
  -e SIGNING_ARGS="$SIGNING_ARGS" \
  -e OPTIONAL_ARGS="$OPTIONAL_ARGS" \
  -e AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID" \
  -e AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY" \
  -e AWS_SESSION_TOKEN="$AWS_SESSION_TOKEN" \
  joelferrier/lime-compiler:latest
