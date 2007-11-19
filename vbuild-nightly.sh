#!/bin/bash
REVISION=$(echo '$Revision$' | sed -e 's,\$,,g' -e 's,^\w*:\s,,' )

COMMANDPATH=$0
COMMAND=$(basename $0)

# default values, tunable with command-line options
DEFAULT_FCDISTRO=fc6
DEFAULT_PLDISTRO=planetlab
DEFAULT_BASE="@DATE@--@PLDISTRO@-@FCDISTRO@"
DEFAULT_SVNPATH="http://svn.planet-lab.org/svn/build/trunk"

DEFAULT_MAILTO_onelab="onelab-build@one-lab.org"
# tmp - send all mails to onelab
#DEFAULT_MAILTO_planetlab="devel@planet-lab.org"
DEFAULT_MAILTO_planetlab=$DEFAULT_MAILTO_onelab

# web publishing results
DEFAULT_WEBPATH="/build/@PLDISTRO@/"

# for the test part
TESTBUILDURL="http://build.one-lab.org/"
TESTBOX=onelab-test.inria.fr
TESTBOXSSH=root@onelab-test.inria.fr
TESTSVNPATH="http://svn.one-lab.org/new_plc_api/trunk/plctest"
TESTSCRIPT=TestMain.py
####################
# assuming vserver runs in UTC
DATE=$(date -u +'%Y.%m.%d')

# Notify recipient of failure or success, manage various stamps 
function failure() {
    set -x
    if [ -n "$MAILTO" ] ; then
	tail -c 8k $LOG | mail -s "Failures for build ${BASE}" $MAILTO
    fi
    cp $LOG ${WEBPATH}/${BASE}.log.txt
    (echo -n "============================== $COMMAND: failure at" ; date ; tail -c 20k $LOG) > ${WEBPATH}/${BASE}.bko.txt
    exit 1
}

function success () {
    set -x
    if [ -n "$MAILTO" ] ; then
	(echo "http://build.one-lab.org/$PLDISTRO/$BASE" ; echo "Completed on $(date)" ) | mail -s "Successfull build for ${BASE}" $MAILTO
    fi
    cp $LOG ${WEBPATH}/${BASE}.log.txt
    touch ${WEBPATH}/${BASE}.bok.txt
    exit 0
}

# run in the vserver - do not manage success/failure, will be done from the root ctx
function build () {
    set -x
    set -e

    echo -n "============================== Starting $COMMAND:build on "
    date

    cd /

  # if TAGSRELEASE specified : update PLDISTROTAGS with this tag
    if [ -n "$TAGSRELEASE" ] ; then
	cd build
	svn up -r $TAGSRELEASE $PLDISTROTAGS
	cd - 
    fi

    show_env
    
    echo "Running make IN $(pwd)"
    make stage1=true "${MAKEOPTS[@]}" PLDISTROTAGS=${PLDISTROTAGS} PLDISTRO=${PLDISTRO} "${MAKEVARS[@]}" -C /build
    # in case we use an older build that does not know about versions
    set +e
    make "${MAKEOPTS[@]}" PLDISTROTAGS=${PLDISTROTAGS} PLDISTRO=${PLDISTRO} "${MAKEVARS[@]}" -C /build versions
    set -e
    make "${MAKEOPTS[@]}" PLDISTROTAGS=${PLDISTROTAGS} PLDISTRO=${PLDISTRO} "${MAKEVARS[@]}" -C /build $MAKETARGETS

}

