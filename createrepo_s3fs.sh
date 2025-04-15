#! /bin/bash

if [ -z "${AWS_S3_PACKAGES_MOUNT}" -o -z "${AWS_S3_PACKAGES_BUCKET}"]; then
  echo "AWS_S3_PACKAGES_MOUNT and AWS_S3_PACKAGES_BUCKET environment variables must be set."
  exit 1
fi

if [ -z "${AWS_ACCESS_KEY_ID" -o -z "${AWS_SECRET_ACCESS_KEY}" ]; then
  echo "AWS credentials must be passed in AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY environment variables."
  exit 1
fi

test -d "${AWS_S3_PACKAGES_MOUNT}" || mkdir -p "${AWS_S3_PACKAGES_MOUNT}"

s3fs "${AWS_S3_PACKAGES_BUCKET}" "${AWS_S3_PACKAGES_MOUNT}"
for REPO in "${AWS_S3_PACKAGES_MOUNT}/repos/current/el/*/*"; do
  repomanage --old --keep 2 ${REPO} | while read OLDRPM; do
    rm -vf "${OLDRPM}"
  done

  createrepo --update ${REPO}/
done
