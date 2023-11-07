# DCI packaging

For any DCI git repository, you can use the `build_rpm.sh` script to build the corresponding rpm package.

Example:

```shellsession
$ ./build_rpm.sh ../python-dciclient
```

or for a specific RHEL release:

```shellsession
$ ./build_rpm.sh ../python-dciclient epel-9-x86_64
```

## Details

`build_rpm.sh` is leveraging (mock)[https://rpm-software-management.github.io/mock/] to build the rpm package. It creates a chroot environment for the specified RHEL release and architecture, installs the required dependencies, create the source tar ball, edit the rpm spec file, and builds the rpm package.

The source tar ball is created using the `setup.py sdist` command if there is a `setup.py` file in the repository, or using the `git archive` command otherwise.

The rpm spec file is edited to add the version, the git commit hash and the build date using these conventions:

- `SEMVER` is replaced by the version extracted from the `VERSION` file if it exists.
- `VERS` is replaced by `${DATE}git${SHA}` where `${DATE}` is the current date in the format `YYYYmmddHHMM` and `${SHA}` is the short git commit hash.
- `SHA` is replaced by the short git commit hash.
- `DATE` is replaced by the current date in the format `YYYYmmddHHMM`.

### dci-doc

The `dci-doc` repository is a special case. It is using the `./build.sh` script to create the source tar ball from all the other git repositories.
