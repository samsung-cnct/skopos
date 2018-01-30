#!/bin/bash

kraken_env() {
  KRAKEN=${HOME}/.kraken # This is the default output directory for Kraken
  SSH_ROOT=${HOME}/.ssh
  AWS_ROOT=${HOME}/.aws
  AWS_CONFIG=${AWS_ROOT}/config # Use these files when using the aws provider
  AWS_CREDENTIALS=${AWS_ROOT}/credentials
  SSH_KEY=${SSH_ROOT}/id_rsa # This is the default rsa key configured
  SSH_PUB=${SSH_ROOT}/id_rsa.pub
  K2OPTS="-v ${KRAKEN}:${KRAKEN}
          -v ${SSH_ROOT}:${SSH_ROOT}
          -v ${AWS_ROOT}:${AWS_ROOT}
          -e HOME=${HOME}
          --rm=true
          -it"

  export KRAKEN SSH_ROOT AWS_ROOT AWS_CONFIG AWS_CREDENTIALS \
    SSH_KEY SSH_PUB K2OPTS
}

cluster_name() {
  # only bad thing about this is that it relies on the name of the config to be "config.yaml"
  # hmmmm.
  clname=$(yaml2json <"$KRAKEN/config.yaml" - | jq -rc '.deployment.clusters[0].name')

  if [[ $clname == "null" ]]; then
    # try this for commontools cluster:
    clname=$(yaml2json <"$KRAKEN/config.yaml" - | jq -rc '.deployment.cluster')
  fi

  echo "$clname"
}

cluster_path() {
  if [[ -d $KRAKEN || -s $KRAKEN ]]; then
    #cluster_cfg=$(basename $(find $KRAKEN/ -maxdepth 1 -type d -not \( -path $KRAKEN/ \) -name 'admin.kubeconfig') 2>/dev/null)

    CLUSTER_NAME="$(cluster_name)"
    export CLUSTER_NAME

    if [[ -z $CLUSTER_NAME || $clname == "null" ]]; then
      echo >&2 "Have you edited in $KRAKEN/config.yaml yet? This env is not valid yet."
    fi
  else
    echo >&2 'Sorry. There does not seem to be a proper .kraken environment IE ~/.kraken'
    return 50
  fi
}

setup_cluster_env() {
  [[ -d $HOME/.helm ]] && GLOBAL_HELM=$HOME/.helm

  if kraken_env; then
    cluster_path &&
      KUBECONFIG=$KRAKEN/$CLUSTER_NAME/admin.kubeconfig &&
      HELM_HOME=$KRAKEN/.helm &&
      export CLUSTER_NAME KUBECONFIG HELM_HOME

    alias k='kubectl'
    alias kg='kubectl get -o wide'
    alias k2="kubectl --kubeconfig=\$KUBECONFIG"
    alias k2g="kubectl --kubeconfig=\$KUBECONFIG get -o wide"
    alias k2ga="kubectl --kubeconfig=\$KUBECONFIG get -o wide --all-namespaces"
    alias kssh="ssh -F \$KRAKEN/\$CLUSTER_NAME/ssh_config "

    if [[ -d $KRAKEN ]]; then
      if [[ -n $GLOBAL_HELM && ! -d $KRAKEN/.helm ]]; then
        #      echo -e "\nLinking $KRAKEN/.helm to $HOME/.helm"
        #      echo -e "If this is undesirable, run 'rm \$KRAKEN/.helm'\n"
        ln -sf "$GLOBAL_HELM" "$KRAKEN/"
      else
        if [[ -e $KRAKEN/.helm && ! -L $KRAKEN/.helm ]]; then
          if mv "$KRAKEN/.helm" "$KRAKEN/dot.helm" 2>/dev/null; then
            if ! ln -sf "$GLOBAL_HELM" "$KRAKEN/"; then
              echo >&2 "Unable to link global .helm to cluster space. mv error code was $?"
            fi
          else
            echo >&2 """
  Your cluster space already has a .helm in it and it could not be moved.
  mv error code was $?
            """
          fi
        else
          if ! ln -sf "$GLOBAL_HELM" "$KRAKEN/"; then
            echo >&2 "Unable to link global .helm to cluster space. mv error code was $?"
          fi
        fi
      fi
    fi

    [[ -z $INITIAL_CLUSTER_SETUP ]] &&
      echo "Cluster path found: $CLUSTER_NAME. Exports set. Alias for kssh created."
  else
    [[ -z $INITIAL_CLUSTER_SETUP ]] &&
      echo >&2 "No kraken clusters found. Skipping env setup. Run 'skopos' when one is up"
  fi

  [[ -z $INITIAL_CLUSTER_SETUP ]] && export INITIAL_CLUSTER_SETUP=1
}

