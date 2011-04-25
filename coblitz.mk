# $Id$
# $URL$
#
# declare the packages to be built and their dependencies
# initial version from Mark Huang
# Mark Huang <mlhuang@cs.princeton.edu>
# Copyright (C) 2003-2006 The Trustees of Princeton University
# rewritten by Thierry Parmentelat - INRIA Sophia Antipolis
#
# $Id$
#
# see doc in Makefile  
#
#
# certmaster & func
# 
ifeq "$(PLDISTROTAGS)" "coblitz-latest-tags.mk"
ifeq "$(DISTRONAME)" "sl6"

certmaster-MODULES := certmaster
certmaster-SPEC := certmaster.spec
certmaster-BUILD-FROM-SRPM := yes
ALL += certmaster
IN_BOOTSTRAPFS += certmaster
IN_MYPLC += certmaster

#func
func-MODULES := func
func-SPEC := func.spec
func-BUILD-FROM-SRPM := yes
ALL += func
IN_BOOTSTRAPFS += func
IN_MYPLC += func

endif
endif

#
# mkinitrd
#
ifeq "$(PLDISTROTAGS)" "coblitz-latest-tags.mk"
ifeq "$(DISTRONAME)" "centos5"
mkinitrd-MODULES := mkinitrd
mkinitrd-SPEC := mkinitrd.spec
mkinitrd-BUILD-FROM-SRPM := yes
ALL += mkinitrd
IN_BOOTCD += mkinitrd
IN_VSERVER += mkinitrd
IN_BOOTSTRAPFS += mkinitrd
IN_MYPLC += mkinitrd
endif
endif

#
# kernel
#
# use a package name with srpm in it:
# so the source rpm is created by running make srpm in the codebase
#

kernel-MODULES := linux-2.6
kernel-SPEC := kernel-2.6.spec
kernel-BUILD-FROM-SRPM := yes
ifeq "$(HOSTARCH)" "i386"
kernel-RPMFLAGS:= --target i686
else
kernel-RPMFLAGS:= --target $(HOSTARCH)
endif
KERNELS += kernel

kernels: $(KERNELS)
kernels-clean: $(foreach package,$(KERNELS),$(package)-clean)

ALL += $(KERNELS)
# this is to mark on which image a given rpm is supposed to go
IN_BOOTCD += $(KERNELS)
IN_VSERVER += $(KERNELS)
IN_BOOTSTRAPFS += $(KERNELS)
# turns out myplc installs kernel-vserver
IN_MYPLC += $(KERNELS)

#
# util-vserver
#
util-vserver-MODULES := util-vserver
util-vserver-SPEC := util-vserver.spec
util-vserver-RPMFLAGS:= --without dietlibc
ALL += util-vserver
IN_BOOTSTRAPFS += util-vserver

#
# libnl - local import
# we need either 1.1 or at least 1.0.pre6
# rebuild this on centos5 - see kexcludes in build.common
#
local_libnl=false
ifeq "$(DISTRONAME)" "centos5"
local_libnl=true
endif

ifeq "$(local_libnl)" "true"
libnl-MODULES := libnl
libnl-SPEC := libnl.spec
libnl-BUILD-FROM-SRPM := yes
# this sounds like the thing to do, but in fact linux/if_vlan.h comes with kernel-headers
libnl-DEPEND-DEVEL-RPMS := kernel-devel kernel-headers
ALL += libnl
IN_BOOTSTRAPFS += libnl
endif

#
# util-vserver-pl
#
util-vserver-pl-MODULES := util-vserver-pl
util-vserver-pl-SPEC := util-vserver-pl.spec
util-vserver-pl-DEPEND-DEVEL-RPMS := util-vserver-lib util-vserver-devel util-vserver-core 
ifeq "$(local_libnl)" "true"
util-vserver-pl-DEPEND-DEVEL-RPMS += libnl libnl-devel
endif
ALL += util-vserver-pl
IN_BOOTSTRAPFS += util-vserver-pl

#
# NodeUpdate
#
nodeupdate-MODULES := nodeupdate
nodeupdate-SPEC := NodeUpdate.spec
ALL += nodeupdate
IN_BOOTSTRAPFS += nodeupdate

