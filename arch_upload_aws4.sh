#!/bin/sh
# Copyleft https://git.k8s.astropenguin.net/penguin/s3-arch-utils

# ##
# Reference
#   https://docs.aws.amazon.com/AmazonS3/latest/API/sig-v4-header-based-auth.html
#
# Usage
#   arch_upload_aws4.sh path/in/bucket file_name.ext
#
# Description
#   Upload file_name.ext to path/in/bucket
#    * file_name.ext must not contain special characters
#    * path/in/bucket must not contain special characters
#
# Env vars
#   ARCH_S3_BUCKET_URL  The bucket url, e.g. my-bucket.s3.us-west-004.backblazeb2.com
#   ARCH_S3_AUTH        In the format of ACCESS_KEY:SECRET_KEY
# #

_PATH=$1
_FILE=$2

if [ -z "$_PATH" ]; then
	echo "Please define a path"
	exit 1
fi

if [ ! -f "$_FILE" ]; then
	echo "File does not exist"
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

_FILE_SHA=$( sha256sum "$_FILE" | cut -d' ' -f1 )
if [ $? -ne 0 ]; then
	exit 1
fi

_DATE=$( date -u +"%Y%m%d" )
_DTIME=$( date -u +"%Y%m%dT%H%M%SZ" )
_HEADERS="content-length;content-type;host;x-amz-content-sha256;x-amz-date"
_CTYPE="application/octet-stream"
_CLEN=$( wc -c < $_FILE | tr -d ' ' )

# Canon Request
_C="PUT"
_C="$_C\n/$_PATH/$_FILE"
_C="$_C\n" # No query string here
_C="$_C\ncontent-length:$_CLEN"
_C="$_C\ncontent-type:$_CTYPE"
_C="$_C\nhost:$BUCKET_URL"
_C="$_C\nx-amz-content-sha256:$_FILE_SHA"
_C="$_C\nx-amz-date:$_DTIME"
_C="$_C\n"
_C="$_C\n$_HEADERS"
_C="$_C\n$_FILE_SHA"

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

echo "Upload Target $_FILE -> $BUCKET_URL/$_PATH/$_FILE"

curl -XPUT -T $_FILE \
  -H "Content-Type: $_CTYPE" \
  -H "Content-Length: $_CLEN" \
  -H "X-Amz-Content-SHA256: $_FILE_SHA" \
  -H "X-Amz-Date: $_DTIME" \
  -H "Authorization: AWS4-HMAC-SHA256 Credential=$ACCESS_KEY/$_DATE/$REGION/$SERVICE/aws4_request,SignedHeaders=$_HEADERS,Signature=$SIG" \
  "https://$BUCKET_URL/$_PATH/$_FILE"
