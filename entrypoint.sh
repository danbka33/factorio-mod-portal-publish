#!/bin/bash

# Parse the tag we're on, do nothing if there isn't one
TAG=$(echo ${GITHUB_REF} | grep tags | grep -o "[^/]*$")
if [[ -z "${TAG}" ]]; then
    echo "Not a tag push, skipping"
    exit 0
fi

# Validate the version string we're building
if ! echo "${TAG}" | grep -P --quiet '^(v)?\d+\.\d+\.\d+$'; then
    echo "Bad version, needs to be (v)%u.%u.%u"
    exit 1
fi

# Strip "v" if it is prepended to the semver
if [[ "${TAG:0:1}" == "v" ]]; then
  GIT_TAG="${TAG}"
  TAG="${TAG:1}"
fi

INFO_VERSION=$(jq -r '.version' info.json)
# Make sure the info.json is parseable and has the expected version number
if ! [[ "${INFO_VERSION}" == "${TAG}" ]]; then
    echo "Tag version doesn't ${TAG} match info.json version ${INFO_VERSION} (or info.json is invalid), failed"
    exit 1
fi
# Pull the mod name from info.json
NAME=$(jq -r '.name' info.json)

# Fix: fatal: detected dubious ownership in repository at '/github/workspace'
git config --global --add safe.directory /github/workspace

# Create the zip
git archive --prefix "${NAME}_$INFO_VERSION/" -o "/github/workspace/${NAME}_$INFO_VERSION.zip" "${GIT_TAG}"
FILESIZE=$(stat --printf="%s" "${NAME}_${TAG}.zip")
echo "File zipped, ${FILESIZE} bytes"
unzip -v "${NAME}_${TAG}.zip"

# Query the mod info, verify the version number we're trying to push doesn't already exist
curl -s "https://mods.factorio.com/api/mods/${NAME}/full" | jq -e ".releases[] | select(.version == \"${TAG}\")"
# store the return code before running anything else
STATUS_CODE=$?

if [[ $STATUS_CODE -ne 4 ]]; then
    echo "Release already exists, skipping"
    exit 0
fi
echo "Release doesn't exist for ${TAG}, uploading"

# Get an upload url for the mod
URL_RESULT=$(curl -s -d "mod=${NAME}" -H "Authorization: Bearer ${FACTORIO_MOD_API_KEY}" https://mods.factorio.com/api/v2/mods/releases/init_upload)
UPLOAD_URL=$(echo "${URL_RESULT}" | jq -r '.upload_url')
if [[ -z "${UPLOAD_URL}" ]]; then
    echo "Couldn't get an upload url, failed"
    ERROR=$(echo "${URL_RESULT}" | jq -r '.error')
    MESSAGE=$(echo "${URL_RESULT}" | jq -r '.message // empty')
    echo "${ERROR}: ${MESSAGE}"
    exit 1
fi

# Upload the file
UPLOAD_RESULT=$(curl -s -F "file=@${NAME}_${TAG}.zip" "${UPLOAD_URL}")

# The success attribute only appears on successful uploads
SUCCESS=$(echo "${UPLOAD_RESULT}" | jq -r '.success')

if [[ "${SUCCESS}" == "null" ]]; then
    echo "Upload failed"
    ERROR=$(echo "${UPLOAD_RESULT}" | jq -r '.error')
    MESSAGE=$(echo "${UPLOAD_RESULT}" | jq -r '.message // empty')
    echo "${ERROR}: ${MESSAGE}"
    exit 1
fi

echo "Upload of ${NAME}_${TAG}.zip completed"
