#!/bin/bash

set -eu

# s3simple is a small, simple bash s3 client with minimal dependencies.
# See http://github.com/paulhammond/s3simple for documentation and licence.
s3simple() {
  local command="$1"
  local url="$2"
  local file="${3:--}"

  if [ "${url:0:5}" != "s3://" ]; then
    echo "Need an s3 url"
    return 1
  fi
  local path="${url:5}"

  if [ -z "${AWS_ACCESS_KEY_ID-}" ]; then
    echo "Need AWS_ACCESS_KEY_ID to be set"
    return 1
  fi

  if [ -z "${AWS_SECRET_ACCESS_KEY-}" ]; then
    echo "Need AWS_SECRET_ACCESS_KEY to be set"
    return 1
  fi

  if [ -z "${AWS_REGION-}" ]; then
    echo "Need AWS_REGION to be set"
    return 1
  fi

  local method md5 args
  case "$command" in
  get)
    method="GET"
    md5=""
    args=(-o "$file")
    ;;
  head)
    method="HEAD"
    md5=""
    args=(-I)
    ;;
  put)
    method="PUT"
    if [ ! -f "$file" ]; then
      echo "file not found"
      exit 1
    fi
    md5="$(openssl md5 -binary "$file" | openssl base64)"
    args=(-T "$file" -H "Content-MD5: $md5")
    ;;
  *)
    echo "Unsupported command"
    return 1
    ;;
  esac

  local aws_headers=""
  if [ -n "${AWS_SESSION_TOKEN-}" ]; then
    args=("${args[@]}" -H "x-amz-security-token: ${AWS_SESSION_TOKEN}")
    aws_headers="x-amz-security-token:${AWS_SESSION_TOKEN}\n"
  fi

  local date
  date="$(date -u '+%a, %e %b %Y %H:%M:%S +0000')"

  local string_to_sign
  printf -v string_to_sign "%s\n%s\n\n%s\n%b%s" "$method" "$md5" "$date" "$aws_headers" "/$path"

  local signature
  signature=$(echo -n "$string_to_sign" | openssl sha1 -binary -hmac "${AWS_SECRET_ACCESS_KEY}" | openssl base64)

  local authorization="AWS ${AWS_ACCESS_KEY_ID}:${signature}"

  local bucket="${path%/*}"
  local key="${path#*/}"

  curl "${args[@]}" -s -f -H "Date: ${date}" -H "Authorization: ${authorization}" "https://${bucket}.s3-${AWS_REGION}.amazonaws.com/${key}"
}

s3simple "$@"
