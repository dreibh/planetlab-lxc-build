# /=========================================================================\
# =             #     #                 #     #                             =
# =             ##    #   ####   #####  ##    #  ######   #####             =
# =             # #   #  #    #  #    # # #   #  #          #               =
# =             #  #  #  #    #  #    # #  #  #  #####      #               =
# =             #   # #  #    #  #####  #   # #  #          #               =
# =             #    ##  #    #  #   #  #    ##  #          #               =
# =             #     #   ####   #    # #     #  ######     #               =
# =                                                                         =
# =             A Real-World, Large-Scale Multi-Homing Testbed              =
# =                          https://www.nntb.no/                           =
# =                                                                         =
# = Contact: Thomas Dreibholz                                               =
# =          dreibh@simula.no, https://www.simula.no/people/dreibh          =
# \=========================================================================/

#
# declare the packages to be built and their dependencies
# initial version from Mark Huang
# Mark Huang <mlhuang@cs.princeton.edu>
# Copyright (C) 2003-2006 The Trustees of Princeton University
# rewritten by Thierry Parmentelat - INRIA Sophia Antipolis
#
# see doc in Makefile  
#


# ###### NorNet customisation ###############################################

kernel-MODULES := linux
kernel-SPEC := kernel.spec
kernel-BUILD-FROM-SRPM := yes
ifeq "$(HOSTARCH)" "i386"
   kernel-RPMFLAGS := --target i686
else
   kernel-RPMFLAGS := --target $(HOSTARCH)
endif
kernel-RPMFLAGS += --without smp --without pae --without debug --without doc --without debuginfo --without perf
kernel-WHITELIST-RPMS := kernel,kernel-headers,kernel-devel,kernel-modules-extra,kernel-tools,kernel-tools-libs,kernel-tools-libs-devel
kernel-SPECVARS += kernelconfig=planetlab
KERNELS += kernel
#kernel-STOCK-DEVEL-RPMS +=

kernels: $(KERNELS)
kernels-clean: $(foreach package,$(KERNELS),$(package)-clean)

ALL += $(KERNELS)
# this is to mark on which image a given rpm is supposed to go
IN_BOOTCD += $(KERNELS)
#IN_SLICEIMAGE += $(KERNELS)
IN_NODEIMAGE += $(KERNELS)

#
# netperfmeter
#
netperfmeter-MODULES := netperfmeter
netperfmeter-SPEC := rpm/netperfmeter.spec
ALL += netperfmeter
IN_NODEIMAGE += netperfmeter

#
# nornet-nn
#
nornet-nn-MODULES := nornet-nn
nornet-nn-SPEC := rpm/nornet-nn.spec
ALL += nornet-nn
IN_NODEIMAGE += nornet-nn

#
# rsplib
#
rsplib-MODULES := rsplib
rsplib-SPEC := rpm/rsplib.spec
ALL += rsplib
IN_NODEIMAGE += rsplib

#
# subnetcalc
#
subnetcalc-MODULES := subnetcalc
subnetcalc-SPEC := rpm/subnetcalc.spec
ALL += subnetcalc
IN_NODEIMAGE += subnetcalc

#
# tracebox
#
# tracebox-MODULES := tracebox
# tracebox-SPEC := rpm/tracebox.spec
# tracebox-STOCK-DEVEL-RPMS := fakeroot
# ALL += tracebox
# IN_NODEIMAGE += tracebox

#
# tsctp
#
tsctp-MODULES := tsctp
tsctp-SPEC := rpm/tsctp.spec
ALL += tsctp
IN_NODEIMAGE += tsctp

# ###########################################################################


### the madwifi drivers ship with fedora16's kernel rpm

#
# lxc-userspace: scripts for entering containers
#
lxc-userspace-MODULES := lxc-userspace
lxc-userspace-SPEC := lxc-userspace.spec
ALL += lxc-userspace
IN_NODEIMAGE += lxc-userspace

