#!/bin/bash
# -*-shell-*-

# close stdin, as with ubuntu and debian VMs this script tends to hang and wait for input ..
0<&-

#shopt -s huponexit

COMMAND=$(basename $0)
DIRNAME=$(dirname $0)
BUILD_DIR=$(pwd)

# pkgs parsing utilities
export PATH=$(dirname $0):$PATH

# old guests have e.g. mount in /bin but this is no longer part of 
# the standard PATH in recent hosts after usrmove, so let's keep it simple
export PATH=$PATH:/bin:/sbin

. build.common

DEFAULT_FCDISTRO=f20
DEFAULT_PLDISTRO=lxc
DEFAULT_PERSONALITY=linux64
DEFAULT_MEMORY=512

##########
# constant
PUBLIC_BRIDGE=br0

# the network interface name as seen from the container
VIF_GUEST=eth0

##########
FEDORA_MIRROR_BASE="http://fedora.uib.no/fedora/linux"
FEDORA_PREINSTALLED="yum initscripts passwd rsyslog vim-minimal dhclient chkconfig rootfiles policycoreutils openssh-server openssh-clients netcf-devel"
DEBIAN_PREINSTALLED="openssh-server openssh-client"

##############################
## stolen from tests/system/template-qemu/qemu-bridge-init
# use /proc/net/dev instead of a hard-wired list
function gather_interfaces () {
    python <<EOF
for line in file("/proc/net/dev"):
    if ':' not in line: continue
    ifname=line.replace(" ","").split(":")[0]
    if ifname.find("lo")==0: continue
    if ifname.find("br")==0: continue
    if ifname.find("virbr")==0: continue
    if ifname.find("veth")==0: continue
    if ifname.find("tap")==0: continue
    print ifname
EOF
}

function discover_interface () {
    for ifname in $(gather_interfaces); do
	ip link show $ifname | grep -qi 'state UP' && { echo $ifname; return; }
    done
    # still not found ? that's bad
    echo unknown
}

########## networking -- ctd
function gethostbyname () {
    hostname=$1
    python -c "import socket; print socket.gethostbyname('"$hostname"')" 2> /dev/null
}

# e.g. 21 -> 255.255.248.0
function masklen_to_netmask () {
    masklen=$1; shift
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

#################### bridge initialization
function create_bridge_if_needed() {
   
    # turn on verbosity
    set -x

    # already created ? - we're done
    ip addr show $PUBLIC_BRIDGE >& /dev/null && {
	echo "Bridge already set up - skipping create_bridge_if_needed"
	return 0
    }

    # find out the physical interface to bridge onto
    if_lan=$(discover_interface)

    ip addr show $if_lan &>/dev/null || {
        echo "Cannot use interface $if_lan - exiting"
        exit 1
    }

    #################### bride initialization
    check_yum_installed bridge-utils

    echo "========== $COMMAND: entering create_bridge - beg"
    hostname
    uname -a
    ip addr show
    ip route
    echo "========== $COMMAND: entering create_bridge - end"

    # disable netfilter calls for bridge interface (they cause panick on 2.6.35 anyway)
    #
    # another option would be to accept the all forward packages for
    # bridged interface like: -A FORWARD -m physdev --physdev-is-bridged -j ACCEPT
    sysctl net.bridge.bridge-nf-call-iptables=0
    sysctl net.bridge.bridge-nf-call-ip6tables=0
    sysctl net.bridge.bridge-nf-call-arptables=0

    
    #Getting host IP/masklen
    address=$(ip addr show $if_lan | grep -v inet6 | grep inet | head --lines=1 | awk '{print $2;}')
    [ -z "$address" ] && { echo "ERROR: Could not determine IP address for $if_lan" ; exit 1 ; }

    broadcast=$(ip addr show $if_lan | grep -v inet6 | grep inet | head --lines=1 | awk '{print $4;}')
    [ -z "$broadcast" ] && echo "WARNING: Could not determine broadcast address for $if_lan"

    gateway=$(ip route show | grep default | awk '{print $3;}')
    [ -z "$gateway" ] && echo "WARNING: Could not determine gateway IP"


    # creating the bridge
    echo "Creating bridge PUBLIC_BRIDGE=$PUBLIC_BRIDGE"
    brctl addbr $PUBLIC_BRIDGE
    brctl addif $PUBLIC_BRIDGE $if_lan
    echo "Activating promiscuous mode if_lan=$if_lan"
    ip link set $if_lan up promisc on
    sleep 2
    # rely on dhcp to re assign IP.. 
    echo "Starting dhclient on $PUBLIC_BRIDGE"
    dhclient $PUBLIC_BRIDGE
    sleep 1

    #Reconfigure the routing table
    echo "Configuring gateway=$gateway"
    ip route add default via $gateway dev $PUBLIC_BRIDGE
    ip route del default via $gateway dev $if_lan
    # at this point we have an extra route like e.g.
    ## ip route show
    #default via 138.96.112.250 dev br0
    #138.96.112.0/21 dev em1  proto kernel  scope link  src 138.96.112.57
    #138.96.112.0/21 dev br0  proto kernel  scope link  src 138.96.112.57
    #192.168.122.0/24 dev virbr0  proto kernel  scope link  src 192.168.122.1
    route_dest=$(ip route show | grep -v default | grep "dev $PUBLIC_BRIDGE" | awk '{print $1;}')
    ip route del $route_dest dev $if_lan

    echo "========== $COMMAND: exiting create_bridge - beg"
    ip addr show
    ip route show
    echo "========== $COMMAND: exiting create_bridge - end"

    # for safety
    sleep 3
    return 0

}

##############################
# return yum or debootstrap
function package_method () {
    fcdistro=$1; shift
    case $fcdistro in
	f[0-9]*|centos[0-9]*|sl[0-9]*) echo yum ;;
	squeeze|wheezy|jessie|oneiric|precise|quantal|raring|saucy) echo debootstrap ;;
	*) echo Unknown distro $fcdistro ;;
    esac 
}

