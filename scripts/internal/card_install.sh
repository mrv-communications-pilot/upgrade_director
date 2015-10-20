#!/bin/bash
#this script installs local card (cc or lc)
#it can handle auto or manual operations
#param1 - mode: (this param must be given)
#         auto - install all for this card
#         manual - install specific package for this card
#param2 - card type
#         CC or LC
#param3 - chassis type
#         OP-X4 or OP-X1
#param4 - options:
#         in auto mode:
#            blank (no param1)      - upgrade all for local card (include fpga)
#            no-fpga                - skip fpga upgrade
#            force-sw               - force all sw modules upgrade
#            force-fpga             - force fpga upgrade
#            force-all              - force complete upgrade
#         in manual mode:
#            fpga                   - upgarde local fpga (force mode)
#            root-fs                - upgrade root-fs, root-fs-extras, main application, config+sync
#            root-fs-extras         - upgrade root-fs-extras
#            main-app               - upgrade main application
#            kernel                 - upgrade kernel
#            config                 - upgrade config + sync
#            set_lc_candidate       - set runninf bundle as LC candidate
#param5 - specific options parameter
#         in manual mode
#            in 'all' optio
#               (same as auto mode options)
source functions.sh
#globals
current_app=$0
OTHER_PARTITION="UNKNOWN"
CARD_TYPE="ZZ"
card_id=0
FPGA_UPG_NEEDED=0
options=0
script_dir=`cd $(dirname $0); pwd`
root_fs_mounted=0
config_mounted=0
log_mounted=0
kernel_mounted=0
boot_mounted=0
force_fpga_upgrade=0
force_sw_upgrade=0
upgrade_done=0
fpga_upgrade_done=0
upgrade_component=0

no_prints=0


find_other_partition(){
    if [ $OTHER_PARTITION != "UNKNOWN" ]; then
        return
    fi
    printf "%-70s" "Find non running partition"
    mount_ret_val=$(mount |grep " / " |awk '{print $1}')
    if [ $mount_ret_val == $ROOT_FS_A_PART ]; then
        OTHER_PARTITION="VER_B"
        echo -e "[  ${green}B ${nc}  ]"
    elif [ $mount_ret_val == $ROOT_FS_B_PART ]; then
        OTHER_PARTITION="VER_A"
        echo -e "[  ${green}A ${nc}  ]"
    else
        echo -e "[ ${red}FAIL${nc} ]"
        exit 1
    fi
}

mount_partition(){
    no_prints=1
    cd /
    if [ "root-fs" == "$1" ]; then
        if [ "$root_fs_mounted" -eq 1 ]; then
            return
        fi
        operation="mount non running root-fs partition"
        if [ $OTHER_PARTITION == VER_A ]; then
            run_cmd mount $ROOT_FS_A_PART $ROOT_FS_MNT
            root_fs_mounted=1
        elif [ $OTHER_PARTITION == VER_B ]; then
            run_cmd mount $ROOT_FS_B_PART $ROOT_FS_MNT
            root_fs_mounted=1
        else
            echo -e "${red}Mount root-fs: unknown upgrading partition${nc}"
            exit 1
        fi
    elif [ "config" == "$1" ]; then
        if [ "$config_mounted" -eq 1 ]; then
            return
        fi
        operation="mount non running configuration partition"
        if [ $OTHER_PARTITION == VER_A ]; then
            run_cmd mount $CONFIG_A_PART $CONFIG_MNT
            config_mounted=1
        elif [ $OTHER_PARTITION == VER_B ]; then
            run_cmd mount $CONFIG_B_PART $CONFIG_MNT
            config_mounted=1
        else
            echo -e "${red}Mount config: unknown upgrading partition${nc}"
            exit 1
        fi
    elif [ "log" == "$1" ]; then
        if [ "$log_mounted" -eq 1 ]; then
            return
        fi
        operation="mount non running log partition"
        if [ $OTHER_PARTITION == VER_A ]; then
            run_cmd mount $LOG_A_PART $LOG_MNT
            log_mounted=1
        elif [ $OTHER_PARTITION == VER_B ]; then
            run_cmd mount $LOG_B_PART $LOG_MNT
            log_mounted=1
        else
            echo -e "${red}Mount log: unknown upgrading partition${nc}"
            exit 1
        fi
    elif [ "kernel" == "$1" ]; then
        if [ "$kernel_mounted" -eq 1 ]; then
            return
        fi
        operation="mount non running kernel partition"
        if [ $OTHER_PARTITION == VER_A ]; then
            run_cmd mount $KERNEL_A_PART $KERNEL_MNT
            kernel_mounted=1
        elif [ $OTHER_PARTITION == VER_B ]; then
            run_cmd mount $KERNEL_B_PART $KERNEL_MNT
            kernel_mounted=1
        else
            echo -e "${red}Mount kernel: unknown upgrading partition${nc}"
            exit 1
        fi
    elif [ "boot" == "$1" ]; then
        if [ "$boot_mounted" -eq 1 ]; then
            return
        fi
        operation="mount boot partition"
        run_cmd mount $BOOT_PART $BOOT_MNT
        boot_mounted=1
    else
        echo -e "${red}internal error${nc}"
        exit 1
    fi
}