#
# NodeManager
#
nodemanager-MODULES := nodemanager
nodemanager-SPEC := NodeManager.spec
ALL += nodemanager
IN_BOOTSTRAPFS += nodemanager

#
# codemux: Port 80 demux
#
codemux-MODULES := codemux
codemux-SPEC   := codemux.spec
#ALL += codemux
#IN_BOOTSTRAPFS += codemux

#
# fprobe-ulog
#
fprobe-ulog-MODULES := fprobe-ulog
fprobe-ulog-SPEC := fprobe-ulog.spec
#ALL += fprobe-ulog
#IN_BOOTSTRAPFS += fprobe-ulog

#
# pf2slice
#
pf2slice-MODULES := pf2slice
pf2slice-SPEC := pf2slice.spec
#ALL += pf2slice

#
# PlanetLab Mom: Cleans up your mess
#
mom-MODULES := Mom
mom-SPEC := pl_mom.spec
#ALL += mom
#IN_BOOTSTRAPFS += mom

#
# iptables
#
iptables-MODULES := iptables
iptables-SPEC := iptables.spec
iptables-DEPEND-DEVEL-RPMS := kernel-devel kernel-headers
ALL += iptables
IN_BOOTSTRAPFS += iptables

#
# iproute
#
iproute-MODULES := iproute2
iproute-SPEC := iproute.spec
ALL += iproute
IN_BOOTSTRAPFS += iproute
IN_VSERVER += iproute
IN_BOOTCD += iproute

#
# inotify-tools - local import
# rebuild this on centos5 (not found) - see kexcludes in build.common
#
local_inotify_tools=false
ifeq "$(DISTRONAME)" "centos5"
local_inotify_tools=true
endif

ifeq "$(DISTRONAME)" "sl6"
local_inotify_tools=true
endif

ifeq "$(local_inotify_tools)" "true"
inotify-tools-MODULES := inotify-tools
inotify-tools-SPEC := inotify-tools.spec
inotify-tools-BUILD-FROM-SRPM := yes
IN_BOOTSTRAPFS += inotify-tools
ALL += inotify-tools
endif

#
# vsys
#
vsys-MODULES := vsys
vsys-SPEC := vsys.spec
# ocaml-docs is not needed anymore but keep it on a tmp basis as some tags may still have it
vsys-DEVEL-RPMS += ocaml-ocamldoc ocaml-docs
ifeq "$(local_inotify_tools)" "true"
vsys-DEPEND-DEVEL-RPMS += inotify-tools inotify-tools-devel
endif
IN_BOOTSTRAPFS += vsys
ALL += vsys

#
# vsys-scripts
#
vsys-scripts-MODULES := vsys-scripts
vsys-scripts-SPEC := vsys-scripts.spec
IN_BOOTSTRAPFS += vsys-scripts
ALL += vsys-scripts

#
# PLCAPI
#
PLCAPI-MODULES := plcapi
PLCAPI-SPEC := PLCAPI.spec
ALL += PLCAPI
IN_MYPLC += PLCAPI

#
# drupal
# 
drupal-MODULES := drupal
drupal-SPEC := drupal.spec
drupal-BUILD-FROM-SRPM := yes
ALL += drupal
IN_MYPLC += drupal

#
# use the plewww module instead
#
plewww-MODULES := plewww
plewww-SPEC := plewww.spec
#ALL += plewww
#IN_MYPLC += plewww

#
# pcucontrol
#
pcucontrol-MODULES := pcucontrol
pcucontrol-SPEC := pcucontrol.spec
ALL += pcucontrol


## monitor
#
monitor-MODULES := monitor
monitor-SPEC := Monitor.spec
monitor-DEVEL-RPMS += net-snmp net-snmp-devel
ALL += monitor
IN_BOOTSTRAPFS += monitor


#
# pyopenssl
#
pyopenssl-MODULES := pyopenssl
pyopenssl-SPEC := pyOpenSSL.spec
pyopenssl-BUILD-FROM-SRPM := yes
ALL += pyopenssl

#
# pyaspects
#
pyaspects-MODULES := pyaspects
pyaspects-SPEC := pyaspects.spec
pyaspects-BUILD-FROM-SRPM := yes
ALL += pyaspects