# this was formerly run in the myplc-devel chroot but now is run in the root context,
# this is so that the .ssh config gets done manually, and once and for all
function runtest () {
    set -x
    set -e

    echo -n "============================== Starting $COMMAND:runtest on $(date)"
    here=$(pwd)

    ### the URL to the myplc package
    cd /vservers/$BASE/build/RPMS/i386
    rpm=$(ls myplc-[0-9]*.rpm)
    if [ ${#rpm[@]} != 1 ] ; then
	echo "$COMMAND: Cannot locate rpm for testing"
	exit 1
    fi
    url=${TESTBUILDURL}${PLDISTRO}/${BASE}/RPMS/i386/${rpm}

    # find the place where the plctest material was checked out
    cd /vservers/$BASE/build/CODEBASES/PLCAPI
    if [ ! -d plctest/ ] ; then
	echo "$COMMAND : Cannot not locate plctest/ - exiting"
	exit 1
    fi
  # compute test directory name on test box
    testdir=plctest-${BASE}
  # rsync/push test material onto the test box
    ssh ${TESTBOXSSH} mkdir -p ${testdir}
    rsync -a -v plctest/ ${TESTBOXSSH}:${testdir}
  # invoke test on testbox
    ssh ${TESTBOXSSH} python -u ${testdir}/${TESTSCRIPT} ${url} 
  #invoke make install from build to the testbox
  # looks suspicious : we'd need this *during* myplc run, not at the end
  # in addition we are not in the vserver here so running make can have weird effects
  # make install PLCHOST=${TESTBOX}
	
    if [ "$?" != 0 ] ; then
	failure
    fi
    
    cd $here
    echo -n "============================== End $COMMAND:runtest on $(date)"
}

function show_env () {
    set +x
    echo FCDISTRO=$FCDISTRO
    echo PLDISTRO=$PLDISTRO
    echo BASE=$BASE
    echo SVNPATH=$SVNPATH
    echo MAKEVARS="${MAKEVARS[@]}"
    echo MAKEOPTS="${MAKEOPTS[@]}"
    echo PLDISTROTAGS="$PLDISTROTAGS"
    echo TAGSRELEASE="$TAGSRELEASE"
    echo WEBPATH="$WEBPATH"
    if [ -d /vservers ] ; then
	echo PLDISTROTAGS="$PLDISTROTAGS"
    else
	echo "XXXXXXXXXXXXXXXXXXXX Contents of tags definition file /build/$PLDISTROTAGS"
	cat /build/$PLDISTROTAGS
	echo "XXXXXXXXXXXXXXXXXXXX end tags definition"
    fi
    set -x
}

function usage () {
    echo "Usage: $COMMAND [option] make-targets"
    echo "This is $REVISION"
    echo "Supported options"
    echo " -n dry-run : -n passed to make - vserver gets created though - no mail sent"
    echo " -f FCDISTRO - defaults to $DEFAULT_FCDISTRO"
    echo " -d PLDISTRO - defaults to $DEFAULT_PLDISTRO"
    echo " -b BASE - defaults to $DEFAULT_BASE"
    echo "    @NAME@ replaced as appropriate"
    echo " -t PLDISTROTAGS - defaults to \${PLDISTRO}-tags.mk"
    echo " -r TAGSRELEASE - a release number that refers to PLDISTROTAGS - defaults to HEAD"
    echo " -s SVNPATH - where to fetch the build module"
    echo " -o : overwrite - re-run in base directory, do not create vserver"
    echo " -m MAILTO"
    echo " -a MAKEVAR=value - space in values are not supported"
    echo " -w WEBPATH - defaults to $DEFAULT_WEBPATH"
    echo " -B : run build only"
    echo " -T : run test only"
    echo " -v : be verbose"
    exit 1
}

function main () {

    set -e

    # preserve arguments for passing them again later
    declare -a argv
    for arg in "$@"; do argv=(${argv[@]} "$arg") ; done
    
    # parse arguments
    MAKEVARS=()
    MAKEOPTS=()
    DO_BUILD=true
    DO_TEST=true
    while getopts "nf:d:b:t:r:s:om:a:w:BTvh" opt ; do
	case $opt in
	    n) DRY_RUN="true" ; MAKEOPTS=(${MAKEOPTS[@]} -n) ;;
	    f) FCDISTRO=$OPTARG ;;
	    d) PLDISTRO=$OPTARG ;;
	    b) BASE=$OPTARG ;;
	    t) PLDISTROTAGS=$OPTARG ;;
	    r) TAGSRELEASE=$OPTARG ;;
	    s) SVNPATH=$OPTARG ;;
	    o) USEOLD=true ;;
	    m) MAILTO=$OPTARG ;;
	    a) MAKEVARS=(${MAKEVARS[@]} "$OPTARG") ;;
	    w) WEBPATH=$OPTARG ;;
	    B) DO_TEST= ;;
	    T) DO_BUILD= ; USEOLD=true ;;
	    v) set -x ;;
	    h|*) usage ;;
	esac
    done
	
    shift $(($OPTIND - 1))
    MAKETARGETS="$@"
    
    # set defaults
    [ -z "$FCDISTRO" ] && FCDISTRO=$DEFAULT_FCDISTRO
    [ -z "$PLDISTRO" ] && PLDISTRO=$DEFAULT_PLDISTRO
    [ -z "$PLDISTROTAGS" ] && PLDISTROTAGS="${PLDISTRO}-tags.mk"
    [ -z "$BASE" ] && BASE="$DEFAULT_BASE"
    [ -z "$WEBPATH" ] && WEBPATH="$DEFAULT_WEBPATH"
    [ -z "$SVNPATH" ] && SVNPATH="$DEFAULT_SVNPATH"
    # 
    if [ "$PLDISTRO" = "onelab" ] ; then
	[ -z "$MAILTO" ] && MAILTO="$DEFAULT_MAILTO_onelab"
    else
	[ -z "$MAILTO" ] && MAILTO="$DEFAULT_MAILTO_planetlab"
    fi
    [ -n "$DRY_RUN" ] && MAILTO=""
	
    ### set BASE from DISTRO, if unspecified
    sedargs="-e s,@DATE@,${DATE},g -e s,@FCDISTRO@,${FCDISTRO},g -e s,@PLDISTRO@,${PLDISTRO},g"
    BASE=$(echo ${BASE} | sed $sedargs)
    WEBPATH=$(echo ${WEBPATH} | sed $sedargs)

    if [ ! -d /vservers ] ; then
        # in the vserver
	echo "==================== Within vserver BEG $(date)"
	build
	echo "==================== Within vserver END $(date)"

    else
	trap failure ERR INT
        # we run in the root context : 
        # (*) create or check for the vserver to use
        # (*) copy this command in the vserver
        # (*) invoke it
	
	if [ -n "$USEOLD" ] ; then
            ### Re-use a vserver (finish an unfinished build..)
	    if [ ! -d /vservers/${BASE} ] ; then
		echo $COMMAND : cannot find vserver $BASE
		exit 1
	    fi
	    # manage LOG - beware it might be a symlink so nuke it first
	    LOG=/vservers/${BASE}.log.txt
	    rm -f $LOG
	    exec > $LOG 2>&1
	    set -x
	    echo "XXXXXXXXXX $COMMAND: using existing vserver $BASE" $(date)
	    show_env
	    # update build
	    vserver ${BASE} exec svn update /build
	else
	    # create vserver: check it does not exist yet
	    i=
	    while [ -d /vservers/${BASE}${i} ] ; do
		# we name subsequent builds <base>-n<i> so the logs and builds get sorted properly
		[ -z ${i} ] && BASE=${BASE}-n
		i=$((${i}+1))
		if [ $i -gt 100 ] ; then
		    echo "$COMMAND: Failed to create build vserver /vservers/${BASE}${i}"
		    exit 1
		fi
	    done
	    BASE=${BASE}${i}
	    # need update
	    # manage LOG - beware it might be a symlink so nuke it first
	    LOG=/vservers/${BASE}.log.txt
	    rm -f $LOG
	    exec > $LOG 2>&1 
	    set -x
	    echo "XXXXXXXXXX $COMMAND: creating vserver $BASE" $(date)
	    show_env

	    ### extract vbuild-init-vserver.sh and run it
	    svn cat $SVNPATH/vbuild-init-vserver.sh > /tmp/vbuild-init-vserver-$$.sh
	    # get .lst 
	    lst=${PLDISTRO}-${FCDISTRO}-devel.lst
	    svn cat $SVNPATH/$lst > /tmp/$lst 

            # Create vserver
	    cd /tmp
	    chmod +x vbuild-init-vserver-$$.sh
	    /tmp/vbuild-init-vserver-$$.sh ${BASE} ${FCDISTRO} ${PLDISTRO}
	    # cleanup
	    rm -f /tmp/vbuild-init-vserver-$$.sh /tmp/$lst
	    cd -
	    # Extract build
	    vserver ${BASE} exec svn checkout ${SVNPATH} /build
	fi
	echo "XXXXXXXXXX $COMMAND: preparation of vserver $BASE done" $(date)

	# The log inside the vserver contains everything
	LOG2=/vservers/${BASE}/log.txt
	(echo "==================== Transcript of vserver creation -- BEG $(date)" ; \
	 cat $LOG ; \
	 echo "==================== Transcript of vserver creation -- END $(date)" ; \
	 echo "xxxxxxxxxx Messing with logs, symlinking $LOG2 to $LOG" ) >> $LOG2
	### not too nice : nuke the former log, symlink it to the new one
	rm $LOG; ln -s $LOG2 $LOG
	LOG=$LOG2
	# redirect log again
	exec >> $LOG 2>&1 

	if [ -n "$DO_BUILD" ] ; then 

	    cp $COMMANDPATH /vservers/${BASE}/build/

	    # invoke this command in the vserver for building (-T)
	    vserver ${BASE} exec /build/$COMMAND "${argv[@]}" -b "${BASE}"
	fi

	# publish to the web so runtest can find them
	rm -rf $WEBPATH/$BASE ; mkdir -p $WEBPATH/$BASE/{RPMS,SRPMS}
	rsync --archive --delete --verbose /vservers/$BASE/build/RPMS/ $WEBPATH/$BASE/RPMS/
	rsync --archive --delete --verbose /vservers/$BASE/build/SRPMS/ $WEBPATH/$BASE/SRPMS/
	
	set +e
	if [ -n "$DO_TEST" ] ; then 
	    runtest
	fi

	success 
	
    fi

}  

##########
main "$@" 
