#!/bin/bash
# Copyleft https://git.k8s.astropenguin.net/penguin/s3-arch-utils

# ##
#
# Usage
#   create-k8s-secrets.sh namespace secret-name
#
# Description
#   Create a secret config for arch_* in secret-name under the
#   specificed namespace
#
# Sample CronJob spec
#   apiVersion: batch/v1
#   kind: CronJob
#   metadata:
#     name: s3-upload
#   spec:
#     schedule: "0 0 * * *"
#     jobTemplate:
#       spec:
#         template:
#           spec:
#             restartPolicy: OnFailure
#             containers:
#               - name: backup
#                 image: [IMAGE_WITH_OPENSSL_AND_BASH]
#                 env:
#                   - name: ARCH_S3_BUCKET_URL
#                     valueFrom:
#                       secretKeyRef:
#                         name: s3-arch-conf
#                         key: BUCKET_URL
#                   - name: ARCH_S3_AUTH
#                     valueFrom:
#                       secretKeyRef:
#                         name: s3-arch-conf
#                         key: AUTH
#                 command:
#                   - sh
#                   - -c
#                   - |
#                     cd /tmp;
#                     _DATE=$( date -u +"%Y%m%dT%H%M%SZ" );
#                     bash /s3/arch_upload_aws4.sh blog/$_DATE.tar.gz $_DATE.tar.gz;
#                     rm -r dump/ $_DATE.tar.gz $_DATE.tar.gz.enc;
#                 volumeMounts:
#                   - mountPath: "/s3"
#                     name: s3-arch-utils
#             volumes:
#               - name: s3-arch-utils
#                 secret:
#                   secretName: [secret-name]
# #

function _print_files {
	for i in $( ls arch_*.sh ); do
		echo "  $i: $( base64 -w0 $i )"
	done
}

cat<<__SECRET__
apiVersion: v1
data:
`_print_files`
kind: Secret
metadata:
  name: $2
  namespace: $1
__SECRET__
