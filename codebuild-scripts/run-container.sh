#!/bin/bash
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
  -e AWS_SESSION_TOKEN="$AWS_SESSION_TOKEN" \
  joelferrier/lime-compiler:latest
