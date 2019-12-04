#!/bin/bash

COMMANDPATH=$0
COMMAND=$(basename $0)

# close stdin, as with ubuntu and debian VMs this script tends to hang and wait for input ..
0<&-

# old guests have e.g. mount in /bin but this is no longer part of
# the standard PATH in recent hosts after usrmove, so let's keep it simple
export PATH=$PATH:/bin:/sbin

# default values, tunable with command-line options
DEFAULT_FCDISTRO=f31
DEFAULT_PLDISTRO=lxc
DEFAULT_PERSONALITY=linux64
DEFAULT_MAILDEST="build at onelab.eu"
DEFAULT_BUILD_SCM_URL="git://github.com/dreibh/planetlab-lxc-build"
DEFAULT_BASE="@DATE@--@PLDISTRO@-@FCDISTRO@-@PERSONALITY@"

# default gpg path used in signing yum repo
DEFAULT_GPGPATH="/etc/planetlab"
# default email to use in gpg secring
DEFAULT_GPGUID="root@$( /bin/hostname )"

DEFAULT_TESTCONFIG="default"
# for passing args to run_log
RUN_LOG_EXTRAS=""

# for publishing results, and the tests settings
DEFAULT_WEBPATH="/build/@PLDISTRO@/"
DEFAULT_TESTBUILDURL="http://benlomond.simula.nornet/testing/"
# this is where the buildurl is pointing towards
DEFAULT_WEBROOT="/build/"
DEFAULT_TESTMASTER="earnslaw.simula.nornet"

####################
# assuming vm runs in UTC
DATE=$(date +'%Y.%m.%d')
TIME=$(date +'%H.%M')
BUILD_BEG=$(date +'%H:%M')
BUILD_BEG_S=$(date +'%s')

# still using /vservers for legacy reasons
# as far as the build & test infra, we could adopt a new name
# but the PL code still uses this name for now, so let's keep it simple
function rootdir () {
    slice=$1; shift
    echo /vservers/$slice
}
function logfile () {
    slice=$1; shift
    echo /vservers/$slice.log.txt
}

