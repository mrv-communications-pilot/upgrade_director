#!/bin/bash
source /ver/bundle/scripts/globals.conf 2

#exports
export LC_ALL=C
percentage=90
log_partition="/var/log"
ver_partition="/ver"
v_card_type=`cat /tmp/card_type`
run_result=0

ARCHIVE=`awk '/^__ARCHIVE_BELOW__/ {print NR + 1; exit 0; }' $0`

usage(){
    echo "usage: $0 [mode]"
    echo "mode options:"
    echo "extract           - extract bundle to working directory"
    echo "auto              - automatic installation"
    echo "--> no-fpga       - skip fpga upgrade"
    echo "manual            - manual installation (additional parameters required)"
    echo "--> fpga          - upgrade fpga"
    echo "info              - detailed information of this bundle"
    echo "extract-info      - extract bundle information for future use"
    echo "extract-xml       - extract bundle xml file"
    exit 1
}

pr_log(){
    #param1 = priority
    #param2 = message
    logger -p $1 -t "$0" "$2"
}

check_space(){
    space_left=`df -h |grep "$log_partition" |awk '{print $5;}' | grep -o "[0-9\. ()]\+"`
    if [[ $space_left -gt ${percentage} ]]; then
        echo -e "\nlog partition is running out of space ($space_left% full)"
        echo "please free some space and try again"
        exit 1
    fi
    #space_left=`df -h |grep "$ver_partition" |awk '{print $5;}' | grep -o "[0-9\. ()]\+"`
    #if [[ $space_left -gt ${percentage} ]]; then
        #echo "versions partition is running out of space ($space_left% full)"
        #echo "please remove older bundles and try again"
        #exit 1
    #fi
}

check_md5(){
    printf "\r%-70s" "Verify bundle checksum"
    files=`find -type f \( -iname "*.tgz" -or -iname "*.bit" -or -iname "*.xml" -or -iname "upg*" -or -iname "*.sh" \) ! -iname "self*.sh" | sort -f`
    md5sum $files > md5.calc
    md5_result=`diff md5.calc md5.check 1> /var/log/stdout.log 2> /var/log/stderr.log`
    
    echo -e "[  ${green}OK${nc}  ]"
    
#    if [ $? != 0 ]; then
#         echo -e "[ ${red}FAIL${nc} ]"
#        pr_log ERROR "=== bundle $0 checksum failed ==="
#        pr_log ERROR "stdout=`cat /var/log/stdout.log`"
#        pr_log ERROR "stderr=`cat /var/log/stderr.log`"
#        pr_log ERROR "=== end of bundle $0 checksum failed ==="
#        exit 1
#    else
#        echo -e "[  ${green}OK${nc}  ]"
#    fi
}

extract_bundle(){
    pr_log INFO "extracting bundle $0"
    check_space
    mkdir -p $1
    echo -ne "Extracting bundle..."
    tail -n+$ARCHIVE $0 | tar -xpzm -C $1 1> /var/log/stdout.log 2> /var/log/stderr.log
    cd $1
    check_md5
}

#clear the screen and set cursor at 1,1
#echo -ne '\e[2J'
#echo -ne '\e[1;1H'
if [ -z $1 ]; then
    usage
fi


if [ -f $ROOT_BUNDLE_DIR/install_in_progress ]; then
	 echo -e "[  ${red}Another installation is already running..please retry later${nc}  ]"
	 echo -e "[  ${red}If you think this is not correct, rm /ver/install_in_progress${nc}  ]"
	 
	 exit 0
fi
	

if [ "extract" == $1 ]; then
    extract_bundle .
    exit 0
elif [ "extract-xml" == $1 ]; then
    extract_bundle .
    exit 0
elif [ "auto" == $1 ]; then 
	touch $ROOT_BUNDLE_DIR/install_in_progress
    rm -rf $BUNDLE_DIR 2> /dev/null
    extract_bundle $BUNDLE_DIR
    cd $BUNDLE_DIR/scripts
    ./auto_install.sh $0 $2 $3 $4
    run_result=$?
elif [ "manual" == $1 ]; then
    rm -rf $BUNDLE_DIR 2> /dev/null
    touch $ROOT_BUNDLE_DIR/install_in_progress
    extract_bundle $BUNDLE_DIR
    cd $BUNDLE_DIR/scripts
    ./manual_install.sh $0 $2 $3 $4 $5 $6 $7 $8 $9 $10 $11
    run_result=$?
elif [ "info" == $1 ]; then
    bundle_name=${0:2:30}
    if [ -d $INFO_DIR/$bundle_name ] ; then
        (cd $INFO_DIR/$bundle_name/scripts; ./bundle_info.sh)
    else
        rm -rf $BUNDLE_DIR 2> /dev/null
        extract_bundle $BUNDLE_DIR
        (cd $BUNDLE_DIR/scripts; ./bundle_info.sh)
    fi
    exit 0
elif [ "extract-info" == $1 ]; then
    rm -rf $BUNDLE_DIR 2> /dev/null
    extract_bundle $BUNDLE_DIR
    (cd $BUNDLE_DIR/scripts; ./extract-info.sh $0)
    exit 0
else
    usage
    exit 0
fi

if [ -f $ROOT_BUNDLE_DIR/install_in_progress ]; then
	rm $ROOT_BUNDLE_DIR/install_in_progress
fi

#auto get here
if [ $run_result -eq 1 ] ; then
	echo -e "${red}ERROR: failed to install $device${nc}"
	exit $run_result
fi

# we do not auto reboot in manual 
if [ "manual" == $1 ]; then
	exit $run_result
fi

if [ $run_result -eq $CARD_NEED_RELOAD ] || [ $run_result -eq $CARD_NEED_REBOOT ]; then
	#for line-cards , we will timeout . for cc, we will ask the user
	if [ "$v_card_type" == "lc" ]; then
	 echo -ne "\rDo you want to reboot the line card now? (y/n)"
	   read -s -t3 -n1 yn
	else
		echo -ne "\rDo you want to reboot the chassis now? (y/n)"
	   read -s -n1 yn
	fi
	case $yn in
          [Yy]* ) echo "yes"
	       	/sbin/reboot chassis;
	       	sleep 5;;
          [Nn]* ) echo "no"; 
                  pr_log INFO "user decide to skip automatic reboot";;
          *     ) echo "yes"
	    /sbin/reboot chassis;
	    	sleep 5;;
    esac
else
       echo -e "${green}All components are already updated, reboot is not required${nc}"
fi 


exit $?
__ARCHIVE_BELOW__