skopos_switch() {
  local new_cfg_loc new_base

  if [[ -n $1 ]]; then
    new_cfg_loc="$1"
  else
    echo "switch requires valid environment name"
    return 70
  fi

  new_base=$(dirname "$KRAKEN")/.kraken-$new_cfg_loc

  if [[ -d $new_base ]]; then
    if rm "$KRAKEN" 2>/dev/null || true; then
      if ln -vsf "$new_base" "$KRAKEN"; then
        unset INITIAL_CLUSTER_SETUP
      else
        echo >&2 "Will not continue. Your kraken env: '$KRAKEN' is not a symlink."
        return 7
      fi
    else
      echo >&2 "Unable to remove old symlink '$KRAKEN', so giving up. Ret code for rm was: $?"
      return 8
    fi
  else
    echo >&2 "the environment '$new_cfg_loc' does not exist"
    return 9
  fi
}

skopos_cleanup() {
  if [[ ! -f $KRAKEN/config.yaml ]]; then
    echo >&2 """
 Your Kraken environment exists, but I can't find a valid config.yaml.
 You may need to create it manually if the 'kraken generate' command
 did not successfully create it. Sometimes 'kraken generate' hangs when
 attempting to generate the configuration. To create your config.yaml
 simply run:

 kraken generate --provider <aws|gcp>

 and then don't forget to edit $KRAKEN/config.yaml to reflect your 
 necessary requirements. It will need at a minimum the name of your
 cluster. You can run the following to fix that automatically:

   sed -ri 's/(^\ +- name:)$/\1 $new_cfg_loc/' $KRAKEN/config.yaml
 """
  else
    if sed -ri 's/(^\ +- name:)$/\1 '"$new_cfg_loc"'/' "$KRAKEN/config.yaml"; then
      echo "Updated config.yaml with your cluster name: '$new_cfg_loc'"
    fi
  fi
}

skopos_create_env() {
  if [[ -n $1 ]]; then
    local new_cfg_loc="$1"
    new_base=$KRAKEN-$new_cfg_loc
    shift 2
  else
    echo "skopos_create_env(): requires valid environment name"
    return 70
  fi

  if [[ $* =~ -- ]]; then
    # OK. Now pass arguments from user on to kraken
    set -- "$@"
  else
    shift
  fi

  if [[ ! -d $new_base ]]; then
    if mkdir -p "$new_base"; then
      echo "Directory: $new_base created successfully"
    else
      echo >&2 "Unable to create '$new_base': exit code was $?"
      return 91
    fi
  fi

  if skopos_switch "$new_cfg_loc"; then
    echo "Now Running: kraken generate $*"
    kraken generate "$@"

    ## I liked the way the following works but it's too complicated
    ## and it rewrites the structure of the config.yaml in such a way
    ## that it's less manageable.
    #      < $KRAKEN/config.yaml yaml2json - | \
    #        jq -rcM --arg "newenv" $new_cfg_loc '. | .deployment.clusters[0].name = "$newenv"' | \
    #        json2yaml - > $KRAKEN/skopos-$new_cfg_loc.yaml
    ##
    ## So we'll just do it this way.
    skopos_cleanup
  fi
}

skopos_init() {
  local new_cfg_loc

  if [[ -n $1 ]]; then
    new_cfg_loc="$1"
  else
    echo "'init' requires valid new environment name"
    return 70
  fi

  if mv "$KRAKEN" "$KRAKEN-$new_cfg_loc" >/dev/null; then
    skopos_switch "$new_cfg_loc"
  fi
}

