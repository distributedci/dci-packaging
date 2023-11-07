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

- `VERS` is replaced by `${DATE}git${SHA}` where `${DATE}` is the date of the git commit in the format `YYYYmmddHHMM` and `${SHA}` is the short git commit hash.
- `DATE` is replaced by the current date in the format `YYYYmmddHHMM`.

### dci-doc

The `dci-doc` repository is a special case. It is using the `./build.sh` script to create the source tar ball from all the other git repositories.

## Semantic Versioning

We use (semantic versioning)[https://semver.org/] for the DCI projects. In a nutshell, it means having a version schema like `X.Y.Z` and always incrementing one the components of the version when there is a change. Simplified rules could be like this:

- `X` is incremented when there is a breaking change.
- `Y` is incremented when there is a new feature.
- `Z` is incremented when there is a bug fix or refactoring. This is optional as we do continuous delivery and useful only if you want to be able to use this version in a requirement of another project.

Increment the release field in the rpm spec file if you are just reworking the rpm packaging.

And for any change to the version, add a changelog entry in the rpm spec file.

For continuous delivery reasons, we append a timestamp and the git short commit hash to the rpm version. These extra components (timestamp and sha1) must not be used when setting versioned requirements to a project. Example:

```ini
Requires:       python-dciauth >= 2.1.7
```

and not:
    
```ini
Requires:       python-dciauth >= 2.1.7-201901011200git1234567
```

### Pypi specifics

To continuously upload to pypi, we must also carry the date in the version. To do so, we use the (`dcibuild.py`\)[dcibuild.py] module in the `setup.py` of the projects we want to upload to pypi. This module generates the version string with the date at build time (`python setup.py sdist`) into the proper `version.py` of the project. Examples of this can be found in the `python-dciclient` and `python-dciauth` projects.