unmount_partition(){
    no_prints=1
    cd /
    if [ "root-fs" == "$1" ]; then
        if [ "$root_fs_mounted" -eq 0 ]; then
            return
        fi
        operation="unmount non running root-fs partition"
        run_cmd umount $ROOT_FS_MNT
        root_fs_mounted=0
    elif [ "config" == "$1" ]; then
        if [ "$config_mounted" -eq 0 ]; then
            return
        fi
        operation="unmount non running configuration partition"
        run_cmd umount $CONFIG_MNT
        config_mounted=0
    elif [ "log" == "$1" ]; then
        if [ "$log_mounted" -eq 0 ]; then
            return
        fi
        operation="unmount non running log partition"
        run_cmd umount $LOG_MNT
        log_mounted=0
    elif [ "kernel" == "$1" ]; then
        if [ "$kernel_mounted" -eq 0 ]; then
            return
        fi
        operation="unmount non running kernel partition"
        run_cmd umount $KERNEL_MNT
        kernel_mounted=0
    elif [ "boot" == "$1" ]; then
        if [ "$boot_mounted" -eq 0 ]; then
            return
        fi
        operation="unmount boot partition"
        run_cmd umount $BOOT_MNT
        boot_mounted=0
    else
        echo -e "${red}internal error${nc}"
        exit 1
    fi
}

unmount_all(){
    cd /
    umount $ROOT_FS_MNT 2>>/dev/null
    umount $CONFIG_MNT 2>>/dev/null
    umount $LOG_MNT 2>>/dev/null
    umount $KERNEL_MNT 2>>/dev/null
    umount $BOOT_MNT 2>>/dev/null
}

verify_mount_points() {
    no_prints=1
    operation="create mount point for root-fs"
    run_cmd mkdir -p $ROOT_FS_MNT
    operation="create mount point for configuration"
    run_cmd mkdir -p $CONFIG_MNT
    operation="create mount point for log"
    run_cmd mkdir -p $LOG_MNT
    operation="create mount point for kernel"
    run_cmd mkdir -p $KERNEL_MNT
    operation="create mount point for boot"
    run_cmd mkdir -p $BOOT_MNT
}

