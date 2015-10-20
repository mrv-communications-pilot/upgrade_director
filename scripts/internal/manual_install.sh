#!/bin/bash
#this script manually installs specific module in specific card
#param1 - bundle name ($0 of the caller script)
#param2 - card id
#         CC1 - CC2, LC1 - LC4, FE1 - FE3, FAN1 - FAN2
#param3 - options:
#         in CC and LC cards:
#            all                    - upgrade all for desiered card (include fpga)
#            fpga                   - upgrade fpga only
#            sw                     - upgrade sw only
#         in FE and FAN cards:
#            fpga                   - upgarde fpga in desired card (force mode)
#param4 - specific options parameter
source functions.sh
#exports
current_app=$0
export script_dir=`cd $(dirname $0); pwd`
no_prints=0
check_final_result=0


usage(){
    echo "usage: $0 [TBD]"
    #echo "mode options:"
    #echo "extract           - extract bundle to working directory"
    exit 1
}



#################################################
# start main script                             #
#################################################
echo -ne "\r"
if [ $? != 0 ]; then
    echo -e "\e[0;31mERROR: failed to source global variables\e[0m"
    exit 1
fi
#verify log folder exists
if [ ! -d $UPGRADE_LOG_DIR ] ; then
    mkdir -p $UPGRADE_LOG_DIR
fi

export OUTPUT_FILE=$UPGRADE_LOG_DIR/manual_install.log
#print header to the log
pr_log INFO "MANUAL UPGRADE STARTED started. params: $1 $2 $3 $4 $5 $6 $7 $8 $9"

if [ -z $1 ]; then
    usage
else
    #export BUNDLE_NAME=${1:2:30}
    export BUNDLE_NAME=${1}
    fix_bundle_filename
fi

if [ -z $2 ]; then
    usage
