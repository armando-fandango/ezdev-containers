#!/usr/bin/env bash

cuname=ezdev
cgname=ezdev

cuid=$(id -u ${cuname})
cgid=$(id -g ${cgname})

if [[ -v HUID && -z $HUID ]]; then
  echo "$0: HUID is set to empty, skipping user modification"
elif [[ -v HUID && $HUID -lt 1 ]]; then
  echo "$0: Error: Can't set uid to $HUID"    
  return 1
elif [[ -v HGID && $HGID -lt 1 ]]; then
  echo "$0: Error: Can't set gid to $HGID"
  return 1
else
  HUID=${HUID:-$(stat -c '%u' "${PWD}")}
  HGID=${HGID:-$(stat -c '%g' "${PWD}")}
  
  #huid=$(stat -c '%u' "${PWD}")
  #hgid=$(stat -c '%g' "${PWD}")

  if [[ "${HUID}" -eq "0" ]]; then
    echo "$0: Error: Working folder ${PWD} is owned by user ${HUID}, That leads to permission issues. Please fix the issue and restart container"
    return 1  
  elif [[ "${HGID}" -eq "0" ]]; then
    echo "$0: Error: Working folder ${PWD} is owned by group ${HGID}, That leads to permission issues. Please fix the issue and restart container"
    return 1  
  else
    # if docker socket is mounted then add host docker group to container user
    if [[ -S /var/run/docker.sock ]]; then
      DOCKER_GID=$(stat -c '%g' /var/run/docker.sock)
      echo "$0: Docker socket found, adding docker's gid ${DOCKER_GID} to ${cuname}"
      sudo groupadd -f -g ${DOCKER_GID} docker
      sudo usermod -a -G ${DOCKER_GID} ${cuname}
      echo "$0: Added docker's gid ${DOCKER_GID} to ${cuname}"
    else
      echo "$0: Docker socket not found, skipping docker group configuration"
    fi

    echo "$0: Changing the uid:gid to ${HUID}:${HGID} to match with working folder: ${PWD}"
    echo "$0: User ${cuname} before change: $(id ${cuname})"

    if [[ "${HGID}" != "${cgid}" ]]; then 
      # renamme the ezdev group to ezdev-old
      sudo groupmod -n ${cgname}-old ${cgname}
      echo "$0: Renamed group ${cgname} to ${cgname}-old"
      # add the new group
      sudo groupadd -g ${HGID} ${cgname}
      #sudo groupmod -g ${HGID} ${cgname}
      echo "$0: Added group ${HGID} as ${cgname}"
      # make new group as user's primary group
      sudo usermod -g ${HGID} ${cuname}
      echo "$0: Added group ${HGID} to ${cuname}"
      # Add old group to user
      sudo usermod -a -G ${cgid} ${cuname}
      echo "$0: Added old group ${cgid} to ${cuname}"
    else
      echo "$0: Group ${cgname} already has gid ${HGID}"
    fi

    if [[ "${HUID}" != "${cuid}" ]]; then 
      sudo usermod -u ${HUID} ${cuname}
      echo "$0: Modified user ${cuname} to ${HUID}"
    else
      echo "$0: User ${cuname} already has uid ${HUID}"
    fi
    echo "$0: User ${cuname} after change: $(id ${cuname})"
  fi
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
