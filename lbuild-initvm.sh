#!/bin/bash
# -*-shell-*-

# close stdin, as with ubuntu and debian VMs this script tends to hang and wait for input ..
0<&-

#shopt -s huponexit

COMMAND=$(basename $0)
DIRNAME=$(dirname $0)
BUILD_DIR=$(pwd)

# pkgs parsing utilities + lbuild-bridge.sh
export PATH=$(dirname $0):$PATH

# old guests have e.g. mount in /bin but this is no longer part of
# the standard PATH in recent hosts after usrmove, so let's keep it simple
export PATH=$PATH:/bin:/sbin

. build.common

# xxx fixme : we pass $lxc around in functions,
# but in fact then we use lxc_root which is a global..
# it works, but this really is poor practice
# we should have an lxc_root function instead
function lxcroot () {
    local lxc=$1; shift
    echo /vservers/$lxc
}

# XXX fixme : when creating a 32bits VM we need to call linux32 as appropriate...s

DEFAULT_FCDISTRO=f29
DEFAULT_PLDISTRO=lxc
DEFAULT_PERSONALITY=linux64
DEFAULT_MEMORY=3072

##########
# constant
PUBLIC_BRIDGE=br0

# the network interface name as seen from the container
VIF_GUEST=eth0

##########
FEDORA_MIRROR="http://mirror.onelab.eu/"
FEDORA_MIRROR_KEYS="http://mirror.onelab.eu/keys/"
FEDORA_PREINSTALLED="dnf dnf-yum passwd rsyslog vim-minimal dhclient chkconfig rootfiles policycoreutils openssh-server openssh-clients"
DEBIAN_PREINSTALLED="openssh-server openssh-client"

########## networking utilities
function gethostbyname () {
    local hostname=$1
    python -c "import socket; print socket.gethostbyname('"$hostname"')" 2> /dev/null
}

# e.g. 21 -> 255.255.248.0
function masklen_to_netmask () {
    local masklen=$1; shift
    python <<EOF
import sys
masklen=$masklen
if not (masklen>=1 and masklen<=32):
  print "Wrong masklen",masklen
  exit(1)
result=[]
for i in range(4):
    if masklen>=8:
       result.append(8)
       masklen-=8
    else:
       result.append(masklen)
       masklen=0
print ".".join([ str(256-2**(8-i)) for i in result ])

EOF
}

##############################
# return dnf or debootstrap
function package_method () {
    local fcdistro=$1; shift
    case $fcdistro in
        f[0-9]*|centos[0-9]*|sl[0-9]*)
            echo dnf ;;
        wheezy|jessie|precise|trusty|utopic|vivid|wily|xenial)
            echo debootstrap ;;
        *)
            echo Unknown distro $fcdistro ;;
    esac
}

# return arch from debian distro and personality
function canonical_arch () {
    local personality=$1; shift
    local fcdistro=$1; shift
    case $(package_method $fcdistro) in
        dnf)
            case $personality in
                *32) echo i386 ;;
                *64) echo x86_64 ;;
                *) echo Unknown-arch-1 ;;
            esac ;;
        debootstrap)
            case $personality in
                *32) echo i386 ;;
                *64) echo amd64 ;;
                *) echo Unknown-arch-2 ;;
            esac ;;
        *)
            echo Unknown-arch-3 ;;
    esac
}

# the new test framework creates /timestamp in /vservers/<name> *before* populating it
function almost_empty () {
    local dir="$1"; shift ;
    # non existing is fine
    [ ! -d $dir ] && return 0;
    # need to have at most one file
    local count=$(cd $dir; ls | wc -l)
    [ $count -le 1 ]
}

##############################
function fedora_install() {
    set -x
    set -e

    local lxc=$1; shift
    local lxc_root=$(lxcroot $lxc)

    local cache=/var/cache/lxc/fedora/$arch/${fedora_release}
    mkdir -p $cache

    (
        flock --exclusive --timeout 60 200 || { echo "Cache repository is busy." ; return 1 ; }

        if [ ! -e "$cache/rootfs" ]; then
            echo "Getting cache download in $cache/rootfs ... "
            fedora_download $cache || { echo "Failed to download 'fedora base'"; return 1; }
        else
            echo "Updating cache $cache/rootfs ..."
            if ! dnf --installroot $cache/rootfs --releasever=${fedora_release} -y --nogpgcheck update ; then
                echo "Failed to update 'fedora base', continuing with last known good cache"
            else
                echo "Update finished"
            fi
        fi

        echo "Filling $lxc_root from $cache/rootfs ... "
        rsync -a $cache/rootfs/ $lxc_root/

        return 0

        ) 200> $cache/lock

    return $?
}

