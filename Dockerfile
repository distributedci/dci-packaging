FROM quay.io/centos/centos:stream9-minimal

ENV AWS_S3_PACKAGES_BUCKET=
ENV AWS_S3_PACKAGES_MOUNT=
ENV AWS_ACCESS_KEY_ID=
ENV AWS_SECRET_ACCESS_KEY=

COPY createrepo_s3fs.sh /opt/

RUN microdnf -y install epel-release && \
  microdnf -y upgrade && \
  microdnf -y install createrepo yum-utils s3fs-fuse && \
  microdnf clean all

CMD ["/opt/createrepo_s3fs.sh"]
