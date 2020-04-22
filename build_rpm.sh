#!/bin/bash
set -eux

source ./rpmbuild.lib

if [[ "$#" -lt 2 ]]; then
    echo "USAGE: ./build_rpm.sh <PATH_TO_PROJ> <PROJ_NAME> [<PATH_TO_REPO>]"
    exit 1
fi

PATH_TO_PROJ=$1
PROJ_NAME=$2
if [[ "$#" == 3 ]]; then
    PATH_TO_REPO=$3
else
    PATH_TO_REPO=""
fi

WORKSPACE='current'
SUPPORTED_DISTRIBUTIONS='epel-7-x86_64'
RDO_CLOUD_MIRROR='mirror.regionone.rdo-cloud.rdoproject.org'

pushd ${PATH_TO_PROJ}


setup_build

generate_srpm

for arch in $SUPPORTED_DISTRIBUTIONS; do
    rpath=$(echo ${arch}|sed s,-,/,g|sed 's,epel,el,')
    with_args=""

    generate_mock_profile
    # Use a TTL=4 to evaluate the distance between the host the mirror
    ping -c 2 -t 4 -W 1 ${RDO_CLOUD_MIRROR} # && set_rdo_cloud_mirror ${HOME}/.mock/${arch}-with-extras.cfg

    if [[ "$PROJ_NAME" == "dci-control-server" ]]; then
        with_args="--enablerepo centos-openstack-rocky --enablerepo centos-sclo-rh --enablerepo dci-extras"
    elif [[ "$PROJ_NAME" == "python-dciclient" ]] || [[ "$PROJ_NAME" == "dci-ui" ]]; then
        with_args="--enablerepo centos-sclo-rh"
    fi

    # Build the RPMs in a clean chroot environment with mock to detect missing
    # BuildRequires lines.
    mock -r ${HOME}/.mock/${arch}-with-extras.cfg rebuild ${with_args} --resultdir=${WORKSPACE}/${rpath} ${HOME}/rpmbuild/SRPMS/*.src.rpm 2>&1
done

popd
