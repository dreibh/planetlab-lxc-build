#!/bin/bash

COMMAND=$(basename $0)
DIRNAME=$(dirname $0)

BUILD="${HOME}/git-build"

LOGS=$HOME/machines

[ -d $LOGS ] || { echo "Creating logs dir $LOGS" ; mkdir -p $LOGS; } 

DOMAIN=pl.sophia.inria.fr

DEFAULT_DISTRO=f31
DEFAULT_MEMORY=16384

CONFIRM=
function usage () {
  message="$@" 
  echo "usage : $COMMAND [-c] [-f distro] [-i image] [ -m memory ] [ -n hostname ] [-s] container"
  echo " -c : confirm, will show the command and prompt for confirmation "
  echo " -f : set distro, default is $DEFAULT_DISTRO"
  echo " -i : if specified, image is rsynced into /vservers"
  echo "      warning: we cannot use an image already in /vservers..."
  echo " -m : memory size in Mb - default is $DEFAULT_MEMORY"
  echo " -n : specify hostname if different from container"
  echo " -s : do not start VM"
  echo " container : used for /vservers/foo as well as the lxc/libvirt name"
  echo "examples"
  echo "  create-vm.sh sandbox"
  echo "    Builds a brand new $DEFAULT_DISTRO 64bits VM named sandbox with hostname sandbox.pl.sophia.inria.fr"
  echo "  create-vm.sh -i /vservers/migrating/testmaster -n testmaster testmaster.f14"
  echo "    Create a container named testmaster.f14 from the specified image with hostname testmaster.pl.sophia.inria.fr"
  [ -n "$message" ] && echo $message
  exit 1
}

# using HOSTNAME won't work as this is already set in environment
while getopts "cf:i:m:n:sh" flag; do
    case $flag in
	c) CONFIRM=true ;;
	f) DISTRO=$OPTARG ;;
        i) IMAGE=$OPTARG ;;
	m) MEMORY=$OPTARG ;;
	n) VM_HOSTNAME=$OPTARG ;;
	s) DO_NOT_START_VM=true ;;
	?|h) usage "" ;;
    esac
done
# parse args
shift $((OPTIND-1))
[[ -z "$@" ]] && usage "no hostname provided"
container="$1" ; shift
[[ -n "$@" ]] && usage "extra arguments" "$@" "(container=$container)"

# sanity checks
[ -d "$BUILD" ] || usage "Could not find directory $BUILD"
[ -d /vservers/$container ] && usage "container $container already exists in /vservers"

echo "Updating $BUILD"
cd $BUILD
git pull
cd -

# compute all vars from args
[ -z "$DISTRO" ] && DISTRO="$DEFAULT_DISTRO"
[ -z "$MEMORY" ] && MEMORY="$DEFAULT_MEMORY"
[ -z "$VM_HOSTNAME" ] && VM_HOSTNAME="$container"
fqdn=$VM_HOSTNAME.$DOMAIN

# prepare initvm command
initvm="$BUILD/lbuild-initvm.sh"
[ -z "$IMAGE" ] && initvm="$initvm -f $DISTRO" || initvm="$initvm -i $IMAGE"
initvm="$initvm -n $fqdn"
[ -n "$DO_NOT_START_VM" ] && initvm="$initvm -s"
[ -n "$MEMORY" ] && initvm="$initvm -m $MEMORY" 
initvm="$initvm $container"

if [ -n "$CONFIRM" ] ; then
    echo -n "Run $initvm OK ? "
    read answer ; case $answer in [nN]*) exit 1 ;; esac
fi

echo "Running $initvm"
echo "Storing output in $LOGS/$container.log"
$initvm >& $LOGS/$container.log