########################################
# workaround for broken lxc-enter-namespace
# 1st version was relying on virsh net-dhcp-leases
# however this was too fragile, would not work for fedora14 containers
# WARNING: this code is duplicated in lbuild-initvm.sh
function guest_ipv4() {
    lxc=$1; shift

    mac=$(virsh -c lxc:/// domiflist $lxc | egrep 'network|bridge' | awk '{print $5;}')
    # sanity check
    [ -z "$mac" ] && return 0
    arp -en | grep "$mac" | awk '{print $1;}'
}

# wrap a quick summary of suspicious stuff
# this is to focus on installation that go wrong
# use with care, a *lot* of other things can go bad as well
function summary () {
    from=$1; shift
    echo "******************** BEG SUMMARY"
    python3 - $from <<EOF
#!/usr/bin/env python3
# read a full log and tries to extract the interesting stuff

import sys, re
m_show_line = re.compile(
".* (BEG|END) (RPM|LXC).*|.*'boot'.*|\* .*| \* .*|.*is not installed.*|.*PROPFIND.*|.* (BEG|END).*:run_log.*|.* Within LXC (BEG|END) .*|.* MAIN (BEG|END).*")
m_installing_any = re.compile('\r  (Installing:[^\]]*]) ')
m_installing_err = re.compile('\r  (Installing:[^\]]*])(..+)')
m_installing_end = re.compile('Installed:.*')
m_installing_doc1 = re.compile("(.*)install-info: No such file or directory for /usr/share/info/\S+(.*)")
m_installing_doc2 = re.compile("(.*)grep: /usr/share/info/dir: No such file or directory(.*)")

def summary (filename):

    try:
        if filename == "-":
            filename = "stdin"
            f = sys.stdin
        else:
            f = open(filename)
        echo = False
        for line in f.xreadlines():
            # first off : discard warnings related to doc
            if m_installing_doc1.match(line):
                (begin,end)=m_installing_doc1.match(line).groups()
                line=begin+end
            if m_installing_doc2.match(line):
                (begin,end)=m_installing_doc2.match(line).groups()
                line=begin+end
            # unconditionnally show these lines
            if m_show_line.match(line):
                print('>>>', line, end="")
            # an 'installing' line with messages afterwards : needs to be echoed
            elif m_installing_err.match(line):
                (installing,error)=m_installing_err.match(line).groups()
                print('>>>',installing)
                print('>>>',error)
                echo=True
            # closing an 'installing' section
            elif m_installing_end.match(line):
                echo=False
            # any 'installing' line
            elif m_installing_any.match(line):
                if echo:
                    installing=m_installing_any.match(line).group(1)
                    print('>>>',installing)
                echo=False
            # print lines when echo is true
            else:
                if echo: print('>>>',line, end="")
        f.close()
    except:
        print('Failed to analyze',filename)

for arg in sys.argv[1:]:
    summary(arg)
EOF
    echo "******************** END SUMMARY"
}

### we might build on a box other than the actual web server
# utilities for handling the pushed material (rpms, logfiles, ...)
function webpublish_misses_dir () {
    ssh root@${WEBHOST}  "bash -c \"test \! -d $1\""
}
function webpublish () {
    ssh root@${WEBHOST} "$@"
}
function webpublish_cp_stdin_to_file () {
    ssh root@${WEBHOST} cat \> $1 \; chmod g+r,o+r $1
}
function webpublish_append_stdin_to_file () {
    ssh root@${WEBHOST} cat \>\> $1 \; chmod g+r,o+r $1
}
# provide remote dir as first argument,
# so any number of local files can be passed next
function webpublish_rsync () {
    local remote="$1"; shift
    rsync --archive --delete $VERBOSE "$@" root@${WEBHOST}:"$remote"
 }

function pretty_duration () {
    total_seconds=$1; shift

    seconds=$(($total_seconds%60))
    total_minutes=$(($total_seconds/60))
    minutes=$(($total_minutes%60))
    hours=$(($total_minutes/60))

    printf "%02d:%02d:%02d" $hours $minutes $seconds
}

# Notify recipient of failure or success, manage various stamps
function failure() {
    set -x
    # early stage ? - let's not create /build/@PLDISTRO@
    if  [ -z "$WEBLOG" ] ; then
        WEBHOST=localhost
        WEBPATH=/tmp
        WEBBASE=/tmp/lbuild-early-$(date +%Y-%m-%d)
        WEBLOG=/tmp/lbuild-early-$(date +%Y-%m-%d).log.txt
    fi
    webpublish mkdir -p $WEBBASE ||:
    webpublish_rsync $WEBLOG $LOG  ||:
    summary $LOG | webpublish_append_stdin_to_file $WEBLOG ||:
    (echo -n "============================== $COMMAND: failure at " ; date ; \
        webpublish tail --lines=1000 $WEBLOG) | \
        webpublish_cp_stdin_to_file $WEBBASE.ko ||:
    if [ -n "$MAILDEST" ] ; then
        ( \
            echo "Subject: KO ${BASE} ${MAIL_SUBJECT}" ; \
            echo "To: $MAILDEST" ; \
            echo "see build results at        $WEBBASE_URL" ; \
            echo "including full build log at $WEBBASE_URL/log.txt" ; \
            echo "and complete test logs at   $WEBBASE_URL/testlogs" ; \
            echo "........................................" ; \
            webpublish tail --lines=1000 $WEBLOG ) | \
            sendmail $MAILDEST
    fi
    exit 1
}

function success () {
    set -x
    # early stage ? - let's not create /build/@PLDISTRO@
    if [ -z "$WEBLOG" ] ; then
        WEBHOST=localhost
        WEBPATH=/tmp
        WEBLOG=/tmp/lbuild-early-$(date +%Y-%m-%d).log.txt
    fi
    webpublish mkdir -p $WEBBASE
    webpublish_rsync $WEBLOG $LOG
    summary $LOG | webpublish_append_stdin_to_file $WEBLOG
    if [ -n "$DO_TEST" ] ; then
        short_message="PASS"
        ext="pass"
        if [ -n "$IGNORED" ] ; then short_message="PASS/WARN"; ext="warn"; fi
        ( \
            echo "Successfully built and tested" ; \
            echo "see build results at        $WEBBASE_URL" ; \
            echo "including full build log at $WEBBASE_URL/log.txt" ; \
            echo "and complete test logs at   $WEBBASE_URL/testlogs" ; \
            [ -n "$IGNORED" ] && echo "WARNING: some tests steps failed but were ignored - see trace file" ; \
            ) | webpublish_cp_stdin_to_file $WEBBASE.$ext
        webpublish rm -f $WEBBASE.pkg-ok $WEBBASE.ko
    else
        short_message="PKGOK"
        ( \
            echo "Successful package-only build, no test requested" ; \
            echo "see build results at        $WEBBASE_URL" ; \
            echo "including full build log at $WEBBASE_URL/log.txt" ; \
            ) | webpublish_cp_stdin_to_file $WEBBASE.pkg-ok
        webpublish rm -f $WEBBASE.ko
    fi
    BUILD_END=$(date +'%H:%M')
    BUILD_END_S=$(date +'%s')
    if [ -n "$MAILDEST" ] ; then
        ( \
            echo "Subject: $short_message ${BASE} ${MAIL_SUBJECT}" ; \
            echo "To: $MAILDEST" ; \
            echo "$PLDISTRO ($BASE) build for $FCDISTRO completed on $(date)" ; \
            echo "see build results at        $WEBBASE_URL" ; \
            echo "including full build log at $WEBBASE_URL/log.txt" ; \
            [ -n "$DO_TEST" ] && echo "and complete test logs at   $WEBBASE_URL/testlogs" ; \
            [ -n "$IGNORED" ] && echo "WARNING: some tests steps failed but were ignored - see trace file" ; \
            echo "BUILD TIME: begin $BUILD_BEG -- end $BUILD_END -- duration $(pretty_duration $(($BUILD_END_S-$BUILD_BEG_S)))" ; \
            ) | sendmail $MAILDEST
    fi
    # XXX For some reason, we haven't been getting this email for successful builds. If this sleep
    # doesn't fix the problem, I'll remove it -- Sapan.
    sleep 5
    exit 0
}

##############################
# manage root / container contexts
function in_root_context () {
    rpm -q libvirt > /dev/null
}

# convenient for simple commands
function run_in_build_guest () {
    buildname=$1; shift
    ssh -o StrictHostKeyChecking=no root@$(guest_ipv4 $buildname) "$@"
}

# run in the vm - do not manage success/failure, will be done from the root ctx
function build () {
    set -x
    set -e

    echo -n "============================== Starting $COMMAND:build on "
    date

    cd /build
    show_env

    echo "Running make IN $(pwd)"

    # stuff our own variable settings
    MAKEVARS=("build-GITPATH=${BUILD_SCM_URL}" "${MAKEVARS[@]}")
    MAKEVARS=("PLDISTRO=${PLDISTRO}" "${MAKEVARS[@]}")
    MAKEVARS=("PLDISTROTAGS=${PLDISTROTAGS}" "${MAKEVARS[@]}")
    MAKEVARS=("PERSONALITY=${PERSONALITY}" "${MAKEVARS[@]}")
    MAKEVARS=("MAILDEST=${MAILDEST}" "${MAKEVARS[@]}")
    MAKEVARS=("WEBPATH=${WEBPATH}" "${MAKEVARS[@]}")
    MAKEVARS=("TESTBUILDURL=${TESTBUILDURL}" "${MAKEVARS[@]}")
    MAKEVARS=("WEBROOT=${WEBROOT}" "${MAKEVARS[@]}")

    MAKEVARS=("BASE=${BASE}" "${MAKEVARS[@]}")

    # initialize latex
    /build/latex-first-run.sh || :

    # stage1
    make -C /build $DRY_RUN "${MAKEVARS[@]}" stage1=true
    # versions
    make -C /build $DRY_RUN "${MAKEVARS[@]}" versions
    # actual stuff
    make -C /build $DRY_RUN "${MAKEVARS[@]}" "${MAKETARGETS[@]}"

}

# this was formerly run in the myplc-devel chroot but now is run in the root context,
# this is so that the .ssh config gets done manually, and once and for all
function run_log () {
    set -x
    set -e
    trap failure ERR INT

    echo "============================== BEG $COMMAND:run_log on $(date)"

    ### the URL to the RPMS/<arch> location
    # f12 now has everything in i686; try i386 first as older fedoras have both
    url=""
    for a in i386 i686 x86_64; do
        archdir=$(rootdir $BASE)/build/RPMS/$a
        if [ -d $archdir ] ; then
            # where was that installed
            url=$(echo $archdir | sed -e "s,$(rootdir $BASE)/build,${WEBPATH}/${BASE},")
            url=$(echo $url | sed -e "s,${WEBROOT},${TESTBUILDURL},")
            break
        fi
    done

    if [ -z "$url" ] ; then
        echo "$COMMAND: Cannot locate arch URL for testing"
        failure
        exit 1
    fi

    testmaster_ssh="root@${TESTMASTER}"

    # test directory name on test box
    testdir=${BASE}

    # clean it
    ssh -n ${testmaster_ssh} rm -rf ${testdir} ${testdir}.git

    # check it out in the build
    run_in_build_guest $BASE make -C /build tests-module ${MAKEVARS[@]}

    # push it onto the testmaster - just the 'system' subdir is enough
    rsync --verbose --archive $(rootdir $BASE)/build/MODULES/tests/system/ ${testmaster_ssh}:${BASE}
    # toss the build in the bargain, so the tests don't need to mess with extracting it
    rsync --verbose --archive $(rootdir $BASE)/build/MODULES/build ${testmaster_ssh}:${BASE}/

    # invoke test on testbox - pass url and build url - so the tests can use lbuild-initvm.sh
    run_log_env="-p $PERSONALITY -d $PLDISTRO -f $FCDISTRO"

    # temporarily turn off set -e
    set +e
    trap - ERR INT
    ssh 2>&1 ${testmaster_ssh} ${testdir}/run_log --build ${BUILD_SCM_URL} --url ${url} $run_log_env $RUN_LOG_EXTRAS $VERBOSE --all; retcod=$?

    set -e
    trap failure ERR INT
    # interpret retcod of TestMain.py; 2 means there were ignored steps that failed
    echo "retcod from run_log" $retcod
    case $retcod in
        0) success=true; IGNORED="" ;;
        2) success=true; IGNORED=true ;;
        *) success="";   IGNORED="" ;;
    esac

    # gather logs in the build vm
    mkdir -p $(rootdir $BASE)/build/testlogs
    rsync --verbose --archive ${testmaster_ssh}:$BASE/logs/ $(rootdir $BASE)/build/testlogs
    # push them to the build web
    chmod -R a+r $(rootdir $BASE)/build/testlogs/
    webpublish_rsync $WEBPATH/$BASE/testlogs/ $(rootdir $BASE)/build/testlogs/

    echo  "============================== END $COMMAND:run_log on $(date)"

    if [ -z "$success" ] ; then
        echo "Tests have failed - bailing out"
        failure
    fi

}

