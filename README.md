# skopos

## Name:

  Skopos -- have multiple kraken clusters? This guy will help. Helps manage multiple clusters.

## Synopsis

  Usage: skopos [init <name>] [list] [switch <name>] 
                [create <name>] [remove <name>] [help]

 ## Description

  c|create     : Creates a new skopos env and switches to it.
  i|init       : Initialize new skopos env.
  l|ls|list    : List all kraken environments available.
  s|sw|switch  : Switch to kraken environment.
  r|rm|remove  : Explains how to remove an environment.
  h|help       : This message.

## Purpose

[Skopos Freek Definition](http://biblehub.com/greek/4649.htm)
*σκοπός, σκοποῦ, ὁ* ((from a root denoting 'to spy,' 'peer,' 'look into the distance'; cf. also Latinspecio, speculum, species, etc.; Fick i., 251f; iv., 279; Curtius, § 111)); from Homer down;

1. an observer, a watchman.
2. ...

This tool is meant to work in concert with [Kraken](https://github.com/samsung-cnct/kraken). It will help manage 
clusters above the cluster, IE master instances.
  
## Prerequisites

  Requires:

  * bash
  * jq
  * yaml2json (included)
  * ruby (system base install)


## Successfully Tested on

  * Linux
  * MacOS

  But will likely need more wide-spread testing

## Needs

  * build tests

## Examples

List environments:

```
  $ skopos ls

  The following kraken environment(s) exist...
  (currently select environment is marked with a '*')

      cyklopsdev
   *  user-test
```

Create a new environment:

```
  $ skopos cr some-new-env
  '/home/user/.kraken' -> '/home/user/.kraken-some-new-env'
  Attempting to generate configuration at: /home/user/.kraken/config.yaml 
  Pulling image 'quay.io/samsung_cnct/k2:v0.1' ██████████ Complete
  Generating cluster config cluster-name-missing █████▒▒▒▒▒ Complete
  Generated aws config at /home/user/.kraken/config.yaml 
  Created /home/user/.kraken-some-new-env and switched to it. You're all set.
  Cluster path found: some-new-env. Exports set. Alias for kssh created.
```

 * automatically sets your environemt up:

```
  $ printenv | grep -P 'KUBE|HELM|KRAK|K2'
  KUBECONFIG=/home/user/.kraken/some-new-env/admin.kubeconfig
  HELM_HOME=/home/user/.kraken/some-new-env/.helm
  K2OPTS=-v /home/user/.kraken:/home/user/.kraken
  KRAKEN=/home/user/.kraken
```

 * Creating a new environment sets your environment
   to the just created env. Your kraken config name
   is automatically set to the same.

```
  $ skopos ls

  The following kraken environment(s) exist...
  (currently select environment is marked with a '*')

      tcyklopsdev
      user-est
   *  some-new-env

  $ grep --context 2 -P '^\s+- name: some-new-env' $KRAKEN/config.yaml
   deployment:
     clusters:
       - name: some-new-env
     	  network: 10.32.0.0/12
      	  dns: 10.32.0.2
```

Switch between environments atomically:

```
  $ skopos sw cyklopsdev
  /home/user/.kraken' -> '/home/user/.kraken-cyklopsdev'
  Cluster path found: cyklopsdev. Exports set. Alias for kssh created.
```
  
 * Resetting your environment to the newly requested environment

```
  $ printenv | grep -P 'KUBE|HELM|KRAK|K2'
  KUBECONFIG=/home/user/.kraken/cyklopsdev/admin.kubeconfig
  HELM_HOME=/home/user/.kraken/cyklopsdev/.helm
  K2OPTS=-v /home/user/.kraken:/home/user/.kraken
  KRAKEN=/home/user/.kraken
```

`skopos rm <env>` prints an informative message on how to remove environments.