#
#
# transforward: root context module for transparent port forwarding
#
transforward-MODULES := transforward
transforward-SPEC := transforward.spec
# ##### NorNet ########################
transforward-LOCAL-DEVEL-RPMS += kernel-devel
transforward-SPECVARS = kernel_version=$(kernel.rpm-version) \
        kernel_release=$(kernel.rpm-release) \
        kernel_arch=$(kernel.rpm-arch)
# #####################################
ALL += transforward
IN_NODEIMAGE += transforward

#
# procprotect: root context module for protecting against weaknesses in /proc
#
procprotect-MODULES := procprotect
procprotect-SPEC := procprotect.spec
# ##### NorNet ########################
procprotect-LOCAL-DEVEL-RPMS += kernel-devel
procprotect-SPECVARS = kernel_version=$(kernel.rpm-version) \
        kernel_release=$(kernel.rpm-release) \
        kernel_arch=$(kernel.rpm-arch)
# #####################################
ALL += procprotect
IN_NODEIMAGE += procprotect

# ?????
# #
# # ipfw: root context module, and slice companion
# #
# # this module won't build yet under f20
# ifeq "$(DISTRONAME)" "f18"
# ipfwroot-MODULES := ipfw
# ipfwroot-SPEC := planetlab/ipfwroot.spec
# # ##### NorNet ########################
# ipfwroot-LOCAL-DEVEL-RPMS += kernel-devel
# ipfwroot-SPECVARS = kernel_version=$(kernel.rpm-version) \
#         kernel_release=$(kernel.rpm-release) \
#         kernel_arch=$(kernel.rpm-arch)
# # #####################################
# ALL += ipfwroot
# IN_NODEIMAGE += ipfwroot
# 
# ipfwslice-MODULES := ipfw
# ipfwslice-SPEC := planetlab/ipfwslice.spec
# # ##### NorNet ########################
# ipfwslice-LOCAL-DEVEL-RPMS += kernel-devel
# ipfwslice-SPECVARS = kernel_version=$(kernel.rpm-version) \
#         kernel_release=$(kernel.rpm-release) \
#         kernel_arch=$(kernel.rpm-arch)
# # #####################################
# ALL += ipfwslice
# endif
# ?????

#
# comgt - a companion to umts tools
# 
comgt-MODULES := comgt
comgt-SPEC := comgt.spec
IN_NODEIMAGE += comgt
ALL += comgt

#
# umts: root context stuff
#
umts-backend-MODULES := planetlab-umts-tools
umts-backend-SPEC := backend.spec
IN_NODEIMAGE += umts-backend
ALL += umts-backend

#
# umts: slice tools
#
umts-frontend-MODULES := planetlab-umts-tools
umts-frontend-SPEC := frontend.spec
IN_SLICEIMAGE += umts-frontend
ALL += umts-frontend

#
# NodeUpdate
#
nodeupdate-MODULES := nodeupdate
nodeupdate-SPEC := NodeUpdate.spec
ALL += nodeupdate
IN_NODEIMAGE += nodeupdate

#
# ipod
#
ipod-MODULES := PingOfDeath
ipod-SPEC := ipod.spec
ALL += ipod
IN_NODEIMAGE += ipod

#
# plnode-utils
# 
plnode-utils-MODULES := plnode-utils
plnode-utils-SPEC := plnode-utils-lxc.spec
ALL += plnode-utils
IN_NODEIMAGE += plnode-utils

# nodemanager
#
nodemanager-MODULES := nodemanager
nodemanager-SPEC := nodemanager.spec
ALL += nodemanager
IN_NODEIMAGE += nodemanager

#
# pl_sshd
#
sshd-MODULES := pl_sshd
sshd-SPEC := pl_sshd.spec
ALL += sshd
IN_NODEIMAGE += sshd

#
# codemux: Port 80 demux
#
codemux-MODULES := codemux
codemux-SPEC   := codemux.spec
ALL += codemux
IN_NODEIMAGE += codemux

