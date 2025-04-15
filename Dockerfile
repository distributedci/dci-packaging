FROM quay.io/centos/centos:stream9

ENV AWS_S3_PACKAGES_BUCKET=
ENV AWS_S3_PACKAGES_MOUNT=
ENV AWS_ACCESS_KEY_ID=
ENV AWS_SECRET_ACCESS_KEY=

COPY createrepo_s3fs.sh /opt/

RUN dnf -y install epel-release && \
  dnf -y upgrade && \
  dnf -y install createrepo yum-utils s3fs-fuse && \
  dnf clean all

CMD ["/opt/createrepo_s3fs.sh"]
