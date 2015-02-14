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
linux-GITPATH                   := git://github.com/dreibh/planetlab-kernel.git@nornet-rel0.9.6
nornet-nn-GITPATH               := git://github.com/dreibh/nornet-nn.git@nornet-rel0.9.6
netperfmeter-GITPATH            := git://github.com/dreibh/netperfmeter.git@master
rsplib-GITPATH                  := git://github.com/dreibh/rsplib.git@master
subnetcalc-GITPATH              := git://github.com/dreibh/subnetcalc.git@master
tsctp-GITPATH                   := git://github.com/dreibh/tsctp.git@master
# tracebox-GITPATH                := git://github.com/dreibh/tracebox.git@master
# ###########################################################################

# ##### NorNet ########################
# -- transforward-GITPATH            := git://github.com/dreibh/planetlab-lxc-transforward.git@master
# -- procprotect-GITPATH             := git://github.com/dreibh/planetlab-lxc-procprotect.git@master
plcapi-GITPATH                  := git://github.com/dreibh/planetlab-lxc-plcapi.git@nornet-rel0.9.5
bootcd-GITPATH                  := git://github.com/dreibh/planetlab-lxc-bootcd.git@nornet-rel0.9.5
nodemanager-GITPATH             := git://github.com/dreibh/planetlab-lxc-nodemanager.git@nornet-rel0.9.5
# #####################################

lxc-userspace-GITPATH           := git://git.onelab.eu/lxc-userspace.git@lxc-userspace-1.0-12
transforward-GITPATH            := git://git.onelab.eu/transforward.git@34fdce63a2afd8fcbdd0b88235a1ed92ba7c5515
procprotect-GITPATH             := git://git.onelab.eu/procprotect.git@14db35384e0ecf9100aba3d4b5cdf34aeeda1141
ipfw-GITPATH                    := https://code.google.com/p/dummynet@155b6cd31089b4763297d579e9c9945393f00c40
# this was known to work with f18 but not f20
#ipfw-GITPATH                    := git://git.code.sf.net/p/dummynet/code@155b6cd31089b4763297d579e9c9945393f00c40
comgt-GITPATH			:= git://git.onelab.eu/comgt.git@0.3
planetlab-umts-tools-GITPATH    := git://git.onelab.eu/planetlab-umts-tools.git@planetlab-umts-tools-0.7-1
nodeupdate-GITPATH              := git://git.onelab.eu/nodeupdate.git@nodeupdate-0.5-11
PingOfDeath-SVNPATH		:= http://svn.planet-lab.org/svn/PingOfDeath/tags/PingOfDeath-2.2-1
plnode-utils-GITPATH            := git://git.onelab.eu/plnode-utils.git@plnode-utils-0.2-2
# !!! Using NorNet customisation! !!! nodemanager-GITPATH             := git://git.planet-lab.org/nodemanager.git@master
#
pl_sshd-SVNPATH			:= http://svn.planet-lab.org/svn/pl_sshd/tags/pl_sshd-1.0-11
codemux-GITPATH			:= git://git.onelab.eu/codemux.git@codemux-0.1-15
fprobe-ulog-GITPATH             := git://git.onelab.eu/fprobe-ulog.git@fprobe-ulog-1.1.4-3
libvirt-BRANCH	                := 1.2.11
libvirt-GITPATH                 := git://git.onelab.eu/libvirt.git@1.2.11
libvirt-python-BRANCH           := 1.2.11
libvirt-python-GITPATH          := git://git.onelab.eu/libvirt-python.git@1.2.11
pf2slice-SVNPATH		:= http://svn.planet-lab.org/svn/pf2slice/tags/pf2slice-1.0-2
mom-GITPATH                     := git://git.onelab.eu/mom.git@mom-2.3-5
inotify-tools-GITPATH		:= git://git.onelab.eu/inotify-tools.git@inotify-tools-3.13-2
openvswitch-GITPATH		:= git://git.onelab.eu/openvswitch.git@openvswitch-1.2-1
vsys-GITPATH			:= git://git.onelab.eu/vsys.git@vsys-0.99-3
vsys-scripts-GITPATH            := git://git.onelab.eu/vsys-scripts.git@vsys-scripts-0.95-49
bind_public-GITPATH             := git://git.onelab.eu/bind_public.git@bind_public-0.1-2
sliver-openvswitch-GITPATH      := git://git.onelab.eu/sliver-openvswitch.git@sliver-openvswitch-2.2.90-1
# !!! Using NorNet customisation! !!! plcapi-GITPATH                  := git://git.planet-lab.org/plcapi.git@plcapi-5.3-5
drupal-GITPATH                  := git://git.onelab.eu/drupal.git@drupal-4.7-15
plewww-GITPATH                  := git://git.onelab.eu/plewww.git@plewww-5.2-4
www-register-wizard-SVNPATH	:= http://svn.planet-lab.org/svn/www-register-wizard/tags/www-register-wizard-4.3-5
monitor-GITPATH			:= git://git.onelab.eu/monitor@monitor-3.1-6
PLCRT-SVNPATH			:= http://svn.planet-lab.org/svn/PLCRT/tags/PLCRT-1.0-11
pyopenssl-GITPATH               := git://git.onelab.eu/pyopenssl.git@pyopenssl-0.9-2
pyaspects-GITPATH               := git://git.onelab.eu/pyaspects.git@pyaspects-0.4.1-3
nodeconfig-GITPATH              := git://git.onelab.eu/nodeconfig.git@nodeconfig-5.2-4
bootmanager-GITPATH             := git://git.onelab.eu/bootmanager.git@bootmanager-5.2-5
pypcilib-GITPATH                := git://git.onelab.eu/pypcilib.git@pypcilib-0.2-11
pyplnet-GITPATH                 := git://git.onelab.eu/pyplnet.git@pyplnet-4.3-18
DistributedRateLimiting-SVNPATH	:= http://svn.planet-lab.org/svn/DistributedRateLimiting/tags/DistributedRateLimiting-0.1-1
pcucontrol-GITPATH              := git://git.onelab.eu/pcucontrol.git@pcucontrol-1.0-13
###
# omf-resctl now comes from yum and gem, no need for rvm-ruby anymore
oml-GITPATH                     := git://git.onelab.eu/oml.git@oml-2.6.1-1
###
# !!! Using NorNet customisation! !!! bootcd-GITPATH                  := git://git.planet-lab.org/bootcd.git@bootcd-5.2-4
sliceimage-GITPATH              := git://git.onelab.eu/sliceimage.git@fa1f64bfbdde37c6a2d788e621eb9d33f329f8fa
nodeimage-GITPATH               := git://git.onelab.eu/nodeimage.git@nodeimage-5.2-4
myplc-GITPATH                   := git://git.onelab.eu/myplc.git@myplc-5.3-2

#
sfa-GITPATH                     := git://git.onelab.eu/sfa.git@sfa-3.1-13
#
tests-GITPATH                   := git://git.onelab.eu/tests.git@fa29584970509214e38235c4f14a6aacc906cf9b
