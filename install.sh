#!/bin/sh

BASHRC="$HOME/.bashrc"
INSTALLED_STR="installed_skopos"
BASH_SCRIPTS=$HOME/.bash

if mkdir -p $BASH_SCRIPTS 2>/dev/null
then
  if ! cp -avp .bash/ $BASH_SCRIPTS
  then
    echo >&2 "Unable to copy files to $BASH_SCRIPTS"
    exit 8
  fi
fi

# this mkdir will not clobber
if mkdir -p $HOME/bin 2>/dev/null
then
  # This cp will not clobber any
  # existing files without explicit
  # permission.
  if cp -iavp bin/* $HOME/bin
  then
    echo "Files installed successfully..."

  else
    echo >&2 "Installation didn't fully succeed, but things might still be OK."
    exit 2
  fi
else
  echo >&2 "Unable to mkdir $HOME/bin. RC was $?"
  exit 4
fi

if [[ $(grep -c "$INSTALLED_STR" $BASHRC) == 0 ]]
then
  cat <<E >> $BASHRC

## $INSTALLED_STR
export BASH_SCRIPTS=$HOME/.bash
[[ -e $BASH_SCRIPTS/skopos/init_skopos ]] && source $BASH_SCRIPTS/skopos/init_skopos
## end install_skopos
E
else
  echo "Skipping addition to $BASHRC. I think it exists already."
fi

echo "Installation is complete. You should logout and log back in, or source your $BASHRC"
