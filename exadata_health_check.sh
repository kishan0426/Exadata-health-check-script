#!/bin/bash

####################################################################################
#                          EXADATA HEALTH SCRIPT                                   #
#                            AUTHOR~Kishan M                                       #
####################################################################################


#                                 1/8th RACK 

####################################################################################
#                               DESCRIPTION                                        #
# This script will generate the status report from  Exadata cell and switch        #
####################################################################################


#print the title

_title()
{
     echo "                     *** -------------------------------- ***"
     echo "                     ***       EXADATA HEALTH CHECK       ***"
     echo "                     *** -------------------------------- ***"
}

#log

_log()
{
     echo "*** $1"
}

#verify_user
_verify_user()
{
   if [ $(id -u) != 0 ]; then
       _log "Run as root user"
       exit 1
   fi
}
#Set environment
_env()
{
_log "*** Exporting environment variables *** "
          export PATH=/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/sbin:/u01/app/oracle/product/11.2.0.4/dbhome_1/bin:/u01/app/12.2.0.1/grid/bin:/u01/app/12.2.0.1/grid/OPatch:/u01/app/oracle/product/11.2.0.4/dbhome_1/OPatch:/u01/app/oracle/ggs_home
CG=/root/cell_group;SG=/root/switch_group;DG=/root/dbs_group;CELLLOG=/tmp/cell.log;IBLOG=/tmp/iberrors.log;HDD=/tmp/hdd.err;FDD=/tmp/fdd.err;IH=/tmp/IMAGEHISTORY.log
export CG;export SG;export CELLLOG;export IBLOG;export HDD;export FDD;export IH
_log "LOGFILES";echo $CELLLOG;echo $IBLOG;echo $HDD;echo $FDD;echo $IH
}

#check file
_file_check(){
   ls "$CELLLOG" "$IBLOG" "$FDD" "$HDD" >/dev/null 2>&1 && echo '***'
   if [ $? -eq 0 ]
   then
     echo ''
   else
     touch $CELLLOG $IBLOG $FDD $HDD
   fi
}



#Cell
_cell_monitor()
{
echo "#################################################################################"
echo "#                              CELL HEALTH CHECK                                #"
echo "#################################################################################"

_log " Checking the cell status  ***"
echo "---------------------------------------------------------------------------------"
/usr/local/bin/dcli -g $CG -l root cellcli -e "list cell"
echo "---------------------------------------------------------------------------------"
_log " Checking cell processes ***"
echo "---------------------------------------------------------------------------------"
/usr/local/bin/dcli -g /root/cell_group -l root "   hostname;echo "-----------------------";cellcli -e "list cell detail"|egrep '(cellsrvStatus)|(msStatus)|(rsStatus)'"|awk '{$1="";print}'
echo "---------------------------------------------------------------------------------"
_log " Cumulative CPU utilization on each cell ***"
echo "---------------------------------------------------------------------------------"
/usr/local/bin/dcli -g $CG -l root cellcli -e "list metriccurrent CL_CPUT"|awk '{$1="";print}'
echo "---------------------------------------------------------------------------------"
_log " Top 5 processes consuming CPU in compute nodes ***"
echo "---------------------------------------------------------------------------------"
/usr/local/bin/dcli -g $DG -l root "   hostname;ps -eo pid,ppid,cmd,%cpu --sort=-%cpu|head -6"|awk '{$1="";print}'|column -t|grep -v "ps"
echo "---------------------------------------------------------------------------------"
_log " Top 5 processes consuming CPU in cell nodes ***"
echo "---------------------------------------------------------------------------------"
/usr/local/bin/dcli -g $CG -l root "   hostname;ps -eo pid,ppid,cmd,%cpu --sort=-%cpu|head -6"|awk '{$1="";print}'|column -t |grep -v "ps"
echo "---------------------------------------------------------------------------------"
_log " Memory utilization on each cell"
echo "---------------------------------------------------------------------------------"
/usr/local/bin/dcli -g $CG -l root cellcli -e "list metriccurrent CL_MEMUT"|awk '{$1="";print}'
echo "---------------------------------------------------------------------------------"
#_log " IOPS on each cell"
#/usr/local/bin/dcli -g $CG -l root cellcli -e "list metriccurrent CD_IO_UTIL"
echo "#################################################################################"
_log " Checking abnormal metrics please wait for sometime ***"
echo "                                                       "
echo "#################################################################################"
/usr/local/bin/dcli -g $CG -l root cellcli -e "list metrichistory where alertState!=\'Normal\'"
echo "#################################################################################"
}

_cell_error_check()
{
_log "   Checking the critical alerts in the cell ***"
echo "#################################################################################"
/usr/local/bin/dcli -g $CG -l root cellcli -e "list alerthistory attributes name,alertMessage,beginTime,endTime where severity = 'critical' detail;"|tail -10 >$CELLLOG && cat $CELLLOG
grep 'alertMessage' $CELLLOG >/dev/null 2>&1
if [ $? -ne 0 ]
then
echo "           *** No cell alerts for now ***"
fi
echo "#################################################################################"
}
#Physical Disk
_hard_disk_check()
{
_log " Checking the abnormal physical disk ***"
/usr/local/bin/dcli -g $CG -l root cellcli -e "list physicaldisk attributes name,id,slotnumber where disktype=\"harddisk\" and status!=\'normal\'" >$HDD && cat $HDD
egrep -i 'poor|predictive' $HDD >/dev/null 2>&1
if [ $? -ne 0 ];then
echo "            *** No hard disk issue ***"
fi
echo "#################################################################################"
}
#Flash Disk
_flash_disk_check()
{
echo "              ***   Flashcache Mode  *** "
echo "---------------------------------------------------------------------------------"
/usr/local/bin/dcli -g /root/cell_group -l root "    hostname;echo "-----------------------";cellcli -e "list cell detail"|egrep 'flashCacheMode'"|awk '{$1="";print}'
echo "---------------------------------------------------------------------------------"
echo "              *** Flashcache used in cell nodes *** "
echo "---------------------------------------------------------------------------------"
/usr/local/bin/dcli -g /root/cell_group -l root "    hostname;echo "-----------------------";cellcli -e "list metriccurrent where name = 'FC_BY_USED'""|awk '{$1="";print}'
echo "---------------------------------------------------------------------------------"
echo "               Checking abnormal flash disk ***"
echo "---------------------------------------------------------------------------------"
/usr/local/bin/dcli -g $CG -l root cellcli -e "list physicaldisk attributes name,id,slotnumber where disktype=\"flashdisk\" and status!=\'normal\'" >$FDD && cat $FDD
egrep -i 'poor|predictive' $FDD >/dev/null 2>&1
if [ $? -ne 0 ];then
echo "           *** No flash disk issue ***"
fi
echo "---------------------------------------------------------------------------------"
}

