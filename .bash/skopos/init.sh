#!/bin/bash

if [[ -n $BASH_SCRIPTS ]]; then
  SKOPOS=$BASH_SCRIPTS/skopos/skopos.sh
  export SKOPOS
else
  echo >&2 'Cannot set up skopos environment. $BASH_SCRIPTS env var is not set.'
  exit 10
fi

# Begin Kraken env functions install_skopos
# test
if [[ -e $SKOPOS ]]; then
  echo "Setting up kraken environment"

  source "$SKOPOS"
  alias sk="\$HOME/bin/skopos"
  setup_cluster_env
fi
