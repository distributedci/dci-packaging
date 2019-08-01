#!/bin/bash
set -eux

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

function set_rdo_cloud_mirror() {
    cfg_file=$1

    sed -i "s#mirrorlist=http://mirrorlist.centos.org/?release=7&arch=x86_64&repo=os#baseurl=http://${RDO_CLOUD_MIRROR}/centos/7/os/x86_64/#g" $cfg_file
    sed -i "s#mirrorlist=http://mirrorlist.centos.org/?release=7&arch=x86_64&repo=updates#baseurl=http://${RDO_CLOUD_MIRROR}/centos/7/updates/x86_64/#g" $cfg_file
}

pushd ${PATH_TO_PROJ}

declare -A repo_conf

repo_conf["gpg_signature"]=''

# CentOS third-party repositories needed
#
repo_conf["epel-7-x86_64"]='
[dci]
name=Distributed CI - CentOS 7
baseurl=https://packages.distributed-ci.io/repos/current/el/7/x86_64/
gpgcheck=1
gpgkey=https://packages.distributed-ci.io/RPM-GPG-KEY-distributedci
enabled=1

[dci-extras]
name=Distributed CI - Extras - CentOS 7
baseurl=http://packages.distributed-ci.io/repos/extras/el/7/x86_64/
gpgcheck=0
enabled=0

[centos-sclo-rh]
name=CentOS-7 - SCLo rh
baseurl=http://mirror.centos.org/centos/7/sclo/$basearch/rh/
gpgcheck=1
enabled=0
gpgkey=https://raw.githubusercontent.com/sclorg/centos-release-scl/master/centos-release-scl/RPM-GPG-KEY-CentOS-SIG-SCLo

[centos-openstack-pike]
name=CentOS-7 - OpenStack Pike
baseurl=http://mirror.centos.org/centos/7/cloud/$basearch/openstack-pike/
gpgcheck=1
enabled=0
gpgkey=https://raw.githubusercontent.com/openstack/puppet-openstack_extras/91fac8eab81d0ad071130887d72338a82c06a7f4/files/RPM-GPG-KEY-CentOS-SIG-Cloud
'

# MISC mock configuration
#
repo_conf["misc"]='
config_opts["use_host_resolv"] = False
config_opts["files"]["etc/hosts"] = """
127.0.0.1 pypi.python.org
"""
config_opts["nosync"] = True
'

# Project specific settings. Needs to be overrided
repo_conf["project_specific"]='
'

# Note: Need to contact the npm registry to retrieve
#       the npm modules.
if [[ "$PROJ_NAME" == "dci-ui" ]]; then
repo_conf["project_specific"]='
config_opts["use_host_resolv"] = True
config_opts["rpmbuild_networking"] = True
'
fi

if [[ -n "$PATH_TO_REPO" ]]; then
repo_conf["project_specific"]='
config_opts["plugin_conf"]["bind_mount_enable"] = True
config_opts["plugin_conf"]["bind_mount_opts"]["dirs"].append(("'$PATH_TO_REPO'", "/tmp/dependency_repo"))
'
fi

# Create the proper filesystem hierarchy to proceed with srpm creatioon
#
rm -rf ${HOME}/rpmbuild && mock --clean
rpmdev-setuptree
if [[ "$PROJ_NAME" == *-distgit ]]; then
    IS_DISTGIT="true"
    SPECS=$(ls  *.spec)
    if [[ ${#SPECS[@]} == 0 ]]; then
        echo "ERROR: No spec file in repository"
        exit 1
    elif [[ ${#SPECS[@]} = 1 ]]; then
        PROJ_NAME=${SPECS[1]//.spec}
    else
        echo "ERROR: Too many spec files in repository ($SPECS[@])"
        exit 1
    fi
fi
cp ${PROJ_NAME}.spec ${HOME}/rpmbuild/SPECS/

if [[ "$PROJ_NAME" == "dci-gpgpubkey" ]]; then
    cp distributed-ci.pub ${HOME}/rpmbuild/SOURCES/
fi

DATE=$(date --utc +%Y%m%d%H%M)
SHA=$(git rev-parse HEAD | cut -c1-8)
if [[ -e setup.py ]]; then
    python setup.py sdist
    cp -v dist/* ${HOME}/rpmbuild/SOURCES/
    if [[ -d contrib/systemd ]]; then
        cp -v contrib/systemd/* ${HOME}/rpmbuild/SOURCES/
    fi
else
    VERS=$(rpmspec -q --qf "%{version}\n" ${HOME}/rpmbuild/SPECS/${PROJ_NAME}.spec|head -n1 2>/dev/null)
    VERS=$(echo $VERS | sed "s/VERS/${DATE}git${SHA}/g")
    if [[ "$PROJ_NAME" == "dci-doc" ]]; then
        ./build.sh
        cp -r docs ${PROJ_NAME}-${VERS}
        tar -czvf ${PROJ_NAME}-${VERS}.tar.gz ${PROJ_NAME}-${VERS}
        mv ${PROJ_NAME}-${VERS}.tar.gz ${HOME}/rpmbuild/SOURCES/
    elif [[ -n "${IS_DISTGIT}" ]]; then
        spectool -g ${PROJ_NAME}.spec -d ${HOME}/rpmbuild/SOURCES/
    else
        git archive HEAD --format=tgz --output=${HOME}/rpmbuild/SOURCES/${PROJ_NAME}-${VERS}.tar.gz
    fi
fi
sed -i "s/VERS/${DATE}git${SHA}/g" ${HOME}/rpmbuild/SPECS/${PROJ_NAME}.spec

rpmbuild -bs ${HOME}/rpmbuild/SPECS/${PROJ_NAME}.spec

for arch in $SUPPORTED_DISTRIBUTIONS; do
    rpath=$(echo ${arch}|sed s,-,/,g|sed 's,epel,el,')
    with_args=""

    mkdir -p ${HOME}/.mock
    cp /etc/mock/${arch}.cfg ${HOME}/.mock/${arch}-with-extras.cfg
    sed -i '$ d' ${HOME}/.mock/${arch}-with-extras.cfg
    cat <<EOF >> ${HOME}/.mock/${arch}-with-extras.cfg
${repo_conf[${arch}]}
"""
${repo_conf[gpg_signature]}
${repo_conf[misc]}
${repo_conf[project_specific]}
EOF

    # Use a TTL=4 to evaluate the distance between the host the mirror
    ping -c 2 -t 4 -W 1 ${RDO_CLOUD_MIRROR} && set_rdo_cloud_mirror ${HOME}/.mock/${arch}-with-extras.cfg

    if [[ "$PROJ_NAME" == "dci-control-server" ]]; then
        with_args="--enablerepo centos-openstack-pike --enablerepo centos-sclo-rh --enablerepo dci-extras"
    elif [[ "$PROJ_NAME" == "python-dciclient" ]]; then
        with_args="--enablerepo centos-sclo-rh"
    fi

    # Build the RPMs in a clean chroot environment with mock to detect missing
    # BuildRequires lines.
    mock -r ${HOME}/.mock/${arch}-with-extras.cfg rebuild ${with_args} --resultdir=${WORKSPACE}/${rpath} ${HOME}/rpmbuild/SRPMS/*.src.rpm 2>&1
done

popd
