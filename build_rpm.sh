#!/bin/bash
set -eux

source ./rpmbuild.lib

if [[ "$#" -lt 2 ]]; then
    echo "USAGE: ./build_rpm.sh <PATH_TO_PROJ> <PROJ_NAME> [<PATH_TO_REPO>]"
    exit 1
fi

PATH_TO_PROJ=$1
PROJ_NAME=$2
if [[ "$#" == 4 ]]; then
    PATH_TO_REPO=$4
else
    PATH_TO_REPO=""
fi

WORKSPACE='current'
RDO_CLOUD_MIRROR='mirror.regionone.rdo-cloud.rdoproject.org'

arch="${3:-epel-7-x86_64}"
rpath=$(echo ${arch}|sed s,-,/,g|sed 's,epel,el,')
with_args=""
basedir=$PWD

MOCKOPTS="-r ${HOME}/.mock/${arch}-with-extras.cfg"

generate_mock_profile
setup_build
mock $MOCKOPTS --init

pushd ${PATH_TO_PROJ}

generate_srpm
# Use a TTL=4 to evaluate the distance between the host the mirror
ping -c 2 -t 4 -W 1 ${RDO_CLOUD_MIRROR} && set_rdo_cloud_mirror ${HOME}/.mock/${arch}-with-extras.cfg
setup_additional_repos
# Build the RPMs in a clean chroot environment with mock to detect missing
# BuildRequires lines.
mock $MOCKOPTS rebuild --resultdir=${WORKSPACE}/${rpath} ${HOME}/rpmbuild/SRPMS/*.src.rpm 2>&1

popd