#Switch
_ib_port_check()
{
echo "#################################################################################"
echo "#                           EXADATA SWITCH PORT HEALTH                          #"
echo "#################################################################################"

echo "       ***   Checking the ports status on the switches ***"
/usr/local/bin/dcli -g $SG -l root "listlinkup"|grep -v '13A\|14A\|15A\|8B\|12B\|15B'|grep 'down' >$IBLOG && cat $IBLOG
grep 'down' $IBLOG >/dev/null 2>&1
if [ $? -ne 0 ];then
echo "---------------------------------------------------------------------------------"
echo "#                            Ports are up!"                                     #
fi
echo "---------------------------------------------------------------------------------"
}
_ib_status(){
echo "#################################################################################"
ibstatus
}
echo "#################################################################################"
echo "                                                                                 "
echo "                                                                                 "
echo "---------------------------------------------------------------------------------"
#Diagnostic Reports
_sundiag_report()
{
while true
  do
  read -p "Do you want to run sundiag report on all cellnodes: Y/N?" I
    case $I in
  [Yy]* ) _log "Running sundiag report! please wait ***"; /usr/local/bin/dcli -g $CG -l root "/opt/oracle.SupportTools/sundiag.sh"; break;;
  [Nn]* ) _log "=====>Exiting Report";  break;;
  * ) echo "Please choose either Yes(Y) or No(N)";;
    esac
  done
}
echo "                                                                                 "

#exacheck version
_exa_chk_version(){
_log "Please verify if you have the latest exachk utility version from MOS"
echo "#################################################################################"
echo "                                                                                 "
/opt/oracle.ahf/exachk -v
echo "                                                                                 "
echo "#################################################################################"
}
_exa_chk()
{
echo "Do want to run exa_chk report? Choose 1 or 2"
select I in "Yes" "No"
  do
    case $I in
  Yes ) _log "Running exachk report! please wait ***";/opt/oracle.ahf/exachk; break;;
  No ) _log "=====>Exiting Report";  break;;
    esac
  done
}
echo "                                                                                 "
echo "                                                                                 "

#if you face error you can login to any of the nodes
_host_logon()
{
echo '***Do you login to any host? Choose a valid option!***'
hosts=("exacel01" "exacel02" "exacel03" "exacel04" "exasw-ibb01" "exasw-iba01" "Exit")
select h in "${hosts[@]}";do
 case $h in
 "exacel01")
  ssh exacel01
  ;;
 "exacel02")
  ssh exacel02
  ;;
 "exacel03")
  ssh exacel03
  ;;
 "exacel04")
  ssh exacel04
  ;;
 "exasw-ibb01")
  ssh exasw-ibb01
  ;;
 "exasw-iba01")
  ssh exasw-iba01
  ;;
 "Exit")
  _log "=====>End of script"; break
  ;;
*) echo "Enter correct hostname";;
 esac
done
}
echo "                                                                                 "
echo "                                                                                 "
_other_stats()
{
_log "Fan status"
echo "---------------------------------------------------------------------------------"
echo "                                                                                 "
/usr/local/bin/dcli -g $CG -l root "    hostname;echo "-----------------------";cellcli -e "list cell detail"|egrep fan"|awk '{$1="";print}'
echo "---------------------------------------------------------------------------------"
_log "Power status"
echo "---------------------------------------------------------------------------------"
echo "                                                                                 "
/usr/local/bin/dcli -g $CG -l root "    hostname;echo "-----------------------";cellcli -e "list cell detail"|egrep power"|awk '{$1="";print}'
echo "---------------------------------------------------------------------------------"
_log "makeModel of cell"
echo "                                                                                 "
echo "---------------------------------------------------------------------------------"

/usr/local/bin/dcli -g $CG -l root "    hostname;echo "-----------------------";cellcli -e "list cell detail"|egrep makeModel"|awk '{$1="";print}'
echo "---------------------------------------------------------------------------------"
echo "                                                                                 "
}

echo "                                                                                 "
echo "---------------------------------------------------------------------------------"

_imagehistory_info()
{
_log "Imagehistory details will be dumped to $IH file"
/usr/local/bin/dcli -g $DG -l root "hostname;echo "-----------------------";imagehistory -all"|awk '{$1="";print}'
/usr/local/bin/dcli -g $CG -l root "hostname;echo "-----------------------";imagehistory -all"|awk '{$1="";print}'
}

_title
_env
_verify_user
_file_check
_cell_monitor
_cell_error_check
_hard_disk_check
_flash_disk_check
_ib_port_check
_ib_status
_other_stats
_imagehistory_info > $IH
_sundiag_report
_exa_chk
_host_logon
