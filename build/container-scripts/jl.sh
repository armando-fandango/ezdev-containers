#!/usr/bin/env bash

SHELL=/bin/bash jupyter lab --ip='*' --NotebookApp.token='' --NotebookApp.password='' "$@"
