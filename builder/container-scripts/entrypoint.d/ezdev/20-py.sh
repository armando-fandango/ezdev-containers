#!/usr/bin/env bash
# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('/opt/py/bin/conda' 'shell.bash' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/opt/py/etc/profile.d/conda.sh" ]; then
        . "/opt/py/etc/profile.d/conda.sh"
    else
        export PATH="/opt/py/bin:$PATH"
    fi
fi
unset __conda_setup

if [ -f "/opt/py/etc/profile.d/mamba.sh" ]; then
    . "/opt/py/etc/profile.d/mamba.sh"
fi
# <<< conda initialize <<<
mamba activate base