upgrade_log(){
    no_prints=1
    mount_partition log
    operation="cd $LOG_MNT"
    run_cmd cd $LOG_MNT
    #test "$(ls -A "$LOG_MNT" 2>/dev/null)"
    #log_is_empty=$?
    #if [ $log_is_empty -eq 1 ]; then
        #no_prints=0
        #operation="Creating clean log partition"
        #run_cmd tar -xmpf $BUNDLE_DIR/$LOG_TARBALL
        #pr_log INFO "============================================================="
        #pr_log INFO "==== CLEAN SYSLOG STARTED (GENERATED BY UPGRADE PROCESS) ===="
        #pr_log INFO "============================================================="
    #fi
    run_cmd mkdir -p core_dump
    run_cmd rm -rf core_dump/*
    unmount_partition log
}

install_root_fs(){
    mount_partition root-fs
    operation="cd $ROOT_FS_MNT"
    run_cmd cd $ROOT_FS_MNT

    #if [ "$options" == "force-sw" ] || [ "$options" == "force-all" ] || [ "$force_sw_upgrade" -eq 1 ]; then
        #upgrade_component=1
    #else
        #installed_os_ver=`cat $ROOT_FS_MNT/etc/os-release |grep "VERSION=" | grep -o "[0-9\. ()]\+" 2>>/dev/null`
        #os_ver=`cat $BUNDLE_DIR/OP-X_BundleCfg.xml | grep  -A3 "<os>" | grep -o "=\"[0-9\. ()]\+" | grep -o "[0-9\. ()]\+" | awk '{print $1}' 2>>/dev/null`
        #printf "%-70s" "Check operating system: running $installed_os_ver bundle $os_ver"
        #if [ "$installed_os_ver" = "$os_ver" ]; then
            #upgrade_component=0
            #echo -e "[ ${green}SKIP${nc} ]"
        #else
            #upgrade_component=1
            #echo -e "[  ${green}YES${nc} ]"
        #fi
    #fi

    #if [ "$upgrade_component" -eq 1 ]; then
        operation="delete previous root-fs content"
        run_cmd rm -rf $ROOT_FS_MNT/*
        no_prints=0
        operation="Install operating system"
        run_cmd tar -xmpf $BUNDLE_DIR/$ROOT_FS_TARBALL
        upgrade_done=1
    #fi

    #install new root-fs requires also the following installations
    install_root_fs_extras
    install_main_application
    install_config
    sync_config
}

install_root_fs_extras(){
    mount_partition root-fs
    operation="cd $ROOT_FS_MNT"
    run_cmd cd $ROOT_FS_MNT

    #if [ "$options" == "force-sw" ] || [ "$options" == "force-all" ] || [ "$force_sw_upgrade" -eq 1 ]; then
        #upgrade_component=1
    #else
        #installed_extras_ver=`cat $ROOT_FS_MNT/etc/root-fs-extras.ver 2>>/dev/null`
        #extras_ver=`cat $BUNDLE_DIR/OP-X_BundleCfg.xml | grep  -A3 "<os_extras>" | grep -o "=\"[0-9\. ()]\+" | grep -o "[0-9\. ()]\+" | awk '{print $1}' 2>>/dev/null`
        #printf "%-70s" "Check system configuration: running $installed_extras_ver bundle $extras_ver"
        #if [ "$installed_extras_ver" = "$extras_ver" ]; then
            #upgrade_component=0
            #echo -e "[ ${green}SKIP${nc} ]"
        #else
            #upgrade_component=1
            #echo -e "[  ${green}YES${nc} ]"
        #fi
    #fi
    #if [ "$upgrade_component" -eq 1 ]; then
        no_prints=0
        operation="Install system configuration"
        run_cmd tar -xmpf $BUNDLE_DIR/$ROOT_FS_EXTRAS_TARBALL
        #fix fstab
        no_prints=1
        operation="fix fstab"
        if [ $OTHER_PARTITION == VER_A ]; then
            run_cmd cp etc/fstab.a etc/fstab
        elif [ $OTHER_PARTITION == VER_B ]; then
            run_cmd cp etc/fstab.b etc/fstab
        fi
        upgrade_log
        upgrade_done=1
    #fi
    unmount_partition root-fs
}

install_main_application(){
    mount_partition root-fs
    operation="cd $ROOT_FS_MNT/usr"
    run_cmd cd $ROOT_FS_MNT/usr
    main_ver=`cat $BUNDLE_DIR/OP-X_BundleCfg.xml | grep -o "ver[ ]*=[ ]*\"[0-9a-z (\.)]*" | grep -o "=[ ]*\"[0-9a-z (\.)]*" | grep -o "[0-9a-z (\.)]*"`

    #check if we need main application upgrade
    #if [ "$options" == "force-sw" ] || [ "$options" == "force-all" ] || [ "$force_sw_upgrade" -eq 1 ]; then
        #upgrade_component=1
    #else
        #if [ $CARD_TYPE == CC ]; then
            #installed_main_ver=`cat $ROOT_FS_MNT/usr/deploy-cc/etc/app.ver 2>>/dev/null`
        #elif [ $CARD_TYPE == LC ]; then
            #installed_main_ver=`cat $ROOT_FS_MNT/usr/deploy-lc/etc/app.ver 2>>/dev/null`
        #else
            #installed_main_ver="NA"
        #fi
        #main_ver=`cat $BUNDLE_DIR/OP-X_BundleCfg.xml | grep -o "ver[ ]*=[ ]*\"[0-9a-z (\.)]*" | grep -o "=[ ]*\"[0-9a-z (\.)]*" | grep -o "[0-9a-z (\.)]*"`
        #printf "%-70s" "Check main application: running $installed_main_ver bundle $main_ver"
        #if [ "$installed_main_ver" = "$main_ver" ]; then
            #upgrade_component=0
            #echo -e "[ ${green}SKIP${nc} ]"
            #unmount_partition root-fs
            #return
        #else
            #upgrade_component=1
            #echo -e "[  ${green}YES${nc} ]"
        #fi
    #fi
    #if we did not return before, then upgrade is needed
    if [ $CARD_TYPE == CC ]; then
        if [ -d $ROOT_FS_MNT/usr/deploy-cc ] ; then
            no_prints=0
            operation="Remove previous main application"
            run_cmd rm -rf $ROOT_FS_MNT/usr/deploy-cc
        fi
        no_prints=1
        operation="make deploy-cc directory"
        run_cmd mkdir deploy-cc
        run_cmd chmod 755 deploy-cc
        operation="cd $ROOT_FS_MNT/usr/deploy-cc"
        run_cmd cd $ROOT_FS_MNT/usr/deploy-cc
        no_prints=0
        operation="Install main application"
        run_cmd tar -xmpf $BUNDLE_DIR/$DEPLOY_CC_TARBALL
        no_prints=1
        run_cmd chown root:root $ROOT_FS_MNT/usr/deploy-cc -R
    elif [ $CARD_TYPE == LC ]; then
        deploy_dest="deploy-lc"
        if [ $CHASSIS_TYPE == OP-X1 ]; then
            deploy_dest="deploy-cc"
        fi

        if [ -d $ROOT_FS_MNT/usr/$deploy_dest ] ; then
            no_prints=0
            operation="Remove previous main application"
            run_cmd rm -rf $ROOT_FS_MNT/usr/$deploy_dest
        fi
        no_prints=1
        operation="make deploy-lc directory"
        run_cmd mkdir $deploy_dest
        run_cmd chmod 755 $deploy_dest
        operation="cd $ROOT_FS_MNT/usr/$deploy_dest"
        run_cmd cd $ROOT_FS_MNT/usr/$deploy_dest
        no_prints=0
        operation="Install main application"
        if [ $CHASSIS_TYPE == OP-X1 ]; then
            run_cmd tar -xmpf $BUNDLE_DIR/$DEPLOY_CC_TARBALL
        else
        run_cmd tar -xmpf $BUNDLE_DIR/$DEPLOY_LC_TARBALL
        fi
        no_prints=1
        run_cmd chown root:root $ROOT_FS_MNT/usr/$deploy_dest -R
    fi

    #update issue and issue.net
    no_prints=1
    run_cmd echo MRV OptiPacket $main_ver '\\n \\l' > $ROOT_FS_MNT/etc/issue
    run_cmd echo MRV OptiPacket $main_ver > $ROOT_FS_MNT/etc/issue.net
    unmount_partition root-fs
    upgrade_done=1
}

install_config(){
    if [ "$upgrade_done" -eq 1 ]; then
        mount_partition config
        operation="cd $CONFIG_MNT"
        run_cmd cd $CONFIG_MNT
        no_prints=0
        operation="Install basic configuration"
        run_cmd tar -xmpf $BUNDLE_DIR/$CC_CONFIG_TARBALL
        unmount_partition config
    fi
}

install_kernel(){
    no_prints=1
    mount_partition kernel
    operation="cd $KERNEL_MNT"
    run_cmd cd $KERNEL_MNT

    #if [ "$options" == "force-sw" ] || [ "$options" == "force-all" ]; then
        #upgrade_component=1
    #else

        #installed_kernel_ver=`cat $KERNEL_MNT/kernel.ver 2>>/dev/null`
        #kernel_ver=`cat $BUNDLE_DIR/OP-X_BundleCfg.xml | grep  -A3 "<kernel>" | grep -o "=\"[0-9\. ()]\+" | grep -o "[0-9\. ()]\+"`
        #printf "%-70s" "Check kernel: running $installed_kernel_ver bundle $kernel_ver"
        #if [ "$installed_kernel_ver" = "$kernel_ver" ]; then
            #upgrade_component=0
            #echo -e "[ ${green}SKIP${nc} ]"
        #else
            #upgrade_component=1
            #echo -e "[  ${green}YES${nc} ]"
        #fi
    #fi
    #if [ "$upgrade_component" -eq 1 ]; then
        operation="delete previous kernel content"
        run_cmd rm -rf $KERNEL_MNT/*
        no_prints=0
        operation="Install kernel"
        run_cmd tar -xmpf $BUNDLE_DIR/$KERNEL_TARBALL
        upgrade_done=1
    #fi
    unmount_partition kernel
}

sync_config(){
    if [ $CARD_TYPE != CC ] &&  [ $CHASSIS_TYPE != OP-X1 ]; then
        return
    fi
    if [ "$upgrade_done" -eq 0 ]; then
        return
    fi
    no_prints=1
    mount_partition root-fs
    mount_partition config
    mount_partition log
    mount_partition kernel
    operation="Sync configuration"
    run_cmd rsync -ratD /config/* $CONFIG_MNT/
    run_cmd rsync -ratD /etc/passwd $ROOT_FS_MNT/etc/passwd
    run_cmd rsync -ratD /etc/shadow $ROOT_FS_MNT/etc/shadow
    #run_cmd rsync -ratD /etc/init/ttyS0.conf $ROOT_FS_MNT/etc/init/ttyS0.conf
    #run_cmd rsync -ratD /etc/init/ttyS1.conf $ROOT_FS_MNT/etc/init/ttyS1.conf
    if [ -f /var/lib/snmp/snmpd.conf ]; then
    run_cmd rsync -ratRD /var/lib/snmp/snmpd.conf  $ROOT_FS_MNT
    fi
    if [ -f /usr/local/etc/snmp/snmpd.conf ]; then
    run_cmd rsync -ratRD /usr/local/etc/snmp/snmpd.conf  $ROOT_FS_MNT
    fi
    no_prints=0 #just for getting the print for the user
    run_cmd rsync -ratD /etc/hostname $ROOT_FS_MNT/etc/hostname
    unmount_partition root-fs
    unmount_partition config
    unmount_partition log
    unmount_partition kernel
}

switch_boot_part(){
    if [ "$upgrade_done" -eq 0 ]; then
        return
    fi
    no_prints=1
    mount_partition boot
    operation="cd $BOOT_MNT"
    run_cmd cd $BOOT_MNT
    upgrade_ver=`cat ${BUNDLE_DIR}/OP-X_BundleCfg.xml | grep -o "ver[ ]*=[ ]*\"[0-9a-z (\.)]*" | grep -o "=[ ]*\"[0-9a-z (\.)]*" | grep -o "[0-9a-z (\.)]*"`
    current_ver=`cat /etc/issue.net`
    if [ -f /usr/deploy-cc/etc/app.ver ] ; then
        app_ver=`cat /usr/deploy-cc/etc/app.ver`
        current_ver="MRV OptiPacket $app_ver"
    elif [ -f /usr/deploy-lc/etc/app.ver ] ; then
        app_ver=`cat /usr/deploy-lc/etc/app.ver`
        current_ver="MRV OptiPacket $app_ver"
    fi

    #copy updated menu.a and menu.b files to boot partition
    operation="Update boot partition"
    run_cmd cp  $script_dir/sata_menu.a  grub/menu.a
    run_cmd cp  $script_dir/sata_menu.b  grub/menu.b
    if [ $OTHER_PARTITION == VER_A ]; then
        run_cmd cp grub/menu.a grub/menu.lst
        operation="Saving current version"
        run_cmd `sed -i "s/VERSION B/$current_ver/g" grub/menu.lst`
        operation="Publishing new version"
        run_cmd `sed -i "s/VERSION A/MRV OptiPacket $upgrade_ver/g" grub/menu.lst`
    elif [ $OTHER_PARTITION == VER_B ]; then
        run_cmd cp grub/menu.b grub/menu.lst
        operation="Saving current version"
        run_cmd `sed -i "s/VERSION A/$current_ver/g" grub/menu.lst`
        operation="Publishing new version"
        run_cmd `sed -i "s/VERSION B/MRV OptiPacket $upgrade_ver/g" grub/menu.lst`
    fi
    unmount_partition boot
}

check_if_fpga_upgrade_needed(){
    if [ "$options" == "force-fpga" ] || [ "$options" == "force-all" ]; then
        FPGA_UPG_NEEDED=1
    else
        printf "%-70s" "Check if firmware upgrade is needed"
        if [ "$options" == "no-fpga" ]; then
            FPGA_UPG_NEEDED=0
            echo -e "[ ${green}SKIP${nc} ]"
        else
            #TODO: check running against bundle version and verify if upgrade is needed
            FPGA_UPG_NEEDED=1
            echo -e "[  ${green}YES${nc} ]"
        fi
    fi
}

local_fpga_upgrade(){
    if [ $force_fpga_upgrade -eq 1 ]; then
        FPGA_UPG_NEEDED=1
    else
        if [ "$options" == "no-fpga" ]; then
            printf "%-70s" "Check if firmware upgrade is needed"
            FPGA_UPG_NEEDED=0
            echo -e "[ ${green}SKIP${nc} ]"
        else
            FPGA_UPG_NEEDED=1
        fi
    fi

   #cancell fpga upgrade when pressing "c"
    if [ $FPGA_UPG_NEEDED -eq 1 ]; then
        printf "%-70s" "FPGA Upgrade... press c->enter to skip"
        read -t5 upgrade
	if [ "$upgrade" == "c" ]; then
	  echo -e "[ ${green}SKIP${nc} ]"
	  FPGA_UPG_NEEDED=0
	fi
    fi


    if [ $FPGA_UPG_NEEDED -eq 1 ]; then
        no_prints=1
        operation="cd $BUNDLE_DIR"
        run_cmd cd $BUNDLE_DIR
        ./upgrade_client upgrade_local_ha_fpga
        run_result=$?
        if [ $run_result -eq $FPGA_UPGRADE_SKIP_EXIT_CODE ]; then
            return
        elif [ $run_result != 0 ]; then
            echo "local fpga upgrade failed!"
            pr_log ERROR "upgrade_local_ha_fpga failed. return code is $run_result"
            exit 1
        else
            fpga_upgrade_done=1
        fi
    fi
}

set_lc_candidate(){
    if [ $CARD_TYPE != CC ]; then
        return
    fi
    no_prints=1
    mount_partition root-fs
    operation="cd $ROOT_FS_MNT/usr/deploy-cc"
    run_cmd cd $ROOT_FS_MNT/usr/deploy-cc

    if [ ! -d $LC_BUNDLE_DIR ] ; then
        operation="create $LC_BUNDLE_DIR directory"
        run_cmd mkdir -p $LC_BUNDLE_DIR
    fi
    operation="cd $LC_BUNDLE_DIR"
    run_cmd cd $LC_BUNDLE_DIR
    rm $LC_BUNDLE_LINK 2>>/dev/null
    no_prints=0
    operation="Set bundle as LC candidate"
    run_cmd ln -s /ver/$BUNDLE_NAME $LC_BUNDLE_LINK
    operation="Publish LC candidate bundle version"
    no_prints=1
    run_cmd cp $ROOT_FS_MNT/usr/deploy-cc/etc/app.ver .
    run_cmd cd $BUNDLE_DIR
    lc_fpga_ver=`./upgrade_client get_lc_bundle_fpga`
    run_cmd cd $LC_BUNDLE_DIR
    echo "$lc_fpga_ver" > fpga.ver
    unmount_partition root-fs
}

check_if_force_sw_is_needed(){
    no_prints=1
    if [ $CARD_TYPE == CC ]; then
        installed_main_ver=`cat /usr/deploy-cc/etc/app.ver 2>>/dev/null`
    elif [ $CARD_TYPE == LC ]; then
        if [ $CHASSIS_TYPE == OP-X1 ]; then
           installed_main_ver=`cat /usr/deploy-cc/etc/app.ver 2>>/dev/null`
        else
           installed_main_ver=`cat /usr/deploy-lc/etc/app.ver 2>>/dev/null`
        fi
    else
        installed_main_ver="NA"
    fi
    main_ver=`cat $BUNDLE_DIR/OP-X_BundleCfg.xml | grep -o "ver[ ]*=[ ]*\"[0-9a-z (\.)]*" | grep -o "=[ ]*\"[0-9a-z (\.)]*" | grep -o "[0-9a-z (\.)]*"`
    printf "%-70s" "Check main application: running $installed_main_ver bundle $main_ver"
    if [ "$installed_main_ver" = "$main_ver" ]; then
        echo -e "[ ${green}SKIP${nc} ]"
        unmount_partition root-fs
        return
    else
        echo -e "[  ${green}YES${nc} ]"
        force_sw_upgrade=1
    fi
}

delete_oldest_bundle() {
    no_prints=1
    old_build=9999999999
    list=`ls -autlr | grep -E '^[^d]' | awk '{print $9;}' | grep -o "[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+" | grep -o "[0-9]\+$"`
    for i in ${list}
    do
        if [ $i -lt $old_build ]; then
                old_build=$i
        fi
    done
    old_bundle=`ls -autlr | grep -E '^[^d]' | awk '{print $9;}' |grep $old_build |head -1`
    run_cmd rm -rf $old_bundle
    pr_log INFO "$old_bundle was automaticaly removed"
}

check_bundles() {
    no_prints=1
    operation="cd $ROOT_BUNDLE_DIR"
    run_cmd cd $ROOT_BUNDLE_DIR
    number_of_bundles=`ls -autlr *.bundle  | wc -l`
    while [ $number_of_bundles -gt 10 ]
    do
        delete_oldest_bundle
        number_of_bundles=`ls -autlr *.bundle  | wc -l`
    done
}


#################################################
# start main script                             #
#################################################
source globals.conf 2>>/dev/null
if [ $? != 0 ]; then
    echo -e "\e[0;31mERROR: failed to source global variables\e[0m"
    exit 1
fi
#print header to the log
pr_log INFO "$0 started. params: $1 $2 $3 $4 $5 $6 $7 $8 $9"
unmount_all
verify_mount_points
CHASSIS_TYPE=$3
if [ "auto" == "$1" ]; then
    options=$4
    CARD_TYPE=$2
    check_bundles
#    CHASSIS_TYPE=$3

    #first thing we do is to program the FPGA, if it fails, don't go on with upgrade
    local_fpga_upgrade
    find_other_partition
    if [ "force-sw" == "$options" ] || [ "force-all" == "$options" ]; then
        force_sw_upgrade=1
    else
        check_if_force_sw_is_needed
    fi
    if [ "$force_sw_upgrade" -eq 1 ]; then
        install_root_fs #also installs root-fs-extras,main application, config+sync
        install_kernel
        switch_boot_part
        set_lc_candidate
    fi
    if [ "force-fpga" == "$options" ] || [ "force-all" == "$options" ]; then
        force_fpga_upgrade=1
    fi
elif [ "manual" == "$1" ]; then
    CARD_TYPE=$2
    check_bundles
#    CHASSIS_TYPE=$3
    if [ "fpga" == "$4" ]; then
        force_fpga_upgrade=1
        local_fpga_upgrade
    elif [ "root-fs" == "$4" ]; then
        find_other_partition
        install_root_fs #also installs root-fs-extras,main application, config+sync
    elif [ "kernel" == "$4" ]; then
        find_other_partition
        install_kernel
    elif [ "main-app" == "$4" ]; then
        find_other_partition
        install_main_application
    elif [ "root-fs-extras" == "$4" ]; then
        find_other_partition
        install_root_fs_extras
    elif [ "config" == "$4" ]; then
        find_other_partition
        install_config
        sync_config
    elif [ "set_lc_candidate" == "$4" ]; then
        set_lc_candidate
    elif [ "all" == "$4" ]; then
        options=$5
        find_other_partition
	#first thing we do is to program the FPGA, if it fails, don't go on with upgrade
	local_fpga_upgrade
        if [ "force-sw" == "$options" ] || [ "force-all" == "$options" ]; then
            force_sw_upgrade=1
        else
        check_if_force_sw_is_needed
        fi
        if [ "$force_sw_upgrade" -eq 1 ]; then
            install_root_fs #also installs root-fs-extras,main application, config+sync
            install_kernel
            switch_boot_part
            set_lc_candidate
        fi
        if [ "force-fpga" == "$options" ] || [ "force-all" == "$options" ]; then
            force_fpga_upgrade=1
        fi
    elif [ "sw" == "$4" ]; then
        find_other_partition
        install_root_fs #also installs root-fs-extras,main application, config+sync
        install_kernel
        switch_boot_part
        set_lc_candidate
    else
	
	echo -e "${red}$0: invalid option  $4${nc}"
	pr_log ERROR "invalid option ($4)"
	exit 1
    fi

else
    echo -e "${red}$0: unknown mode $1${nc}"
    pr_log ERROR "unknown mode type ($1)"
    exit 1
fi


if [ $fpga_upgrade_done -eq 1 ]; then
    pr_log DEBUG "card upgrade finished successfully. reload is needed"
    exit $CARD_NEED_RELOAD
elif [ $upgrade_done -eq 1 ]; then
pr_log DEBUG "card upgrade finished successfully. reboot is needed"
    exit $CARD_NEED_REBOOT
else
    pr_log DEBUG "card upgrade finished successfully. latest bundle already installed"
    exit 0
fi
