# skopos

Have multiple kraken clusters? This guy will help. Helps
manage multiple clusters.

## Usage

`skopos [init <name>] [list] [switch <name>] [create <name>] [remove <name>] [help]`

## Description

- c|create: Creates a new skopos env and switches to it
- i|init: Initialize new skopos env
- l|ls|list: List all kraken environments available
- s|sw|switch: Switch to kraken environment
- r|rm|remove: Explains how to remove an environment
- h|help : This message

## Purpose

[Skopos Freek Definition](http://biblehub.com/greek/4649.htm) *σκοπός,
σκοποῦ, ὁ* ((from a root denoting 'to spy,' 'peer,' 'look into the
distance'; cf. also Latin specio, speculum, species, etc.; Fick i., 251f;
iv., 279; Curtius, § 111)); from Homer down;

1. an observer, a watchman.
2. ...

This tool is meant to work in concert with
[Kraken](https://github.com/samsung-cnct/kraken). It will help manage
clusters above the cluster, IE master instances.

## Prerequisites

Requires:

- bash
- jq
- yaml2json (included)
- ruby (system base install)

## Successfully Tested on

- Linux
- MacOS

But will likely need more wide-spread testing

## Needs

- build tests

## Examples

List environments:

```shell
  skopos ls

  The following kraken environment(s) exist...
  (currently select environment is marked with a '*')

      cyklopsdev
   *  user-test
```

Create a new environment:

```shell
  skopos cr some-new-env
  '/home/user/.kraken' -> '/home/user/.kraken-some-new-env'
  Attempting to generate configuration at: /home/user/.kraken/config.yaml
  Pulling image 'quay.io/samsung_cnct/k2:v0.1' ██████████ Complete
  Generating cluster config cluster-name-missing █████▒▒▒▒▒ Complete
  Generated aws config at /home/user/.kraken/config.yaml
  Created /home/user/.kraken-some-new-env and switched to it. You're all set.
  Cluster path found: some-new-env. Exports set. Alias for kssh created.
```

- Kraken supports AWS and GKE as well as future support for other
  providers by specifying the `--provider` argument to `generate`.
  *skopos* allows you to pass the `--provider` flag on to `kraken`
  during the `create` process.

<!-- end list -->

```shell
  alias sk='skopos'
  sk cr foo-gke -- --provider=gke
  '/home/jimconn/.kraken' -> '/home/jimconn/.kraken-foo-gke'
  Attempting to generate configuration at: /home/jimconn/.kraken/config.yaml
  Pulling image 'quay.io/samsung_cnct/k2:v0.1' ███▒▒▒▒▒▒▒ Complete
  Generating cluster config cluster-name-missing █████▒▒▒▒▒ Complete
  Generated aws config at /home/jimconn/.kraken/config.yaml
  Created /home/jimconn/.kraken-foo-gke and switched to it. You're all set.
  Cluster path found: foo-gke. Exports set. Alias for kssh created.
```

- automatically sets your environemt up:

<!-- end list -->

```shell
  printenv | grep -P 'KUBE|HELM|KRAK|K2'
  KUBECONFIG=/home/user/.kraken/some-new-env/admin.kubeconfig
  HELM_HOME=/home/user/.kraken/some-new-env/.helm
  K2OPTS=-v /home/user/.kraken:/home/user/.kraken
  KRAKEN=/home/user/.kraken
```

- Creating a new environment sets your environment to the just created
  env. Your kraken config name is automatically set to the same.

<!-- end list -->

```shell
  alias sk='skopos'
  sk ls

  The following kraken environment(s) exist...
  (currently select environment is marked with a '*')

      tcyklopsdev
      user-est
   *  some-new-env

  grep --context 2 -P '^\s+- name: some-new-env' $KRAKEN/config.yaml
   deployment:
     clusters:
       - name: some-new-env
          network: 10.32.0.0/12
          dns: 10.32.0.2
```

Switch between environments atomically:

```shell
  skopos sw cyklopsdev
  /home/user/.kraken' -> '/home/user/.kraken-cyklopsdev'
  Cluster path found: cyklopsdev. Exports set. Alias for kssh created.
```

 - Resetting your environment to the newly requested environment

<!-- end list -->

```shell
  printenv | grep -P 'KUBE|HELM|KRAK|K2'
  KUBECONFIG=/home/user/.kraken/cyklopsdev/admin.kubeconfig
  HELM_HOME=/home/user/.kraken/cyklopsdev/.helm
  K2OPTS=-v /home/user/.kraken:/home/user/.kraken
  KRAKEN=/home/user/.kraken
```

`skopos rm <env>` prints an informative message on how to remove
environments.

## All The Things

Skopos maintains the directory structure of clusters created
(minimally), and it expects certain files and directories to exist to
function properly.

- The kraken cluster configuration is expected to be:
  `$HOME/<user>/.kraken/config.yaml`

- Any directories patterned after `$HOME/<user>/.kraken-<something>`
  will be goverend by skopos, which shouldn't generally be a problem.

- Skopos will symlink your cluster `.helm` path to your `$HOME/.helm`
  -- If you manually import a cluster from someone or somewhere, this
  is likely the right way to do it:

<!-- end list -->

```shell
    alias sk="skopos"

    # create a new home for it...
    sk cr imported

    # copy the kraken cluster tree to new skopos home:
    cp -avp /path/to/kraken-cluster-assets $HOME/<username>/.kraken-imported
```

Your structure should look something like this:

```shell
  ls -atr | grep -P '^.kraken'
  .kraken -> $HOME/.kraken-cyklopsdev   <<-- currently selected cluster
  .kraken-cyklopsdev
  .kraken-commontools
  .kraken-user-default

  cd .kraken

  ls -altr
  total 28
  -rw-r--r--  1 user user 12729 Sep 27 15:12 config.yaml
  drwxr-xr-x  2 user user  4096 Sep 29 19:24 cyklopsdev
  lrwxrwxrwx  1 user user    19 Oct  2 21:41 .helm -> /home/user/.helm
  drwxr-xr-x  3 user user  4096 Oct  2 21:41 .
  drwxr-xr-x 32 user user  4096 Oct 12 17:41 ..
```

Skopos determines the name of your cluster by searching the cluster
directory for a configuration file called 'config.yaml'

## Known bugs

Currently, `skopos` sets the environment variables for your cluster in
the shell in which you run skopos. If you start a new shell, your
environment will get properly set up in that new shell. If you're in a
running shell terminal where you change your cluster environment and
then switch to another already running shell terminal, the terminal to
which you just switched will still have the old skopos environment
variables in memory. The workaround for this is to simply run `skopos`
once (without args) in the new terminal, which will refresh the env
variables. This bug will be fixed in a soon-to-be release.

Kraken places the `.helm` path for the cluster in
`$HOME/user/.kraken/clustername/.helm` Skopos links
`$HOME/user/.kraken/.helm` to `$HOME/.helm` and sets `$HELM_HOME`
accordingly. This set up works fine until one wants to `kraken cluster
down`. The current workaround is:

```shell
    cd $KRAKEN
    rm .helm
    export HELM_HOME=$KRAKEN/$(basename $(dirname $KUBECONFIG))/.helm
    kraken cluster down
```
