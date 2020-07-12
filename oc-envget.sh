#!/usr/bin/env bash
# https://github.com/olivergondza/bash-strict-mode
set -euo pipefail
trap 's=$?; echo >&2 "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
CWD="$(pwd)"

# 0. Define variables that will be used in this script.
django="false"
filename="${CWD}/.env"
login_url=""
overwrite="false"
project=""
resource=""
tool="oc"
user="$(whoami)"
# Variable used for testing
output=""

help_text="EnvGet for OpenShift and Kubernetes

This script will create a .env file containing all environment files referenced in a given
deploymentconfig. Since the OpenShift command-line tools share much of the functionality
with kubectl, this script will allow you to specify which tool to use.

If the deploymentconfig references secrets, those values will automatically be base64 decoded. For
configmaps, those values will be resolved. Environment variable priority will mimic what is used in
deploymentconfigs, meaning later configmap/secrets take precedence over earlier ones (envFrom), and
environment variables defined directly in the dc/name resource will overwrite those from configmaps
and secrets with the same names.

oc v3.11+ and/or kubectl v1.11+ is required to use this script.

Usage:
  oc-envget [options] <resource>

Example:
  oc-envget --login-url=[https://localhost:8443] --overwrite=true dc/config_name

Options:

    --django=false:    If true, the value DJANGO_ALLOWED_HOSTS=localhost,127.0.0.1 is added to the output file.
    --filename='':     Specifies the output file name. Defaults to ${CWD}/.env. Creates this file as needed.
    --help             Shows this text.
    --login-url='':    The URL for the Kubernetes/OpenShift instance.
    --overwrite=false: If true, overwrites the output file if it exists.
    --project='':      Specifies the project that contains the deploymentconfig. Defaults to the current project.
    --resource='':     The deploymentconfig from which to retrieve environment variables.
    --tool=oc:         If \"kubectl\", use the Kubernetes tool for controlling clusters.
    --user='':         The login username, defaulting to \"${user}\".
"

# 1. Show the help text if no parameters are specified or if --help is specified.
# Also, capture any other options that are specified.
if [ ${#} -eq 0 ]; then
    # Print the help text and exit.
    echo "${help_text}"
    exit 0;
fi;

# 2. Handle command line parameters and default values.
for i in "$@"
do
case $i in
    --django=*)
    django="${i#*=}"

    if [ "${django}" = "true" ]; then
        django=true
    fi
    shift # past argument=value
    ;;
    --filename=*)
    filename="${i#*=}"
    shift # past argument=value
    ;;
    -h|--help)
    echo "$help_text"
    exit 0;
    shift # past argument with no value
    ;;
    --login-url=*)
    login_url="${i#*=}"
    shift # past argument=value
    ;;
    --overwrite=*)
    temp="${i#*=}"

    if [ "${temp}" = "true" ]; then
        overwrite=true
    fi
    shift # past argument=value
    ;;
    --project=*)
    project="${i#*=}"
    shift # past argument=value
    ;;
    --resource=*)
    resource="${i#*=}"
    shift # past argument=value
    ;;
    --tool=*)
    tool="${i#*=}"
    shift # past argument=value
    ;;
    --user=*)
    user="${i#*=}"
    shift # past argument=value
    ;;
    *)
    resource="${i}"
    shift
    ;;
esac
done

# 3. Input validation
# Stops if the file exists and overwriting has not be explicitly enabled.
if [ -z "${filename}" ]; then
    echo "You must specify a valid output filename (--filename)."
    exit 1;
fi

if [ -f "${filename}" ] && [ "${overwrite}" != "true" ]; then
    echo "The file ${filename} exists and overwrite is false by default (set --overwrite=true)."
    exit 1;
fi

# Stops if no deploymentconfig resource is specified.
if [ -z "${resource}" ]; then
    echo "You must specify a deploymentconfig, like dc/config_name (--resource)."
    exit 1;
fi

