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
nornet-ca-GITPATH               := https://github.com/dreibh/nornet-ca.git@master
nornet-nn-GITPATH               := https://github.com/dreibh/nornet-nn.git@master

netperfmeter-GITPATH            := https://github.com/dreibh/netperfmeter.git@master
rsplib-GITPATH                  := https://github.com/dreibh/rsplib.git@master
subnetcalc-GITPATH              := https://github.com/dreibh/subnetcalc.git@master
tsctp-GITPATH                   := https://github.com/dreibh/tsctp.git@master
# ###########################################################################

# ##### NorNet ########################
bootmanager-GITPATH             := https://github.com/dreibh/planetlab-lxc-bootmanager.git@master
plcapi-GITPATH                  := https://github.com/dreibh/planetlab-lxc-plcapi.git@master
plewww-GITPATH                  := https://github.com/dreibh/planetlab-lxc-plewww@master
bootcd-GITPATH                  := https://github.com/dreibh/planetlab-lxc-bootcd.git@master
nodemanager-GITPATH             := https://github.com/dreibh/planetlab-lxc-nodemanager.git@master
tests-GITPATH                   := https://github.com/dreibh/planetlab-lxc-tests.git@master
linux-GITPATH                   := https://github.com/dreibh/planetlab-kernel.git@kernel-v4.19
# #####################################

lxc-userspace-GITPATH       := https://github.com/dreibh/planetlab-lxc-userspace.git@lxc-userspace-2.0-0
transforward-GITPATH        := https://github.com/dreibh/planetlab-lxc-transforward.git@transforward-0.1-12
comgt-GITPATH               := https://github.com/dreibh/planetlab-lxc-comgt.git@0.3
planetlab-umts-tools-GITPATH:= https://github.com/dreibh/planetlab-lxc-planetlab-umts-tools.git@planetlab-umts-tools-0.7-1
nodeupdate-GITPATH          := https://github.com/dreibh/planetlab-lxc-nodeupdate.git@nodeupdate-1.0-0
PingOfDeath-GITPATH         := https://github.com/dreibh/planetlab-lxc-pingofdeath.git@master
plnode-utils-GITPATH        := https://github.com/dreibh/planetlab-lxc-plnode-utils.git@plnode-utils-1.0-0
# !!! Using NorNet customisation! !!! nodemanager-GITPATH             := https://github.com/dreibh/planetlab-lxc-nodemanager.git@master

pl_sshd-GITPATH             := https://github.com/dreibh/planetlab-lxc-pl_sshd.git@pl_sshd-1.0-11
codemux-GITPATH             := https://github.com/dreibh/planetlab-lxc-codemux.git@codemux-0.1-15
libvirt-GITPATH             := https://github.com/dreibh/planetlab-lxc-libvirt.git@libvirt-1.2.11-2
libvirt-python-GITPATH      := https://github.com/dreibh/planetlab-lxc-libvirt-python.git@libvirt-1.2.11-2
pf2slice-GITPATH            := https://github.com/dreibh/planetlab-lxc-pf2slice.git@pf2slice-1.0-2
inotify-tools-GITPATH       := https://github.com/dreibh/planetlab-lxc-inotify-tools.git@inotify-tools-3.13-2
vsys-GITPATH                    := https://github.com/dreibh/planetlab-lxc-vsys.git@master
vsys-scripts-GITPATH            := https://github.com/dreibh/planetlab-lxc-vsys-scripts.git@master
bind_public-GITPATH         := https://github.com/dreibh/planetlab-lxc-bind_public.git@bind_public-0.1-3
sliver-openvswitch-GITPATH  := https://github.com/dreibh/planetlab-lxc-sliver-openvswitch.git@sliver-openvswitch-2.2.90-1
# !!! Using NorNet customisation! !!! plcapi-GITPATH                  := https://github.com/dreibh/planetlab-lxc-plcapi.git@master
drupal-GITPATH              := https://github.com/dreibh/planetlab-lxc-drupal.git@drupal-4.7-17
plewww-GITPATH                  := https://github.com/dreibh/planetlab-lxc-plewww.git@master
www-register-wizard-GITPATH := https://github.com/dreibh/planetlab-lxc-www-register-wizard.git@www-register-wizard-4.3-5
monitor-GITPATH             := https://github.com/dreibh/planetlab-lxc-monitor@monitor-3.1-6
PLCRT-GITPATH               := https://github.com/dreibh/planetlab-lxc-plcrt.git@master
nodeconfig-GITPATH          := https://github.com/dreibh/planetlab-lxc-nodeconfig.git@nodeconfig-5.2-5
# !!! Using NorNet customisation! !!! bootmanager-GITPATH             := https://github.com/dreibh/planetlab-lxc-bootmanager.git@master
pypcilib-GITPATH                := https://github.com/dreibh/planetlab-lxc-pypcilib.git@master
pyplnet-GITPATH             := https://github.com/dreibh/planetlab-lxc-pyplnet.git@pyplnet-7.0-0
pcucontrol-GITPATH              := https://github.com/dreibh/planetlab-lxc-pcucontrol.git@master
# !!! Using NorNet customisation! !!! bootcd-GITPATH                  := https://github.com/dreibh/planetlab-lxc-bootcd.git@master
sliceimage-GITPATH              := https://github.com/dreibh/planetlab-lxc-sliceimage.git@master
nodeimage-GITPATH               := https://github.com/dreibh/planetlab-lxc-nodeimage.git@master
myplc-GITPATH                   := https://github.com/dreibh/planetlab-lxc-myplc.git@master
#
sfa-GITPATH                     := https://github.com/dreibh/planetlab-lxc-sfa.git@python2
#
# !!! Using NorNet customisation! !!! tests-GITPATH               := https://github.com/dreibh/planetlab-lxc-tests.git@master
