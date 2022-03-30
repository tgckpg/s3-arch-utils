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
