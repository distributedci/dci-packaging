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
SUPPORTED_DISTRIBUTIONS='fedora-26-x86_64 epel-7-x86_64'

pushd ${PATH_TO_PROJ}

# Configure rpmmacros to enable signing packages
#
echo '%_signature gpg' >> ~/.rpmmacros
echo '%_gpg_name Distributed-CI' >> ~/.rpmmacros

declare -A repo_conf
# Specify the mock options so the generated packages will
# be signed
repo_conf["gpg_signature"]='
config_opts["plugin_conf"]["sign_enable"] = True
config_opts["plugin_conf"]["sign_opts"] = {}
config_opts["plugin_conf"]["sign_opts"]["cmd"] = "rpmsign"
config_opts["plugin_conf"]["sign_opts"]["opts"] = "--addsign %(rpms)s"
'

# Fedora third-party repositories needed
#
repo_conf["fedora-26-x86_64"]='
[dci-deps-ci]
name=Distributed CI - Packaged build during CI
baseurl=file:///tmp/dependency_repo/development/fedora/26/x86_64/
gpgcheck=0
enabled=1
skip_if_unavailable=1
priority=1

[dci]
name=Distributed CI - Fedora
baseurl=https://packages.distributed-ci.io/repos/current/fedora/26/x86_64/
gpgcheck=1
gpgkey=https://packages.distributed-ci.io/RPM-GPG-KEY-distributedci
enabled=1

[dci-devel]
name=Distributed CI - Devel - Fedora
baseurl=http://packages.distributed-ci.io/repos/development/fedora/26/x86_64/
gpgcheck=1
gpgkey=https://packages.distributed-ci.io/RPM-GPG-KEY-distributedci
enabled=1

[openstack-pike]
name=OpenStack Pike Repository
baseurl=http://mirror.centos.org/centos/7/cloud/$basearch/openstack-pike/
gpgcheck=1
enabled=1
gpgkey=https://raw.githubusercontent.com/openstack/puppet-openstack_extras/91fac8eab81d0ad071130887d72338a82c06a7f4/files/RPM-GPG-KEY-CentOS-SIG-Cloud
includepkgs=python2-pifpaf
'

# CentOS third-party repositories needed
#
repo_conf["epel-7-x86_64"]='
[dci-deps-ci]
name=Distributed CI - Packaged build during CI
baseurl=file:///tmp/dependency_repo/development/el/7/x86_64/
gpgcheck=0
enabled=1
skip_if_unavailable=1
priority=1

[elasticsearch-2.x]
name="Elasticsearch repository for 2.x packages"
baseurl=http://packages.elastic.co/elasticsearch/2.x/centos
gpgcheck=1
enabled=1
gpgkey=https://packages.elastic.co/GPG-KEY-elasticsearch

[dci]
name=Distributed CI - CentOS 7
baseurl=https://packages.distributed-ci.io/repos/current/el/7/x86_64/
gpgcheck=1
gpgkey=https://packages.distributed-ci.io/RPM-GPG-KEY-distributedci
enabled=1

[dci-devel]
name=Distributed CI - Devel - CentOS 7
baseurl=http://packages.distributed-ci.io/repos/development/el/7/x86_64/
gpgcheck=1
gpgkey=https://packages.distributed-ci.io/RPM-GPG-KEY-distributedci
enabled=1

[dci-extras]
name=Distributed CI - Extras - CentOS 7
baseurl=http://packages.distributed-ci.io/repos/extras/el/7/x86_64/
gpgcheck=0
enabled=1

[centos-openstack-pike]
name=CentOS-7 - OpenStack Pike
baseurl=http://mirror.centos.org/centos/7/cloud/$basearch/openstack-pike/
gpgcheck=1
enabled=1
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
cp ${PROJ_NAME}.spec ${HOME}/rpmbuild/SPECS/

if [[ "$PROJ_NAME" == "dci-gpgpubkey" ]]; then
    cp distributed-ci.pub ${HOME}/rpmbuild/SOURCES/
fi

non_py_projects=("dci-ansible", "dci-ansible-agent", "dci-ui", "ansible-role-dci-feeders", "ansible-role-openstack-stackdump", "ansible-role-openstack-certification", "ansible-role-openstack-rally", "ansible-role-httpd", "dci-doc")
if [[ -e setup.py ]]; then
    DATE=$(date +%Y%m%d%H%M)
    SHA=$(git rev-parse HEAD | cut -c1-8)
    WORKSPACE='development'
    python setup.py sdist
    cp -v dist/* ${HOME}/rpmbuild/SOURCES/
    if [[ -d contrib/systemd ]]; then
        cp -v contrib/systemd/* ${HOME}/rpmbuild/SOURCES/
    fi
    sed -i "s/VERS/${DATE}git${SHA}/g" ${HOME}/rpmbuild/SPECS/${PROJ_NAME}.spec
elif [[ "${non_py_projects[@]}" =~ "${PROJ_NAME}" ]]; then
    DATE=$(date +%Y%m%d%H%M)
    SHA=$(git rev-parse HEAD | cut -c1-8)
    WORKSPACE='development'
    if [[ "$PROJ_NAME" == "dci-doc" ]]; then
        cp -r docs ${PROJ_NAME}-0.0.${DATE}git${SHA}
        tar -czvf ${PROJ_NAME}-0.0.${DATE}git${SHA}.tar.gz ${PROJ_NAME}-0.0.${DATE}git${SHA}
        mv ${PROJ_NAME}-0.0.${DATE}git${SHA}.tar.gz ${HOME}/rpmbuild/SOURCES/
    else
        git archive HEAD --format=tgz --output=${HOME}/rpmbuild/SOURCES/${PROJ_NAME}-0.0.${DATE}git${SHA}.tar.gz
    fi

    sed -i "s/VERS/${DATE}git${SHA}/g" ${HOME}/rpmbuild/SPECS/${PROJ_NAME}.spec
fi

rpmbuild -bs ${HOME}/rpmbuild/SPECS/${PROJ_NAME}.spec

for arch in $SUPPORTED_DISTRIBUTIONS; do
    rpath=$(echo ${arch}|sed s,-,/,g|sed 's,epel,el,')

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

    # Note: for the dci-control-server project
    if [[ "$PROJ_NAME" == "dci-control-server" ]]; then
        PROJ_NAME=dci
    fi

    # Build the RPMs in a clean chroot environment with mock to detect missing
    # BuildRequires lines.
    mock -r ${HOME}/.mock/${arch}-with-extras.cfg rebuild --resultdir=${WORKSPACE}/${rpath} ${HOME}/rpmbuild/SRPMS/${PROJ_NAME}*
done

popd