# return arch from debian distro and personality
function canonical_arch () {
    personality=$1; shift
    fcdistro=$1; shift
    case $(package_method $fcdistro) in
	yum)
	    case $personality in *32) echo i386 ;; *64) echo x86_64 ;; *) echo Unknown-arch-1 ;; esac ;;
	debootstrap)
	    case $personality in *32) echo i386 ;; *64) echo amd64 ;; *) echo Unknown-arch-2 ;; esac ;;
	*)
	    echo Unknown-arch-3 ;;
    esac
}

# the new test framework creates /timestamp in /vservers/<name> *before* populating it
function almost_empty () { 
    dir="$1"; shift ; 
    # non existing is fine
    [ ! -d $dir ] && return 0; 
    # need to have at most one file
    count=$(cd $dir; ls | wc -l); [ $count -le 1 ]; 
}

##############################
function check_yum_installed () {
    package=$1; shift
    rpm -q $package >& /dev/null || yum -y install $package
}

function check_yumgroup_installed () {
    group="$1"; shift
    yum grouplist "$group" | grep -q Installed || { yum -y groupinstall "$group" ; }
}

##############################
function fedora_install() {
    set -x
    set -e

    cache=/var/cache/lxc/fedora/$arch/$release
    
    mkdir -p /var/lock/subsys/
    (
        flock -n -x 200 || { echo "Cache repository is busy." ; return 1 ; }

        if [ ! -e "$cache/rootfs" ]; then
            echo "Getting cache download in $cache/rootfs ... "
            fedora_download || { echo "Failed to download 'fedora base'"; return 1; }
        else
            echo "Updating cache $cache/rootfs ..."
	    if ! yum --installroot $cache/rootfs -y --nogpgcheck update ; then
                echo "Failed to update 'fedora base', continuing with last known good cache"
            else
                echo "Update finished"
            fi
        fi

        echo "Copy $cache/rootfs to $lxc_root ... "
	rsync -a $cache/rootfs/ $lxc_root/
	
        return 0

        ) 200>/var/lock/subsys/lxc

    return $?
}

