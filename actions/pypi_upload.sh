#!/bin/bash
set -e

REPO="$1"
PROJECT="$2"
VERSION="$3"
FORK="$4"
LOCAL_REPO="$5"
PYPI_USERNAME="$6"
PYPI_PASSWORD="$7"
GIT_REPO="git@github.com:${FORK}/${REPO}.git"
BRANCH="v${VERSION%*.*}"
CWD=$(pwd)
VENV_PATH="~/venv-pypi"

function cleanup()
{
    echo "Cleaning up pypi upload environment"
    cd "${CWD}"
    rm -rf "${LOCAL_REPO}" "${PYPIRC}" "${VENV_PATH}"
}

# Check the branch is actually available.
if ! git ls-remote --heads "${GIT_REPO}" | grep -q "refs/heads/${BRANCH}"; then
    >&2 echo "ERROR: Branch ${BRANCH} does not exist in ${GIT_REPO}."
    exit 1
fi

# Generate local repository directory name if not provided.
test -z "${LOCAL_REPO}" && LOCAL_REPO="${REPO}_$(date +'%s')_$(($RANDOM % 899 + 100))"

# Remove local repository if it already exists.
test -d "${LOCAL_REPO}" && rm -rf "${LOCAL_REPO}"

# Clean up on exit.
trap cleanup EXIT

echo "Cloning ${GIT_REPO} to ${LOCAL_REPO}..."
git clone "${GIT_REPO}" "${LOCAL_REPO}"

cd "${LOCAL_REPO}"
echo "Currently at directory $(pwd)..."
echo "Checkout out branch ${BRANCH}..."
git checkout -b "${BRANCH}" "origin/${BRANCH}"

# Create pypirc
PYPIRC=~/.pypirc

test -e "${PYPIRC}" &&  rm -f "${PYPIRC}"

cat <<EOF >"${PYPIRC}"
[distutils]
index-servers =
    pypi
    pypitest

[pypi]
username: ${PYPI_USERNAME}
password: ${PYPI_PASSWORD}

[pypitest]
username: ${PYPI_USERNAME}
password: ${PYPI_PASSWORD}
EOF

if [[ ! -e "${PYPIRC}" ]]; then
    >&2 echo "ERROR: Unable to write file ${PYPIRC}"
    exit 1
fi

# Hack for cases where a git repo has multiple projects (i.e. st2/st2client)
if [[ "${REPO}" != "${PROJECT}" ]]; then
    cd "./${PROJECT}"
fi

echo "Currently at directory $(pwd)..."
echo "Setup virtual envronment for pypi"
export DEBIAN_FRONTEND=noninteractive
sudo apt -y install python3-venv

echo "Activate virtual environment"
python3 -m venv "$VENV_PATH"
source "${VENV_PATH}/bin/activate"

pip install -U twine wheel
python3 setup.py sdist bdist_wheel
twine --no-color upload --disable-progress-bar --verbose --skip-existing dist/* --repository pypi
if [[ $? != 0 ]]; then
    echo "Error uploading assets to pypi" >&2
    exit 1
fi

deactivate
