#
# Copyright (C) 2023 Red Hat, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.

"""Utility functions used by setup.py in other DCI projects"""

import datetime
import os
import re
import subprocess
from setuptools.command.sdist import sdist as _sdist


def run_cmd(cmd):
    "Run a command and return its output"
    p = subprocess.Popen(cmd.split(" "), stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    out, err = p.communicate()
    if err:
        print("Error: %s" % err)
        raise Exception("Error running command: %s" % cmd)
    return out.strip().decode("UTF-8")


def extract_epoch():
    "Extract the UNIX epoch of the last commit"
    return int(run_cmd("git show HEAD -s --format=%ct"))


# keep these commands in sync with the ones in rpmbuild.lib
def extract_date(epoch):
    "Extract the date of the last commit"
    return datetime.datetime.fromtimestamp(epoch, datetime.timezone.utc).strftime(
        "%Y%m%d%H%M"
    )


def get_local_version(epoch):
    """Return the version extracted from the .spec file like '0.0.1'

    If the version contains the EPOCH string, replace it with the given UNIX epoch."""
    spec = [f for f in os.listdir(".") if f.endswith(".spec")][0]
    with open(spec) as f:
        content = f.read()
    res = re.search(r"^Version:\s*(\S+)\s*$", content, re.I | re.M)
    local_version = res.group(1)
    if "EPOCH" in local_version:
        return local_version.replace("EPOCH", str(epoch))
    return local_version


def get_version():
    "Return the version as computed from VERSION and git like '0.0.1.post201706261235'"

    epoch = extract_epoch()
    date = extract_date(epoch)
    version = get_local_version(epoch)

    return "%s.post%s" % (version, date)


def write_version(module):
    version = get_version()

    with open(os.path.join(module, "__init__.py"), "w") as f:
        f.write("__version__ = '%s'\n" % version)


### Remove after me after all projects constains pyproject.toml


# keep this command in sync with the ones in rpmbuild.lib
def extract_sha256():
    "Extract the sha56 of the last commit"
    return run_cmd("git rev-parse --short=8 HEAD")


def get_full_version():
    "Return the full version as computed from VERSION and git like '0.0.1.post201706261235+gitc2c9c2d'"

    epoch = extract_epoch()
    version = get_local_version(epoch)
    sha56 = extract_sha256()
    date = extract_date(epoch)

    return "%s.post%s+git%s" % (version, date, sha56)


class sdist(_sdist):
    dci_mod = ""

    def run(self):
        version = get_full_version()

        # Write the version number to the version.py file
        with open(os.path.join(self.dci_mod, "version.py"), "w") as f:
            f.write("__version__ = '%s'\n" % version)

        # Call the superclass's run method to handle the usual sdist creation
        _sdist.run(self)


# dcibuild.py ends here
