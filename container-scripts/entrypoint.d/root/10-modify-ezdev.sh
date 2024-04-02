#!/usr/bin/env bash

cuname=ezdev
cgname=ezdev

cuid=$(id -u ${cuname})
cgid=$(id -g ${cgname})

huid=$(stat -c '%u' "${PWD}")
hgid=$(stat -c '%g' "${PWD}")

if [ "${huid}" != "0" ]; then

  echo "$0: Changing the uid:gid to ${huid}:${hgid} to match with working folder: ${PWD}"
  echo "$0: User before change: `id ${cuname}`"

  if [ "${hgid}" != "${cgid}" ]; then 
    sudo groupmod -g $hgid ${cgname}
    echo "$0: Modified group ${cgname} to ${hgid}"
    sudo usermod -a -G $hgid ${cuname}
    echo "$0: Added group ${hgid} to ${cuname}"
  else
    echo "$0: Group ${cgname} already has gid ${hgid}"
  fi

  if [ -S /var/run/docker.sock ]; then
    DOCKER_GID=$(stat -c '%g' /var/run/docker.sock)
    echo "$0: Adding docker's gid ${DOCKER_GID} to ${cuname}"
    sudo groupadd -f -g $DOCKER_GID docker
    sudo usermod -a -G $DOCKER_GID ${cuname}
    echo "$0: Added docker's gid ${DOCKER_GID} to ${cuname}"
  else
    echo "$0: Docker socket not found, skipping docker group configuration"
  fi

  if [ "${huid}" != "${cuid}" ]; then 
    sudo usermod -u ${huid} ${cuname}
    echo "$0: Modified user ${cuname} to ${huid}"
  else
    echo "$0: User ${cuname} already has uid ${huid}"
  fi
  echo "$0: User after change: `id ezdev`"

else
  echo "$0: Working folder: ${PWD} is owned by ${huid}, That leads to permission issues. Please fix the issue and restart container"
  return 1
fi

#set -- gosu ezdev /opt/container-scripts/root/modify-ezdev-2.sh "$@"
#exec "$@"

#sudo groupmod -g $hgid ${cgname}
#sudo usermod -a -G $hgid ${cuname}

#sudo usermod -u $huid ${cuname} 2> /dev/null && {
#sudo groupmod -g $hgid ${cgname} 2> /dev/null || sudo usermod -a -G $hgid ${cuname}
#}

#sudo groupmod -g $hgid ${cgname} 2> /dev/null
#sudo usermod -a -G $hgid ${cuname}

#echo "$0: Changed the user: `id -a ezdev`"
