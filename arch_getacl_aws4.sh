#!/bin/sh
# Copyleft https://git.k8s.astropenguin.net/penguin/s3-arch-utils

# ##
# Reference
#   https://docs.aws.amazon.com/AmazonS3/latest/API/API_GetObjectAcl.html
#
# Usage
#   arch_getactl_aws4.sh path/in/bucket/key.ext
#
# Description
#   Prints the contents of an object from s3 into stdout
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

BUCKET_NAME=$( echo -n $ARCH_S3_BUCKET_URL | cut -d'.' -f1 )
SERVICE=$( echo -n $ARCH_S3_BUCKET_URL | cut -d'.' -f2 )
REGION=$( echo -n $ARCH_S3_BUCKET_URL | cut -d'.' -f3 )
ACCESS_KEY=$( echo -n $ARCH_S3_AUTH | cut -d':' -f1 )
SECRET_KEY=$( echo -n $ARCH_S3_AUTH | cut -d':' -f2 )

BUCKET_URL=$ARCH_S3_BUCKET_URL

_DATE=$( date -u +"%Y%m%d" )
_DTIME=$( date -u +"%Y%m%dT%H%M%SZ" )
_HEADERS="host;x-amz-content-sha256;x-amz-date"
_SHA=$( echo -n "" | sha256sum | cut -d' ' -f1 )

# Keys should be sorted
QPARAMS=(
	"versionId" ""
)

function _urlencode {
	echo -n $1 | sed "s/\//%2F/g"
}

_L=${#QPARAMS[@]}
QSTR="acl="

for (( i=0; i<$_L; i+=2 )); do
	_K=${QPARAMS[$i]}
	_V=${QPARAMS[(($i+1))]}
	if [ -z "$_V" ]; then
		continue
	fi

	_S="$_K=$( _urlencode $_V )"
	QSTR="$QSTR&$_S"
done

# Canon Request
_C="GET"
_C="$_C\n/$_PATH"
_C="$_C\n$QSTR"
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
_S="$_S\n$( echo -ne "$_C" | sha256sum | cut -d' ' -f1 )"

function _HMAC { echo -ne "$2" | openssl dgst -sha256 -hex -mac HMAC -macopt "$1" | cut -d' ' -f2; }

SIG=$( _HMAC "key:AWS4$SECRET_KEY" "$_DATE" )
SIG=$( _HMAC "hexkey:$SIG" "$REGION" )
SIG=$( _HMAC "hexkey:$SIG" "$SERVICE" )
SIG=$( _HMAC "hexkey:$SIG" "aws4_request" )
SIG=$( _HMAC "hexkey:$SIG" "$_S" )

curl -s -XGET \
  -H "X-Amz-Date: $_DTIME" \
  -H "X-Amz-Content-SHA256: $_SHA" \
  -H "Authorization: AWS4-HMAC-SHA256 Credential=$ACCESS_KEY/$_DATE/$REGION/$SERVICE/aws4_request, SignedHeaders=$_HEADERS, Signature=$SIG" \
  "https://$BUCKET_URL/$_PATH?$QSTR"
