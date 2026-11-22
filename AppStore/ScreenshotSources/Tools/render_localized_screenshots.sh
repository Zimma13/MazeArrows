#!/bin/zsh
set -eu
exec python3 "${0:A:h}/media_v2.py" render "$@"