# Stops if an invalid tool is specified
if [ "${tool}" != "oc" ] && [ "${tool}" != "kubectl" ]; then
    echo "You must specify a valid tool, either kubectl or oc (--tool)."
    exit 1;
fi

# Stops if the specified tool is unavailable
if ! command -V "${tool}" &> /dev/null; then
    echo "The specified tool, ${tool}, is not available in the \$PATH (--tool)."
    exit 1;
fi

# Stops if no login URL is specified
if [ -z "${login_url}" ]; then
    echo "You must specify a login URL for accessing ${tool} (--login-url)."
    exit 1;
fi

# Stops if no username is specified
if [ -z "${user}" ]; then
    echo "You must specify your account user name for ${tool} (--user)."
    exit 1;
fi

# 4. Login with the OpenShift command-line tools (oc)
# The "whoami" command gets your computer username; if your computer username is
# not your Onyen, then use your Onyen instead
# If login fails, no need to continue.
oc login "${login_url}" -u "${user}" || exit

# 5. Switch to the specified project, or stay on the current one.
if [ -n "${project}" ]; then
    oc project "${project}" || exit
fi

# 3. List all environment variables loaded from configMaps and secrets
# 3a. Save the names of all configmaps and secrets in order of priority (least to greatest).


# Reads the given string containing environment variables and removes any with the same key name
# from the output file.
function addValues() {
    newValues=$1

    # Delete env variables from the output file that exist in this config map
    while read -r current_line; do
        # Skip ahead if the current line starts with a hash
        # We don't have to worry about comments
        if [[ "${current_line}" == \#* ]]; then
            continue
        fi

        # Get the environment variable key, which is the part before the equal sign.
        # https://stackoverflow.com/a/20348190/1620794
        # Add the equal sign to the end to make sure we're replacing exact matches
        # Escape the equal sign just in case
        envKey="${current_line%%=*}="
        # echo "envKey: ${envKey}"

        # Delete lines in ${filename} that start with ${envKey}
        # If grep doesn't find the current envKey, then it returns 1.
        # However, we want the script to keep going as not finding the key just means there
        # is nothing to replace.
        # We then copy the output file with the keys removed to a temporary
        # file and then copy the contents back to the original output file
        # since your input and output file cannot be the same.
        grep -v "^${envKey}" "${filename}" > "${filename}.tmp" || true
        cp "${filename}.tmp" "${filename}"
    done <<< "${newValues}"

    # This variable is used for testing purposes; stores all new values
    output=$(printf "%s\n%s" "${output}" "${newValues}")

    # Outputs the new values to the output file
    printf "%s\n" "${newValues}" >> "${filename}"
}

# Uses a go-template to retrieve all values for a given secret or configmap.
# Adds the prefix to those values, if any, as specified in the deploymentconfig.
# Here is the command this function is based on:
# # oc get configmap/name -o go-template='{{range $k,$v := .data}}{{printf "%s=" $k}}{{if not $v}}{{$v}}{{else}}{{$v }}{{end}}{{"\n"}}{{end}}'
# oc get secret/db-secrets-edw01dev -o go-template='{{range $k,$v := .data}}{{printf "%s=" $k}}{{if not $v}}{{$v}}{{else}}{{$v | base64decode}}{{end}}{{"\n"}}{{end}}'
# https://stackoverflow.com/a/58117444/1620794
# https://unix.stackexchange.com/a/261735
# uses go-templates instead of jsonpath: https://golang.org/pkg/text/template/
function getValues() {
    # Needs to be either "secret" or "configmap"
    # If "secret", then we will base64 decode the values.
    mapType=$1
    # The name of the secret or configMapRef; used to create the resource name, like
    # configmap/name
    mapName=$2
    # The prefix specified in the deploymentconfig for all values from this secret/configmap
    mapPrefix=$3

    echo "Retrieving values from ${mapType} '${mapName}'..."

    # The template string is the go-template used to process the secret or
    # configmap. $k and $v are not Bash variables!
    template_string="{{range \$k,\$v := .data}}"

    # Apply the given prefix if specified
    if [ -n "${mapPrefix}" ]; then
        template_string="${template_string}{{\"${mapPrefix}\"}}"
    fi

    # If we are processing a secret, then base64decode the values
    template_string="${template_string}{{printf \"%s=\" \$k}}{{if not \$v}}{{\$v}}{{else}}"
    if [ "${mapType}" == "secret" ]; then
        template_string="${template_string}{{\$v | base64decode}}"
    else
        template_string="${template_string}{{\$v}}"
    fi

    # Complete the template string
    template_string="${template_string}{{end}}{{\"\n\"}}{{end}}"

    # Create the command that will retrieve the values using the template string
    temp=$(${tool} get "${mapType}/${mapName}" -o go-template="${template_string}")

    # Delete env variables from the output file that exist in this config map
    addValues "${temp}"
}

# converts the space-delimited list of configMap/secrets to an array
allMaps="$(${tool} get ${resource} -o=jsonpath="{range .spec.template.spec.containers[*].envFrom[*]}[{.prefix}]|[{.configMapRef.name}]|[{.secretRef.name}] {end}")"
# To print ${allMaps} with tabs intact, quote it; otherwise, \t is printed as a space.
# Convert ${allMaps} to an array
read -r -a envFrom <<< "${allMaps}"

# Get the total number of configmaps and secrets
array_length=${#envFrom[@]}

# Creates a backup of the output file if it already exists
if [ -f "${filename}" ]; then
    echo "The file ${filename} exists. A backup will be made before continuing."
    cp "${filename}" "${filename}.bak" || exit
fi
# Creates the output file as necessary
touch "${filename}"
# Clears the output file
true > "${filename}"

# Loops through all secrets/configmaps in order of priority; later environment variables overwrite
# earlier defined ones.
for (( key=0; key<array_length; key++ ));
    do
        # 0. Get the current line which contains values in brackets separated by pipes
        line="${envFrom[$key]}"

        # 1. Replace the pipes with spaces
        line="${line//|/ }"

        # 2. Convert line to an array with these three elements:
        # Prefix (if applicable)
        # Name of configMapRef
        # Name of secretRef
        read -r -a parts <<< "${line}"

        # 3. Capture the prefix, configMapRef name, and secret name
        prefix=${parts[0]//[}
        prefix=${prefix//]}

        configMapRef=${parts[1]//[}
        configMapRef=${configMapRef//]}

        secretRef=${parts[2]//[}
        secretRef=${secretRef//]}

        # 4. Retrieve all of the configMap values with the prefix, if set
        if [ -n "$configMapRef" ]; then
            getValues "configmap" "$configMapRef" "${prefix}"
        fi

        # Prints out the secret values with the prefix, if applicable.
        if [ -n "$secretRef" ]; then
            getValues "secret" "$secretRef" "${prefix}"
        fi
    done

# 4. Add environment variables directly defined on the deploymentconfig itself.
# This code retrieves the values directly from the deploymentconfig, resolving any
# values from secrets
echo "Retrieving values from deploymentconfig '${resource}'..."
temp=$(${tool} set env "${resource}" --resolve=true --list)

# Adds these environment variables values to the output file
addValues "${temp}"

# If the "django" parameter is True, then add this value, replacing any previous
# ones
if [ "${django}" = "true" ]; then
    echo "Adding DJANGO_ALLOWED_HOSTS=localhost,127.0.0.1 as requested..."
    temp="DJANGO_ALLOWED_HOSTS=localhost,127.0.0.1"
    addValues "${temp}"
fi

# Sort the files in place
sort -o "${filename}" "${filename}"

# Prints a success message if the .env file is created and not empty.
if [ -f "${filename}" ] && [ -s "${filename}" ]; then
    # Delete the temporary file
    rm "${filename}.tmp"
    echo "${filename} created successfully."
    exit 0;
else
    echo "Failed to save environment variables to ${filename}."
    exit 1;
fi
