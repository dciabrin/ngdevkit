#!/bin/bash

# Copyright (c) 2020 Damien Ciabrini
# This file is part of ngdevkit


# Disable verbose to prevent leaking credentials
set +x


help() {
    echo "Usage: $0 --repo={user}/{repo} --token={github-api-token} --tag-regex={str}" >&2
    exit ${1:-0}
}

error() {
    echo "Error: $1" >&2
    help 1
}

check() {
    if [ $2 != 200 ] && [ $2 != 204 ]; then
        error "unexpected return from '$1' ($2). Aborting"
    fi
}

# ----------------- config parsing -----------------
#
USER=$(echo ${TRAVIS_REPO_SLUG:-} | cut -d'/' -f1)
REPO=$(echo ${TRAVIS_REPO_SLUG:-} | cut -d'/' -f2)
GITHUB_TOKEN=${GH_TOKEN:-}
TAG_REGEX=
DRYRUN=

OPTS=$(/usr/bin/getopt -n $0 --long help,dry-run,user:,repo:,token:,tag-regex: -- $0 $@)
if [ $? != 0 ]; then
    error "parsing arguments failed"
fi

eval set -- "$OPTS"
while true; do
    case "$1" in
        --help) help;;
        --dry-run ) DRYRUN=1; shift ;;
        --user ) USER="$2"; shift 2 ;;
        --repo ) REPO="$2"; shift 2 ;;
        --token ) GITHUB_TOKEN="$2"; shift 2 ;;
        --tag-regex ) TAG_REGEX="$2"; shift 2 ;;
        -- ) shift; break ;;
        * ) break ;;
    esac
done

if [ -z "$USER" ]; then
    error "no user specified"
fi
if [ -z "$REPO" ]; then
    error "no repository specified"
fi
if [ -z "$GITHUB_TOKEN" ]; then
    error "no token/password specified for GitHub API credentials"
fi
if [ -z "$TAG_REGEX" ]; then
    error "no tag regex specified, cannot filter which tag to remove"
fi
CREDS=$USER:$GITHUB_TOKEN


# ----------------- garbage-collect nightly tags that match regex -----------------
#
echo "Downloading tag list from $REPO..."
ret=$(curl -s -w "%{http_code}" -X GET -u $CREDS https://api.github.com/repos/$USER/$REPO/git/refs/tags -o tags)
check "downloading list of nightly tags" $ret

# all tags to remove
# note: keep the two most recent tags. that way we ensure the latest can
# be the 2nd can be served by brew while the latest can be rebuilt.
tags_rm=$(jq -r '. | map(select(.ref | test("'"$TAG_REGEX"'"))) | sort_by(.ref) | reverse | .[] | .ref' tags | sed '1d;2d')
if [ -n "$tags_rm" ]; then
    echo "Deleting all the nightly tags matching '$TAG_REGEX'"
else
    echo "  (no nightly tags detected)"
fi

for i in $tags_rm; do
    echo "removing nightly tag $i"
    if [ -z "$DRYRUN" ]; then
        ret=$(curl -s -w "%{http_code}" -X DELETE -u $CREDS https://api.github.com/repos/$USER/$REPO/git/$i)
        check "removing nightly tag $i" $ret
        sleep 0.5
    fi
done
