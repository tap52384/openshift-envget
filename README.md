# openshift-envget

A Bash script that creates a .env from a given deploymentconfig in OpenShift and
Kubernetes for the purposes of local development. Tested on Windows (Git Bash) and macOS.

## Description

This script will create a .env file containing all environment files referenced in a given
deploymentconfig. Since the OpenShift command-line tools share much of the functionality
with kubectl, this script will allow you to specify which tool to use.

If the deploymentconfig references secrets, those values will automatically be base64 decoded. For
configmaps, those values will be resolved. Environment variable priority will mimic what is used in
deploymentconfigs, meaning later configmap/secrets take precedence over earlier ones (envFrom), and
environment variables defined directly in the dc/name resource will overwrite those from configmaps
and secrets with the same names.

## Prerequisites

You need at least the [OpenShift command-line tools](https://github.com/openshift/origin/releases)
__v3.11__ or `kubectl` __v1.11__ to use this script as it includes the `base64decode` function
[necessary for easily decoding secrets](https://github.com/kubernetes/kubernetes/pull/60755). If the
requested tool (`oc`, `kubectl`) is not present, the script will exit and let you know.

If you get an error that the resource is not found, make sure you are on the correct project.

The command `kubectl` may be installed along with
[Docker Desktop](https://www.docker.com/products/docker-desktop).

You can use the `oc-install.sh` script in this repository to install the
[OpenShift command-line tools](https://github.com/openshift/origin/releases).

## Usage

These scripts have been tested for Windows ([Git Bash](https://git-scm.com/)) and macOS.

```bash
oc-envget [options] <resource>
```

An example:

```bash
oc-envget --login-url=[https://localhost:8443] --overwrite=true dc/config_name
```

## Command Line Options

* __--django=false__

    If true, the value DJANGO_ALLOWED_HOSTS=localhost,127.0.0.1 is added to the output file, which
    can be useful with the [Django Web Framework](https://docs.djangoproject.com/en/3.0/ref/settings/#allowed-hosts).

* __--filename=''__

    Specifies the output file name. Defaults to `.env` in the current directory. Creates this file
    as needed.

* __--help__

    Shows all options, usage, and script description.

* __--login-url=''__

    The URL for the Kubernetes/OpenShift instance.

* __--overwrite=false__

    If true, overwrites the output file if it exists.

* __--project=''__

    Specifies the project that contains the deploymentconfig. Defaults to the current project.

* __--resource=''__

    The deploymentconfig from which to retrieve environment variables.

* __--tool=oc__

    If `kubectl`, use the Kubernetes tool for controlling clusters.

* __--user=''__

     The login username, defaulting to `$(whoami)`.

## Reference Links
- <https://stackoverflow.com/a/58117444/1620794>
- <https://unix.stackexchange.com/a/261735>
- <https://golang.org/pkg/text/template/>
- <https://stackoverflow.com/a/20348190/1620794>
- <https://github.com/olivergondza/bash-strict-mode>
