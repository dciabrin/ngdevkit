#!/bin/bash

# Copyright (c) 2021 Damien Ciabrini
# This file is part of ngdevkit

set -ue

# Disable verbose to prevent leaking credentials
set +x


help() {
    echo "Usage: $0 --slug=\"{~user}/{ppa}/+git/{package}\" --name=\"{launchpad-key-name}\"" >&2
    exit ${1:-0}
}

error() {
    echo "Error: $1" >&2
    help 1
}


# ----------------- config parsing -----------------
#
DRYRUN=

OPTS=$(/usr/bin/getopt -n $0 --long help,dry-run,slug:,name: -- $0 $@)
if [ $? != 0 ]; then
    error "parsing arguments failed"
fi

eval set -- "$OPTS"
while true; do
    case "$1" in
        --help) help;;
        --dry-run ) DRYRUN=1; shift ;;
        --slug ) SLUG="$2"; shift 2 ;;
        --name ) NAME="$2"; shift 2 ;;
        -- ) shift; break ;;
        * ) break ;;
    esac
done


if [ -z "$SLUG" ]; then
    error "no user specified"
fi
if [ -z "$NAME" ]; then
    error "no Launchpad key specified"
fi
if [ -z "$LAUNCHPAD_TOKEN" ]; then
    error "no token specified for env variable LAUNCHPAD_TOKEN"
fi
if [ -z "$LAUNCHPAD_TOKEN_SECRET" ]; then
    error "no token secret specified for env variable LAUNCHPAD_TOKEN_SECRET"
fi


# ----------------- garbage-collect nightly tags that match regex -----------------
#
# Build authentication string
TIMESTAMP=$(date +%s)
NONCE=$(python3 -c 'import string; import secrets; print("".join((secrets.choice(string.ascii_letters+string.digits) for i in range(36))))')
AUTH="OAuth oauth_consumer_key=\"${NAME}\", oauth_nonce=\"${NONCE}\", oauth_signature=\"%26${LAUNCHPAD_TOKEN_SECRET}\", oauth_signature_method=\"PLAINTEXT\", oauth_timestamp=\"${TIMESTAMP}\", oauth_token=\"${LAUNCHPAD_TOKEN}\", oauth_version=\"1.0\""

# Call "code import" to force Launchpad to sync its git remote and rebuild
OUT=$(curl --dump-header - -X POST -H "Authorization: ${AUTH}" --data "ws.op=requestImport" https://api.launchpad.net/1.0/${SLUG}/+code-import)

if ! echo $OUT | grep HTTP | grep -qw 200; then
    echo "failed to call +code-import:" >&2
    echo $OUT >&2
    exit 1
fi

echo "Launchpad code import API called succesfully"