#
# fprobe-ulog
#
# xxx temporarily turning this off on f20 and f21
ifneq "$(DISTRONAME)" "$(filter $(DISTRONAME),f20 f21)"
fprobe-ulog-MODULES := fprobe-ulog
fprobe-ulog-SPEC := fprobe-ulog.spec
ALL += fprobe-ulog
IN_NODEIMAGE += fprobe-ulog
endif

#################### libvirt version selection
# settling with using version 1.2.1 on all fedoras
# although this does not solve the slice re-creation issue seen on f20

local_libvirt=true
separate_libvirt_python=true

#
# libvirt
#
ifeq "$(local_libvirt)" "true"

libvirt-MODULES := libvirt
libvirt-SPEC    := libvirt.spec
libvirt-BUILD-FROM-SRPM := yes
# The --without options are breaking spec2make : hard-wired in the specfile instead
libvirt-STOCK-DEVEL-RPMS += xhtml1-dtds
libvirt-STOCK-DEVEL-RPMS += libattr-devel augeas libpciaccess-devel yajl-devel 
libvirt-STOCK-DEVEL-RPMS += libpcap-devel radvd ebtables device-mapper-devel 
libvirt-STOCK-DEVEL-RPMS += ceph-devel numactl-devel libcap-ng-devel scrub 
# for 1.2.1 - first seen on f20, not sure for the other ones
libvirt-STOCK-DEVEL-RPMS += libblkid-devel glusterfs-api-devel glusterfs-devel
# strictly speaking fuse-devel is not required anymore but we might wish to turn fuse back on again in the future
libvirt-STOCK-DEVEL-RPMS += fuse-devel libssh2-devel dbus-devel numad 
libvirt-STOCK-DEVEL-RPMS += systemd-devel libnl3-devel iptables-services netcf-devel
# 1.2.11
libvirt-STOCK-DEVEL-RPMS += wireshark-devel
libvirt-STOCK-DEVEL-RPMS += ceph-devel-compat
ALL += libvirt
IN_NODEREPO += libvirt
IN_NODEIMAGE += libvirt

endif

#
## libvirt-python
#
ifeq "$(separate_libvirt_python)" "true"

libvirt-python-MODULES := libvirt-python
libvirt-python-SPEC    := libvirt-python.spec
libvirt-python-BUILD-FROM-SRPM := yes
libvirt-python-STOCK-DEVEL-RPMS += pm-utils
# for 1.2.11
libvirt-python-STOCK-DEVEL-RPMS += python-nose
# it would make sense to do something like this if we wanted to
# build against python3 as well, but for now I turned this feature off
# in libvirt-python
#ifeq "$(distro)" "Fedora"
#xxx if $(distrorelease) > 18
#libvirt-python-STOCK-DEVEL-RPMS += python3-devel python3-nose python3-lxml
#endif
#endif
libvirt-python-LOCAL-DEVEL-RPMS += libvirt-devel libvirt-docs libvirt-client
libvirt-python-RPMFLAGS :=     --define 'packager PlanetLab'
ALL += libvirt-python
IN_NODEREPO += libvirt-python
IN_NODEIMAGE += libvirt-python

endif

#
# DistributedRateLimiting
#
#DistributedRateLimiting-MODULES := DistributedRateLimiting
#DistributedRateLimiting-SPEC := DistributedRateLimiting.spec
#ALL += DistributedRateLimiting
#IN_NODEREPO += DistributedRateLimiting

#
# pf2slice
#
pf2slice-MODULES := pf2slice
pf2slice-SPEC := pf2slice.spec
ALL += pf2slice

##
## PlanetLab Mom: Cleans up your mess
##
#mom-MODULES := mom
#mom-SPEC := pl_mom.spec
#ALL += mom
#IN_NODEIMAGE += mom

