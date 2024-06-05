#!/bin/bash
set -eux

DCI_PKG_DIR=$(cd $(dirname $0); pwd)

source ./rpmbuild.lib

if [[ "$#" -lt 1 ]]; then
    echo "Usage: ./build_rpm.sh <PATH_TO_PROJ> [<ARCH> [<PATH_TO_REPO>]]"
    echo "       <ARCH> default to epel-8-x86_64"
    exit 1
fi

PATH_TO_PROJ="$1"

if [[ "$#" == 3 ]]; then
    PATH_TO_REPO=$3
else
    PATH_TO_REPO=""
fi

# We assume there is only one spec file per project
PROJ_NAME=$(basename $PATH_TO_PROJ/*.spec .spec)

WORKSPACE='current'
arch="${2:-epel-8-x86_64}"
rpath=$(echo ${arch}|sed s,-,/,g|sed 's,epel,el,')
with_args=""
basedir=$PWD

MOCKOPTS="-r ${HOME}/.mock/${arch}-with-extras.cfg --no-bootstrap-chroot"

replace_mirror_with_vault_on_el8
generate_mock_profile
setup_build
mock $MOCKOPTS --init

cd ${PATH_TO_PROJ}

generate_srpm
setup_additional_repos
# Build the RPMs in a clean chroot environment with mock to detect missing
# BuildRequires lines.
mock $MOCKOPTS rebuild --resultdir=${WORKSPACE}/${rpath} ${TOPDIR}/SRPMS/*.src.rpm 2>&1
