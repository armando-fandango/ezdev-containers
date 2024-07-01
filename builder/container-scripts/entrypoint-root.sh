#!/usr/bin/env bash

# /opt/container-scripts/entrypoint.d contains the entrypoint scripts
# all scripts in .d/root are executed as root
# all scripts in .d/ezdev are executed as ezdev

set -e

if [ -z "${ENTRYPOINT_QUIET_LOGS:-}" ]; then
    exec 3>&1
else
    exec 3>/dev/null
fi

#CONTAINER_ALREADY_STARTED="/tmp/CONTAINER_ALREADY_STARTED_PLACEHOLDER"
#if [ ! -e $CONTAINER_ALREADY_STARTED ]; then
#    touch $CONTAINER_ALREADY_STARTED
#    echo "-- First container startup --"
#else
#    echo "-- Second or later container startup --"
#fi

echo >&3 "$0: Started root entrypoint as user `id`"

#if [[ $(id -u) -ne 0 ]]; then
#  echo "$0: Container started as non-root. Skipping root entrypoints"
#fi

scripts_folder="/opt/container-scripts/entrypoint.d/root/"
if /usr/bin/find "${scripts_folder}" -mindepth 1 -maxdepth 1 -type f -print -quit 2>/dev/null | read v; then
    echo >&3 "$0: ${scripts_folder} is not empty, will attempt to perform configuration"

    echo >&3 "$0: Looking for shell scripts in ${scripts_folder}"
    #FILE_LIST=$(find "${scripts_folder}" -follow -xtype f -print | sort -V )
    FILE_LIST=$(find "${scripts_folder}" -follow -type f -print | sort -V )
    for f in $FILE_LIST; do
        #case "$f" in
        #    *.sh)
                #if [ -x "$f" ]; then
                    echo >&3 "$0: Launching $f";
                    source "$f"
                    if [ $? -ne 0 ]; then
                        echo >&3 "$0: Error while executing $f, exiting"
                        exit 1
                    fi
                #else
                #    # warn on shell scripts without exec bit
                #    echo >&3 "$0: Ignoring $f, not executable";
                #fi
        #        ;;
        #    *) echo >&3 "$0: Ignoring $f";;
        #esac
    done

    echo >&3 "$0: root configuration complete"
else
    echo >&3 "$0: No files found in ${scripts_folder}, skipping root configuration"
fi

echo >&3 "$0: Ending root entrypoint as user `id`"

export GOSU_PLEASE_LET_ME_BE_COMPLETELY_INSECURE_I_GET_TO_KEEP_ALL_THE_PIECES="I've seen things you people wouldn't believe. Attack ships on fire off the shoulder of Orion. I watched C-beams glitter in the dark near the Tannhäuser Gate. All those moments will be lost in time, like tears in rain. Time to die."

#ls -la /usr/sbin | grep gosu  # gosu is -rwsr-sr-x 1 root root   1286720 Dec  7  2021 gosu
set -- gosu ezdev /opt/container-scripts/entrypoint-ezdev.sh "$@"

#set -- /opt/container-scripts/entrypoint-ezdev.sh "$@"

exec "$@"