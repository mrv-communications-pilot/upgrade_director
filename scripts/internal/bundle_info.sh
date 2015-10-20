#!/bin/bash

app_ver=`cat ../OP-X_BundleCfg.xml | grep -o "ver[ ]*=[ ]*\"[0-9a-z (\.)]*" | grep -o "=[ ]*\"[0-9a-z (\.)]*" | grep -o "[0-9a-z (\.)]*"`
os_ver=`cat ../OP-X_BundleCfg.xml | grep  -A3 "<os>" | grep -o "=\"[0-9\. ()]\+" | grep -o "[0-9\. ()]\+"`
os_extras=`cat ../OP-X_BundleCfg.xml | grep  -A3 "<os_extras>" | grep -o "=\"[0-9\. ()]\+" | grep -o "[0-9\. ()]\+"`
kernel_ver=`cat ../OP-X_BundleCfg.xml | grep  -A3 "<kernel>" | grep -o "=\"[0-9\. ()]\+" | grep -o "[0-9\. ()]\+"`
#OP-X4
cc_opx4_ha_fpga=`cat ../OP-X_BundleCfg.xml | grep  -A3 "<cc_opx4_ha_fpga>" | grep -o "=\"[a-f,0-9\. ()]\+" | grep -o "[a-f,0-9\. ()]\+"`
lc_40x10g_opx4_ha_fpga=`cat ../OP-X_BundleCfg.xml | grep  -A3 "<lc_40x10g_opx4_ha_fpga>" | grep -o "=\"[a-f,0-9\. ()]\+" | grep -o "[a-f,0-9\. ()]\+"`
lc_2x100g_opx4_ha_fpga=`cat ../OP-X_BundleCfg.xml | grep  -A3 "<lc_2x100g_opx4_ha_fpga>" | grep -o "=\"[a-f,0-9\. ()]\+" | grep -o "[a-f,0-9\. ()]\+"`
fe_opx4_ha_fpga=`cat ../OP-X_BundleCfg.xml | grep  -A3 "<fe_opx4_ha_fpga>" | grep -o "=\"[a-f,0-9\. ()]\+" | grep -o "[a-f,0-9\. ()]\+"`
fan_opx4_ha_fpga=`cat ../OP-X_BundleCfg.xml | grep  -A3 "<fan_opx4_ha_fpga>" | grep -o "=\"[a-f,0-9\. ()]\+" | grep -o "[a-f,0-9\. ()]\+"`
#OP-X1
lc_40x10g_opx1_ha_fpga=`cat ../OP-X_BundleCfg.xml | grep  -A3 "<lc_40x10g_opx1_ha_fpga>" | grep -o "=\"[a-f,0-9\. ()]\+" | grep -o "[a-f,0-9\. ()]\+"`
lc_2x100g_opx1_ha_fpga=`cat ../OP-X_BundleCfg.xml | grep  -A3 "<lc_2x100g_opx1_ha_fpga>" | grep -o "=\"[a-f,0-9\. ()]\+" | grep -o "[a-f,0-9\. ()]\+"`
fan_opx1_ha_fpga=`cat ../OP-X_BundleCfg.xml | grep  -A3 "<fan_opx1_ha_fpga>" | grep -o "=\"[a-f,0-9\. ()]\+" | grep -o "[a-f,0-9\. ()]\+"`

bundle_date=`cat ../OP-X_BundleCfg.xml | grep "Created" | awk '{print $3,$4,$5,$8,$6;}'`

echo -e "\r"
echo "    Component                     Version"
echo "=================================================================="
echo "SW Componenets"
echo "    Main Application              $app_ver"
echo "    Operating System              $os_ver"
echo "    System Configuration          $os_extras"
echo "    Kernel                        $kernel_ver"
echo "------------------------------------------------------------------"
echo "Firmware"
echo "    =============== OP-X4 =========="
echo "    Control Card                  $cc_opx4_ha_fpga"
echo "    Line Card 40x10g              $lc_40x10g_opx4_ha_fpga"
echo "    Line Card 2x100g              $lc_2x100g_opx4_ha_fpga"
echo "    Fabric Element                $fe_opx4_ha_fpga"
echo "    Fan                           $fan_opx4_ha_fpga"
echo "    =============== OP-X1 =========="
echo "    Line Card 40x10g              $lc_40x10g_opx1_ha_fpga"
echo "    Line Card 2x100g              $lc_2x100g_opx1_ha_fpga"
echo "    Fan                           $fan_opx1_ha_fpga"
echo "------------------------------------------------------------------"
echo "Release Date"
echo "    $bundle_date"
echo "------------------------------------------------------------------"

exit 0