# this part won't work if WEBHOST does not match the local host
# would need to be made webpublish_* compliant
# but do we really need this feature anyway ?
function sign_node_packages () {

    echo "Signing node packages"

    need_createrepo=""

    repository=$WEBPATH/$BASE/RPMS/
    # the rpms that need signing
    new_rpms=
    # and the corresponding stamps
    new_stamps=

    for package in $(find $repository/ -name '*.rpm') ; do
        stamp=$repository/signed-stamps/$(basename $package).signed
        # If package is newer than signature stamp
        if [ $package -nt $stamp ] ; then
            new_rpms="$new_rpms $package"
            new_stamps="$new_stamps $stamp"
        fi
        # Or than createrepo database
        [ $package -nt $repository/repodata/repomd.xml ] && need_createrepo=true
    done

    if [ -n "$new_rpms" ] ; then
        # Create a stamp once the package gets signed
        mkdir $repository/signed-stamps 2> /dev/null

        # Sign RPMS. setsid detaches rpm from the terminal,
        # allowing the (hopefully blank) GPG password to be
        # entered from stdin instead of /dev/tty.
        echo | setsid rpm \
            --define "_signature gpg" \
            --define "_gpg_path $GPGPATH" \
            --define "_gpg_name $GPGUID" \
            --resign $new_rpms && touch $new_stamps
    fi

     # Update repository index / yum metadata.
    if [ -n "$need_createrepo" ] ; then
        echo "Indexing node packages after signing"
        if [ -f $repository/yumgroups.xml ] ; then
            createrepo --quiet -g yumgroups.xml $repository
        else
            createrepo --quiet $repository
        fi
    fi
}