#
# openvswitch
#
# openvswitch-MODULES := openvswitch
# openvswitch-SPEC := openvswitch.spec
# openvswitch-STOCK-DEVEL-RPMS += kernel-devel
# IN_NODEIMAGE += openvswitch
# # build only on f14 as f16 has this natively
# ifeq "$(DISTRONAME)" "$(filter $(DISTRONAME),f14)"
# ALL += openvswitch
# endif

#
# vsys
#
vsys-MODULES := vsys
vsys-SPEC := vsys.spec
# ocaml-docs is not needed anymore but keep it on a tmp basis as some tags may still have it
vsys-STOCK-DEVEL-RPMS += ocaml-ocamldoc ocaml-docs
IN_NODEIMAGE += vsys
ALL += vsys

#
# vsyssh : installed in slivers
#
vsyssh-MODULES := vsys
vsyssh-SPEC := vsyssh.spec
IN_SLICEIMAGE += vsyssh
ALL += vsyssh

#
# vsys-scripts
#
vsys-scripts-MODULES := vsys-scripts
vsys-scripts-SPEC := root-context/vsys-scripts.spec
IN_NODEIMAGE += vsys-scripts
ALL += vsys-scripts

# xxx temporarily turning this off on f21
ifneq "$(DISTRONAME)" "$(filter $(DISTRONAME),f21)"
vsys-wrapper-MODULES := vsys-scripts
vsys-wrapper-SPEC := slice-context/vsys-wrapper.spec
IN_SLICEIMAGE += vsys-wrapper
ALL += vsys-wrapper
endif

# ##### NorNet ########################
#
# bind_public
#
# bind_public-MODULES := bind_public
# bind_public-SPEC := bind_public.spec
# IN_SLICEIMAGE += bind_public
# ALL += bind_public
# ##### NorNet ########################

#
# sliver-openvswitch
#
sliver-openvswitch-MODULES := sliver-openvswitch
sliver-openvswitch-SPEC := sliver-openvswitch.spec
IN_SLICEIMAGE += sliver-openvswitch
ALL += sliver-openvswitch

#
# plcapi
#
plcapi-MODULES := plcapi
plcapi-SPEC := plcapi.spec
ALL += plcapi
IN_MYPLC += plcapi

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
ALL += plewww
IN_MYPLC += plewww

#
# www-register-wizard
#
www-register-wizard-MODULES := www-register-wizard
www-register-wizard-SPEC := www-register-wizard.spec
ALL += www-register-wizard
IN_MYPLC += www-register-wizard

#
# pcucontrol
#
pcucontrol-MODULES := pcucontrol
pcucontrol-SPEC := pcucontrol.spec
ALL += pcucontrol

#
# monitor
#
#monitor-MODULES := monitor
#monitor-SPEC := Monitor.spec
#monitor-STOCK-DEVEL-RPMS += net-snmp net-snmp-devel
#ALL += monitor
#IN_NODEIMAGE += monitor

#
# PLC RT
#
plcrt-MODULES := PLCRT
plcrt-SPEC := plcrt.spec
ALL += plcrt

# f12 has 0.9-1 already
ifeq "$(DISTRONAME)" "$(filter $(DISTRONAME),f8 centos5)"
#
# pyopenssl
#
pyopenssl-MODULES := pyopenssl
pyopenssl-SPEC := pyOpenSSL.spec
pyopenssl-BUILD-FROM-SRPM := yes
ALL += pyopenssl
endif

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
nodeconfig-MODULES := nodeconfig
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
IN_NODEIMAGE += pyplnet
IN_MYPLC += pyplnet
IN_BOOTCD += pyplnet

#
# OML measurement library
#
oml-MODULES := oml
oml-STOCK-DEVEL-RPMS += sqlite-devel 
oml-SPEC := liboml.spec
ALL += oml

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
# images for slices
#
sliceimage-MODULES := sliceimage build
sliceimage-SPEC := sliceimage.spec
sliceimage-DEPEND-PACKAGES := $(IN_SLICEIMAGE)
sliceimage-DEPEND-FILES := RPMS/yumgroups.xml
sliceimage-RPMDATE := yes
ALL += sliceimage
IN_NODEIMAGE += sliceimage

