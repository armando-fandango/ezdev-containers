#!/usr/bin/env bash

set -e

if [ -z "${ENTRYPOINT_QUIET_LOGS:-}" ]; then
    exec 3>&1
else
    exec 3>/dev/null
fi

cuname=ezdev

echo >&3 "$0: Starting ezdev entrypoint as user `id`"

#chown -R $(id -u):$(id -g) /home/${cuname}

scripts_folder="/opt/container-scripts/entrypoint.d/ezdev/"
if /usr/bin/find "${scripts_folder}" -mindepth 1 -maxdepth 1 -type f -print -quit 2>/dev/null | read v; then
    echo >&3 "$0: ${scripts_folder} is not empty, will attempt to perform configuration"

    echo >&3 "$0: Looking for shell scripts in ${scripts_folder}"
#    FILE_LIST=$(find "${scripts_folder}" -follow -xtype f -print | sort -V )
    FILE_LIST=$(find "${scripts_folder}" -follow -type f -print | sort -V )
    for f in $FILE_LIST; do
        #case "$f" in
        #    *.sh)
                #if [ -x "$f" ]; then
                    echo >&3 "$0: Launching $f";
                    source "$f"
                #else
                #    # warn on shell scripts without exec bit
                #    echo >&3 "$0: Ignoring $f, not executable";
                #fi
        #        ;;
        #    *) echo >&3 "$0: Ignoring $f";;
        #esac
    done

    echo >&3 "$0: Configuration complete; ready for start up"
else
    echo >&3 "$0: No files found in ${scripts_folder}, skipping configuration"
fi

if [ "${1#-}" != "${1}" ] || [ -z "$(command -v "${1}")" ] || { [ -f "${1}" ] && ! [ -x "${1}" ]; }; then
  set -- "echo" "Unknown command " "$@"
fi

echo "executing: $@"
exec "$@"