else
    run_result=20 #start with wrong result
	# will export CHASSIS_TYPE
    find_chassis_type
    #desiered card
    DESIERED_SLOT=${2}
    DESIERED_CARD=${DESIERED_SLOT:0:2}
    DESIERED_ID=${DESIERED_SLOT:2:3}
    if [ "cc" == $DESIERED_CARD ] || [ "CC" == $DESIERED_CARD ]; then
        if [ "$DESIERED_ID" -ne 1 ] && [ "$DESIERED_ID" -ne 2 ]; then
            echo -e "${red}ERROR:${nc} wrong desiered cc slot id ($DESIERED_ID)"
            exit 1
        else
            #upgrade cc 
            find_local_card
            # will export CARD_TYPE
            if [ "$card_id" == $DESIERED_SLOT ] || [ "$card_id" == "${DESIERED_SLOT^^}" ]; then
                #local upgrade needed
		echo "====== Installing Version on $card_id ========"
                ./card_install.sh manual $CARD_TYPE $CHASSIS_TYPE $3 $4
                run_result=$?
                check_final_result=1
            else
                #remote upgrade needed, start remote upgrade, need to make sure return value goes back to local cc
				#this will copy bundle to remote and execute maunal upgrade of cc, the code above us
        		operation="Copy bundle to $DESIERED_SLOT"
        		run_cmd scp $ROOT_BUNDLE_DIR/$BUNDLE_NAME $DESIERED_SLOT:/$ROOT_BUNDLE_DIR
        		ssh root@$DESIERED_SLOT -q "(cd $ROOT_BUNDLE_DIR; ./$BUNDLE_NAME manual $DESIERED_SLOT all )"
        		run_result=$?
        		#echo "remote card result $run_result"
        		
            fi
        fi
    elif [ "lc" == $DESIERED_CARD ] || [ "LC" == $DESIERED_CARD ]; then
        if [ "$DESIERED_ID" -ne 1 ] && [ "$DESIERED_ID" -ne 2 ] && [ "$DESIERED_ID" -ne 3 ] && [ "$DESIERED_ID" -ne 4 ]; then
            echo -e "${red}ERROR:${nc} wrong desiered lc slot id ($DESIERED_ID)"
            exit 1
        else
            #upgrade lc
            find_local_card
            if [ "$card_id" == $DESIERED_SLOT ] || [ "$card_id" == "${DESIERED_SLOT^^}" ]; then
                #local upgrade (we are running now on remote lc)
				$BUNDLE_DIR/upgrade_client send_msg install_bundle
                pr_log INFO "performing local upgrade to lc$CARD_ID"
                ./card_install.sh manual $CARD_TYPE $CHASSIS_TYPE $3 $4
                run_result=$?
                check_final_result=1
                $BUNDLE_DIR/upgrade_client send_msg upgrade_done
            else
                #remote upgrade lc card
                pr_log INFO "performing remote upgrade to lc$CARD_ID"
                operation="Copy bundle to $DESIERED_SLOT"
                run_cmd scp $ROOT_BUNDLE_DIR/$BUNDLE_NAME lc$DESIERED_ID:/$ROOT_BUNDLE_DIR
                ssh root@lc$DESIERED_ID  -q "(cd $ROOT_BUNDLE_DIR; ./$BUNDLE_NAME manual LC$DESIERED_ID $3 $4 $5)"
            fi
        fi
    # all line card upgrade - pass as lx 
    elif [ "lx" == $DESIERED_CARD ] || [ "LX" == $DESIERED_CARD ]; then
        
            #upgrade lc
			NUMBERS="1 2 3 4"
            find_local_card
        	for number in `echo $NUMBERS`  # for number in 9 7 3 8 37.53
			do
				DESIERED_ID=$number
				DESIERED_SLOT=LC$DESIERED_ID
				#echo -n "$number "
				printf "%-70s" "Upgrading LC$number"
	            if [ "$card_id" == "LC$number" ]; then
	                #local upgrade (we are running now on remote lc)
	                pr_log INFO "performing local upgrade to lc$number"
	                ./card_install.sh manual $CARD_TYPE $CHASSIS_TYPE $3 $4
	                run_result=$?
	                check_final_result=1
	            else
	                #remote upgrade lc card
	                pr_log INFO "performing remote upgrade to lc$number"
	                operation="Copy bundle to $DESIERED_SLOT"
	                #run_cmd scp $ROOT_BUNDLE_DIR/$BUNDLE_NAME lc$DESIERED_ID:/$ROOT_BUNDLE_DIR
	                scp $ROOT_BUNDLE_DIR/$BUNDLE_NAME lc$DESIERED_ID:/$ROOT_BUNDLE_DIR  1> /var/log/stdout.log 2> /var/log/stderr.log
	                if [ $? != 0 ]; then
	                	echo -e "[ ${red}FAIL${nc} ]"
	            	else
	            		echo -e "[  ${green}OK${nc} ]"
	            		ssh root@lc$DESIERED_ID  -q "(cd $ROOT_BUNDLE_DIR; ./$BUNDLE_NAME manual LC$DESIERED_ID $3 $4 $5)"
	            	fi
	                	 
	                
	            fi
            done
        
    elif [ "fe" == $DESIERED_CARD ] || [ "FE" == $DESIERED_CARD ]; then
        if [ "$DESIERED_ID" -ne 1 ] && [ "$DESIERED_ID" -ne 2 ] && [ "$DESIERED_ID" -ne 3 ]; then
            echo -e "${red}ERROR:${nc} wrong desiered fe slot id ($DESIERED_ID)"
            exit 1
        else
            upgrade_far_fpga fe$DESIERED_ID
            run_result=$?
            if [ $run_result -eq 0 ]; then
                echo "INFO chassis reload is needed to apply changes"
            fi
        fi
    else
        DESIERED_CARD=${DESIERED_SLOT:0:3}
        DESIERED_ID=${DESIERED_SLOT:3:4}
        if [ "fan" == $DESIERED_CARD ] || [ "FAN" == $DESIERED_CARD ]; then
            echo "fan selected"
            if [ "$DESIERED_ID" -ne 1 ] && [ "$DESIERED_ID" -ne 2 ]; then
                echo -e "${red}ERROR:${nc} wrong desiered fan slot id ($DESIERED_ID)"
                exit 1
            else
                upgrade_far_fpga fan$DESIERED_ID
                run_result=$?
                if [ $run_result -eq 0 ]; then
                    echo "INFO chassis reload is needed to apply changes"
                fi
            fi
        else
            echo -e "${red}ERROR:${nc} wrong desiered slot ($DESIERED_SLOT)"
            exit 1
        fi
    fi
    #check if we succeed in last operation
    if [ "$check_final_result" -eq 1 ]; then
        if [ $run_result -eq $CARD_NEED_RELOAD ]; then
            pr_log DEBUG "$DESIERED_SLOT upgrade finished successfully. reload is needed"
            echo -e "${green}$DESIERED_SLOT upgrade finished successfully. reload is needed${nc}"
            
            exit $CARD_NEED_RELOAD
        elif [ $run_result -eq $CARD_NEED_REBOOT ]; then
            pr_log DEBUG "$DESIERED_SLOT upgrade finished successfully. reboot is needed"
            echo -e "${green}$DESIERED_SLOT upgrade finished successfully. reboot is needed${nc}"
            exit $CARD_NEED_REBOOT
        elif [ $run_result != 0 ]; then
            pr_log ERROR "failed to install $DESIERED_SLOT. exit code is $run_result"
            echo -e "failed to install $DESIERED_SLOT. exit code is $run_result"
            exit 1
        else
            pr_log DEBUG "$DESIERED_SLOT upgrade finished successfully. latest bundle already installed"
            echo -e "$DESIERED_SLOT upgrade finished successfully. latest bundle already installed"
            exit 0
        fi
    fi
fi

exit $run_result
