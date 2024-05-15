#!/usr/bin/env bash

SHELL=/bin/bash jupyter notebook --ip='*' --NotebookApp.token='' --NotebookApp.password='' "$@"
