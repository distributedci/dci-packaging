#!/bin/bash -e

if [[ "$#" -lt 1 ]]; then
    echo "USAGE: $0 [<PATH_TO_RPM>]"
    exit 1
fi


# Unlock gpg key
while (( "$#" )); do
    PKG="$1"
    [ -f "$PKG" ] || { echo "$PKG: not a file"; exit 1; }
    echo "Signing ${PKG}"

    rpm -qi "${PKG}" | egrep -qs "Release\s+:.*\.el9$"
    if [ $? -eq 0 ]; then
        KEY="Distributed-CI EL9 <distributed-ci@redhat.com>"
    else
        KEY="Distributed-CI <distributed-ci@redhat.com>"
    fi

    echo "Using key '${KEY}'"
    echo '%_signature gpg' > ~/.rpmmacros
    echo "%_gpg_name ${KEY}" >> ~/.rpmmacros

    rpm --addsign ${PKG}

    shift
done
