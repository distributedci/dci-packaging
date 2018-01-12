#!/bin/bash -e

if [[ "$#" -lt 1 ]]; then
    echo "USAGE: $0 [<PATH_TO_RPM>]"
    exit 1
fi

echo '%_signature gpg' > ~/.rpmmacros
echo '%_gpg_name Distributed-CI' >> ~/.rpmmacros

# Unlock gpg key
killall gpg-agent || true
echo fake > fake
echo "--" > psk
chmod 400 psk
gpg2  --passphrase-file psk  -u Distributed-CI --no-tty --yes --batch -s --pinentry-mode loopback fake
rm psk

while (( "$#" )); do
    PKG="$1"
    [ -f "$PKG" ] || { echo "$PKG: not a file"; exit 1; }
    echo "Signing ${PKG}"
    rpm --addsign ${PKG}
    shift
done
