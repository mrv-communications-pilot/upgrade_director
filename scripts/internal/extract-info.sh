#!/bin/bash

script_dir=`cd $(dirname $0); pwd`

run_cmd(){
    if [ "$no_prints" -eq 0 ]; then
        echo -ne "$operation"
    fi
    cmd=$@
    echo "operation: $operation" 1>> ${OUTPUT_FILE} 2>> ${OUTPUT_FILE}
    echo "cmd: $cmd" 1>> ${OUTPUT_FILE} 2>> ${OUTPUT_FILE}
    echo "date: `date`" 1>> ${OUTPUT_FILE} 2>> ${OUTPUT_FILE}
    echo "==========================================" 1>> ${OUTPUT_FILE} 2>> ${OUTPUT_FILE}
    if [ "$no_prints" -eq 0 ]; then
        let spaces=80-10-${#operation}
        printf "%-${spaces}s" " "
    fi
    ${cmd} 1>> ${OUTPUT_FILE} 2>> ${OUTPUT_FILE}
    if [ $? != 0 ]; then 
        if [ "$no_prints" -eq 0 ]; then
            echo -e "[ ${red}FAIL${nc} ]"
        fi
        exit 1
    fi
    if [ "$no_prints" -eq 0 ]; then
        echo -e "[  ${green}OK${nc}  ]"
    fi
    echo "==========================================" 1>> ${OUTPUT_FILE} 2>> ${OUTPUT_FILE}
}

echo -e "\r"
source globals.conf 2>>/dev/null
if [ $? != 0 ]; then
    echo -e "\e[0;31mERROR: failed to source global variables\e[0m"
    exit 1
fi

#print header to the log
echo "==========================================" 1>> ${OUTPUT_FILE} 2>> ${OUTPUT_FILE}
echo "$0 started" 1>> ${OUTPUT_FILE} 2>> ${OUTPUT_FILE}
echo "date: `date`" 1>> ${OUTPUT_FILE} 2>> ${OUTPUT_FILE}
echo "==========================================" 1>> ${OUTPUT_FILE} 2>> ${OUTPUT_FILE}

if [ ! -d $INFO_DIR ] ; then
    mkdir -p $INFO_DIR
fi
cd $INFO_DIR
bundle_name=${1:2:30}
if [ -d $INFO_DIR/$bundle_name ] ; then
    rm -rf $INFO_DIR/$bundle_name
fi

no_prints=1
operation="create bundle info directory"
run_cmd mkdir -p $INFO_DIR/$bundle_name
no_prints=0
operation="Extract Bundle Information"
run_cmd cp -ra $BUNDLE_DIR/OP-X_BundleCfg.xml $INFO_DIR/$bundle_name/
operation="Extract Bundle Tools"
run_cmd cp -ra $BUNDLE_DIR/scripts/ $INFO_DIR/$bundle_name/
exit 0
