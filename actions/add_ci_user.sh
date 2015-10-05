#!/bin/bash

USERNAME=${1}
PASSWORD=${2}
DISTRO=${3}
SALT=${4}

if [ -z ${SALT} ]
then
  SALT='mkpasswd'
fi

if [ -z "${USERNAME}" ]
then
  echo "USERNAME required to created user."
  exit 1
fi

if [ -z "${PASSWORD}" ]
then
  echo "PASSWORD required to created user."
  exit 2
fi

if [ -z "${DISTRO}" ]
then
  echo "DISTRO required."
  exit 3
fi

if [[ "$DISTRO" = UBUNTU* ]]
then
  useradd ${USERNAME} -p `mkpasswd --method=sha-512 $PASSWORD ${SALT}`
elif [[ "$DISTRO" = RHEL* ]]
then
  echo "Created user ${USERNAME}."
  sha512_pass=$(python -c "import crypt; print crypt.crypt('${PASSWORD}', '\$6\$${SALT}\$')")
  useradd ${USERNAME} -p ${sha512_pass}
else
  echo "Unsupported distro ${DISTRO}."
fi
