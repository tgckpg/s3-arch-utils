#!/bin/sh
# Copyleft https://git.k8s.astropenguin.net/penguin/s3-arch-utils

# ##
# Reference
#   https://docs.aws.amazon.com/AmazonS3/latest/API/API_DeleteObject.html
#
# Usage
#   arch_delete_aws4.sh path/in/bucket/filename.ext
#
# Description
#   Delete an object from bucket for key: path/in/bucket/filename.ext
#    * key must not contain special characters
#
# Env vars
#   ARCH_S3_BUCKET_URL  The bucket url, e.g. my-bucket.s3.us-west-004.backblazeb2.com
#   ARCH_S3_AUTH        In the format of ACCESS_KEY:SECRET_KEY
# #

_PATH="$1"
if [ -z "$_PATH" ]; then
	echo "Object key is required"
	exit 1
fi

if [ -z "$ARCH_S3_BUCKET_URL" ]; then
	echo "Env ARCH_S3_BUCKET_URL is required"
	exit 1
fi

function _str { printf "%s" $@; }
function _stre { printf $@; }

BUCKET_NAME=$( _str $ARCH_S3_BUCKET_URL | cut -d'.' -f1 )
SERVICE=$( _str $ARCH_S3_BUCKET_URL | cut -d'.' -f2 )
REGION=$( _str $ARCH_S3_BUCKET_URL | cut -d'.' -f3 )
ACCESS_KEY=$( _str $ARCH_S3_AUTH | cut -d':' -f1 )
SECRET_KEY=$( _str $ARCH_S3_AUTH | cut -d':' -f2 )

BUCKET_URL=$ARCH_S3_BUCKET_URL

_DATE=$( date -u +"%Y%m%d" )
_DTIME=$( date -u +"%Y%m%dT%H%M%SZ" )
_HEADERS="host;x-amz-content-sha256;x-amz-date"
_SHA=$( _str "" | sha256sum | cut -d' ' -f1 )

# Canon Request
_C="DELETE"
_C="$_C\n/$_PATH"
_C="$_C\n" # no query strings here
_C="$_C\nhost:$BUCKET_URL"
_C="$_C\nx-amz-content-sha256:$_SHA"
_C="$_C\nx-amz-date:$_DTIME"
_C="$_C\n"
_C="$_C\n$_HEADERS"
_C="$_C\n$_SHA"

# String to Sign
_S="AWS4-HMAC-SHA256"
_S="$_S\n$_DTIME"
_S="$_S\n$_DATE/$REGION/$SERVICE/aws4_request"
_S="$_S\n$( _stre "$_C" | sha256sum | cut -d' ' -f1 )"

function _HMAC { _stre "$2" | openssl dgst -sha256 -hex -mac HMAC -macopt "$1" | cut -d' ' -f2; }

SIG=$( _HMAC "key:AWS4$SECRET_KEY" "$_DATE" )
SIG=$( _HMAC "hexkey:$SIG" "$REGION" )
SIG=$( _HMAC "hexkey:$SIG" "$SERVICE" )
SIG=$( _HMAC "hexkey:$SIG" "aws4_request" )
SIG=$( _HMAC "hexkey:$SIG" "$_S" )

curl -s -XDELETE \
  -H "X-Amz-Date: $_DTIME" \
  -H "X-Amz-Content-SHA256: $_SHA" \
  -H "Authorization: AWS4-HMAC-SHA256 Credential=$ACCESS_KEY/$_DATE/$REGION/$SERVICE/aws4_request, SignedHeaders=$_HEADERS, Signature=$SIG" \
  "https://$BUCKET_URL/$_PATH"
