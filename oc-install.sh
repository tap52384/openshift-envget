#!/usr/bin/env bash
# https://github.com/olivergondza/bash-strict-mode
set -euo pipefail
trap 's=$?; echo >&2 "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

if [[ "$OSTYPE" == "darwin"* || "$OSTYPE" == "linux"* ]]; then
    # Install Homebrew (https://brew.sh) and necessary libraries
    # Stops if Homebrew could not be installed
    command -V brew || /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)" || exit
    formulas=('openshift-cli' 'source-to-image')
    for formula in "${formulas[@]}"; do
        brew ls --versions "$formula" > /dev/null
        formula_installed=$?
        if [ ! "$formula_installed" -eq 0 ]; then
            echo "Installing '$formula' formula..."
            brew install "$formula"
        else
            echo "Formula '$formula' is already installed; checking for updates..."
            brew upgrade "$formula"
        fi
    done
    # Install Docker if it is not installed already
    command -V docker || brew cask install docker
elif [[ "$OSTYPE" == "cygwin" || "$OSTYPE" == "msys" ]]; then
    echo 'Detected that this script is running within Git Bash...'
    download_path="$HOME/AppData/Local/Microsoft/WindowsApps"

    files=(
        # OpenShift command-line tools
        'openshift.zip'
        # Source-to-Image
        's2i.zip'
    )
    urls=(
        'https://github.com/openshift/origin/releases/download/v3.11.0/openshift-origin-client-tools-v3.11.0-0cbc58b-windows.zip'
        'https://github.com/openshift/source-to-image/releases/download/v1.3.0/source-to-image-v1.3.0-eed2850f-windows-amd64.zip'
    )

    array_length=${#files[@]}
    for (( key=0; key<array_length; key++ ));
    do
        echo "Downloading '${urls[$key]}'..."
        curl -sSL -o "$download_path/${files[$key]}" --url "${urls[$key]}"
        echo "Unzipping '$download_path/${files[$key]}'..."
        unzip -o "${download_path}/${files[$key]}" -d "${download_path}"
        echo "Deleting downloaded file '${download_path}/${files[$key]}'..."
        rm -v "$download_path/${files[$key]}"
    done
    echo "Openshift command-line tools and source-to-image successfully installed."
fi