function fedora_download() {
    set -x
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
    cp /etc/yum.repos.d/fedora* $INSTALL_ROOT/etc/yum.repos.d/

    # append fedora repo files with desired $release and $basearch
    for f in $INSTALL_ROOT/etc/yum.repos.d/* ; do
      sed -i "s/\$basearch/$arch/g; s/\$releasever/$release/g;" $f
    done 

    MIRROR_URL=$FEDORA_MIRROR_BASE/releases/$release/Everything/$arch/os
    RELEASE_URL1="$MIRROR_URL/Packages/fedora-release-$release-1.noarch.rpm"
    # with fedora18 the rpms are scattered by first name
    RELEASE_URL2="$MIRROR_URL/Packages/f/fedora-release-$release-1.noarch.rpm"
    RELEASE_TARGET=$INSTALL_ROOT/fedora-release-$release.noarch.rpm
    found=""
    for attempt in $RELEASE_URL1 $RELEASE_URL2; do
	if curl -f $attempt -o $RELEASE_TARGET ; then
	    echo "Retrieved $attempt"
	    found=true
	    break
	else
	    echo "Failed attempt $attempt"
	fi
    done
    [ -n "$found" ] || { echo "Could not retrieve fedora-release rpm - exiting" ; exit 1; }
    
    mkdir -p $INSTALL_ROOT/var/lib/rpm
    rpm --root $INSTALL_ROOT  --initdb
    # when installing f12 this apparently is already present, so ignore result
    rpm --root $INSTALL_ROOT -ivh $INSTALL_ROOT/fedora-release-$release.noarch.rpm || :
    # however f12 root images won't get created on a f18 host
    # (the issue here is the same as the one we ran into when dealing with a vs-box)
    # in a nutshell, in f12 the glibc-common and filesystem rpms have an apparent conflict
    # >>> file /usr/lib/locale from install of glibc-common-2.11.2-3.x86_64 conflicts 
    #          with file from package filesystem-2.4.30-2.fc12.x86_64
    # in fact this was - of course - allowed by f12's rpm but later on a fix was made 
    #   http://rpm.org/gitweb?p=rpm.git;a=commitdiff;h=cf1095648194104a81a58abead05974a5bfa3b9a
    # So ideally if we want to be able to build f12 images from f18 we need an rpm that has
    # this patch undone, like we have in place on our f14 boxes (our f14 boxes need a f18-like rpm)

    YUM="yum --installroot=$INSTALL_ROOT --nogpgcheck -y"
    echo "$YUM install $FEDORA_PREINSTALLED"
    $YUM install $FEDORA_PREINSTALLED || { echo "Failed to download rootfs, aborting." ; return 1; }

    mv "$INSTALL_ROOT" "$cache/rootfs"
    echo "Download complete."

    return 0
}

##############################
function fedora_configure() {

    set -x
    set -e

    # disable selinux in fedora
    mkdir -p $lxc_root/selinux
    echo 0 > $lxc_root/selinux/enforce

    # set the hostname
    case "$fcdistro" in 
	f18|f2?)
	    cat <<EOF > ${lxc_root}/etc/hostname
$GUEST_HOSTNAME
EOF
	    echo ;;
	*)
            cat <<EOF > ${lxc_root}/etc/sysconfig/network
NETWORKING=yes
HOSTNAME=$GUEST_HOSTNAME
EOF
            # set minimal hosts
	    cat <<EOF > $lxc_root/etc/hosts
127.0.0.1 localhost $GUEST_HOSTNAME
EOF
	    echo ;;
    esac

    dev_path="${lxc_root}/dev"
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

    if [ "$(echo $fcdistro | cut -d"f" -f2)" -le "14" ]; then
	fedora_configure_init
    else
	fedora_configure_systemd
    fi

    guest_ifcfg=${lxc_root}/etc/sysconfig/network-scripts/ifcfg-$VIF_GUEST
    ( [ -n "$BUILD_MODE" ] && write_guest_ifcfg_build || write_guest_ifcfg_test ) > $guest_ifcfg

    [ -z "$IMAGE" ] && fedora_configure_yum $lxc $fcdistro $pldistro

    return 0
}

function fedora_configure_init() {
    set -e
    set -x
    sed -i 's|.sbin.start_udev||' ${lxc_root}/etc/rc.sysinit
    sed -i 's|.sbin.start_udev||' ${lxc_root}/etc/rc.d/rc.sysinit
    # don't mount devpts, for pete's sake
    sed -i 's/^.*dev.pts.*$/#\0/' ${lxc_root}/etc/rc.sysinit
    sed -i 's/^.*dev.pts.*$/#\0/' ${lxc_root}/etc/rc.d/rc.sysinit
    chroot ${lxc_root} chkconfig udev-post off
    chroot ${lxc_root} chkconfig network on
}

# this code of course is for guests that do run on systemd
function fedora_configure_systemd() {
    set -e
    set -x
    # so ignore if we can't find /etc/systemd at all 
    [ -d ${lxc_root}/etc/systemd ] || return 0
    # otherwise let's proceed
    ln -sf /lib/systemd/system/multi-user.target ${lxc_root}/etc/systemd/system/default.target
    touch ${lxc_root}/etc/fstab
    ln -sf /dev/null ${lxc_root}/etc/systemd/system/udev.service
# Thierry - Feb 2013
# this was intended for f16 initially, in order to enable getty that otherwise would not start
# having a getty running is helpful only if ssh won't start though, and we see a correlation between
# VM's that refuse to lxc-stop and VM's that run crazy getty's
# so, turning getty off for now instead
#   #dependency on a device unit fails it specially that we disabled udev
#    sed -i 's/After=dev-%i.device/After=/' ${lxc_root}/lib/systemd/system/getty\@.service
    ln -sf /dev/null ${lxc_root}/etc/systemd/system/"getty@.service"
    rm -f ${lxc_root}/etc/systemd/system/getty.target.wants/*service || :
# can't seem to handle this one with systemctl
    chroot ${lxc_root} chkconfig network on
}

# overwrite container yum config
function fedora_configure_yum () {
    set -x 
    set -e 
    trap failure ERR INT

    lxc=$1; shift
    fcdistro=$1; shift
    pldistro=$1; shift

    # rpm --rebuilddb
    chroot $lxc_root rpm --rebuilddb

    echo "Initializing yum.repos.d in $lxc"
    rm -f $lxc_root/etc/yum.repos.d/*

    cat > $lxc_root/etc/yum.repos.d/building.repo <<EOF
[fedora]
name=Fedora \$releasever - \$basearch
baseurl=$FEDORA_MIRROR_BASE/releases/\$releasever/Everything/\$basearch/os/
enabled=1
metadata_expire=7d
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-fedora-\$releasever-\$basearch

[updates]
name=Fedora \$releasever - \$basearch - Updates
baseurl=$FEDORA_MIRROR_BASE/updates/\$releasever/\$basearch/
enabled=1
metadata_expire=7d
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-fedora-\$releasever-\$basearch
EOF

    # for using vtest-init-lxc.sh as a general-purpose lxc creation wrapper
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
# need to specify the right mirror for debian variants like ubuntu and the like
function debian_mirror () {
    fcdistro=$1; shift
    case $fcdistro in
	squeeze|wheezy|jessie) 
	    echo http://ftp2.fr.debian.org/debian/ ;;
	oneiric|precise|quantal|raring|saucy) 
	    echo http://mir1.ovh.net/ubuntu/ubuntu/ ;;
	*) echo unknown distro $fcdistro; exit 1;;
    esac
}

function debian_install () {
    set -e
    set -x
    lxc=$1; shift
    mkdir -p $lxc_root
    arch=$(canonical_arch $personality $fcdistro)
    mirror=$(debian_mirror $fcdistro)
    debootstrap --arch $arch $fcdistro $lxc_root $mirror
    # just like with fedora we ensure a few packages get installed as well
    # not started yet
    #virsh -c lxc:/// lxc-enter-namespace $lxc --noseclabel /bin/bash -c "apt-get update"
    #virsh -c lxc:/// lxc-enter-namespace $lxc --noseclabel /bin/bash -c "apt-get -y install $DEBIAN_PREINSTALLED"
    chroot $lxc_root apt-get update
    chroot $lxc_root apt-get -y install $DEBIAN_PREINSTALLED
    # configure hostname
    cat <<EOF > ${lxc_root}/etc/hostname
$GUEST_HOSTNAME
EOF
    
}

function debian_configure () {
    guest_interfaces=${lxc_root}/etc/network/interfaces
    ( [ -n "$BUILD_MODE" ] && write_guest_interfaces_build || write_guest_interfaces_test ) > $guest_interfaces
}

function write_guest_interfaces_build () {
    cat <<EOF
auto $VIF_GUEST
iface $VIF_GUEST inet dhcp
EOF
}

function write_guest_interfaces_test () {
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

    lxc=$1; shift
    fcdistro=$1; shift
    pldistro=$1; shift
    personality=$1; shift

    # create lxc container 
    
    pkg_method=$(package_method $fcdistro)
    case $pkg_method in
	yum)
            if [ -z "$IMAGE" ]; then
                fedora_install ||  { echo "failed to install fedora root image"; exit 1 ; }
            fi
	    fedora_configure || { echo "failed to configure fedora for a container"; exit 1 ; }
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
    mkdir $lxc_root/cgroup
    
    # set up resolv.conf
    cp /etc/resolv.conf $lxc_root/etc/resolv.conf
    # and /etc/hosts for at least localhost
    [ -f $lxc_root/etc/hosts ] || echo "127.0.0.1 localhost localhost.localdomain" > $lxc_root/etc/hosts
    
    # grant ssh access from host to guest
    mkdir -p $lxc_root/root/.ssh
    cat /root/.ssh/id_rsa.pub >> $lxc_root/root/.ssh/authorized_keys
    chmod 700 $lxc_root/root/.ssh
    chmod 600 $lxc_root/root/.ssh/authorized_keys

    # don't keep the input xml, this can be retrieved at all times with virsh dumpxml
    config_xml=/tmp/$lxc.xml
    ( [ -n "$BUILD_MODE" ] && write_lxc_xml_build $lxc || write_lxc_xml_test $lxc ) > $config_xml
    
    # define lxc container for libvirt
    virsh -c lxc:/// define $config_xml

    return 0
}

function write_lxc_xml_test () {
    lxc=$1; shift
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
  <network>
    <name>host-bridge</name>
    <forward mode="bridge"/>
    <bridge name="$PUBLIC_BRIDGE"/>
  </network>
</domain>
EOF
}

function write_lxc_xml_build () { 
    lxc=$1; shift
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
    <interface type="network">
      <source network="default"/>
    </interface>
    <console type='pty' />
  </devices>
</domain>
EOF
}

# this one is dhcp-based
function write_guest_ifcfg_build () {
    cat <<EOF
DEVICE=$VIF_GUEST
BOOTPROTO=dhcp
ONBOOT=yes
NM_CONTROLLED=no
TYPE=Ethernet
MTU=1500
EOF
}

# use fixed GUEST_IP as specified by GUEST_HOSTNAME
function write_guest_ifcfg_test () {
    cat <<EOF
DEVICE=$VIF_GUEST
BOOTPROTO=static
ONBOOT=yes
HOSTNAME=$GUEST_HOSTNAME
IPADDR=$GUEST_IP
NETMASK=$NETMASK
GATEWAY=$GATEWAY
NM_CONTROLLED=no
TYPE=Ethernet
MTU=1500
EOF
}

function devel_or_vtest_tools () {

    set -x 
    set -e 
    trap failure ERR INT

    lxc=$1; shift
    fcdistro=$1; shift
    pldistro=$1; shift
    personality=$1; shift

    pkg_method=$(package_method $fcdistro)

    pkgsfile=$(pl_locateDistroFile $DIRNAME $pldistro $PREINSTALLED)

    ### install individual packages, then groups
    # get target arch - use uname -i here (we want either x86_64 or i386)
   
    lxc_arch=$(chroot $lxc_root uname -i)
    # on debian systems we get arch through the 'arch' command
    [ "$lxc_arch" = "unknown" ] && lxc_arch=$(chroot $lxc_root arch)

    packages=$(pl_getPackages -a $lxc_arch $fcdistro $pldistro $pkgsfile)
    groups=$(pl_getGroups -a $lxc_arch $fcdistro $pldistro $pkgsfile)

    case "$pkg_method" in
	yum)
	    [ -n "$packages" ] && chroot $lxc_root yum -y install $packages
	    for group_plus in $groups; do
		group=$(echo $group_plus | sed -e "s,+++, ,g")
		chroot $lxc_root yum -y groupinstall "$group"
	    done
	    # store current rpm list in /init-lxc.rpms in case we need to check the contents
	    chroot $lxc_root rpm -aq > $lxc_root/init-lxc.rpms
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
	        #virsh -c lxc:/// lxc-enter-namespace $lxc --noseclabel /bin/bash -c "apt-get install -y $package" || :
		chroot $lxc_root apt-get install -y $package || :
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
    lxc=$1; shift 
    personality=$1; shift
    if [ -n "$BUILD_MODE" ] ; then
	post_install_build $lxc $personality
	virsh -c lxc:/// start $lxc
	# manually run dhclient in guest - somehow this network won't start on its own
	virsh -c lxc:/// lxc-enter-namespace $lxc --noseclabel /bin/bash -c "dhclient $VIF_GUEST"
    else
	post_install_myplc $lxc $personality
	virsh -c lxc:/// start $lxc
# it sounds like we don't need ssh per se any more
# it still makes sense to wait for network readiness though
# some day maybe...
	wait_for_ssh $lxc
    fi
    # setup localtime from the host
    cp /etc/localtime $lxc_root/etc/localtime
}

function post_install_build () {

    set -x 
    set -e 
    trap failure ERR INT

    lxc=$1; shift
    personality=$1; shift

### From myplc-devel-native.spec
# be careful to backslash $ in this, otherwise it's the root context that's going to do the evaluation
    cat << EOF | chroot $lxc_root bash -x
    
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

    lxc=$1; shift
    personality=$1; shift

# be careful to backslash $ in this, otherwise it's the root context that's going to do the evaluation
    cat << EOF | chroot $lxc_root bash -x

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

function wait_for_ssh () {
    set -x
    set -e
    #trap failure ERR INT

    lxc=$1; shift
  
    echo network in guest is up, waiting for ssh...

    #wait max 2 min for sshd to start 
    ssh_up=""
    current_time=$(date +%s)
    stop_time=$(($current_time + 120))
    
    counter=1
    while [ "$current_time" -lt "$stop_time" ] ; do
         echo "$counter-th attempt to reach sshd in container $lxc ..."
         ssh -o "StrictHostKeyChecking no" $GUEST_IP 'uname -i' && { ssh_up=true; echo "SSHD in container $lxc is UP"; break ; } || :
         sleep 10
         current_time=$(($current_time + 10))
         counter=$(($counter+1))
    done

    # Thierry: this is fatal, let's just exit with a failure here
    [ -z $ssh_up ] && { echo "SSHD in container $lxc is not running" ; exit 1 ; } 
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

    while getopts "n:f:d:p:r:P:i:m:v" opt ; do
	case $opt in
	    n) GUEST_HOSTNAME=$OPTARG;;
	    f) fcdistro=$OPTARG;;
	    d) pldistro=$OPTARG;;
	    p) personality=$OPTARG;;
	    r) REPO_URL=$OPTARG;;
	    P) PREINSTALLED=$OPTARG;;
            i) IMAGE=$OPTARG;;
            m) MEMORY=$OPTARG;;
	    v) VERBOSE=true; set -x;;
	    *) usage ;;
	esac
    done
	
    shift $(($OPTIND - 1))

    # parse fixed arguments
    [[ -z "$@" ]] && usage
    lxc=$1 ; shift
    lxc_root=/vservers/$lxc

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

    # BUILD_MODE is true unless we specified a hostname
    [ -n "$GUEST_HOSTNAME" ] || BUILD_MODE=true

    # set default values
    [ -z "$fcdistro" ] && fcdistro=$DEFAULT_FCDISTRO
    [ -z "$pldistro" ] && pldistro=$DEFAULT_PLDISTRO
    [ -z "$personality" ] && personality=$DEFAULT_PERSONALITY
    [ -z "$MEMORY" ] && MEMORY=$DEFAULT_MEMORY
    
    # set memory in KB
    MEMORY=$(($MEMORY * 1024))
    
    # the set of preinstalled packages - depends on mode
    if [ -z "$PREINSTALLED"] ; then
	if [ -n "$BUILD_MODE" ] ; then
	    PREINSTALLED=devel.pkgs
	else
	    PREINSTALLED=runtime.pkgs
	fi
    fi

    if [ -n "$BUILD_MODE" ] ; then
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
    release=$(echo $fcdistro | cut -df -f2)

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
    if [ -z "$BUILD_MODE" ] ; then

	create_bridge_if_needed

	GUEST_IP=$(gethostbyname $GUEST_HOSTNAME)
	# use same NETMASK as bridge interface br0
	MASKLEN=$(ip addr show $PUBLIC_BRIDGE | grep -v inet6 | grep inet | awk '{print $2;}' | cut -d/ -f2)
        NETMASK=$(masklen_to_netmask $MASKLEN)
        GATEWAY=$(ip route show | grep default | awk '{print $3}' | head -1)
        VIF_HOST="i$(echo $GUEST_HOSTNAME | cut -d. -f1)"
    fi

    setup_lxc $lxc $fcdistro $pldistro $personality 

    devel_or_vtest_tools $lxc $fcdistro $pldistro $personality

    # container gets started here
    post_install $lxc $personality
    
    echo $COMMAND Done

    exit 0
}

main "$@"