function show_env () {
    set +x
    echo FCDISTRO=$FCDISTRO
    echo PLDISTRO=$PLDISTRO
    echo PERSONALITY=$PERSONALITY
    echo BASE=$BASE
    echo BUILD_SCM_URL=$BUILD_SCM_URL
    echo MAKEVARS="${MAKEVARS[@]}"
    echo DRY_RUN="$DRY_RUN"
    echo PLDISTROTAGS="$PLDISTROTAGS"
    # this does not help, it's not yet set when we run show_env
    #echo WEBPATH="$WEBPATH"
    echo TESTBUILDURL="$TESTBUILDURL"
    echo WEBHOST="$WEBHOST"
    if in_root_context ; then
        echo PLDISTROTAGS="$PLDISTROTAGS"
    else
        if [ -f /build/$PLDISTROTAGS ] ; then
            echo "XXXXXXXXXXXXXXXXXXXX Contents of tags definition file /build/$PLDISTROTAGS"
            cat /build/$PLDISTROTAGS
            echo "XXXXXXXXXXXXXXXXXXXX end tags definition"
        else
            echo "XXXXXXXXXXXXXXXXXXXX Cannot find tags definition file /build/$PLDISTROTAGS, assuming remote pldistro"
        fi
    fi
    set -x
}