#
# nodeconfig
#
nodeconfig-MODULES := nodeconfig build
nodeconfig-SPEC := nodeconfig.spec
ALL += nodeconfig
IN_MYPLC += nodeconfig

#
# bootmanager
#
bootmanager-MODULES := bootmanager
bootmanager-SPEC := bootmanager.spec
ALL += bootmanager
IN_MYPLC += bootmanager

#
# pypcilib : used in bootcd
# 
pypcilib-MODULES := pypcilib
pypcilib-SPEC := pypcilib.spec
ALL += pypcilib
IN_BOOTCD += pypcilib

#
# pyplnet
#
pyplnet-MODULES := pyplnet
pyplnet-SPEC := pyplnet.spec
ALL += pyplnet
IN_BOOTSTRAPFS += pyplnet
IN_MYPLC += pyplnet
IN_BOOTCD += pyplnet

#
# bootcd
#
bootcd-MODULES := bootcd build
bootcd-SPEC := bootcd.spec
bootcd-DEPEND-PACKAGES := $(IN_BOOTCD)
bootcd-DEPEND-FILES := RPMS/yumgroups.xml
bootcd-RPMDATE := yes
ALL += bootcd
IN_MYPLC += bootcd

#
# vserver : reference image for slices
#
vserver-MODULES := vserver-reference build
vserver-SPEC := vserver-reference.spec
vserver-DEPEND-PACKAGES := $(IN_VSERVER)
vserver-DEPEND-FILES := RPMS/yumgroups.xml
vserver-RPMDATE := yes
ALL += vserver
IN_BOOTSTRAPFS += vserver

#
# bootstrapfs
#
bootstrapfs-MODULES := bootstrapfs build
bootstrapfs-SPEC := bootstrapfs.spec
bootstrapfs-DEPEND-PACKAGES := $(IN_BOOTSTRAPFS)
bootstrapfs-DEPEND-FILES := RPMS/yumgroups.xml
bootstrapfs-RPMDATE := yes
ALL += bootstrapfs
IN_MYPLC += bootstrapfs

#
# noderepo
#
# all rpms resulting from packages marked as being in bootstrapfs and vserver
NODEREPO_RPMS = $(foreach package,$(IN_BOOTSTRAPFS) $(IN_VSERVER),$($(package).rpms))
# replace space with +++ (specvars cannot deal with spaces)
SPACE=$(subst x, ,x)
NODEREPO_RPMS_3PLUS = $(subst $(SPACE),+++,$(NODEREPO_RPMS))

noderepo-MODULES := bootstrapfs 
noderepo-SPEC := noderepo.spec
# package requires all regular packages
noderepo-DEPEND-PACKAGES := $(IN_BOOTSTRAPFS) $(IN_VSERVER)
noderepo-DEPEND-FILES := RPMS/yumgroups.xml
#export rpm list to the specfile
noderepo-SPECVARS = node_rpms_plus=$(NODEREPO_RPMS_3PLUS)
noderepo-RPMDATE := yes
ALL += noderepo
IN_MYPLC += noderepo

#
# MyPLC : lightweight packaging, dependencies are yum-installed in a vserver
#
myplc-MODULES := myplc build 
myplc-SPEC := myplc.spec
myplc-DEPEND-FILES := myplc-release RPMS/yumgroups.xml
ALL += myplc

# myplc-docs only contains docs for PLCAPI and NMAPI, but
# we still need to pull MyPLC, as it is where the specfile lies, 
# together with the utility script docbook2drupal.sh
myplc-docs-MODULES := myplc plcapi nodemanager
myplc-docs-SPEC := myplc-docs.spec
ALL += myplc-docs

# using some other name than myplc-release, as this is a make target already
release-MODULES := myplc
release-SPEC := myplc-release.spec
release-RPMDATE := yes
ALL += release

ifeq "$(PLDISTROTAGS)" "coblitz-latest-tags.mk"
# chroot supported yum
yum-MODULES := yum
yum-SPEC := yum.spec
yum-BUILD-FROM-SRPM := yes
ALL += yum
endif
