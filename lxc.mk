#
# declare the packages to be built and their dependencies
# initial version from Mark Huang
# Mark Huang <mlhuang@cs.princeton.edu>
# Copyright (C) 2003-2006 The Trustees of Princeton University
# rewritten by Thierry Parmentelat - INRIA Sophia Antipolis
#
# see doc in Makefile
#



### starting with f31 : serverside-only
ifneq "$(DISTRONAME)" "$(filter $(DISTRONAME), f31 f33 f35)"
###



### the madwifi drivers ship with fedora16's kernel rpm

#
# lxc-userspace: scripts for entering containers
#
lxc-userspace-MODULES := lxc-userspace
lxc-userspace-SPEC := lxc-userspace.spec
ALL += lxc-userspace
IN_NODEIMAGE += lxc-userspace

#
# transforward: root context module for transparent port forwarding
#
# with 4.19, the jprobe api has gone entirely
# https://github.com/torvalds/linux/commit/4de58696de076d9bd2745d1cbe0930635c3f5ac9
#
ifneq "$(DISTRONAME)" "$(filter $(DISTRONAME), f31 f33 f35)"
#
transforward-MODULES := transforward
transforward-SPEC := transforward.spec
ALL += transforward
IN_NODEIMAGE += transforward
endif

#
# procprotect: root context module for protecting against weaknesses in /proc
# has gone since f20
#

#
# ipfw: root context module, and slice companion
# has gone since f21
#

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

#
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
# has gone since f20
#

#
# our own brew of libvirt
# is no longer needed since f22
#

#
# pf2slice
#
pf2slice-MODULES := pf2slice
pf2slice-SPEC := pf2slice.spec
ALL += pf2slice

#
# vsys
#
# dropped in f33:
#ocamlopt  -c -o inotify.cmx inotify.ml
#File "inotify.ml", line 95, characters 27-30:
#95 |    let toread = Unix.read fd buf 0 toread in
#                                ^^^
#Error: This expression has type string but an expression was expected of type bytes
#
ifneq "$(DISTRONAME)" "$(filter $(DISTRONAME), f33 f35)"
vsys-MODULES := vsys
vsys-SPEC := vsys.spec
# ocaml-docs is not needed anymore but keep it on a tmp basis as some tags may still have it
vsys-STOCK-DEVEL-RPMS += ocaml-ocamldoc ocaml-docs
IN_NODEIMAGE += vsys
ALL += vsys
endif

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

vsys-wrapper-MODULES := vsys-scripts
vsys-wrapper-SPEC := slice-context/vsys-wrapper.spec
IN_SLICEIMAGE += vsys-wrapper
ALL += vsys-wrapper

#
# bind_public
#
bind_public-MODULES := bind_public
bind_public-SPEC := bind_public.spec
IN_SLICEIMAGE += bind_public
ALL += bind_public

# in fedora 29, this triggers nasty-looking compile messages
# not trying too hard, we're mostly after the serverside of f29 and above
ifneq "$(DISTRONAME)" "$(filter $(DISTRONAME), f31 f33 f35)"
#
# sliver-openvswitch
#
sliver-openvswitch-MODULES := sliver-openvswitch
sliver-openvswitch-SPEC := sliver-openvswitch.spec
IN_SLICEIMAGE += sliver-openvswitch
ALL += sliver-openvswitch
endif



### serverside-only
endif
### serverside-only




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
# WARNING: as of f27 I have to remove support for SSL in pcucontrol
# see pcucontrol.spec for details
# no longer builds in f33
# stdsoap2.cpp: In function ‘char* soap_string_in(soap*, int, long int, long int)’:
# stdsoap2.cpp:8259:18: error: narrowing conversion of ‘2147483708’ from ‘unsigned int’ to ‘int’ [-Wnarrowing]
#  8259 |       case '<' | 0x80000000:
#       |                  ^~~~~~~~~~
ifneq "$(DISTRONAME)" "$(filter $(DISTRONAME), f33 f35)"
pcucontrol-MODULES := pcucontrol
pcucontrol-SPEC := pcucontrol.spec
ALL += pcucontrol
endif

#
# monitor
#
#monitor-MODULES := monitor
#monitor-SPEC := Monitor.spec
#monitor-STOCK-DEVEL-RPMS += net-snmp net-snmp-devel
#ALL += monitor
#IN_NODEIMAGE += monitor


### serverside-only
ifneq "$(DISTRONAME)" "$(filter $(DISTRONAME), f31 f33 f35)"
### serverside-only


#
# PLC RT
#
plcrt-MODULES := PLCRT
plcrt-SPEC := plcrt.spec
ALL += plcrt

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


### serverside-only
endif
### serverside-only


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
# this is python2, somehow the tests won't pass against a py3 plcapi
# oddly enough, when the py2 sfa code issues xmlrpc calls over ssl
# to the underlying myplc, we get SSL handshake issues
# so, let's keep this out of the way for now
# 2019 mar 27: reinstating for hopefully connecting fed4fire
# 2022 apr 28:
# we currently run on r2labapi.inria.fr a hybrid f33/f34/f35
# that has python2 (recipe from f33) + php-7.4 (from f34) and httpd-2.4.53 (from f35)
# and we'll hold to that until end of june 2022
# however the python2 ecosystem is too far-fetched now
# so we're dropping for good support for sfa, last version is f33
#
ifeq "$(DISTRONAME)" "$(filter $(DISTRONAME), f33)"
sfa-MODULES := sfa
sfa-SPEC := sfa.spec
ALL += sfa
endif
