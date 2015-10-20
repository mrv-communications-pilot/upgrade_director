#!/bin/bash
current_app=$0
export script_dir=`cd $(dirname $0); pwd`
export OUTPUT_FILE=$UPGRADE_LOG_DIR/auto_install.log
export next_install_cc=1
export CARD_ID=0
export BUNDLE_NAME=$1
no_prints=0
need_reload=0
remote_cc_run_result=0




#################################################
# start main script                             #
#################################################
echo -ne "\r"
echo "dir is $PWD"

if [ $? != 0 ]; then
    echo -e "\e[0;31mERROR: failed to source global variables\e[0m"
    exit 1
fi
#verify log folder exists
if [ ! -d $UPGRADE_LOG_DIR ] ; then
    mkdir -p $UPGRADE_LOG_DIR
fi
#print header to the log
source functions.sh
pr_log INFO "AUTOMATIC UPGRADE STARTED started. params: $1 $2 $3 $4 $5 $6 $7 $8 $9"
upgrade_version=`cat $BUNDLE_DIR/VERSION`
pr_log INFO "upgrade version is $upgrade_version"

fix_bundle_filename
find_chassis_type
#find real hardware card type
find_card_type
#virtual card type ( lc in op-x1 is CC ) 
v_card_type=`cat /tmp/card_type` 
device=$v_card_type$CARD_ID

if [ "$v_card_type" == "cc" ]; then
    #check if second cc if available
    check_ccy_availability
    if [ "$ccy_exist" == "yes" ]; then
        if [ "$CARD_ID" -eq 1 ]; then
            next_install_cc=2
        elif [ "$CARD_ID" -eq 2 ]; then
            next_install_cc=1
        else
            echo -e "${red}ERROR: failed to determine redundancy control card id${nc}"
            pr_log ERROR "failed to determine redund*ancy control card id"
        fi
        #start remote upgrade
	./manual_install.sh $BUNDLE_NAME cc$next_install_cc
        remote_cc_run_result=$?
        #echo "remote_cc_run_result $remote_cc_run_result"
    fi

    if [ "no-fpga" != "$2" ]; then
        #upgrade fabric elements opx-4 only - we do not fail upgrade if those guys fails for now 
		if [ $CHASSIS_TYPE == OP-X4 ]; then
	    	upgrade_far_fpga fe1
	    	[ $? -eq $CARD_NEED_RELOAD ] && need_reload=1
	    
			upgrade_far_fpga fe2
		    [ $? -eq $CARD_NEED_RELOAD ] && need_reload=1
	    
	    	upgrade_far_fpga fe3
	    	[ $? -eq $CARD_NEED_RELOAD ] && need_reload=1
	    	
	    	upgrade_far_fpga fan1
	        [ $? -eq $CARD_NEED_RELOAD ] && need_reload=1
	    
		fi
	#OP-X4\1 both update fan 2
    	upgrade_far_fpga fan2
    	[ $? -eq $CARD_NEED_RELOAD ] && need_reload=1
	    	
    fi
else
     #notify CC that we are starting to install 
     $BUNDLE_DIR/upgrade_client send_msg install_bundle
fi


# local component installation 
cd $script_dir
./card_install.sh auto $CARD_TYPE $CHASSIS_TYPE $2 $3
run_result=$?


#echo "remote_cc_run_result $remote_cc_run_result   run_result $run_result"
#we have to make sure to check both remote and local upgrade status, so we OR the results 
total_run_result=$(( $run_result | $remote_cc_run_result))
#echo "total_run_result $total_run_result"

#notify CC that were done with upgrade
if [ "$v_card_type" == "lc" ]; then
  $BUNDLE_DIR/upgrade_client send_msg upgrade_done
fi
exit $total_run_result
