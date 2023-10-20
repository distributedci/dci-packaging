#!/bin/bash -e

if [[ "$#" -lt 1 ]]; then
    echo "USAGE: $0 [<PATH_TO_RPM>]"
    exit 1
fi

add_sign_to_rpm () {
    echo "Signing the rpm with the new key '$1'"
    echo '%_signature gpg' > ~/.rpmmacros
    echo "%_gpg_name $1" >> ~/.rpmmacros

    rpm --addsign $2
}

# Unlock gpg key
while (( "$#" )); do
    PKG="$1"
    [ -f "$PKG" ] || { echo "$PKG: not a file"; exit 1; }
    echo "Signing ${PKG}"

    NEW_KEY="Distributed-CI 2024 <distributed-ci@redhat.com>"
    add_sign_to_rpm "${NEW_KEY}" "${PKG}"

    shift
done
