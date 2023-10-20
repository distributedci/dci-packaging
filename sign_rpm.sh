#!/bin/bash -e

if [[ "$#" -lt 1 ]]; then
    echo "USAGE: $0 [<PATH_TO_RPM>]"
    exit 1
fi

add_sign_to_rpm () {
    echo "Signin the rpm with the new key '$1'"
    echo '%_signature gpg' > ~/.rpmmacros
    echo "%_gpg_name $1" >> ~/.rpmmacros

    rpm --addsign $2
}

# Unlock gpg key
while (( "$#" )); do
    PKG="$1"
    [ -f "$PKG" ] || { echo "$PKG: not a file"; exit 1; }
    echo "Signing ${PKG}"

    set +e
    rpm -qi "${PKG}" | egrep -qs "Release\s+:.*\.el9$"
    if [ $? -eq 0 ]; then
        KEY="Distributed-CI EL9 <distributed-ci@redhat.com>"
    else
        KEY="Distributed-CI <distributed-ci@redhat.com>"
    fi
    set -e

    add_sign_to_rpm ${KEY} ${PKG}

    NEW_KEY="Distributed-CI 2024 <distributed-ci@redhat.com>"
    add_sign_to_rpm ${NEW_KEY} ${PKG}

    shift
done
