#!/bin/bash
source globals.conf 

upgrade_far_fpga(){
    FAR_FPGA_UPG_NEEDED=0
    printf "%-70s" "Check $1 availability"
    avail=`$BUNDLE_DIR/upgrade_client check_slot_avail $1`
    if [ $? != 0 ]; then 
        echo -e "[ ${red}FAIL${nc} ]"
        return $FPGA_UPGRADE_SKIP_EXIT_CODE 
    else
        if [ $avail == YES ]; then
            echo -e "[  ${green}YES${nc} ]"
            FAR_FPGA_UPG_NEEDED=1
        else
            echo -e "[  ${green}NO${nc}  ]"
        fi
    fi
  
    if [ $FAR_FPGA_UPG_NEEDED -eq 1 ]; then
        no_prints=1
        operation="cd $BUNDLE_DIR"
        run_cmd cd $BUNDLE_DIR
        ./upgrade_client upgrade_remote_ha_fpga $1
        run_result=$?
        if [ $run_result -eq $FPGA_UPGRADE_SKIP_EXIT_CODE ]; then
            return $FPGA_UPGRADE_SKIP_EXIT_CODE
        elif [ $run_result != 0 ]; then
            printf "\r%-70s" "Upgrade $1 firmware revision"
            echo -e "[ ${red}FAIL${nc} ]"
            pr_log ERROR "upgrade_remote_ha_fpga $1 failed. return code is $run_result"
            return $FPGA_UPGRADE_SKIP_EXIT_CODE
        else
            pr_log INFO "upgrade_remote_ha_fpga $1 succeeded"
            return $CARD_NEED_RELOAD
            

        fi
    fi
}

pr_log(){
    #param1 = priority
    #param2 = message
    logger $debug_options -p $1 -t "$current_app[${BASH_LINENO[$i]}]" "$2"
}


find_card_type(){
    
    printf "%-70s" "Find card type"
    card_id=`$BUNDLE_DIR/upgrade_client card_id`
    if [ $? != 0 ]; then 
        echo -e "[ ${red}FAIL${nc} ]"
        exit 1
    fi
    CARD_TYPE=${card_id:0:2}
    CARD_ID=${card_id:2:3}
    echo -e "[  ${green}$CARD_TYPE${nc}  ]"
}
find_local_card(){
    
    find_card_type
}


find_chassis_type(){
    
    printf "%-70s" "Find chassis type"
    card_id=`$BUNDLE_DIR/upgrade_client chassis_id`
    if [ $? != 0 ]; then 
        echo -e "[ ${red}FAIL${nc} ]"
        exit 1
    fi
    CHASSIS_TYPE=${card_id:0:5}
    echo -e "[ ${green}$CHASSIS_TYPE${nc}]"
}

check_ccy_upgrade(){
    
    printf "%-70s" "Check if redundancy control card is being upgraded"
    #local upgrade=`$BUNDLE_DIR/upgrade_client is_background_ccy_upgrade`
	ssh -q 172.21.13.36 [[ -f /home/ran/1 ]] && upgrade="YES" || echo upgrade="NO";
    if [ $? != 0 ]; then 
        echo -e "[ ${red}FAIL${nc} ]"
        exit 1
    else
        if [ "$upgrade" == "YES" ]; then
            echo -e "[  ${green}YES${nc} ]"
            ccy_upgrade="yes"
        else
            echo -e "[  ${green}NO${nc}  ]"
            ccy_upgrade="no"
        fi
    fi
}

check_ccy_availability(){
    
    printf "%-70s" "Check redundancy control card availability"
    avail=`$BUNDLE_DIR/upgrade_client check_slot_avail ccy`
    if [ $? != 0 ]; then 
        echo -e "[ ${red}FAIL${nc} ]"
        exit 1
    else
        if [ $avail == YES ]; then
            echo -e "[  ${green}YES${nc} ]"
            ccy_exist="yes"
        else
            echo -e "[  ${green}NO${nc}  ]"
            ccy_exist="no"
        fi
    fi
}


run_cmd(){
    if [ "$no_prints" -eq 0 ]; then
        echo -ne "$operation"
    fi
    cmd=$@
    if [ "$no_prints" -eq 0 ]; then
        let spaces=80-10-${#operation}
        printf "%-${spaces}s" " "
    fi
    pr_log DEBUG "[from line ${BASH_LINENO[$i]}] running command: ${cmd}"
    ${cmd} 1> /var/log/stdout.log 2> /var/log/stderr.log
    if [ $? != 0 ]; then 
        if [ "$no_prints" -eq 0 ]; then
            echo -e "[ ${red}FAIL${nc} ]"
        fi
        pr_log ERROR "failed to run command: ${cmd}"
        pr_log ERROR "stdout=`cat /var/log/stdout.log`"
        pr_log ERROR "stderr=`cat /var/log/stderr.log`"
        exit 1
    fi
    if [ "$no_prints" -eq 0 ]; then
        echo -e "[  ${green}OK${nc}  ]"
    fi
}


fix_bundle_filename() {
    export BUNDLE_NAME=`basename $BUNDLE_NAME`
    if [ $? != 0 ] || [ -z $BUNDLE_NAME ]; then
        printf "\r%-70s" "Checking bundle name"
        echo -e "[ ${red}FAIL${nc} ]"
        exit 1
    fi
}

