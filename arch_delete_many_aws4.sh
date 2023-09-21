#!/bin/bash
# Copyleft https://git.k8s.astropenguin.net/penguin/s3-arch-utils

# ##
# Reference
#   https://docs.aws.amazon.com/AmazonS3/latest/API/API_DeleteObjects.html
#
# Usage
#   arch_delete_aws4.sh fileList.text
#   cat fileList.txt | arch_delete_aws4.sh -
#
# Description
#   Delete objects from a bucket with provided fileList.txt
#    * keys must not contain special characters
#
# Env vars
#   ARCH_S3_BUCKET_URL  The bucket url, e.g. my-bucket.s3.us-west-004.backblazeb2.com
#   ARCH_S3_AUTH        In the format of ACCESS_KEY:SECRET_KEY
# #

_LIST_SRC=$1
if [ -z "$_LIST_SRC" ]; then
	echo "File is not defined, Use \"-\" if you were streaming from stdin"
	exit 1
fi

if [ -z "$ARCH_S3_BUCKET_URL" ]; then
	echo "Env ARCH_S3_BUCKET_URL is required"
	exit 1
fi

function _str { printf "%s" $@; }
function _stre { printf $( echo -n "$@" | sed "s/%/%%/g" ); }

_TEMP=$( mktemp )
function __clean_up { rm $_TEMP; }
trap __clean_up EXIT

_str "<Delete>" > $_TEMP
sed "s/.\+/<Object><Key>\0<\/Key><\/Object>/g" $_LIST_SRC | tr -d '\n' >> $_TEMP
if [ $? -ne 0 ]; then
	exit 1
fi
_str "</Delete>" >> $_TEMP

BUCKET_NAME=$( _str $ARCH_S3_BUCKET_URL | cut -d'.' -f1 )
SERVICE=$( _str $ARCH_S3_BUCKET_URL | cut -d'.' -f2 )
REGION=$( _str $ARCH_S3_BUCKET_URL | cut -d'.' -f3 )
ACCESS_KEY=$( _str $ARCH_S3_AUTH | cut -d':' -f1 )
SECRET_KEY=$( _str $ARCH_S3_AUTH | cut -d':' -f2 )

BUCKET_URL=$ARCH_S3_BUCKET_URL

_DATE=$( date -u +"%Y%m%d" )
_DTIME=$( date -u +"%Y%m%dT%H%M%SZ" )
_HEADERS="content-md5;host;x-amz-content-sha256;x-amz-date"

_MD5=$( openssl dgst -md5 -binary $_TEMP | base64 -w0 )
_SHA=$( sha256sum $_TEMP | cut -d' ' -f1 )

# Canon Request
_C="POST"
_C="$_C\n/"
_C="$_C\ndelete="
_C="$_C\ncontent-md5:$_MD5"
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

# BUCKET_URL="127.0.0.1:12345"
curl -s --data @$_TEMP -XPOST \
  -H "X-Amz-Date: $_DTIME" \
  -H "Content-MD5: $_MD5" \
  -H "Content-Type: application/xml" \
  -H "X-Amz-Content-SHA256: $_SHA" \
  -H "Authorization: AWS4-HMAC-SHA256 Credential=$ACCESS_KEY/$_DATE/$REGION/$SERVICE/aws4_request, SignedHeaders=$_HEADERS, Signature=$SIG" \
  "https://$BUCKET_URL/?delete" \
  | grep -Eo "<Deleted><Key>[^<]*?</Key>" \
  | sed "s/^<Deleted><Key>\|<\/Key>//g" | sed "s/^/Deleted \0/g"
