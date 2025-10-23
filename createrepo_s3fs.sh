#! /bin/bash

if [ -z "${AWS_S3_PACKAGES_MOUNT}" -o -z "${AWS_S3_PACKAGES_BUCKET}" ]; then
  echo "AWS_S3_PACKAGES_MOUNT and AWS_S3_PACKAGES_BUCKET environment variables must be set."
  exit 1
fi

test -d "${AWS_S3_PACKAGES_MOUNT}" || mkdir -p "${AWS_S3_PACKAGES_MOUNT}"

s3fs -o iam_role=auto "${AWS_S3_PACKAGES_BUCKET}" "${AWS_S3_PACKAGES_MOUNT}"
for REPO in "${AWS_S3_PACKAGES_MOUNT}"/repos/current/el/*/*; do
  echo ".:[ Processing ${REPO} ]:."
  repomanage --old --keep 2 "${REPO}" | while read OLDRPM; do
    rm -vf "${OLDRPM}"
  done

  createrepo --local-sqlite --update "${REPO}/"
done
