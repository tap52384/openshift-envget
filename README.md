# openshift-envget

A Bash script that creates a .env from a given deploymentconfig in OpenShift and
Kubernetes for the purposes of local development. Tested on Windows (Git Bash) and macOS.

## Prerequisites

You need at least the [OpenShift command-line tools](https://github.com/openshift/origin/releases)
__v3.11__ or `kubectl` __v1.11__ to use this script as it includes the `base64decode` function
[necessary for easily decoding secrets](https://github.com/kubernetes/kubernetes/pull/60755). If the
requested tool (`oc`, `kubectl`) is not present, the script will exit and let you know.

If you get an error that the resource is not found, make sure you are on the correct project.

The command `kubectl` may be installed along with
[Docker Desktop](https://www.docker.com/products/docker-desktop).

## Reference Links
- <https://stackoverflow.com/a/58117444/1620794>
- <https://unix.stackexchange.com/a/261735>
- <https://golang.org/pkg/text/template/>
- <https://stackoverflow.com/a/20348190/1620794>
- <https://github.com/olivergondza/bash-strict-mode>
