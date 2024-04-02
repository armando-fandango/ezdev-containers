#!/bin/sh
set -e

# pnpm
export PNPM_HOME="/home/ezdev/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end

# first arg is `-f` or `--some-option`
if [ "${1#-}" != "${1}" ] || [ -z "$(command -v "${1}")" ] || { [ -f "${1}" ] && ! [ -x "${1}" ]; }; then
	set -- node "$@"
fi

exec "$@"