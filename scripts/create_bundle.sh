#!/bin/bash

#set colors
red='\e[0;31m'
green='\e[0;32m'
yellow='\e[1;33m'
white='\e[1;37m'
blue='\e[1;34m'
nc='\e[0m'

#exports
export LC_ALL=C


# Get external fpga list if exist
. ./fpga_images_list.env
FPGA_LIST=${fpga_images_list:-" cc_ha_fpga.bit lc_ha_fpga.bit fe_ha_fpga.bit fan_ha_fpga.bit "}

PACKAGE_DIR="../package"



if [ ! -d "$PACKAGE_DIR" ]; then
    echo -ne "${red}"
    echo "package directory does not exist!"
    echo "please update package information and try again"
    echo -ne "${nc}"
    exit 1
fi

script_dir=`cd $(dirname $0); pwd`

OUTPUT_FILE=${script_dir}/bundle.log
echo "log start: `date`" > ${OUTPUT_FILE}
echo "==========================================" 1>> ${OUTPUT_FILE} 2>> ${OUTPUT_FILE}

#next command parameters
operation="NA"
cmd_time=0
let acc_time=0
let progress=0

run_cmd(){
    echo -ne "${yellow}$operation${nc}"
    cmd=$@
    echo "cmd: $cmd" 1>> ${OUTPUT_FILE} 2>> ${OUTPUT_FILE}
    echo "date: `date`" 1>> ${OUTPUT_FILE} 2>> ${OUTPUT_FILE}
    echo "==========================================" 1>> ${OUTPUT_FILE} 2>> ${OUTPUT_FILE}
    ${cmd} 1>> ${OUTPUT_FILE} 2>> ${OUTPUT_FILE}
    if [ $? != 0 ]
    then
        echo "failed"
        echo -e "ERROR: failed to run command: ${cmd}"
        exit 1
    fi
    echo -e "${green} done${nc}"
    echo "==========================================" 1>> ${OUTPUT_FILE} 2>> ${OUTPUT_FILE}
}

#check that we have all necessary tarballs
for file in root-fs-x86.tgz log.tgz root-fs-extras.tgz kernel.tgz deploy-cc.tgz deploy-lc.tgz cc_config.tgz ${FPGA_LIST} upgrade_client OP-X_BundleCfg.xml VERSION; do
    if [ ! -f $PACKAGE_DIR/$file ]; then
        echo -e "ERROR: $file is missing"
        exit 1
    fi
done

operation="add scripts directory"
run_cmd mkdir -p $PACKAGE_DIR/scripts

operation="add internal scripts"
run_cmd cp -ra $script_dir/internal/* $PACKAGE_DIR/scripts/

cd $PACKAGE_DIR/
rm -rf package.*
files=`find -type f \( -iname "*.tgz" -or -iname "*.bit" -or -iname "*.xml" -or -iname "upg*" -or -iname "*.sh" \) ! -iname "self*.sh"| sort -f`; md5sum $files > md5.check
operation="create package tarball"
run_cmd tar -czpf package.tgz OP-X_BundleCfg.xml scripts/ upgrade_client kernel.tgz cc_config.tgz ${FPGA_LIST} root-fs-extras.tgz log.tgz root-fs-x86.tgz deploy-cc.tgz deploy-lc.tgz VERSION md5.check

operation="add self extractor script"
run_cmd cp -ra $script_dir/internal/selfextractor.sh $PACKAGE_DIR/

operation="create self extracting bundle"
echo -ne "${yellow}$operation${nc}"
cat selfextractor.sh package.tgz  > package.bundle
if [ $? != 0 ]
then
    echo "failed"
    echo -e "ERROR: failed to create self extracting bundle${cmd}"
    exit 1
else
    echo -e "${green} done${nc}"
fi

operation="fix permissions"
run_cmd chmod a+x package.bundle

