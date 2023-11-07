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

"""Utility functions used by setup.py in other DCI projects
"""

import os
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


# keep this command in sync with the ones in rpmbuild.lib
def extract_sha1():
    "Extract the sha1 of the last commit"
    return run_cmd("git rev-parse --short=8 HEAD")


# keep these commands in sync with the ones in rpmbuild.lib
def extract_date():
    "Extract the date of the last commit"
    ct = run_cmd("git show HEAD -s --format=%ct")
    if ct is not None:
        return run_cmd("date --utc -d @%s +%%Y%%m%%d%%H%%M" % ct)
    return None


def get_version(full=False):
    "Return the version as computed from VERSION and git like '0.0.1-201706261235+gitc2c9c2d'"
    with open("VERSION", "r") as f:
        version = f.read().strip()

    sha1 = extract_sha1()
    date = extract_date()

    if full:
        return "%s.post%s+git%s" % (version, date, sha1)
    else:
        return "%s.post%s" % (version, date)


class sdist(_sdist):
    dci_mod = ""

    def run(self):
        version = get_version(True)

        # Write the version number to the version.py file
        with open(os.path.join(self.dci_mod, "version.py"), "w") as f:
            f.write("__version__ = '%s'\n" % version)

        # Call the superclass's run method to handle the usual sdist creation
        _sdist.run(self)


# dcibuild.py ends here