skopos_list() {
  if [[ ! -L $KRAKEN ]]; then
    echo >&2 "Skopos doesn't seem to be set up. Please run 'skopos init'"
    skopos_usage
  fi

  if [[ -e "$KRAKEN-*" ]]; then
    echo -e "\nThe following kraken environment(s) exist..."
    echo -e "(currently select environment is marked with a '*')\n"
  fi

  for d in "$KRAKEN-"*; do
    d=${d#*-*}

    [[ $(realpath "$KRAKEN") == *.kraken-$d ]] &&
      echo ' *  '"$d" ||
      echo '    '"$d"
  done
  echo
}

skopos_rm() {
  local env_to_rm=$1

  if [[ -z $env_to_rm ]]; then
    echo >&2 "usage: skopos rm <envname>"
    skopos_usage
    return 20
  fi

  echo """
  Skopos will not remove any environments as yet. That currently
  is your responsibility so as not to accidentally remove an env
  without explicit knowledge. To remove an environment one should
  do the following:

    # step 1
    $ skopos list

    ... find an environment other than the one you want to 
        remove. If there are no other environments then skip to #4.

    # step 2
    $ skopos switch env_other_than_the_one_you_want_rm

    # step 3
    $ rm -rf \$KRAKEN-$env_to_rm

    # step 4 -- skip this step if you ran step 3.
    # If you are removing your only Kraken env, you're likely
    # starting over from scratch or something, so you will
    # likely want to remove everything. If you do this, you
    # may be removing stuff you need if you've run this cluster.
    # Run this at your own expense!
    $ rm -rf \$KRAKEN

    # Reset any env vars
    unset KUBECONFIG HELM_HOME CLUSTER_NAME K2OPTS

    tl;dr

    copy and paste the following after running 'skopos sw <some_other_cluser>':

    rm -rf \$KRAKEN-$env_to_rm && unset KUBECONFIG HELM_HOME CLUSTER_NAME K2OPTS

"""
}

skopos_usage() {
  echo """
  Usage: skopos [init <name>] [list] [switch <name>] [create <name> 
                [-- kraken args]] [remove <name>] [help] -- <kraken args>

  c|create     : Creates a new skopos env and switches to it.
  i|init       : Initialize new skopos env.
  l|ls|list    : List all kraken environments available.
  s|sw|switch  : Switch to kraken environment.
  r|rm|remove  : Explains how to remove an environment.
  h|help       : This message.

  IMPORTANT NOTE:

  The create argument will pass along all additional arguments
  to kraken when arguments are separated by a '--' IE

  kraken create foo-cluster -- --provider gke

  will create a Kraken GKE cluster config in a newly created
  'foo-cluster' path.

"""
}

# http://www.biblestudytools.com/lexicons/greek/nas/skopos.html
## This is the main function
skopos() {
  trap "skopos_cleanup" INT

  local prereqs="yaml2json jq ruby"

  for pr in $prereqs; do
    if ! which "$pr" >/dev/null 2>&1; then
      echo 2>&"Pre-requisite '$pr' is not found on system or in \$PATH"
      return 60
    fi
  done

  if which kraken >/dev/null 2>&1; then
    #    setup_cluster_env

    if [[ -n $KRAKEN ]]; then
      while [[ $1 ]]; do
        case $1 in
        list | l | ls)
          shift
          set -- "$@"
          skopos_list "$*"
          ;;
        switch | s | sw)
          shift
          set -- "$@"
          skopos_switch "$*"
          setup_cluster_env
          break
          ;;
        help | h | -h | --help)
          shift
          skopos_usage
          break
          ;;
        init | i)
          shift
          set -- "$@"
          skopos_init "$*"
          setup_cluster_env
          break
          ;;
        create | c | cr)
          shift

          skopos_create_env "$*"
          setup_cluster_env

          echo "Switched to $new_base. You're all set."
          break
          ;;
        delete | d | r | rm | del)
          shift
          set -- "$@"
          skopos_rm "$*"
          break
          ;;
        *)
          echo >&2 "Invalid option: '$1'"
          shift
          skopos_usage
          return 5
          ;;
        esac
      done
    else
      echo >&2 'Unable to continue. $KRAKEN is not set.'
      return 100
    fi
  else
    echo >&2 'Kraken must be installed and in our $PATH'
  fi
}