#
# lxc-specific sliceimage initialization
# 
lxc-sliceimage-MODULES	:= sliceimage
lxc-sliceimage-SPEC	:= lxc-sliceimage.spec
lxc-sliceimage-RPMDATE	:= yes
ALL			+= lxc-sliceimage
IN_NODEIMAGE		+= lxc-sliceimage

#
# nodeimage
#
nodeimage-MODULES := nodeimage build
nodeimage-SPEC := nodeimage.spec
nodeimage-DEPEND-PACKAGES := $(IN_NODEIMAGE)
nodeimage-DEPEND-FILES := RPMS/yumgroups.xml
nodeimage-RPMDATE := yes
ALL += nodeimage
IN_MYPLC += nodeimage

#
# noderepo
#
# all rpms resulting from packages marked as being in nodeimage and sliceimage
NODEREPO_RPMS = $(foreach package,$(IN_NODEIMAGE) $(IN_NODEREPO) $(IN_SLICEIMAGE),$($(package).rpms))
# replace space with +++ (specvars cannot deal with spaces)
SPACE=$(subst x, ,x)
NODEREPO_RPMS_3PLUS = $(subst $(SPACE),+++,$(NODEREPO_RPMS))

noderepo-MODULES := nodeimage
noderepo-SPEC := noderepo.spec
# package requires all embedded packages
noderepo-DEPEND-PACKAGES := $(IN_NODEIMAGE) $(IN_NODEREPO) $(IN_SLICEIMAGE)
noderepo-DEPEND-FILES := RPMS/yumgroups.xml
#export rpm list to the specfile
noderepo-SPECVARS = node_rpms_plus=$(NODEREPO_RPMS_3PLUS)
noderepo-RPMDATE := yes
ALL += noderepo
IN_MYPLC += noderepo

#
# slicerepo
#
# all rpms resulting from packages marked as being in vserver
SLICEREPO_RPMS = $(foreach package,$(IN_SLICEIMAGE),$($(package).rpms))
# replace space with +++ (specvars cannot deal with spaces)
SPACE=$(subst x, ,x)
SLICEREPO_RPMS_3PLUS = $(subst $(SPACE),+++,$(SLICEREPO_RPMS))

slicerepo-MODULES := nodeimage
slicerepo-SPEC := slicerepo.spec
# package requires all embedded packages
slicerepo-DEPEND-PACKAGES := $(IN_SLICEIMAGE)
slicerepo-DEPEND-FILES := RPMS/yumgroups.xml
#export rpm list to the specfile
slicerepo-SPECVARS = slice_rpms_plus=$(SLICEREPO_RPMS_3PLUS)
slicerepo-RPMDATE := yes
ALL += slicerepo

#
# MyPLC : lightweight packaging, dependencies are yum-installed in a vserver
#
myplc-MODULES := myplc
myplc-SPEC := myplc.spec
myplc-DEPEND-FILES := myplc-release RPMS/yumgroups.xml
ALL += myplc

# myplc-docs only contains docs for PLCAPI and NMAPI, but
# we still need to pull MyPLC, as it is where the specfile lies, 
# together with the utility script docbook2drupal.sh
myplc-docs-MODULES := myplc plcapi nodemanager monitor
myplc-docs-SPEC := myplc-docs.spec
ALL += myplc-docs

# using some other name than myplc-release, as this is a make target already
release-MODULES := myplc
release-SPEC := myplc-release.spec
release-RPMDATE := yes
ALL += release

##############################
#
# sfa - Slice Facility Architecture
#
sfa-MODULES := sfa
sfa-SPEC := sfa.spec
ALL += sfa
