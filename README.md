# RPM build process

## What does it do ?

This set of scripts is used to build RPM packages and at the same time python modules.


## Scripts

- build_rpm.exp: helper expect script
- build_rpm.sh: main shell script
- config-<platform>.rc: Mock configuration templates (one per target platform)
- rpmbuild.lib: shell library (setup, cleanup, mock profiles generation, SRPM generation etc.)
- sign_rpm.sh: helper shell script used to sign RPMs


## Process

1. generate_mock_profile()
2. setup_build()
3. initialize mock
4. generate_srpm()
   a. set DATE and SHA shell variables used to generate RPM version
   b. generate sdist tarball with version set <semantic version scheme>.dev0+VERS in version.py
   c. generate SRPM with version set to <semantic version scheme>.VERS%{?dist} with VERS replaced by ${DATE}git${SHA}
    build RPM in spec file
5. run mock
6. cleanup (automatically called at exit time)


## Version scheme explanation

### RPM

RPM versioning follows Fedora/RHEL guidelines as [documented](https://docs.fedoraproject.org/en-US/packaging-guidelines/Versioning/). RPM packages are identified by their NVR (Name-Version-Release), based on information from the spec file.

An extract from actual DCI spec file:

```sh
Name:           dci-control-server
Version:        0.3.1   # semantic version
Release:        2.VERS%{?dist} # 2 is the RPM package version and %{?dist} identifies the target distro
Source0:        dci-control-server-%{version}.dev0+VERS.tar.gz

(..)

%prep -a
%autosetup -n %{name}-%{version}.dev0+VERS
```

Since DCI packages are automotically generated through Continuous Delivery, semantic version does not change as often as we publish software. So we need to identify each release with additional information: git SHA1SUM, and build timestamp. So we use VERS as a placeholder to inject the string "${DATE}git${SHA}" which will generate an unique NVR for a specific build. E.g: `dci-control-server-0.3.4-1.202308091244gitaf8356d7.el8.noarch.rpm`


### Python module

Before, we only uploaded python modules when making actual releases, by pushing a tag which triggered the dci-upload-pypi job on the release pipeline.
Since we decided to upload python modules each time, we publish RPMs, the dci-upload-pypi job is now triggered on the dci-post pipeline. So we needed to generate an unique version scheme to distinguish individual builds and be able to map them to their RPM counterparts.

So we append the ".dev0+${DATE}git${SHA}" to the semantic versioning in `version.py` files in DCI packages when generating the python modules (done right before the RPM build". This scheme follows [PEP-0440](https://peps.python.org/pep-0440/)