function fedora_download() {
    set -x

    local cache=$1; shift

    # check the mini fedora was not already downloaded
    INSTALL_ROOT=$cache/partial
    echo $INSTALL_ROOT

    # download a mini fedora into a cache
    echo "Downloading fedora minimal ..."

    mkdir -p $INSTALL_ROOT || { echo "Failed to create '$INSTALL_ROOT' directory" ; return 1; }

    mkdir -p $INSTALL_ROOT/etc/yum.repos.d
    mkdir -p $INSTALL_ROOT/dev
    mknod -m 0444 $INSTALL_ROOT/dev/random c 1 8
    mknod -m 0444 $INSTALL_ROOT/dev/urandom c 1 9

    # copy yum config and repo files
    cp /etc/yum.conf $INSTALL_ROOT/etc/
    cp /etc/yum.repos.d/fedora{,-updates}.repo $INSTALL_ROOT/etc/yum.repos.d/

    # append fedora repo files with hardwired releasever and basearch
    for f in $INSTALL_ROOT/etc/yum.repos.d/* ; do
      sed -i "s/\$basearch/$arch/g; s/\$releasever/${fedora_release}/g;" $f
    done

# looks like all this business about fetching fedora-release is not needed
# it does
#    MIRROR_URL=$FEDORA_MIRROR/fedora/releases/${fedora_release}/Everything/$arch/os
#    # since fedora18 the rpms are scattered by first name
#    # first try the second version of fedora-release first
#    RELEASE_URLS=""
#    local subindex
#    for subindex in 3 2 1; do
#        RELEASE_URLS="$RELEASE_URLS $MIRROR_URL/Packages/f/fedora-release-${fedora_release}-${subindex}.noarch.rpm"
#    done
#
#    RELEASE_TARGET=$INSTALL_ROOT/fedora-release-${fedora_release}.noarch.rpm
#    local found=""
#    local attempt
#    for attempt in $RELEASE_URLS; do
#        if curl --silent --fail $attempt -o $RELEASE_TARGET; then
#            echo "Successfully Retrieved $attempt"
#            found=true
#            break
#        else
#            echo "Failed (not to worry about) with attempt $attempt"
#        fi
#    done
#    [ -n "$found" ] || { echo "Could not retrieve fedora-release rpm - exiting" ; exit 1; }

    mkdir -p $INSTALL_ROOT/var/lib/rpm
    rpm --root $INSTALL_ROOT  --initdb
    # when installing f12 this apparently is already present, so ignore result
#    rpm --root $INSTALL_ROOT -ivh $INSTALL_ROOT/fedora-release-${fedora_release}.noarch.rpm || :
    # however f12 root images won't get created on a f18 host
    # (the issue here is the same as the one we ran into when dealing with a vs-box)
    # in a nutshell, in f12 the glibc-common and filesystem rpms have an apparent conflict
    # >>> file /usr/lib/locale from install of glibc-common-2.11.2-3.x86_64 conflicts
    #          with file from package filesystem-2.4.30-2.fc12.x86_64
    # in fact this was - of course - allowed by f12's rpm but later on a fix was made
    #   http://rpm.org/gitweb?p=rpm.git;a=commitdiff;h=cf1095648194104a81a58abead05974a5bfa3b9a
    # So ideally if we want to be able to build f12 images from f18 we need an rpm that has
    # this patch undone, like we have in place on our f14 boxes (our f14 boxes need a f18-like rpm)

    DNF="dnf --installroot=$INSTALL_ROOT --nogpgcheck -y"
    echo "$DNF install $FEDORA_PREINSTALLED"
    $DNF install $FEDORA_PREINSTALLED || { echo "Failed to download rootfs, aborting." ; return 1; }

    mv "$INSTALL_ROOT" "$cache/rootfs"
    echo "Download complete."

    return 0
}

##############################
function fedora_configure() {

    set -x
    set -e

    local lxc=$1; shift
    local fcdistro=$1; shift
    local lxc_root=$(lxcroot $lxc)

    # disable selinux in fedora
    mkdir -p $lxc_root/selinux
    echo 0 > $lxc_root/selinux/enforce

    # enable networking and set hostname
    cat <<EOF > ${lxc_root}/etc/sysconfig/network
NETWORKING=yes
EOF
    cat <<EOF > ${lxc_root}/etc/hostname
$GUEST_HOSTNAME
EOF

    local dev_path="${lxc_root}/dev"
    rm -rf $dev_path
    mkdir -p $dev_path
    mknod -m 666 ${dev_path}/null c 1 3
    mknod -m 666 ${dev_path}/zero c 1 5
    mknod -m 666 ${dev_path}/random c 1 8
    mknod -m 666 ${dev_path}/urandom c 1 9
    mkdir -m 755 ${dev_path}/pts
    mkdir -m 1777 ${dev_path}/shm
    mknod -m 666 ${dev_path}/tty c 5 0
    mknod -m 666 ${dev_path}/tty0 c 4 0
    mknod -m 666 ${dev_path}/tty1 c 4 1
    mknod -m 666 ${dev_path}/tty2 c 4 2
    mknod -m 666 ${dev_path}/tty3 c 4 3
    mknod -m 666 ${dev_path}/tty4 c 4 4
    mknod -m 600 ${dev_path}/console c 5 1
    mknod -m 666 ${dev_path}/full c 1 7
    mknod -m 600 ${dev_path}/initctl p
    mknod -m 666 ${dev_path}/ptmx c 5 2

    fedora_configure_systemd $lxc

    local guest_ifcfg=${lxc_root}/etc/sysconfig/network-scripts/ifcfg-$VIF_GUEST
    mkdir -p $(dirname ${guest_ifcfg})
    # starting with f27, we go for NetworkManager
    # no more NM_CONTROLLED nonsense
    if [ -n "$NAT_MODE" ]; then
        write_guest_ifcfg_natip
    else
        write_guest_ifcfg_publicip
    fi > $guest_ifcfg

    [ -z "$IMAGE" ] && fedora_configure_yum $lxc $fcdistro $pldistro

    return 0
}

# this code of course is for guests that do run on systemd
function fedora_configure_systemd() {
    set -e
    set -x
    local lxc=$1; shift
    local lxc_root=$(lxcroot $lxc)

    # so ignore if we can't find /etc/systemd at all
    [ -d ${lxc_root}/etc/systemd ] || return 0
    # otherwise let's proceed
    ln -sf /lib/systemd/system/multi-user.target ${lxc_root}/etc/systemd/system/default.target
    touch ${lxc_root}/etc/fstab
    ln -sf /dev/null ${lxc_root}/etc/systemd/system/udev.service
# Thierry - Feb 2013 relying on getty is looking for trouble
# so, turning getty off for now instead
#    sed -i 's/After=dev-%i.device/After=/' ${lxc_root}/lib/systemd/system/getty\@.service
    ln -sf /dev/null ${lxc_root}/etc/systemd/system/"getty@.service"
    rm -f ${lxc_root}/etc/systemd/system/getty.target.wants/*service || :
# can't seem to handle this one with systemctl
    chroot ${lxc_root} $personality chkconfig network on
}

# overwrite container yum config
function fedora_configure_yum () {
    set -x
    set -e
    trap failure ERR INT

    local lxc=$1; shift
    local fcdistro=$1; shift
    local pldistro=$1; shift

    local lxc_root=$(lxcroot $lxc)
    # rpm --rebuilddb
    chroot ${lxc_root} $personality rpm --rebuilddb

    echo "Initializing yum.repos.d in $lxc"
    rm -f $lxc_root/etc/yum.repos.d/*

    # use mirroring/ stuff instead of a hard-wired config
    local repofile=$lxc_root/etc/yum.repos.d/building.repo
    yumconf_mirrors $repofile ${DIRNAME} $fcdistro \
        "" $FEDORA_MIRROR
    # the keys stuff requires adjustment though
    sed -i $repofile -e s,'gpgkey=.*',"gpgkey=${FEDORA_MIRROR_KEYS}/RPM-GPG-KEY-fedora-${fedora_release}-primary,"

    # import fedora key so that gpgckeck does not whine or require stdin
    # required since fedora24
    rpm --root $lxc_root --import $FEDORA_MIRROR_KEYS/RPM-GPG-KEY-fedora-${fedora_release}-primary

    # for using this script as a general-purpose lxc creation wrapper
    # just mention 'none' as the repo url
    if [ -n "$REPO_URL" ] ; then
        if [ ! -d $lxc_root/etc/yum.repos.d ] ; then
            echo "WARNING : cannot create myplc repo"
        else
            # exclude kernel from fedora repos
            yumexclude=$(pl_plcyumexclude $fcdistro $pldistro $DIRNAME)
            for repo in $lxc_root/etc/yum.repos.d/* ; do
                [ -f $repo ] && yumconf_exclude $repo "exclude=$yumexclude"
            done
            # the build repo is not signed at this stage
            cat > $lxc_root/etc/yum.repos.d/myplc.repo <<EOF
[myplc]
name= MyPLC
baseurl=$REPO_URL
enabled=1
gpgcheck=0
EOF
        fi
    fi
}

##############################
# apparently ubuntu exposes a mirrors list by country at
# http://mirrors.ubuntu.com/mirrors.txt
# need to specify the right mirror for debian variants like ubuntu and the like
function debian_mirror () {
    local fcdistro=$1; shift
    case $fcdistro in
        wheezy|jessie)
            echo http://ftp2.fr.debian.org/debian/ ;;
        precise|trusty|utopic|vivid|wily|xenial)
            echo http://www-ftp.lip6.fr/pub/linux/distributions/Ubuntu/archive/ ;;
        *) echo unknown distro $fcdistro; exit 1;;
    esac
}

function debian_install () {
    set -e
    set -x
    local lxc=$1; shift
    local lxc_root=$(lxcroot $lxc)
    mkdir -p $lxc_root
    local arch=$(canonical_arch $personality $fcdistro)
    local mirror=$(debian_mirror $fcdistro)
    debootstrap --no-check-gpg --arch $arch $fcdistro $lxc_root $mirror
    # just like with fedora we ensure a few packages get installed as well
    # not started yet
    #virsh -c lxc:/// lxc-enter-namespace $lxc /usr/bin/$personality /bin/bash -c "apt-get update"
    #virsh -c lxc:/// lxc-enter-namespace $lxc /usr/bin/$personality /bin/bash -c "apt-get -y install $DEBIAN_PREINSTALLED"
    chroot ${lxc_root} $personality apt-get update
    chroot ${lxc_root} $personality apt-get -y install $DEBIAN_PREINSTALLED
    # configure hostname
    cat <<EOF > ${lxc_root}/etc/hostname
$GUEST_HOSTNAME
EOF

}

function debian_configure () {
    local guest_interfaces=${lxc_root}/etc/network/interfaces
    ( [ -n "$NAT_MODE" ] && write_guest_interfaces_natip || write_guest_interfaces_publicip ) > $guest_interfaces
}

function write_guest_interfaces_natip () {
    cat <<EOF
auto $VIF_GUEST
iface $VIF_GUEST inet dhcp
EOF
}

function write_guest_interfaces_publicip () {
    cat <<EOF
auto $VIF_GUEST
iface $VIF_GUEST inet static
address $GUEST_IP
netmask $NETMASK
gateway $GATEWAY
EOF
}
##############################
function setup_lxc() {

    set -x
    set -e
    #trap failure ERR INT

    local lxc=$1; shift
    local fcdistro=$1; shift
    local pldistro=$1; shift
    local personality=$1; shift

    local lxc_root=$(lxcroot $lxc)

    # create lxc container

    pkg_method=$(package_method $fcdistro)
    case $pkg_method in
        dnf)
            if [ -z "$IMAGE" ]; then
                fedora_install $lxc ||  { echo "failed to install fedora root image"; exit 1 ; }
                # this appears to be safer; observed in Jan. 2016 on a f23 host and a f14 cached image
                # we were getting this message when attempting the first chroot dnf install
                # rpmdb: Program version 4.8 doesn't match environment version 5.3
                chroot $(lxcroot $lxc) $personality rm -rf /var/lib/rpm/__db.00{0,1,2,3,4,5,6,7,8,9}
                chroot $(lxcroot $lxc) $personality rpm --rebuilddb
            fi
            fedora_configure $lxc $fcdistro || { echo "failed to configure fedora for a container"; exit 1 ; }
            ;;
        debootstrap)
            if [ -z "$IMAGE" ]; then
                debian_install $lxc || { echo "failed to install debian/ubuntu root image"; exit 1 ; }
            fi
            debian_configure || { echo "failed to configure debian/ubuntu for a container"; exit 1 ; }
            ;;
        *)
            echo "$COMMAND:: unknown package_method - exiting"
            exit 1
            ;;
    esac

    # Enable cgroup -- xxx -- is this really useful ?
    [ -d $lxc_root/cgroup ] || mkdir $lxc_root/cgroup

    ### set up resolv.conf from host
    # ubuntu precise and on, /etc/resolv.conf is a symlink to ../run/resolvconf/resolv.conf
    [ -h $lxc_root/etc/resolv.conf ] && rm -f $lxc_root/etc/resolv.conf
    cp /etc/resolv.conf $lxc_root/etc/resolv.conf
    ### and /etc/hosts for at least localhost
    [ -f $lxc_root/etc/hosts ] || echo "127.0.0.1 localhost localhost.localdomain" > $lxc_root/etc/hosts

    # grant ssh access from host to guest
    mkdir -p $lxc_root/root/.ssh
    cat /root/.ssh/id_rsa.pub >> $lxc_root/root/.ssh/authorized_keys
    chmod 700 $lxc_root/root/.ssh
    chmod 600 $lxc_root/root/.ssh/authorized_keys

    # don't keep the input xml, this can be retrieved at all times with virsh dumpxml
    local config_xml=/tmp/$lxc.xml
    ( [ -n "$NAT_MODE" ] && write_lxc_xml_natip $lxc || write_lxc_xml_publicip $lxc ) > $config_xml

    # define lxc container for libvirt
    virsh -c lxc:/// define $config_xml

    return 0
}

# this part does not belong in a domain any more
# but goes in a network object of its own existence
#      <network>
#        <name>host-bridge</name>
#        <forward mode="bridge"/>
#        <bridge name="br0"/>
#      </network>
#

function write_lxc_xml_publicip () {
    local lxc=$1; shift
    local lxc_root=$(lxcroot $lxc)
    cat <<EOF
<domain type='lxc'>
  <name>$lxc</name>
  <memory>$MEMORY</memory>
  <os>
    <type arch='$arch2'>exe</type>
    <init>/sbin/init</init>
  </os>
  <features>
    <acpi/>
  </features>
  <vcpu>1</vcpu>
  <clock offset='utc'/>
  <on_poweroff>destroy</on_poweroff>
  <on_reboot>restart</on_reboot>
  <on_crash>destroy</on_crash>
  <devices>
    <emulator>/usr/libexec/libvirt_lxc</emulator>
    <filesystem type='mount'>
      <source dir='$lxc_root'/>
      <target dir='/'/>
    </filesystem>
    <interface type="bridge">
      <source bridge="$PUBLIC_BRIDGE"/>
      <target dev='$VIF_HOST'/>
    </interface>
    <console type='pty' />
  </devices>
</domain>
EOF
}

# grant build guests the ability to do mknods
function write_lxc_xml_natip () {
    local lxc=$1; shift
    local lxc_root=$(lxcroot $lxc)
    cat <<EOF
<domain type='lxc'>
  <name>$lxc</name>
  <memory>$MEMORY</memory>
  <os>
    <type arch='$arch2'>exe</type>
    <init>/sbin/init</init>
  </os>
  <features>
    <acpi/>
    <capabilities policy='default'>
      <mknod state='on'/>
    </capabilities>
  </features>
  <vcpu>1</vcpu>
  <clock offset='utc'/>
  <on_poweroff>destroy</on_poweroff>
  <on_reboot>restart</on_reboot>
  <on_crash>destroy</on_crash>
  <devices>
    <emulator>/usr/libexec/libvirt_lxc</emulator>
    <filesystem type='mount'>
      <source dir='$lxc_root'/>
      <target dir='/'/>
    </filesystem>
    <interface type="network">
      <source network="default"/>
    </interface>
    <console type='pty' />
  </devices>
</domain>
EOF
}

# this one is dhcp-based
function write_guest_ifcfg_natip () {
    cat <<EOF
DEVICE=$VIF_GUEST
BOOTPROTO=dhcp
ONBOOT=yes
TYPE=Ethernet
MTU=1500
EOF
}

# use fixed GUEST_IP as specified by GUEST_HOSTNAME
function write_guest_ifcfg_publicip () {
    cat <<EOF
DEVICE=$VIF_GUEST
BOOTPROTO=static
ONBOOT=yes
HOSTNAME=$GUEST_HOSTNAME
IPADDR=$GUEST_IP
NETMASK=$NETMASK
GATEWAY=$GATEWAY
TYPE=Ethernet
MTU=1500
EOF
}

function devel_or_test_tools () {

    set -x
    set -e
    trap failure ERR INT

    local lxc=$1; shift
    local fcdistro=$1; shift
    local pldistro=$1; shift
    local personality=$1; shift

    local lxc_root=$(lxcroot $lxc)

    local pkg_method=$(package_method $fcdistro)

    local pkgsfile=$(pl_locateDistroFile $DIRNAME $pldistro $PREINSTALLED)

    ### install individual packages, then groups
    # get target arch - use uname -i here (we want either x86_64 or i386)

    local lxc_arch=$(chroot ${lxc_root} $personality uname -i)
    # on debian systems we get arch through the 'arch' command
    [ "$lxc_arch" = "unknown" ] && lxc_arch=$(chroot ${lxc_root} $personality arch)

    local packages=$(pl_getPackages -a $lxc_arch $fcdistro $pldistro $pkgsfile)
    local groups=$(pl_getGroups -a $lxc_arch $fcdistro $pldistro $pkgsfile)

    case "$pkg_method" in
        dnf)
            # --allowerasing required starting with fedora24
            #
            local has_dnf=""
            chroot ${lxc_root} $personality dnf --version && has_dnf=true
            if [ -n "$has_dnf" ]; then
                echo "container has dnf - invoking with --allowerasing"
                local pkg_installer="dnf -y install --allowerasing"
                local grp_installer="dnf -y groupinstall --allowerasing"
            else
                echo "container has only dnf"
                local pkg_installer="dnf -y install"
                local grp_installer="dnf -y groupinstall"
            fi
            [ -n "$packages" ] && chroot ${lxc_root} $personality $pkg_installer $packages
            for group_plus in $groups; do
                local group=$(echo $group_plus | sed -e "s,+++, ,g")
                chroot ${lxc_root} $personality $grp_installer "$group"
            done
            # store current rpm list in /init-lxc.rpms in case we need to check the contents
            chroot ${lxc_root} $personality rpm -aq > $lxc_root/init-lxc.rpms
            ;;
        debootstrap)
            # for ubuntu
            if grep -iq ubuntu /vservers/$lxc/etc/lsb-release 2> /dev/null; then
                # on ubuntu, at this point we end up with a single feed in /etc/apt/sources.list
                # we need at least to add the 'universe' feed for python-rpm
                ( cd /vservers/$lxc/etc/apt ; head -1 sources.list | sed -e s,main,universe, > sources.list.d/universe.list )
                # also adding a link to updates sounds about right
                ( cd /vservers/$lxc/etc/apt ; head -1 sources.list | sed -e 's, main,-updates main,' > sources.list.d/updates.list )
                # tell apt about the changes
                chroot /vservers/$lxc apt-get update
            fi
            for package in $packages ; do
                # container not started yet
                #virsh -c lxc:/// lxc-enter-namespace $lxc /usr/bin/$personality /bin/bash -c "apt-get install -y $package" || :
                chroot ${lxc_root} $personality apt-get install -y $package || :
            done
            ### xxx todo install groups with apt..
            ;;
        *)
            echo "unknown pkg_method $pkg_method"
            ;;
    esac

    return 0
}

function post_install () {
    local lxc=$1; shift
    local personality=$1; shift
    local lxc_root=$(lxcroot $lxc)
    # setup localtime from the host
    cp /etc/localtime $lxc_root/etc/localtime
    sshd_disable_password_auth $lxc
    # post install hook
    [ -n "$NAT_MODE" ] && post_install_natip $lxc $personality || post_install_myplc $lxc $personality
    # start the VM unless specified otherwise
    if [ -n "$START_VM" ] ; then
        echo Starting guest $lxc
        virsh -c lxc:/// start $lxc
        if [ -n "$NAT_MODE" ] ; then
            wait_for_ssh $lxc
        else
            wait_for_ssh $lxc $GUEST_IP
        fi
    fi
}

# just in case, let's stay on the safe side
function sshd_disable_password_auth () {
    local lxc=$1; shift
    local lxc_root=$(lxcroot $lxc)
    sed --in-place=.password -e 's,^#\?PasswordAuthentication.*,PasswordAuthentication no,' \
        $lxc_root/etc/ssh/sshd_config
}

function post_install_natip () {

    set -x
    set -e
    trap failure ERR INT

    local lxc=$1; shift
    local personality=$1; shift
    local lxc_root=$(lxcroot $lxc)

### From myplc-devel-native.spec
# be careful to backslash $ in this, otherwise it's the root context that's going to do the evaluation
    cat << EOF | chroot ${lxc_root} $personality bash -x

    # customize root's prompt
    /bin/cat << PROFILE > /root/.profile
export PS1="[$lxc] \\w # "
PROFILE

EOF

}

function post_install_myplc  () {
    set -x
    set -e
    trap failure ERR INT

    local lxc=$1; shift
    local personality=$1; shift
    local lxc_root=$(lxcroot $lxc)

# be careful to backslash $ in this, otherwise it's the root context that's going to do the evaluation
    cat << EOF | chroot ${lxc_root} $personality bash -x

    # create /etc/sysconfig/network if missing
    [ -f /etc/sysconfig/network ] || /bin/echo NETWORKING=yes > /etc/sysconfig/network

    # turn off regular crond, as plc invokes plc_crond
    /sbin/chkconfig crond off

    # customize root's prompt
    /bin/cat << PROFILE > /root/.profile
export PS1="[$lxc] \\w # "
PROFILE

EOF
}

########################################
# workaround for broken lxc-enter-namespace
# 1st version was relying on virsh net-dhcp-leases
# however this was too fragile, would not work for fedora14 containers
# WARNING: this code is duplicated in lbuild-nightly.sh
function guest_ipv4() {
    local lxc=$1; shift

    local mac=$(virsh -c lxc:/// domiflist $lxc | egrep 'network|bridge' | awk '{print $5;}')
    # sanity check
    [ -z "$mac" ] && return 0
    arp -en | grep "$mac" | awk '{print $1;}'
}

function wait_for_ssh () {
    set -x
    set -e

    local lxc=$1; shift

    # if run in public_ip mode, we know the IP of the guest and it is specified here
    [ -n "$1" ] && { guest_ip=$1; shift; }

    #wait max 2 min for sshd to start
    local success=""
    local current_time=$(date +%s)
    local stop_time=$(($current_time + 120))

    local counter=1
    while [ "$current_time" -lt "$stop_time" ] ; do
         echo "$counter-th attempt to reach sshd in container $lxc ..."
         [ -z "$guest_ip" ] && guest_ip=$(guest_ipv4 $lxc)
         [ -n "$guest_ip" ] && ssh -o "StrictHostKeyChecking no" $guest_ip 'uname -i' && {
                 success=true; echo "SSHD in container $lxc is UP on IP $guest_ip"; break ; } || :
         counter=$(($counter+1))
         sleep 10
         current_time=$(date +%s)
    done

    # Thierry: this is fatal, let's just exit with a failure here
    [ -z $success ] && { echo "SSHD in container $lxc could not be reached (guest_ip=$guest_ip)" ; exit 1 ; }
    return 0
}

####################
function failure () {
    echo "$COMMAND : Bailing out"
    exit 1
}

function usage () {
    set +x
    echo "Usage: $COMMAND [options] lxc-name             (aka build mode)"
    echo "Usage: $COMMAND -n hostname [options] lxc-name (aka test mode)"
    echo "Description:"
    echo "    This command creates a fresh lxc instance, for building, or running a test myplc"
    echo "In its first form, spawned VM gets a private IP bridged with virbr0 over dhcp/nat"
    echo "With the second form, spawned VM gets a public IP bridged on public bridge br0"
    echo ""
    echo "Supported options"
    echo " -n hostname - the hostname to use in container"
    echo " -f fcdistro - for creating the root filesystem - defaults to $DEFAULT_FCDISTRO"
    echo " -d pldistro - defaults to $DEFAULT_PLDISTRO - current support for fedoras debians ubuntus"
    echo " -p personality - defaults to $DEFAULT_PERSONALITY"
    echo " -r repo-url - used to populate yum.repos.d - required in test mode"
    echo " -P pkgs_file - defines a set of extra packages to install in guest"
    echo "    by default we use devel.pkgs (build mode) or runtime.pkgs (test mode)"
    echo " -i image - the location of the rootfs"
    echo " -m memory - the amount of allocated memory in MB - defaults to $DEFAULT_MEMORY MB"
    echo " -s do not start VM"
    echo " -v be verbose"
    exit 1
}

### parse args and
function main () {

    #set -e
    #trap failure ERR INT

    if [ "$(id -u)" != "0" ]; then
          echo "This script should be run as 'root'"
          exit 1
    fi

    START_VM=true
    while getopts "n:f:d:p:r:P:i:m:sv" opt ; do
        case $opt in
            n) GUEST_HOSTNAME=$OPTARG;;
            f) fcdistro=$OPTARG;;
            d) pldistro=$OPTARG;;
            p) personality=$OPTARG;;
            r) REPO_URL=$OPTARG;;
            P) PREINSTALLED=$OPTARG;;
            i) IMAGE=$OPTARG;;
            m) MEMORY=$OPTARG;;
            s) START_VM= ;;
            v) VERBOSE=true; set -x;;
            *) usage ;;
        esac
    done

    shift $(($OPTIND - 1))

    # parse fixed arguments
    [[ -z "$@" ]] && usage
    local lxc=$1 ; shift
    local lxc_root=$(lxcroot $lxc)

    # rainchecks
    almost_empty $lxc_root || \
        { echo "container $lxc already exists in $lxc_root - exiting" ; exit 1 ; }
    virsh -c lxc:/// domuuid $lxc >& /dev/null && \
        { echo "container $lxc already exists in libvirt - exiting" ; exit 1 ; }
    mkdir -p $lxc_root

    # if IMAGE, copy the provided rootfs to lxc_root
    if [ -n "$IMAGE" ] ; then
        [ ! -d "$IMAGE" ] && \
        { echo "$IMAGE rootfs folder does not exist - exiting" ; exit 1 ; }
        rsync -a $IMAGE/ $lxc_root/
    fi

    # check we've exhausted the arguments
    [[ -n "$@" ]] && usage

    # NAT_MODE is true unless we specified a hostname
    [ -n "$GUEST_HOSTNAME" ] || NAT_MODE=true

    # set default values
    [ -z "$fcdistro" ] && fcdistro=$DEFAULT_FCDISTRO
    [ -z "$pldistro" ] && pldistro=$DEFAULT_PLDISTRO
    [ -z "$personality" ] && personality=$DEFAULT_PERSONALITY
    [ -z "$MEMORY" ] && MEMORY=$DEFAULT_MEMORY

    # set memory in KB
    MEMORY=$(($MEMORY * 1024))

    # the set of preinstalled packages - depends on mode
    if [ -z "$PREINSTALLED" ] ; then
        if [ -n "$NAT_MODE" ] ; then
            PREINSTALLED=devel.pkgs
        else
            PREINSTALLED=runtime.pkgs
        fi
    fi

    if [ -n "$NAT_MODE" ] ; then
        # we can now set GUEST_HOSTNAME safely
        [ -z "$GUEST_HOSTNAME" ] && GUEST_HOSTNAME=$(echo $lxc | sed -e 's,\.,-,g')
    else
        # as this command can be used in other contexts, not specifying
        # a repo is considered a warning
        # use -r none to get rid of this warning
        if [ "$REPO_URL" == "none" ] ; then
            REPO_URL=""
        elif [ -z "$REPO_URL" ] ; then
            echo "WARNING -- setting up a yum repo is recommended"
        fi
    fi

    ##########
    fedora_release=$(echo $fcdistro | cut -df -f2)

    if [ "$personality" == "linux32" ]; then
        arch=i386
        arch2=i686
    elif [ "$personality" == "linux64" ]; then
        arch=x86_64
        arch2=x86_64
    else
        echo "Unknown personality: $personality"
    fi

    # compute networking details for the test mode
    # (build mode relies entirely on dhcp on the private subnet)
    if [ -z "$NAT_MODE" ] ; then

        #create_bridge_if_needed $PUBLIC_BRIDGE
        lbuild-bridge.sh $PUBLIC_BRIDGE

        GUEST_IP=$(gethostbyname $GUEST_HOSTNAME)
        # use same NETMASK as bridge interface br0
        masklen=$(ip addr show $PUBLIC_BRIDGE | grep -v inet6 | grep inet | awk '{print $2;}' | cut -d/ -f2)
        NETMASK=$(masklen_to_netmask $masklen)
        GATEWAY=$(ip route show | grep default | awk '{print $3}' | head -1)
        VIF_HOST="vif$(echo $GUEST_HOSTNAME | cut -d. -f1)"
    fi

    setup_lxc $lxc $fcdistro $pldistro $personality

    # historically this command is for setting up a build or a test VM
    # kind of patchy right now though
    devel_or_test_tools $lxc $fcdistro $pldistro $personality

    # container gets started here
    post_install $lxc $personality

    echo $COMMAND Done

    exit 0
}

main "$@"
