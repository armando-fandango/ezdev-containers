#!/usr/bin/env bash
JUPYTER_CMD="${JUPYTER_CMD:=lab}"
SHELL=/bin/bash jupyter ${JUPYTER_CMD} --ip='*' --NotebookApp.token='' --NotebookApp.password='' --no-browser &
