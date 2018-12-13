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

# ###### NorNet customisation ###############################################
nornet-ca-GITPATH               := git://github.com/dreibh/nornet-ca.git@master
nornet-nn-GITPATH               := git://github.com/dreibh/nornet-nn.git@master

netperfmeter-GITPATH            := git://github.com/dreibh/netperfmeter.git@master
rsplib-GITPATH                  := git://github.com/dreibh/rsplib.git@master
subnetcalc-GITPATH              := git://github.com/dreibh/subnetcalc.git@master
tsctp-GITPATH                   := git://github.com/dreibh/tsctp.git@master
# ###########################################################################

# ##### NorNet ########################
bootmanager-GITPATH             := git://github.com/dreibh/planetlab-bootmanager.git@master
linux-GITPATH                   := git://github.com/dreibh/planetlab-kernel.git@kernel-v4.19
plcapi-GITPATH                  := git://github.com/dreibh/planetlab-lxc-plcapi.git@master
plewww-GITPATH                  := git://github.com/dreibh/planetlab-lxc-plewww@master
bootcd-GITPATH                  := git://github.com/dreibh/planetlab-lxc-bootcd.git@master
nodemanager-GITPATH             := git://github.com/dreibh/planetlab-lxc-nodemanager.git@master
tests-GITPATH                   := git://github.com/dreibh/planetlab-lxc-tests.git@master
# #####################################

lxc-userspace-GITPATH           := git://git.onelab.eu/lxc-userspace.git@lxc-userspace-1.0-12
transforward-GITPATH            := git://git.onelab.eu/transforward.git@master
procprotect-GITPATH             := git://git.onelab.eu/procprotect.git@procprotect-0.4-7
# ipfw-sourceforge.git (obsolete) mirrored on git.onelab.eu from git://git.code.sf.net/p/dummynet/code
# ipfw-google.git (current) is mirrored on git.onelab.eu from https://code.google.com/p/dummynet
ipfw-GITPATH                    := git://git.onelab.eu/ipfw-google.git@e717cdd4bef764a4aa7babedc54220b35b04c777
comgt-GITPATH			:= git://git.onelab.eu/comgt.git@0.3
planetlab-umts-tools-GITPATH    := git://git.onelab.eu/planetlab-umts-tools.git@planetlab-umts-tools-0.7-1
nodeupdate-GITPATH              := git://git.onelab.eu/nodeupdate.git@nodeupdate-0.5-14
PingOfDeath-GITPATH		:= git://git.onelab.eu/pingofdeath.git@PingOfDeath-2.2-1
plnode-utils-GITPATH            := git://git.onelab.eu/plnode-utils.git@plnode-utils-0.2-2
# !!! Using NorNet customisation! !!! nodemanager-GITPATH             := git://git.onelab.eu/nodemanager.git@nodemanager-5.2-19

#
pl_sshd-GITPATH			:= git://git.onelab.eu/pl_sshd.git@pl_sshd-1.0-11
codemux-GITPATH			:= git://git.onelab.eu/codemux.git@codemux-0.1-15
fprobe-ulog-GITPATH             := git://git.onelab.eu/fprobe-ulog.git@fprobe-ulog-1.1.4-3
libvirt-GITPATH                 := git://git.onelab.eu/libvirt.git@libvirt-1.2.11-2
libvirt-python-GITPATH          := git://git.onelab.eu/libvirt-python.git@libvirt-1.2.11-2
pf2slice-GITPATH		:= git://git.onelab.eu/pf2slice.git@pf2slice-1.0-2
mom-GITPATH                     := git://git.onelab.eu/mom.git@mom-2.3-5
inotify-tools-GITPATH		:= git://git.onelab.eu/inotify-tools.git@inotify-tools-3.13-2
openvswitch-GITPATH		:= git://git.onelab.eu/openvswitch.git@openvswitch-1.2-1
vsys-GITPATH                    := git://git.onelab.eu/vsys.git@master
vsys-scripts-GITPATH            := git://git.onelab.eu/vsys-scripts.git@vsys-scripts-0.95-51
bind_public-GITPATH             := git://git.onelab.eu/bind_public.git@bind_public-0.1-3
sliver-openvswitch-GITPATH      := git://git.onelab.eu/sliver-openvswitch.git@sliver-openvswitch-2.2.90-1
# !!! Using NorNet customisation! !!! plcapi-GITPATH                  := git://git.onelab.eu/plcapi.git@plcapi-5.4-0
drupal-GITPATH                  := git://git.onelab.eu/drupal.git@drupal-4.7-16
# !!! Using NorNet customisation! !!! plewww-GITPATH                  := git://git.onelab.eu/plewww.git@plewww-5.2-8
www-register-wizard-GITPATH	:= git://git.onelab.eu/www-register-wizard.git@www-register-wizard-4.3-5
monitor-GITPATH			:= git://git.onelab.eu/monitor@monitor-3.1-6
PLCRT-GITPATH			:= git://git.onelab.eu/plcrt.git@PLCRT-1.0-11
pyopenssl-GITPATH               := git://git.onelab.eu/pyopenssl.git@pyopenssl-0.9-2
pyaspects-GITPATH               := git://git.onelab.eu/pyaspects.git@pyaspects-0.4.1-4
nodeconfig-GITPATH              := git://git.onelab.eu/nodeconfig.git@nodeconfig-5.2-5
# !!! Using NorNet customisation! !!! bootmanager-GITPATH             := git://git.onelab.eu/bootmanager.git@bootmanager-5.3-4
pypcilib-GITPATH                := git://git.onelab.eu/pypcilib.git@pypcilib-0.2-11
pyplnet-GITPATH                 := git://git.onelab.eu/pyplnet.git@master
DistributedRateLimiting-GITPATH	:= git://git.onelab.eu/distributedratelimiting.git@DistributedRateLimiting-0.1-1
pcucontrol-GITPATH              := git://git.onelab.eu/pcucontrol.git@master
###
# omf-resctl now comes from yum and gem, no need for rvm-ruby anymore
oml-GITPATH                     := git://git.onelab.eu/oml.git@oml-2.6.1-1
###
# !!! Using NorNet customisation! !!! bootcd-GITPATH                  := git://git.onelab.eu/bootcd.git@bootcd-5.4-1
sliceimage-GITPATH              := git://git.onelab.eu/sliceimage.git@master
nodeimage-GITPATH               := git://git.onelab.eu/nodeimage.git@master
myplc-GITPATH                   := git://git.onelab.eu/myplc.git@master

#
sfa-GITPATH                     := git://git.onelab.eu/sfa.git@master
#
# !!! Using NorNet customisation! !!! tests-GITPATH                   := git://git.onelab.eu/tests.git@tests-6.0.4