function setupssh () {
    base=$1; shift
    sshkey=$1; shift

    if [ -f ${sshkey} ] ; then
        SSHDIR=$(rootdir ${base})/root/.ssh
        mkdir -p ${SSHDIR}
        cp $sshkey ${SSHDIR}/thekey
        (echo "host *"; \
            echo "  IdentityFile ~/.ssh/thekey"; \
            echo "  StrictHostKeyChecking no" ) > ${SSHDIR}/config
        chmod 700 ${SSHDIR}
        chmod 400 ${SSHDIR}/*
    else
        echo "WARNING : could not find provided ssh key $sshkey - ignored"
    fi
}

function usage () {
    echo "Usage: $COMMAND [option] [var=value...] make-targets"
    echo "Supported options"
    echo " -f fcdistro - defaults to $DEFAULT_FCDISTRO"
    echo " -d pldistro - defaults to $DEFAULT_PLDISTRO"
    echo " -p personality - defaults to $DEFAULT_PERSONALITY"
    echo " -m mailto - defaults to $DEFAULT_MAILDEST"
    echo " -s build_scm_url - git URL where to fetch the build module - defaults to $DEFAULT_BUILD_SCM_URL"
    echo "    define GIT tag or branch name appending @tagname to url"
    echo " -t pldistrotags - defaults to \${PLDISTRO}-tags.mk"
    echo " -b base - defaults to $DEFAULT_BASE"
    echo "    @NAME@ replaced as appropriate"
    echo " -o base: (overwrite) do not re-create vm, re-use base instead"
    echo "    the -f/-d/-p/-m/-s/-t options are uneffective in this case"
    echo " -c testconfig - defaults to $DEFAULT_TESTCONFIG"
    echo " -y {pl,pg} - passed to run_log"
    echo " -e step - passed to run_log"
    echo " -i step - passed to run_log"
    echo " -X : passes --lxc to run_log"
    echo " -S : passes --vs to run_log"
    echo " -x <run_log_args> - a hook to pass other arguments to run_log"
    echo " -w webpath - defaults to $DEFAULT_WEBPATH"
    echo " -W testbuildurl - defaults to $DEFAULT_TESTBUILDURL; this is also used to get the hostname where to publish builds"
    echo " -r webroot - defaults to $DEFAULT_WEBROOT - the fs point where testbuildurl actually sits"
    echo " -M testmaster - defaults to $DEFAULT_TESTMASTER"
    echo " -Y - sign yum repo in webpath"
    echo " -g gpg_path - to the gpg secring used to sign rpms.  Defaults to $DEFAULT_GPGPATH"
    echo " -u gpg_uid - email used in secring. Defaults to $DEFAULT_GPGUID"
    echo " -K sshkey - specify ssh key to use when reaching git over ssh"
    echo " -S - do not publish source rpms"
    echo " -B - run build only"
    echo " -T - run test only"
    echo " -n - dry-run: -n passed to make - vm gets created though - no mail sent"
    echo " -v - be verbose"
    echo " -7 - uses weekday-@FCDISTRO@ as base"
    echo " --build-branch branch - build using the branch from build module"
    exit 1
}

function main () {

    set -e
    trap failure ERR INT

    # parse arguments
    MAKEVARS=()
    MAKETARGETS=()
    DRY_RUN=
    DO_BUILD=true
    DO_TEST=true
    PUBLISH_SRPMS=true
    SSH_KEY=""
    SIGNYUMREPO=""

    OPTS_ORIG=$@
    OPTS=$(getopt -o "f:d:p:m:s:t:b:o:c:y:e:i:XSx:w:W:r:M:Yg:u:K:SBTnv7i:P:h" -l "build-branch:" -- $@)
    if [ $? != 0 ]
    then
        usage
    fi
    eval set -- "$OPTS"
    while true; do
        case $1 in
            -f) FCDISTRO=$2; shift 2 ;;
            -d) PLDISTRO=$2; shift 2 ;;
            -p) PERSONALITY=$2; shift 2 ;;
            -m) MAILDEST=$2; shift 2 ;;
            -s) BUILD_SCM_URL=$2; shift 2 ;;
            -t) PLDISTROTAGS=$2; shift 2 ;;
            -b) BASE=$2; shift 2 ;;
            -o) OVERBASE=$2; shift 2 ;;
            -c) TESTCONFIG="$TESTCONFIG $2"; shift 2 ;;
            ########## passing stuff to run_log
            # -y foo -> run_log -y foo
            -y) RUN_LOG_EXTRAS="$RUN_LOG_EXTRAS --rspec-style $2"; shift 2 ;;
            # -e foo -> run_log -e foo
            -e) RUN_LOG_EXTRAS="$RUN_LOG_EXTRAS --exclude $2"; shift 2 ;;
            -i) RUN_LOG_EXTRAS="$RUN_LOG_EXTRAS --ignore $2"; shift 2 ;;
            # -X -> run_log --lxc
            -X) RUN_LOG_EXTRAS="$RUN_LOG_EXTRAS --lxc"; shift;;
            # -S -> run_log --vs
            -S) RUN_LOG_EXTRAS="$RUN_LOG_EXTRAS --vs"; shift;;
            # more general form to pass args to run_log
            # -x foo -> run_log foo
            -x) RUN_LOG_EXTRAS="$RUN_LOG_EXTRAS $2"; shift 2;;
            ##########
            -w) WEBPATH=$2; shift 2 ;;
            -W) TESTBUILDURL=$2; shift 2 ;;
            -r) WEBROOT=$2; shift 2 ;;
            -M) TESTMASTER=$2; shift 2 ;;
            -Y) SIGNYUMREPO=true; shift ;;
            -g) GPGPATH=$2; shift 2 ;;
            -u) GPGUID=$2; shift 2 ;;
            -K) SSH_KEY=$2; shift 2 ;;
            -S) PUBLISH_SRPMS="" ; shift ;;
            -B) DO_TEST= ; shift ;;
            -T) DO_BUILD= ; shift;;
            -n) DRY_RUN="-n" ; shift ;;
            -v) set -x ; VERBOSE="-v" ; shift ;;
            -7) BASE="$(date +%a|tr A-Z a-z)-@FCDISTRO@" ; shift ;;
            -P) PREINSTALLED="-P $2"; shift 2;;
            -h) usage ; shift ;;
            --) shift; break ;;
        esac
    done

    # preserve options for passing them again later, together with expanded base
    options=$OPTS_ORIG

    # allow var=value stuff;
    for target in "$@" ; do
        # check if contains '='
        target1=$(echo $target | sed -e s,=,,)
        if [ "$target" = "$target1" ] ; then
            MAKETARGETS=(${MAKETARGETS[@]} "$target")
        else
            MAKEVARS=(${MAKEVARS[@]} "$target")
        fi
    done

    # set defaults
    [ -z "$FCDISTRO" ] && FCDISTRO=$DEFAULT_FCDISTRO
    [ -z "$PLDISTRO" ] && PLDISTRO=$DEFAULT_PLDISTRO
    [ -z "$PERSONALITY" ] && PERSONALITY=$DEFAULT_PERSONALITY
    [ -z "$MAILDEST" ] && MAILDEST=$(echo $DEFAULT_MAILDEST | sed -e 's, at ,@,')
    [ -z "$PLDISTROTAGS" ] && PLDISTROTAGS="${PLDISTRO}-tags.mk"
    [ -z "$BASE" ] && BASE="$DEFAULT_BASE"
    [ -z "$WEBPATH" ] && WEBPATH="$DEFAULT_WEBPATH"
    [ -z "$TESTBUILDURL" ] && TESTBUILDURL="$DEFAULT_TESTBUILDURL"
    [ -z "$WEBROOT" ] && WEBROOT="$DEFAULT_WEBROOT"
    [ -z "$GPGPATH" ] && GPGPATH="$DEFAULT_GPGPATH"
    [ -z "$GPGUID" ] && GPGUID="$DEFAULT_GPGUID"
    [ -z "$BUILD_SCM_URL" ] && BUILD_SCM_URL="$DEFAULT_BUILD_SCM_URL"
    [ -z "$TESTCONFIG" ] && TESTCONFIG="$DEFAULT_TESTCONFIG"
    [ -z "$TESTMASTER" ] && TESTMASTER="$DEFAULT_TESTMASTER"

    [ -n "$DRY_RUN" ] && MAILDEST=""

    # elaborate the extra args to be passed to run_log
    for config in ${TESTCONFIG} ; do
        RUN_LOG_EXTRAS="$RUN_LOG_EXTRAS --config $config"
    done


    if [ -n "$OVERBASE" ] ; then
        sedargs="-e s,@DATE@,${DATE},g -e s,@TIME@,${TIME},g"
        BASE=$(echo ${OVERBASE} | sed $sedargs)
    else
        sedargs="-e s,@DATE@,${DATE},g -e s,@TIME@,${TIME},g -e s,@FCDISTRO@,${FCDISTRO},g -e s,@PLDISTRO@,${PLDISTRO},g -e s,@PERSONALITY@,${PERSONALITY},g"
        BASE=$(echo ${BASE} | sed $sedargs)
    fi

    ### elaborate mail subject
    if [ -n "$DO_BUILD" -a -n "$DO_TEST" ] ; then
        MAIL_SUBJECT="full"
    elif [ -n "$DO_BUILD" ] ; then
        MAIL_SUBJECT="pkg-only"
    elif [ -n "$DO_TEST" ] ; then
        MAIL_SUBJECT="test-only"
    fi
    if [ -n "$OVERBASE" ] ; then
        MAIL_SUBJECT="${MAIL_SUBJECT} rerun"
    else
        MAIL_SUBJECT="${MAIL_SUBJECT} fresh"
    fi
    short_hostname=$(hostname | cut -d. -f1)
    MAIL_SUBJECT="on ${short_hostname} - ${MAIL_SUBJECT}"

    ### compute WEBHOST from TESTBUILDURL
    # this is to avoid having to change the builds configs everywhere
    # simplistic way to extract hostname from a URL
    WEBHOST=$(echo "$TESTBUILDURL" | cut -d/ -f 3)

    if ! in_root_context ; then
        # in the vm
        echo "==================== Within LXC BEG $(date)"
        build
        echo "==================== Within LXC END $(date)"

    else
        trap failure ERR INT
        # we run in the root context :
        # (*) create or check for the vm to use
        # (*) copy this command in the vm
        # (*) invoke it

        if [ -n "$OVERBASE" ] ; then
            ### Re-use a vm (finish an unfinished build..)
            if [ ! -d $(rootdir ${BASE}) ] ; then
                echo $COMMAND : cannot find vm $BASE
                exit 1
            fi
            # manage LOG - beware it might be a symlink so nuke it first
            LOG=$(logfile ${BASE})
            rm -f $LOG
            exec > $LOG 2>&1
            set -x
            echo "XXXXXXXXXX $COMMAND: using existing vm $BASE" $(date)
            # start in case e.g. we just rebooted
            virsh -c lxc:/// start ${BASE} || :
            # retrieve environment from the previous run
            FCDISTRO=$(run_in_build_guest $BASE /build/getdistroname.sh)
            BUILD_SCM_URL=$(run_in_build_guest $BASE make --no-print-directory -C /build stage1=skip +build-GITPATH)
            # for efficiency, crop everything in one make run
            tmp=/tmp/${BASE}-env.sh
            run_in_build_guest $BASE make --no-print-directory -C /build stage1=skip \
                ++PLDISTRO ++PLDISTROTAGS ++PERSONALITY ++MAILDEST ++WEBPATH ++TESTBUILDURL ++WEBROOT > $tmp
            . $tmp
            rm -f $tmp
            # update build
            [ -n "$SSH_KEY" ] && setupssh ${BASE} ${SSH_KEY}
            run_in_build_guest $BASE "(cd /build; git pull; make tests-clean)"
            # make sure we refresh the tests place in case it has changed
            rm -f /build/MODULES/tests
            options=(${options[@]} -d $PLDISTRO -t $PLDISTROTAGS -s $BUILD_SCM_URL)
            [ -n "$PERSONALITY" ] && options=(${options[@]} -p $PERSONALITY)
            [ -n "$MAILDEST" ] && options=(${options[@]} -m $MAILDEST)
            [ -n "$WEBPATH" ] && options=(${options[@]} -w $WEBPATH)
            [ -n "$TESTBUILDURL" ] && options=(${options[@]} -W $TESTBUILDURL)
            [ -n "$WEBROOT" ] && options=(${options[@]} -r $WEBROOT)
            show_env
        else
            # create vm: check it does not exist yet
            i=
            while [ -d $(rootdir ${BASE})${i} ] ; do
                # we name subsequent builds <base>-n<i> so the logs and builds get sorted properly
                [ -z ${i} ] && BASE=${BASE}-n
                i=$((${i}+1))
                if [ $i -gt 100 ] ; then
                    echo "$COMMAND: Failed to create build vm $(rootdir ${BASE})${i}"
                    exit 1
                fi
            done
            BASE=${BASE}${i}
            # need update
            # manage LOG - beware it might be a symlink so nuke it first
            LOG=$(logfile ${BASE})
            rm -f $LOG
            exec > $LOG 2>&1
            set -x
            echo "XXXXXXXXXX $COMMAND: creating vm $BASE" $(date)
            show_env

            ### extract the whole build - much simpler
            tmpdir=/tmp/$COMMAND-$$
            GIT_REPO=$(echo $BUILD_SCM_URL | cut -d@ -f1)
            GIT_TAG=$(echo $BUILD_SCM_URL | cut -s -d@ -f2)
            GIT_TAG=${GIT_TAG:-master}
            mkdir -p $tmpdir
            ( git archive --remote=$GIT_REPO $GIT_TAG | tar -C $tmpdir -xf -) || \
                ( echo "==================== git archive FAILED, trying git clone instead" ; \
                  git clone $GIT_REPO $tmpdir && cd $tmpdir && git checkout $GIT_TAG && rm -rf .git)

            # Create lxc vm
            cd $tmpdir
            ./lbuild-initvm.sh $VERBOSE -f ${FCDISTRO} -d ${PLDISTRO} -p ${PERSONALITY} ${PREINSTALLED} ${BASE}
            # cleanup
            cd -
            rm -rf $tmpdir
            # Extract build again - in the vm
            [ -n "$SSH_KEY" ] && setupssh ${BASE} ${SSH_KEY}
            run_in_build_guest $BASE "(git clone $GIT_REPO /build; cd /build; git checkout $GIT_TAG)"
        fi
        echo "XXXXXXXXXX $COMMAND: preparation of vm $BASE done" $(date)

        # The log inside the vm contains everything
        LOG2=$(rootdir ${BASE})/log.txt
        (echo "==================== BEG LXC Transcript of vm creation" ; \
         cat $LOG ; \
         echo "==================== END LXC Transcript of vm creation" ; \
         echo "xxxxxxxxxx Messing with logs, symlinking $LOG2 to $LOG" ) >> $LOG2
        ### not too nice : nuke the former log, symlink it to the new one
        rm $LOG; ln -s $LOG2 $LOG
        LOG=$LOG2
        # redirect log again
        exec >> $LOG 2>&1

        sedargs="-e s,@DATE@,${DATE},g -e s,@TIME@,${TIME},g -e s,@FCDISTRO@,${FCDISTRO},g -e s,@PLDISTRO@,${PLDISTRO},g -e s,@PERSONALITY@,${PERSONALITY},g"
        WEBPATH=$(echo ${WEBPATH} | sed $sedargs)
        webpublish mkdir -p ${WEBPATH}

        # where to store the log for web access
        WEBBASE=${WEBPATH}/${BASE}
        WEBLOG=${WEBPATH}/${BASE}/log.txt
        # compute the log URL - inserted in the mail messages for convenience
        WEBBASE_URL=$(echo $WEBBASE | sed -e "s,//,/,g" -e "s,${WEBROOT},${TESTBUILDURL},")

        if [ -n "$DO_BUILD" ] ; then

            # invoke this command into the build directory of the vm
            cp $COMMANDPATH $(rootdir ${BASE})/build/

            # invoke this command in the vm for building (-T)
            run_in_build_guest $BASE chmod +x /build/$COMMAND
            run_in_build_guest $BASE /build/$COMMAND "${options[@]}" -b "${BASE}" "${MAKEVARS[@]}" "${MAKETARGETS[@]}"
        fi

        # publish to the web so run_log can find them
        set +e
        trap - ERR INT
#        webpublish rm -rf $WEBPATH/$BASE
        # guess if we've been doing any debian-related build
        if [ ! -f $(rootdir $BASE)/etc/debian_version  ] ; then
            webpublish mkdir -p $WEBPATH/$BASE/{RPMS,SRPMS}
            # after moving to f29, we see this dir created as 700
            # as remote umask is 077
            webpublish chmod 755 $WEBPATH/$BASE
            webpublish_rsync $WEBPATH/$BASE/RPMS/ $(rootdir $BASE)/build/RPMS/
            [[ -n "$PUBLISH_SRPMS" ]] && webpublish_rsync $WEBPATH/$BASE/SRPMS/ $(rootdir $BASE)/build/SRPMS/
        else
            # run scanpackages so we can use apt-get on this
            # (not needed on fedora b/c this is done by the regular build already)
            run_in_build_guest $BASE "(cd /build ; dpkg-scanpackages DEBIAN/ | gzip -9c > Packages.gz)"
            webpublish mkdir -p $WEBPATH/$BASE/DEBIAN
            webpublish_rsync $WEBPATH/$BASE/DEBIAN/ $(rootdir $BASE)/build/DEBIAN/*.deb
            webpublish_rsync $WEBPATH/$BASE/ $(rootdir $BASE)/build/Packages.gz
        fi
        # publish myplc-release if this exists
        release=$(rootdir $BASE)/build/myplc-release
        [ -f $release ] && webpublish_rsync $WEBPATH/$BASE $release
        set -e
        trap failure ERR INT

        # create yum repo and sign packages.
        if [ -n "$SIGNYUMREPO" ] ; then
            # this script does not yet support signing on a remote (webhost) repo
            sign_here=$(hostname) ; sign_web=$(webpublish hostname)
            if [ "$hostname" = "$sign_here" ] ; then
                sign_node_packages
            else
                echo "$COMMAND does not support signing on a remote yum repo"
                echo "you might want to turn off the -y option, or run this on the web server box itself"
                exit 1
            fi
        fi

        if [ -n "$DO_TEST" ] ; then
            run_log
        fi

        success

        echo "==================== MAIN END $(date)"
    fi

}

##########
main "$@"
