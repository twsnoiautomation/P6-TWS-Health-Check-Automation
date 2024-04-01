#!/bin/sh
#   script: tws_inst_pull_info.sh
# function: Will extract TWS instance information that can be used to resolve a TWS issue.
#  version: 9
# revision: 5
# 08/22/2012
#  Updates:
#  Updated: 01/27/09 Updated USAGE variable.
#  Updated: 01/22/09 Pulling of the /etc/hosts file
#  Updated: 01/22/09 Pulling of the nsswitch/netsvc files
#  Updated: 01/22/09 Pulling of the "zonecfg list" if OS is Solaris
#  Updated: 01/22/09 Copy of previous days schedlog
#  Updated: 02/06/09 Changed display listing syntax for appserver listing
#  Updated: 02/06/09 Added new variables that will be used to create directories for data pulled.
#  Updated: 02/09/09 Added -date option. This is used to specify date to use for data pulls.
#  Updated: 02/10/09 Added checking of entered date value.
#  Updated: 02/11/09 Changed format of data pulled file to include date of data pulled.
#  Updated: 03/11/09 Added checking for existence of WAS directory and included new variable
#                    to pull data based on path of TWS WAS directory.
#  Updated: 04/22/09 Added text file that has name of local cpu and TWSuser. Added EWas_server_name
#                    variable.
#  Change WAS pull so that duplicate logs are not copied.
#  store errors to a variable.
#  Updated: 09/23/09 Removed tar packaging technique for WebSphere logs
#            Added pull of <TWSHome>/stdlist/<DATE> files
#  Updated: 11/17/09 Fixed HOME discovery grep command to differentiate TWS and CLI instances
#  Updated: 01/11/10 Changed gather criteria for archived Symphony files to match all current
#                    and previous day's dates
#  Updated: 02/08/10 Added version 8.5.1 and test for eWAS files for 8.5.1
#            Modify user search in /etc/passwd to allow for NIS user format
#            Discover WebSphere server name using wsadmin.sh
#            Gather ssm and monconf information
#            Gather event rule definitions
#            Copy /etc/TWA
#            Gather more OS information
#            Grouped script into functions
#            Discover and gather for standalone TDWC
#  Update: 2/10/10   Added new options:
#           -outdir <path>  \\Option to specify output to directory other than /tmp
#           -nodbdefs       \\ Supress composer create commands
#           -debug      \\ set -xv for all functions. Use: > debug.out 2>&1
#                Updated USAGE
#  Update: 2/11/10   Gather all install logs
#                    Perform space available test before creating tar file
#            Perform space avaliable test for msg files
#            Perform space avaliable test for WAS files
#  Update: 2/12/10   Include tws_user's ulimit -a output
#
#  Update: 7/5/2012  Gather EIF files
#
#  Update: 7/18/2012 Added new option:
#           -twsdir <path>  \\Override automatic TWSHOME discovery.
#  Update: 7/18/2012 Version 3_8
#  Update: 9/27/2012 Added support for TWS 8.6.0
#  Update: 9/27/2012 Added section for TIP specific pull
#  Update: 2/8/2013 Resolved 3 issues: r3batch PL hang; host IP parse; tar symbolic link length issue.
#  Update: 8/12/2014 Added ability to capture TWS and DWC 9.1+.
#            Added db2 instance and database discovery and basic db2 information commands
#            Added additional system information captures including /etc/pam.d, umask etc.
#            Updated version to 3_9
#  Update 6/18/2015  Added support for TWS 9.3
#            Removed call to r3batch PL
#            Added specificity for space check in TWS/stdlist
#            Corrected call to gather a copy of TWS/version
#            Added date command output.
#            Collecting /etc/environment
#  Update 6/25/2015  Added ps command to AIX system: ps -eo pcpu,pid,args | sort -rk1 | head -6
#  Update 8/14/2015  Added call to deployment engine health check utility for TIP.
#             /usr/ibm/common/acsi/bin/de_healthChecker.sh
# Update 8/26/2015-11/26/2015  Test JazzSM's server.xml for CORBA.ORBServerId port value and compare to ORB_LISTENER_ADDRESS in serverindex.xml
#                    Sample: find $path -name server.xml -exec grep -l "CORBA.ORBServerId" '{}' \; | xargs -I{} grep "CORBA.ORBServerId" {} | sed -e 's/.*CORBA.ORBServerId.*value=\"\(.*\)\".*/\1/'
#            If CORBA.ORBServerId in server.xml does not match ORB_LISTENER_ADDRESS port in serverindex.xml then DWC to TWS connection fails.
# Update 9/16/2015  Gather file listing from TWS/..
# Update 9/16/2015  Gather <TWSHOME>/twsinst* files and dirs
#  Update 11/4/2015  Modified calc test to include test for file or dir and fixed TDWB directory tests esp dbtools - was missing path to test elements.
#  Update 11/25/2015 test WebSphere instances for autoGenerate and populate the PMR Stamp:
# Added - doc link for disable autoGenerate and for export/import ltpa key.
# Update 12/10/2015  Added copy of ${TWS_basePath}/jmJobTableDir
# Update 12/29/2015 - Create TWS_INSTALL_LOG directory to send /var/ibm/InstallationManager files.
# Update 1/11/2016 - Added test in set_was_vars for TDWC in registry file if TDWC_version is 0 after failing to set the version.
# Update 2/4/2016 - Added composer list vt and composer di vt.
# Update 2/9/2016 - Added lssrc -a for AIX system information.
# Update 12/27/2016  Added support for TWS 9.4
# Update 5/19/2017 Adding composer calls for new object types RUNCYCLEGROUP,WAT,SECURITYDOMAIN,SECURITYROLE,ACCESSCONTROLLIST #WAT is Workload Automation Template
# Update 5/19/2017 Disable most TIP/DASH must gather scripts.
# Update 6/26/2017 Fix some output errors defect 179471.


TWS_SCRIPT="$0"; export TWS_SCRIPT
INDENT="    "
USAGE_0="$0 -twsuser <tws_user_id> [-twsdir <path>] [-date <yyyymmdd>][-outdir <path> | -log_dir_base <path>][-extract_db_defs][-debug][-u]\n"
USAGE_twsuser="${INDENT}-twsuser The TWS user specified when TWS was installed. This user must exist in the /etc/TWS/TWSregistry.dat file if an existing TWS instance.\n"
#This parameter is mandatory.
USAGE_log_dir_base="${INDENT}-outdir|-log_dir_base The base directory location for directories that will store gathered information.\n"
#This parameter is mandatory.
USAGE_extract_db_defs="${INDENT}-extract_db_defs y | n If 'y' database definitions will be extracted , if workstation is a master. (Optional, default y).\n"

USAGE_date1="${INDENT}-date yyyymmdd. Date that will be used to base date for gathered data logs.\n" 
USAGE_date2="${INDENT}${INDENT}The tws_inst_pull_info script should be executed as soon as an issue occurs.\n"
USAGE_date3="${INDENT}${INDENT}This is necessary to gather data that is specific to time frame of issue date.\n"
USAGE_date4="${INDENT}${INDENT}If issue was encountered on the current date this option is not required.\n"
USAGE_date5="${INDENT}${INDENT}If issue occurred on a previous day then the date issue occurred must be specified in yyyymmdd format.\n" 
USAGE_date6="${INDENT}${INDENT}Either the current date or specified date will be used to identify files and logs script will be extracted.\n"
USAGE_date7="${INDENT}${INDENT}(Optional, default current date).\n"
USAGE_date=${USAGE_date1}${USAGE_date2}${USAGE_date3}${USAGE_date4}${USAGE_date5}${USAGE_date6}${USAGE_date7}

USAGE_twsdir="${INDENT}-twsdir path that ends with TWS and contain tws_env.sh. (Optional, default read in /etc/TWS/TWSRegistry.dat)\n"
USAGE_twsdir_ex1="${INDENT}${INDENT}*Example1: -twsdir <inst_dir>/TWS.\n"
USAGE_debug="${INDENT}-debug Use this option for debugging.\n"
USAGE_usage="${INDENT}-u Use this option for printing this usage message.\n"
USAGE=${USAGE_0}${USAGE_twsuser}${USAGE_twsdir}${USAGE_twsdir_ex1}${USAGE_date}${USAGE_log_dir_base}${USAGE_extract_db_defs}${USAGE_debug}${USAGE_usage}

REQUIREMENT="The ${TWS_SCRIPT} script must be executed by root or the TWS user for which the TWS instance was installed and a Symphony file must exist to gather complete information.\n";export REQUIREMENT
GENERAL_INFO="The ${TWS_SCRIPT} script will gather specific TWS instance information.  If TWS instance is a master TWS objects will be extracted to flat files by default.  To disable use the -nodbdefs flag.\n";export GENERAL_INFO

#Known issue: On Solaris, the files copied may not retain the original ownership.

#Added 06/27/08 PSJ
#Added checking for OS
os_test()
{
        #*****DO NOT MODIFY********
        # Checks for valid OS
        OS=`uname`;export OS
        case $OS in
                AIX)
                OS="AIX";export OS
                ;;
                HP-UX)
                OS="HPUX";export OS
                ;;
                Linux)
                OS="LINUX_I386";export OS
                ;;
                SunOS)
                OS="SOLARIS";export OS
                ;;
                *)
                echo "Error: Invalid OS"
                echo "Utility will only work on AIX, HPUX Linux, or Solaris"
                echo "Unable to continue with ${TWS_SCRIPT}, exiting"
                exit 1
        esac
} #End os_test

set_default_vars()
{
        #               CUSTOMIZABLE VARIABLES
        TMP_DIR="/tmp";export TMP_DIR
        DEBUG="n";export DEBUG
        tws_home_specified="n";export tws_home_specified
    PATH=$PATH:/usr/sbin;export PATH
        #Determines if database objects should be extracted to files using composer.
        extract_db_defs="y";export extract_db_defs

        #               NON-Customiziable Variables
        #Location of TWSRegistry.dat file
        TWS_REGISTRY_PATH="/etc/TWS";export TWS_REGISTRY_PATH
        TWA_REGISTRY_PATH="/etc/TWA";export TWA_REGISTRY_PATH
        #Added variable MAESTROLINES to prevent prompting for TWS output more that 24 lines
        MAESTROLINES=-1;export MAESTROLINES
        #MKD 4.28.09 Added variable MAESTRO_OUTPUT_STYLE=LONG to allow full object names to be displayed
        MAESTRO_OUTPUT_STYLE=LONG;export MAESTRO_OUTPUT_STYLE
        #Added 02/09/09 PSJ
        ORIG_SYNTAX="$0 $*";export ORIG_SYNTAX
        date_opt_used="n";export date_opt_used

        #Added 10/11/2010 MKD - default value for tws_user_is_valid
        #..necessary if /etc/TWS/TWSRegistry.dat cannot be read and tws_user is local
        tws_user_is_valid="n";export tws_user_is_valid

        #Added/Updated 03/05/09 PSJ
        #Added EXEC_USER and base_date variables and updated tws_user to be blank

        if [ "${OS}" = "SOLARIS" ]
        then
                EXEC_USER=`/usr/ucb/whoami`;export EXEC_USER
        else
                EXEC_USER=`whoami`;export EXEC_USER
        fi

        base_date="N/A"
        TWS_version=0;export TWS_version
        TWS_VERSION_EXTRACTED_FROM="";export TWS_VERSION_EXTRACTED_FROM
        TWS_HOME_EXTRACTED_FROM="";export TWS_HOME_EXTRACTED_FROM

        #               Message Variables
        MAIN_ERR_MSG="";export MAIN_ER_MSG #This variable will include a composite of additional error messsages.
        ERR_MESG="";export ERR_MESG
        WARN_SPECIFIED_USER="";export WARN_SPECIFIED_USER
	    required_size=0
	    TDWC_version=0; export TDWC_version
	    TDWC_basePath=""; export TDWC_basePath
	    WLP_DIR=NULL; export WAS_DIR
} #End set_default_vars

test_temporary_directory()
{
    if [ "${DEBUG}" = "y" ]; then set -xv; fi

    if [ -d ${TMP_DIR} ]
    then
        log_dir_base="${TMP_DIR}/tws_info";export log_dir_base

        if [ -d ${log_dir_base} ]
        then
            if [ ! -w "${log_dir_base}" ]
            then
                echo ""
                echo "${EXEC_USER} cannot write to directory ${log_dir_base}."
                echo ""
                echo "Please change the mode of ${log_dir_base} to rwx for ${EXEC_USER}."
                echo "- or -"
                echo "Specify a directory to which ${EXEC_USER} can write using the option: -outdir <path>"
                echo ""
                echo "USAGE: ${USAGE}"
                exit 1
            fi
        fi
    else
#       echo "The ${TMP_DIR} does not exist, ${TWS_SCRIPT} script attempt to create ${TMP_DIR}"
        mkdir -p ${TMP_DIR}
        RETVAL=$?
        if [ "${RETVAL}" != "0" ]
        then
            echo "Create ${TMP_DIR} directory and rerun ${TWS_SCRIPT} script."
            exit ${RETVAL}
        fi
    fi
    WORKING_DIR=`pwd`; export WORKING_DIR
    TMP_DIR=`cd ${TMP_DIR};pwd` export TMP_DIR
    cd ${WORKING_DIR}

} # End test_temporary_directory

parse_args()
{
    if [ "${DEBUG}" = "y" ]; then set -vx; fi
        #Determine if -date option was specified. If -date is specified a date must follow the opiton
    #It does not check that specified date is valid. If -date option is not specified it will
    #continue with normal operations.

    while [ $# -gt 0 ]
    do
        CPARM01=$1;export CPARM01
    shift

    case $CPARM01 in
        -twsuser)
            if [ $# -eq 0 ] || [ "`echo $1 | cut -c1`" = "-" ]
            then
                echo ""
                echo "Error: Invalid -twsuser option, specify -twsuser <tws_user_id>."
                RETVAL=1;export RETVAL
                exit ${RETVAL}
            fi
            tws_user=$1;export tws_user
            shift
        ;;


        -date)
            if [ $# -eq 0 ] || [ "`echo $1 | cut -c1`" = "-" ]
            then
                echo ""
                echo "Error: Invalid -date option, specify -date <yyyymmdd>."
                RETVAL=1;export RETVAL
                exit ${RETVAL}
            fi
            date_opt_used="y"
            pull_date=$1;export pull_date
            echo ${pull_date}|cut -c8|grep "[0-9]" > /dev/null 2>&1
                RETVAL=$?
                if [ "${RETVAL}" != "0" ]
                then
                echo ""
                        echo "Error: Invalid -date option, specify -date <yyyymmdd>."
                RETVAL=1;export RETVAL
                        exit ${RETVAL}
                fi
            shift
        ;;

        -outdir|-log_dir_base)
            if [ $# -eq 0 ] || [ "`echo $1 | cut -c1`" = "-" ]
            then
                #echo "\nError: Invalid -outdir option, specify -outdir <path>."
                echo ""
                echo "Error: Invalid $CPARM01 option, specify $CPARM01 <path>."
                RETVAL=1;export RETVAL
                exit ${RETVAL}
            fi
            TMP_DIR=$1;export TMP_DIR
            test_temporary_directory
        ;;

        -debug)
            DEBUG="y";export DEBUG
        ;;

        -extract_db_defs)
            if [ $# -eq 0 ] || [ "`echo $1 | cut -c1`" = "-" ]
            then
                 echo ""
                echo "Error: Invalid $CPARM01 option, specify $CPARM01 y | n."
                RETVAL=1;export RETVAL
                exit ${RETVAL}
            fi
            extract_db_defs=$1
        ;;

        -u)
            echo "USAGE: $USAGE"
            exit 0
        ;;

        -twsdir)
            if [ $# -eq 0 ] || [ "`echo $1 | cut -c1`" = "-" ]
            then
                echo ""
                echo "Error: Invalid $CPARM01 option, specify $CPARM01 <path>."
                RETVAL=1;export RETVAL
                exit ${RETVAL}
            fi
            tws_home_specified="y";export tws_home_specified
            TWS_REG_FILE=NULL;export TWS_REG_FILE
            TWA_REG_FILE=NULL; export TWA_REG_FILE
            WLP_DIR=NULL
            TWS_basePath=`echo $1 |sed 's/\(.*\)\/$/\1/g'`;export TWS_basePath
            TWA_path=`echo ${TWS_basePath} | sed "s/\/[^\/]*$//"`; export TWA_path
            TWS_HOME_EXTRACTED_FROM="INPUT"; export TWS_HOME_EXTRACTED_FROM
            TWS_basePath_dirName=`echo ${TWS_basePath} |sed 's/\(.*\)\/$/\1/g'| awk -F\/ '{print $NF}'`;export TWS_basePath_dirName
            if [ ! -d ${TWS_basePath} ]
            then
                echo "The directory specified for -twsdir, ${TWS_basePath}, does not exist."
                echo "${USAGE}"
                exit 1
            else
                if [ "${TWS_basePath_dirName}" = "TWS" ] && [ -f ${TWS_basePath}/tws_env.sh ]
                then
                    echo "Valid directory name for -twsdir specified ${TWS_basePath_dirName}"
                else
                    echo ""
                            echo "Error: Non TWS path specified: ${TWS_basePath}"
                    echo ""
                            echo "***Note: -twsdir path must end with TWS and must contain tws_env.sh"
                            echo "*Example1: -twsdir ${TWS_basePath}/TWS"
                            echo "*Example2: -twsdir /opt/IBM/TWA/TWS"
                    exit 1
                fi

            fi
    esac
    done

    if [ "$tws_user" = "" ]
    then
        echo "The -twsuser option is required."
        echo "USAGE: $USAGE"
        exit 1
    fi

} # End parse_args

set_output_vars()
{
    if [ "${DEBUG}" = "y" ]; then set -xv; fi

    local_cpu=`uname -n`;export local_cpu

    #Directory names to be used for storing pulled data.
    WLPINFO_DIR="wlp_info";export WLPINFO_DIR
    SYSINFO_DIR="system_info";export SYSINFO_DIR
    TWSINFO_DIR="TWS_Engine";export TWSINFO_DIR
    TWSMSG_DIR="tws_msg_files";export TWSMSG_DIR
    TWSMTHD_DIR="tws_methods";export TWSMTHD_DIR
    TWSLOGS_DIR="$TWSINFO_DIR/tws_logs";export TWSLOGS_DIR
    STDLIST_DIR="$TWSLOGS_DIR/stdlist";export STDLIST_DIR
    STDLISTLOGS_DIR="$TWSLOGS_DIR/stdlist/logs";export STDLISTLOGS_DIR
    STDLISTTRC_DIR="$TWSLOGS_DIR/stdlist/traces";export STDLISTTRC_DIR
    STDLISTAPPSRV_DIR="$TWSLOGS_DIR/stdlist/appserver";export STDLISTAPPSRV_DIR
    TWS_XTRACE_DIR="$TWSLOGS_DIR/xtrace_files"
    DB2INFO_DIR="db2_info";export DB2INFO_DIR
    EVENT_DIR="event_info";export EVENT_DIR
    TDWC_DIR="tdwc_info";export TDWC_DIR
    TWS_INSTALL_LOGS="install_logs"; export TWS_INSTALL_LOGS

    # Location base for directories for gathered information
    # MKD 1.09.13 moved the log_dir_base variable setting to begining of script.
    #   log_dir_base="${TMP_DIR}/tws_info";export log_dir_base
        CREATED_DATE_TIME=`date +%Y%m%d_%H%M%S`;export CREATED_DATE_TIME

    # log_dir_curr Location of directory where all new sub directories are written
        log_dir_curr="${log_dir_base}/TWS_${CREATED_DATE_TIME}";export log_dir_curr
        mkdir -p ${log_dir_curr}
        if [ ! -d ${log_dir_curr} ]
        then
            echo "FAILED to create ${log_dir_curr}."
            echo "Consider specifying a directory to which the user `whoami` can write"
            echo "For example:  -outdir /tmp/`whoami`_tmp"
            echo "USAGE: $USAGE"
            exit 1
        fi

    # MKD 4.29.09 added summary log to reduce echo to stdout
        summary_log="${log_dir_curr}/datagather_summary.log";export summary_log
        touch $summary_log
} # End set_output_vars

exec_user_test()
{
    if [ "${DEBUG}" = "y" ]; then set -xv; fi
    if [ "${EXEC_USER}" != "${tws_user}" ]
    then
        #Added 03/05/09 PSJ
        # Script may be executed by root or TWS user. Some scripts cannot be run by TWSUser
        if [ ${EXEC_USER} = root ]
        then
            echo "Script executed by root." >> $summary_log
            echo "Original syntax is ${ORIG_SYNTAX}" >> $summary_log
        else
            echo "Script was executed by ${EXEC_USER}." >> $summary_log
            echo "Original syntax is ${ORIG_SYNTAX}" >> $summary_log
            WARN_SPECIFIED_USER="**Warning: Executed by ${EXEC_USER}, but TWSuser is ${tws_user}. Expect errors and incomplete data.";export WARN_SPECIFIED_USER
                echo ""
                echo "${WARN_SPECIFIED_USER}" | tee -a $summary_log
                echo ""
                MAIN_ERR_MSG="${MAIN_ERR_MSG}\n${WARN_SPECIFIED_USER}"
        fi
    else
        echo "Script executed by ${EXEC_USER} and -twsuser option are same ${tws_user}." >> $summary_log
        echo "Original syntax is ${ORIG_SYNTAX}" >> $summary_log
    fi

    if [ "${DEBUG}" = "y" ]
    then
        echo "Original syntax is ${ORIG_SYNTAX}" | tee -a $summary_log
        echo "EXEC_USER is ${EXEC_USER}" | tee -a $summary_log
        echo "tws_user is ${tws_user}" | tee -a $summary_log
        echo "pull_date is ${pull_date}" | tee -a $summary_log
    fi
} # End exec_user_test

specify_home()
{
    if [ "${DEBUG}" = "y" ]; then set -vx; fi
    if [ -f ${TWS_basePath}/tws_env.sh ]
    then
        echo "Will attempt to invoke TWS environment." >> $summary_log
        . ${TWS_basePath}/tws_env.sh >> $summary_log
        TWS_datadir=$UNISONWORK; export TWS_datadir
    fi

    #MKD 4.30.09 setting $HOME to $tws_user's $HOME for access to $HOME/.TWS/useropts_$tws_user
    tws_user_home=`sed 's/^+//' /etc/passwd | grep "^${tws_user}:" | awk -F: '{print $6}'`;export tws_user_home

    if [ "${tws_user_home}" != "" ]
    then
        if [ -d ${tws_user_home} ]
        then
            HOME=$tws_user_home;export HOME
        fi
    fi
} # End specify_home

tws_user_test()
{
    if [ "${DEBUG}" = "y" ]; then set -xv; fi


    grep "/${tws_user}_DN" /etc/TWS/TWSRegistry.dat > /dev/null 2>&1
    TWSRC=$?
#/etc/TWA/twainstance1.TWA.properties:DWC_user_name=m95_dwc
    egrep "TWS_user_name=${tws_user}$|DWC_user_name=${tws_user}$" /etc/TWA/*.properties > /dev/null 2>&1
    TWARC=$?

    if [ ${TWSRC} -eq 0 ]
    then
            TWS_REG_FILE=`grep -l "/${tws_user}_DN" /etc/TWS/TWSRegistry.dat`; export TWS_REG_FILE
            TWS_basePath=`grep "\/Tivoli\/Workload_Scheduler\/${tws_user}_DN_InstallationPath" ${TWS_REG_FILE} | cut -f2 -d "="`;export TWS_basePath
      		TWS_basePath_dirName=`echo ${TWS_basePath} |sed 's/\(.*\)\/$/\1/g'| awk -F\/ '{print $NF}'`;export TWS_basePath_dirName
            TWS_version=`grep "\/Tivoli\/Workload_Scheduler\/${tws_user}_DN_PackageName" ${TWS_REG_FILE} | awk -F. '{print $2$3$4}'`; export TWS_version
            TWS_instance_type=`grep "/${tws_user}_DN_Agent" ${TWS_REG_FILE} | awk -F= '{print $2}' 2>/dev/null`;export TWS_intance_type
            if [ `echo ${TWS_version} | wc -c` -gt 1 ]
            then
	            if [ ${TWS_version} -gt 840 ]
	            then
	                        TWA_path=`echo ${TWS_basePath} | sed "s/\/[^\/]*$//"`;export TWA_path
	            fi
            fi
    else
        TWS_REG_FILE=NULL; export TWS_REG_FILE
    fi

    if [ ${TWARC} -eq 0 ]
    then
            TWA_REG_FILE=`egrep -l "TWS_user_name=${tws_user}$|DWC_user_name=${tws_user}$" /etc/TWA/*.properties`
            TWS_basePath=`grep "TWS_basePath=" ${TWA_REG_FILE} | awk -F= '{print $2}' 2>>$summary_log`; export TWS_basePath
	        TWS_basePath_dirName=`echo ${TWS_basePath} |sed 's/\(.*\)\/$/\1/g'| awk -F\/ '{print $NF}'`;export TWS_basePath_dirName
            TWA_path=`grep "TWA_path=" ${TWA_REG_FILE} | awk -F= '{print $2}' 2>>$summary_log`; export TWA_path
            TWS_version=`grep "TWS_version=" ${TWA_REG_FILE} | awk -F= '{print $2}' 2>>$summary_log`; export TWS_version
            TWS_version=`echo $TWS_version | awk -F\. '{print $1$2$3}'`;export TWS_version
            TWS_instance_type=`grep "TWS_instance_type=" ${TWA_REG_FILE} | awk -F= '{print $2}' 2>>$summary_log`; export TWS_instance_type
            TWA_componentList=`grep "TWA_componentList=" ${TWA_REG_FILE} | awk -F= '{print $2}' 2>>$summary_log`; export TWA_componentList
            TWS_datadir=`grep "TWS_datadir=" ${TWA_REG_FILE} | awk -F= '{print $2}' 2>>$summary_log`; export TWS_datadir
            TWS_wlpdir=`grep "TWS_wlpdir=" ${TWA_REG_FILE} | awk -F= '{print $2}' 2>>$summary_log`; export TWS_wlpdir
            TWS_jdbcdir=`grep "TWS_jdbcdir=" ${TWA_REG_FILE} | awk -F= '{print $2}' 2>>$summary_log`; export TWS_jdbcdir
#/etc/TWA/twainstance1.TWA.properties:DWC_user_name=m95_dwc
DWC_user_name=`grep "DWC_user_name=${tws_user}$" ${TWA_REG_FILE} | awk -F= '{print $2}' 2>>$summary_log`; export DWC_user_name    
#TWA_path=/opt/HWS/95/dwc
#TWA_componentList=DWC
#DWC_version=9.5.0.01
#DWC_counter=1
#DWC_instance_type=DWC
#DWC_basePath=/opt/HWS/95/dwc
DWC_basePath=`grep "DWC_basePath=" ${TWA_REG_FILE} | awk -F= '{print $2}' 2>>$summary_log`; export DWC_basePath
#DWC_user_name=m95_dwc
#DWC_wlpdir=/opt/HWS/95/wlp
DWC_wlpdir=`grep "DWC_wlpdir=" ${TWA_REG_FILE} | awk -F= '{print $2}' 2>>$summary_log`; export DWC_wlpdir
#DWC_datadir=/opt/HWS/95/dwc/DWC_DATA
DWC_datadir=`grep "DWC_datadir=" ${TWA_REG_FILE} | awk -F= '{print $2}' 2>>$summary_log`; export DWC_datadir
#DWC_jdbcdir=/opt/HWS/95/dwc/jdbcdrivers/db2	
DWC_jdbcdir=`grep "DWC_jdbcdir=" ${TWA_REG_FILE} | awk -F= '{print $2}' 2>>$summary_log`; export DWC_jdbcdir
    else
            TWA_REG_FILE=NULL; export TWA_REG_FILE
    fi

    if [ ${TWSRC} -ne 0 ] && [ ${TWARC} -ne 0 ]
    then
        echo "**User $tws_user not found in /etc/TWS/TWSRegistry.dat nor any /etc/TWA/*.properties file."
        echo " "
        echo "If you know that $tws_user is correct try using: -twsdir <tws_path> "
        echo "*Note: For -twsdir the <tws_path> must be the full path to the TWS or TDWC directory."
        echo "*Example1: -twsdir /opt/wa/DWC"
        echo "*Example2: -twsdir /opt/wa/server/TWS"
        echo "*Example8.4: /opt/wa (where the file /opt/wa/tws_env.sh exists)"
        echo ""
        if [ -f /etc/TWS/TWSRegistry.dat ]
        then
            echo "Users found in /etc/TWS/TWSRegistry.dat:"
            for user in `grep _DN_ou= /etc/TWS/TWSRegistry.dat | awk -F= '{print $2}'`
            do
                echo "  $user"
            done
        fi
        if [ `ls /etc/TWA/twainstance*.TWA.properties 2>/dev/null | wc -l` -ge 1 ]
        then
            echo "Users found in /etc/TWA/*properties files:"
            echo "  TWS_user_name:"
            for user in `egrep "TWS_user_name=|DWC_user_name" /etc/TWA/*properties | awk -F= '{print $2}'`
            do
                echo "      $user"
            done
            echo "  EWas_user:"
            for user in `grep EWas_user= /etc/TWA/*properties | awk -F= '{print $2}'`
            do
                echo "      $user"
            done
        else
            echo "/etc/TWA/twainstance*.properties files missing or inaccessible." >> $summary_log
        fi
        exit 1
    fi
} # End tws_user_test

locate_home()
{
    if [ "${DEBUG}" = "y" ]; then set -vx; fi

    if [ -f ${TWS_basePath}/tws_env.sh ]
    then
        echo "Will attempt to invoke TWS environment." >> $summary_log
        . ${TWS_basePath}/tws_env.sh >> $summary_log
    fi

    #MKD 4.30.09 setting $HOME to $tws_user's $HOME for access to $HOME/.TWS/useropts_$tws_user
    tws_user_home=`sed 's/^+//' /etc/passwd | grep "^${tws_user}:" | awk -F: '{print $6}'`;export tws_user_home
    if [ "${tws_user_home}" != "" ]
    then
        if [ -d ${tws_user_home} ]
        then
            HOME=$tws_user_home;export HOME
        fi
    fi

} # End locate_home

set_was_vars()
{
    if [ "${DEBUG}" = "y" ]; then set -xv; fi
    
    if [ -d "${TWS_basePath}" ] && [ -d "${TWS_basePath}/usr" ]; then
    	WLP_DIR=${TWS_basePath}/usr; export WLP_DIR
    elif [ -d "${DWC_basePath}" ] && [ -d "${DWC_basePath}/usr" ]; then
	WLP_DIR=${DWC_basePath}/usr; export WLP_DIR
    fi
    if [ -d "${TWS_basePath}/../usr" ] && [ -d "${TWS_basePath}" ]; then
    	WLP_DIR=${TWS_basePath}/../usr; export WLP_DIR
    elif [ -d "${DWC_basePath}/../usr" ] && [ -d "${DWC_basePath}" ]; then
        WLP_DIR=${DWC_basePath}/../usr; export WLP_DIR
    fi

    if [ -d "${TWS_datadir}/stdlist/appserver" ]; then
   	WLP_LOGDIR=${TWS_datadir}/stdlist/appserver; export WLP_LOGDIR
    elif [ -d "${DWC_datadir}/stdlist/appserver" ]; then
        WLP_LOGDIR=${DWC_datadir}/stdlist/appserver; export WLP_LOGDIR
    fi
    if [ -d ${WLP_DIR} ]
    then
        WLP_DIR_exists="y";export WLP_DIR_exists
    fi
    echo "WLP_DIR path is ${WLP_DIR}." >> $summary_log
    echo "WLP_LOGDIR is ${WLP_LOGDIR}." >> $summary_log
} # End set_was_vars

#***** Start Util Functions *****

split_date()
{

if [ "${DEBUG}" = "y" ]; then set -vx; fi

    year=`echo ${base_date}|cut -c1-4`;export year
    month=`echo ${base_date}|cut -c5-6`;export month
    day=`echo ${base_date}|cut -c7-8`;export day

} # End split_date

cal_day_minus()
{

    if [ "${DEBUG}" = "y" ]; then set -vx; fi

#Calculate today - 1 day
    day=`expr "$day" - 1`
    case "$day" in
             0)
                month=`expr "$month" - 1`
                case "$month" in
                0)
                                month=12
                                year=`expr "$year" - 1`
                ;;
                *)
                #The following will change the day value from one character to two characters.
                if [ ${month} -le 10 ]
                then
                    month="0${month}";export month
                fi
                ;;
            esac
            day=`cal $month $year | grep . | fmt -1 | tail -1`
    esac

    #The following will change the day value from one character to two characters.
    if [ ${day} -le 10 ]
    then
        day="0${day}";export day
    fi

} # End cal_day_minus

cal_day_plus()
{

    if [ "${DEBUG}" = "y" ]; then set -vx; fi

    #Calculate today + 1 day
    day=`expr "$day" + 1`
    eom=`cal $month $year | grep . | fmt -1 | tail -1`
    if [ $day -gt $eom ]
    then
        day=1;export day
        month=`expr ${month} + 1`
        #The following will change the day value from one character to two characters.
        if [ ${month} -le 10 ]
        then
            month="0${month}";export month
        fi
        if [ ${month} -gt 12 ]
        then
            year=`expr ${year} + 1`;export year
            month=01;export month
        fi
    fi
    #The following will change the day value from one character to two characters.
    if [ ${day} -le 10 ]
    then
        day="0${day}";export day
    fi
} # End cal_day_plus


#Added 03/13/09 PSJ
#Added module to calculate source disk usage and available $(TMP_DIR} disk space

calc_disk_space_usage_and_avail()
{
    if [ "${DEBUG}" = "y" ]; then set -vx; fi

    if [ -e "${source_item}" ]
    then
        ENOUGH_SPACE="n";export ENOUGH_SPACE

        #Determine available disk space in ${TMP_DIR}
        if [ "$OS" = "AIX" ]
        then
            avail_space=`df -k ${TMP_DIR}|tail -1|awk '{print $3}'`
        fi

        if [ "$OS" = "HPUX" ]
        then
            avail_space=`bdf ${TMP_DIR}|tail -1|awk '{print $4}'`
        fi

        if [ "$OS" = "SOLARIS" ]
        then
            avail_space=`df -k ${TMP_DIR}|tail -1|awk '{print $4}'`
        fi
        if [ "$OS" = "LINUX_I386" ]
        then
            avail_space=`df -P ${TMP_DIR}|tail -1|awk '{print $4}'`
        fi

        #If required_size is specified then we don't test the size of the source_item
        if [ $required_size -gt 0 ]
        then
            echo "Need to test for $required_size rather than test $source_item." >> $summary_log
            source_item=""
        else
            source_item_size=`du -ks ${source_item} 2>>$summary_log |awk '{print $1}'`
            required_size=`expr \( $source_item_size \* 2 \)`;export required_size
        fi

        if [ ${required_size} -gt ${avail_space} ]
        then
            echo "${source_item} is ${source_item_size}KB, ${TMP_DIR} requires ${required_size}KB free and has ${avail_space}KB." >> $summary_log
            echo "There IS NOT sufficient disk space to include ${source_item}. ${TMP_DIR} requires ${required_size}KB free and has ${avail_space}KB." | tee -a $summary_log
            ERR_MSG="ERROR: \nThere IS NOT sufficient disk space to include ${source_item} in data pull."
            MAIN_ERR_MSG="${MAIN_ERR_MSG}\n${ERR_MSG}"
            ENOUGH_SPACE="n";export ENOUGH_SPACE
        else
            echo "Confirmed available kb in ${TMP_DIR} at ${avail_space} is greater than ${required_size} for ${source_item}" >> $summary_log
            ENOUGH_SPACE="y";export ENOUGH_SPACE
        fi
        required_size=0;export required_size
    fi

} # End calc_disk_space_usage_and_avail


test_for_symphony()
{
    if [ "${DEBUG}" = "y" ]; then set -xv; fi

#Check for existance of Symphony file
    if [ -f ${TWS_datadir}/Symphony ]
    then
        echo "Symphony file exists" >> $summary_log
        TSYM_EXISTS="y";export TSYM_EXISTS

        if [ -r ${TWS_datadir}/Symphony ]
        then
            echo "${TWS_datadir}/Symphony is readable by ${EXEC_USER}" >> $summary_log
            echo "Will extract TWS CPU instance workstation name." >> $summary_log
            tws_cpu=`${TWS_basePath}/bin/conman sc 2>>$summary_log |grep "*"|cut -f1 -d " "`;export tws_cpu
            echo "The TWS CPU instance workstation name is ${tws_cpu}." >> $summary_log

        #Identify TWS version for workstation
            TWS_VERSION=`${TWS_basePath}/bin/cpuinfo ${tws_cpu} 2>>$summary_log |grep "^VERSION:" 2>>$summary_log|cut -f2 -d " " 2>>$summary_log`;export TWS_VERSION
            TWS_VERSION_EXTRACTED_FROM="Symphony";export TWS_VERSION_EXTRACTED_FROM

        #Determines if TWS workstation is a master.
            CPU_TYPE=`${TWS_basePath}/bin/conman sc 2>>$summary_log | grep "*" | awk '{print $4}'`  >> $summary_log 2>&1
            export CPU_TYPE
        else
            echo "${TWS_datadir}/Symphony cannot be read by ${EXEC_USER}. Information gathered will be incomplete." | tee -a $summary_log
            ERR_MESG="Warning: Symphony could not be opened. Information gathered will be incomplete.";export ERR_MESG
            MAIN_ERR_MSG="${MAIN_ERR_MSG}\n${ERR_MESG}"
            TSYM_EXISTS="n"
        fi
    else
        echo "Symphony file is NOT in ${TWS_datadir} or cannot be opened by ${EXEC_USER}." | tee -a $summary_log
        echo ""
        ERR_MESG="Warning: Symphony file DID NOT exist, a complete list of files may not have been extracted.";export ERR_MESG
        MAIN_ERR_MSG="${MAIN_ERR_MSG}\n${ERR_MESG}"
        TSYM_EXISTS="n"
    fi
} # End test_for_symphony


date_calculations()
{
    if [ "${DEBUG}" = "y" ]; then set -xv; fi

#Calculates values for variables if the date opion is used.
if [ "${date_opt_used}" = "y" ]
then
    echo "This area applies if the -date option is used." >> $summary_log
    if [ -f ${TWS_basePath}/bin/datecalc ] && [ "${TWS_basePath}" != "" ]
    then
        echo "This area applies if TWSHome/bin/datecalc exists." >> $summary_log
        today=`${TWS_basePath}/bin/datecalc ${pull_date} pic yyyymmdd`;export today
        today2=`${TWS_basePath}/bin/datecalc ${pull_date} pic yyyy.mm.dd`;export today2
        today_plus=`${TWS_basePath}/bin/datecalc ${pull_date} +1 day pic yyyymmdd`;export today_plus
        yesterday=`${TWS_basePath}/bin/datecalc ${pull_date} -1 day pic yyyymmdd`;export yesterday
        yesterday2=`${TWS_basePath}/bin/datecalc ${pull_date} -1 day pic yyyy.mm.dd`;export yesterday2

        LOGNAME_UC=`echo ${LOGNAME}|tr "[:lower:]" "[:upper:]"`;export LOGNAME_UC
    else
        echo "This area does date calculations when TWSHome/bin/datecalc does not exist." >> $summary_log
        #Calculate pull date
        base_date="${pull_date}";export base_date
        split_date
        today="${year}${month}${day}";export today
        today2="${year}.${month}.${day}";export today2
        #Calculates pullday +1 day, call cal_day_minus()
        base_date="${pull_date}";export today
        split_date
        cal_day_plus
        today_plus="${year}${month}${day}";export today_plus

        #Calculates pullday -1 day, call cal_day_minus()
        base_date="${pull_date}";export today
        split_date
        cal_day_minus
        yesterday="${year}${month}${day}";export yesterday
        yesterday2="${year}.${month}.${day}";export yesterday2

        LOGNAME_UC=`echo ${LOGNAME}|tr "[:lower:]" "[:upper:]"`;export LOGNAME_UC
    fi
else
    echo "This area applies if the -date option is not used." >> $summary_log
    if [ -f ${TWS_basePath}/bin/datecalc ] && [ "${TWS_basePath}" != "" ]
    then
        echo "This area applies if TWSHome/bin/datecalc exists." >> $summary_log
        today=`${TWS_basePath}/bin/datecalc today pic yyyymmdd`;export today
        today2=`${TWS_basePath}/bin/datecalc today pic yyyy.mm.dd`;export today2
        yesterday=`${TWS_basePath}/bin/datecalc today -1 day pic yyyymmdd`;export yesterday
        yesterday2=`${TWS_basePath}/bin/datecalc today -1 day pic yyyy.mm.dd`;export yesterday2
        base_date="${today}";export base_date
        LOGNAME_UC=`echo ${LOGNAME}|tr "[:lower:]" "[:upper:]"`;export LOGNAME_UC
    else
        echo "This area does date calculations when TWSHome/bin/datecalc does not exist." >> $summary_log
        #Calculate current date
        base_date=`date "+%Y%m%d"`;export base_date
        split_date
        today="${year}${month}${day}";export today
        today2="${year}.${month}.${day}";export today2

        #Calculate today -1 day, call cal_day_minus()
        base_date=`date "+%Y%m%d"`;export today
        split_date
        cal_day_minus
        yesterday="${year}${month}${day}";export yesterday
        yesterday2="${year}.${month}.${day}";export yesterday2
        LOGNAME_UC=`echo ${LOGNAME}|tr "[:lower:]" "[:upper:]"`;export LOGNAME_UC


    fi
fi

if [ "${DEBUG}" = "y" ]
then
    echo "date_opt_used is ${date_opt_used}" | tee -a $summary_log
    echo "base_date is ${base_date}" | tee -a $summary_log
    echo "today is ${today}" | tee -a $summary_log
    echo "today2 is ${today2}" | tee -a $summary_log
    echo "today_plus is ${today_plus}" | tee -a $summary_log
    echo "yesterday is ${yesterday}" | tee -a $summary_log
    echo "yesterday2 is ${yesterday2}" | tee -a $summary_log
fi
} # End date_calculations

create_data_directories()
{
    if [ "${DEBUG}" = "y" ]; then set -xv; fi

echo "The ${log_dir_curr} directory will be created and contain information specific to TWS instance ${tws_cpu}." >> $summary_log

#cd ${TWS_basePath}

#Create ${log_dir_curr} directory for gathered files
echo "Creating ${log_dir_curr} directory for gathered files." >> $summary_log
mkdir -p ${log_dir_curr} 2>>$summary_log
chmod 777 ${log_dir_curr}

mkdir -p ${log_dir_curr}/${SYSINFO_DIR} 2>>$summary_log

} # End create_data_directories

gather_workstation_information()
{
    if [ "${DEBUG}" = "y" ]; then set -xv; fi

echo "*****Gathering Workstation specific information.*****"

#Gather system i/o performance information using vmstat.
    echo "Sending output of vmstat 5 5 to ${log_dir_curr}/${SYSINFO_DIR}/vmstat_5_5.out" >>$summary_log
    vmstat 5 5 > ${log_dir_curr}/${SYSINFO_DIR}/vmstat_5_5.out &

#Extract local cpu name
#echo " "
echo "Extracting local cpu name to ${log_dir_curr}/${SYSINFO_DIR}/cpu_node_info.txt." >> $summary_log
uname -a > ${log_dir_curr}/${SYSINFO_DIR}/cpu_node_info.txt

#Extract environment for current TWS instance
#echo " "
echo "Extracting environment for current TWS instance to ${log_dir_curr}/${SYSINFO_DIR}/instance_env_info.txt." >> $summary_log
env  > ${log_dir_curr}/${SYSINFO_DIR}/instance_env_info.txt

#Extract nslookup info for local cpu
#echo " "
echo "Extracting nslookup info for local cpu to ${log_dir_curr}/${SYSINFO_DIR}/cpu_nslookup_info.txt." >> $summary_log
nslookup ${local_cpu} > ${log_dir_curr}/${SYSINFO_DIR}/cpu_nslookup_info.txt 2>>$summary_log

#Extract netstat info for local cpu
#echo " "
echo "Extracting netstat info for local cpu to ${log_dir_curr}/${SYSINFO_DIR}/cpu_netstat_info.txt." >> $summary_log
netstat -a  > ${log_dir_curr}/${SYSINFO_DIR}/cpu_netstat_info.txt 2>&1
netstat -rn  >> ${log_dir_curr}/${SYSINFO_DIR}/cpu_netstat_info.txt 2>&1

#Extract current executing processes for current TWS user
#echo " "
echo "Extracting current executing processes for current TWS user to ${log_dir_curr}/${SYSINFO_DIR}/ps_ef_listing.txt." >> $summary_log
ps -ef > ${log_dir_curr}/${SYSINFO_DIR}/ps_ef_listing.txt


#Extract current available disk space for all filesystems on system
#echo " "
echo "Extracting available diskspace for all filesystems on system" >> $summary_log
echo "to ${log_dir_curr}/${SYSINFO_DIR}/system_disk_available.txt file." >> $summary_log
df -k > ${log_dir_curr}/${SYSINFO_DIR}/system_disk_available.txt

#Added 01/22/09 PSJ
#Added the pulling of the /etc/hosts file
echo "Copying hosts, services, and environment files from /etc to ${log_dir_curr}/${SYSINFO_DIR} directory." >> $summary_log
cp -p /etc/hosts ${log_dir_curr}/${SYSINFO_DIR} 2>>$summary_log
cp -p /etc/services ${log_dir_curr}/${SYSINFO_DIR} 2>>$summary_log
cp -p /etc/environment ${log_dir_curr}/${SYSINFO_DIR} 2>>$summary_log
ls -l /etc/localtime > ${log_dir_curr}/${SYSINFO_DIR}/localtime_file_info 2>>$summary_log

#Added 02/12/10 MKD
echo "Send ulimit -a, umask, and date commands output to ${log_dir_curr}/${SYSINFO_DIR}" >> $summary_log
if [ "${EXEC_USER}" = "root" ] && [ "${tws_user}" != "root" ]
then
    ulimit -a > ${log_dir_curr}/${SYSINFO_DIR}/ulimit_a.root 2>>$summary_log
    umask > ${log_dir_curr}/${SYSINFO_DIR}/umask.root 2>>$summary_log
    date > ${log_dir_curr}/${SYSINFO_DIR}/date.root 2>>$summary_log
    su - ${tws_user} -c "ulimit -a" > ${log_dir_curr}/${SYSINFO_DIR}/ulimit_a.${tws_user} 2>>$summary_log
    su - ${tws_user} -c "umask" > ${log_dir_curr}/${SYSINFO_DIR}/umask.${tws_user} 2>>$summary_log
    su - ${tws_user} -c "date" > ${log_dir_curr}/${SYSINFO_DIR}/date.${tws_user} 2>>$summary_log
fi
if [ "${EXEC_USER}" = "${tws_user}" ]
then
    ulimit -a > ${log_dir_curr}/${SYSINFO_DIR}/ulimit_a.${tws_user} 2>>$summary_log
    umask > ${log_dir_curr}/${SYSINFO_DIR}/umask.${tws_user} 2>>$summary_log
    date > ${log_dir_curr}/${SYSINFO_DIR}/date.${tws_user} 2>>$summary_log
fi

#Added 01/22/09 PSJ
#Added the pulling of the nsswitch/netsvc files and OS package information
        case $OS in
                AIX)
                echo "Copying netsvc.conf to ${log_dir_curr}/${SYSINFO_DIR} directory." >> $summary_log
                cp -p /etc/netsvc.conf ${log_dir_curr}/${SYSINFO_DIR} 2>>$summary_log
                oslevel -s > ${log_dir_curr}/${SYSINFO_DIR}/oslevel_s 2>>$summary_log
                oslevel -r > ${log_dir_curr}/${SYSINFO_DIR}/oslevel_r 2>>$summary_log
                lslpp -l > ${log_dir_curr}/${SYSINFO_DIR}/lslpp_l.out 2>>$summary_log
                prtconf > ${log_dir_curr}/${SYSINFO_DIR}/prtconf.out 2>>$summary_log
            bootinfo -K > ${log_dir_curr}/${SYSINFO_DIR}/bootinfo_K.out 2>>$summary_log
            lsattr -El sys0 -a realmem > ${log_dir_curr}/${SYSINFO_DIR}/memory.out 2>>$summary_log
            lssrc -a > ${log_dir_curr}/${SYSINFO_DIR}/lssrc_a.out 2>>$summary_log
            cp -p /etc/pam.conf ${log_dir_curr}/${SYSINFO_DIR} 2>>$summary_log
            cp -p /etc/ldap.conf ${log_dir_curr}/${SYSINFO_DIR} 2>>$summary_log
            ps -eo pcpu,pid,args | sort -rk1 | head -20 > ${log_dir_curr}/${SYSINFO_DIR}/ps_eo_percentCPU.out 2>>$summary_log
                ;;
                HPUX)
            echo "Copying nsswitch.* files to ${log_dir_curr} directory." >> $summary_log
            cp -p /etc/nsswitch.* ${log_dir_curr}/${SYSINFO_DIR} 2>>$summary_log
            swlist > ${log_dir_curr}/${SYSINFO_DIR}/swlist.out 2>>$summary_log
            uname -m > ${log_dir_curr}/${SYSINFO_DIR}/uname_m.out 2>>$summary_log
            uname -r > ${log_dir_curr}/${SYSINFO_DIR}/uname_r.out 2>>$summary_log
            who -r > ${log_dir_curr}/${SYSINFO_DIR}/who_r.out 2>>$summary_log
            cp -p /etc/pam.conf ${log_dir_curr}/${SYSINFO_DIR} 2>>$summary_log
            cp -p /etc/group ${log_dir_curr}/${SYSINFO_DIR}/etc_group 2>>$summary_log
            if [ "${EXEC_USER}" = "root" ]
            then
                /opt/ignite/bin/print_manifest | grep Memory > ${log_dir_curr}/${SYSINFO_DIR}/memory.out
                model > ${log_dir_curr}/${SYSINFO_DIR}/model.out
                /usr/bin/arch -k > ${log_dir_curr}/${SYSINFO_DIR}/arch_k.out
                machinfo > ${log_dir_curr}/${SYSINFO_DIR}/machinfo.out
            fi
                ;;
                LINUX_I386)
            echo "Copying nsswitch.* files to ${log_dir_curr} directory." >> $summary_log
            cp -p /etc/nsswitch.* ${log_dir_curr}/${SYSINFO_DIR} 2>>$summary_log
            cp -p /etc/issue ${log_dir_curr}/${SYSINFO_DIR} 2>>$summary_log
            cp -p /etc/redhat* ${log_dir_curr}/${SYSINFO_DIR} 2>>$summary_log
            cp -pR /etc/pam.d ${log_dir_curr}/${SYSINFO_DIR} 2>>$summary_log
            cp -p /etc/ldap.conf ${log_dir_curr}/${SYSINFO_DIR} 2>>$summary_log
            rpm -qa > ${log_dir_curr}/${SYSINFO_DIR}/rpm_qa.out 2>>$summary_log
            uname -m > ${log_dir_curr}/${SYSINFO_DIR}/uname_m.out 2>>$summary_log
            uname -r > ${log_dir_curr}/${SYSINFO_DIR}/uname_r.out 2>>$summary_log
            runlevel > ${log_dir_curr}/${SYSINFO_DIR}/runlevel.out 2>>$summary_log
            free > ${log_dir_curr}/${SYSINFO_DIR}/memory.out
                ;;
                SOLARIS)
            echo "Copying nsswitch.* files to ${log_dir_curr} directory." >> $summary_log
            cp -p /etc/nsswitch.* ${log_dir_curr}/${SYSINFO_DIR} 2>>$summary_log
            cp -p /etc/pam.conf ${log_dir_curr}/${SYSINFO_DIR} 2>>$summary_log
            #Added 01/22/09 PSJ
            #Added the pulling of the "zonecfg list" if OS is Solaris
            echo "Will determine if ${OS} is 10.x or greater." >> $summary_log
            if [ -f /usr/sbin/zonecfg ]
            then
                /usr/sbin/zonecfg list 2>>$summary_log
                RETVAL=$?;export RETVAL
                if [ "$RETVAL" = "0" ]
                then
                    echo "Copying output of zonecfg list to  ${log_dir_curr}." >> $summary_log
                    zonecfg list > ${log_dir_curr}/${SYSINFO_DIR}/zonecfg.txt 2>>$summary_log
                else
                    echo "{OS} is not 10.x or greater."  >> $summary_log
                fi
            fi
            pkginfo >  ${log_dir_curr}/${SYSINFO_DIR}/pkginfo.out 2>>$summary_log
            uname -imp > ${log_dir_curr}/${SYSINFO_DIR}/uname_imp.out 2>>$summary_log
            uname -r > ${log_dir_curr}/${SYSINFO_DIR}/uname_r.out 2>>$summary_log
            who -r > ${log_dir_curr}/${SYSINFO_DIR}/who_r.out 2>>$summary_log
            prtdiag | grep Memory > ${log_dir_curr}/${SYSINFO_DIR}/memory_config.out
            prtconf -v | grep Memory > ${log_dir_curr}/${SYSINFO_DIR}/memory_size.out

                ;;
        esac

#Gather results of uptime command:
    echo "Sending output of uptime to ${log_dir_curr}/${SYSINFO_DIR}/uptime.out" >>$summary_log
    uptime > ${log_dir_curr}/${SYSINFO_DIR}/uptime.out 2>>$summary_log

#Gather results of the last command:
    echo "Sending output of last to ${log_dir_curr}/${SYSINFO_DIR}/last.out" >>$summary_log
    last > ${log_dir_curr}/${SYSINFO_DIR}/last.out 2>>$summary_log

#If not HPUX run ifconfig -a
    if [ "$OS" != "HPUX" ]
    then
        echo "Sending output of ifconfig -a to ${log_dir_curr}/${SYSINFO_DIR}/ifconfig.out" >>$summary_log
        ifconfig -a >${log_dir_curr}/${SYSINFO_DIR}/ifconfig.out 2>>$summary_log
    fi

#MKD 2/11/10 Gather file listing in /usr/Tivoli/TWS
    if [ -d /usr/Tivoli/TWS ]
    then
        ls -lR /usr/Tivoli/TWS > ${log_dir_curr}/${SYSINFO_DIR}/usr_Tivoli_libs.out 2>>$summary_log
    fi

} # End gather_workstation_information

gather_tws_information()
{
    if [ "${DEBUG}" = "y" ]; then set -vx; fi
    echo "*****Gathering TWS specific information.*************" | tee -a $summary_log

    mkdir ${log_dir_curr}/${TWSINFO_DIR}

    #Generate .msg files list
    if [ -f ${TWS_datadir}/Mailbox.msg ]
    then
        mkdir -p ${log_dir_curr}/${TWSINFO_DIR}/${TWSMSG_DIR}
        echo "Generating .msg files list to ${log_dir_curr}/${TWSINFO_DIR}/${TWSMSG_DIR}/msg_file_listing.txt." >> $summary_log
        ls -l ${TWS_datadir}/*.msg > ${log_dir_curr}/${TWSINFO_DIR}/${TWSMSG_DIR}/msg_file_listing.txt 2>>$summary_log
        if [ -d ${TWS_datadir}/pobox ]
        then
            ls -l ${TWS_datadir}/pobox/* >> ${log_dir_curr}/${TWSINFO_DIR}/${TWSMSG_DIR}/msg_file_listing.txt 2>>$summary_log
        fi

             #Copy *.msg files
             echo "Copying *.msg files to ${log_dir_curr}/${TWSINFO_DIR}/${TWSMSG_DIR} directory." >> $summary_log
             for i in `ls ${TWS_datadir}/*.msg`
             do
                     source_item="$i"
                     calc_disk_space_usage_and_avail
                     if [ "${ENOUGH_SPACE}" = "y" ]
                     then
                             cp -p ${TWS_datadir}/*.msg ${log_dir_curr}/${TWSINFO_DIR}/${TWSMSG_DIR} 2>>$summary_log
                     fi
             done
    fi

        if [ -d ${TWS_datadir}/pobox ]
        then
                for i in `ls ${TWS_datadir}/pobox/*.msg 2>>$summary_log`
                do
                        source_item="$i"
                        calc_disk_space_usage_and_avail
                        if [ "${ENOUGH_SPACE}" = "y" ]
                        then
                                cp -p $i ${log_dir_curr}/${TWSINFO_DIR}/${TWSMSG_DIR} 2>>$summary_log
                        fi
                done
        fi


    # MKD 2/10/10 Added to gather eventrule information.
    echo "Gathering conman output" >> $summary_log
    if [ -f ${TWS_basePath}/tws_env.sh ]
    then
        mkdir ${log_dir_curr}/${TWSINFO_DIR}/conman_output_files
        . ${TWS_basePath}/tws_env.sh >> $summary_log 2>>$summary_log
        conman 'sc @!@; getmon; noask' > ${log_dir_curr}/${TWSINFO_DIR}/conman_output_files/conman_sc_getmon.out 2>> $summary_log &
        conman 'sc @!@; i' > ${log_dir_curr}/${TWSINFO_DIR}/conman_output_files/conman_sc_i.out 2>> $summary_log &
        conman 'sc @!@; l' > ${log_dir_curr}/${TWSINFO_DIR}/conman_output_files/conman_sc_l.out 2>> $summary_log &
        conman 'sc @!@' > ${log_dir_curr}/${TWSINFO_DIR}/conman_output_files/conman_sc.out 2>> $summary_log &
        conman 'ss @#/@/@' > ${log_dir_curr}/${TWSINFO_DIR}/conman_output_files/conman_ss.out 2>> $summary_log &
        conman 'ss @#/@/@;showid' > ${log_dir_curr}/${TWSINFO_DIR}/conman_output_files/conman_ss_showid.out 2>> $summary_log &
        conman 'ss @#/@/@;recnum' > ${log_dir_curr}/${TWSINFO_DIR}/conman_output_files/conman_ss_recnum.out 2>> $summary_log &
        conman 'sj @#/@/@' > ${log_dir_curr}/${TWSINFO_DIR}/conman_output_files/conman_sj.out 2>> $summary_log &
        conman 'sj @#/@/@;showid' > ${log_dir_curr}/${TWSINFO_DIR}/conman_output_files/conman_sj_showid.out 2>> $summary_log &
        conman 'sj @#/@/@;recnum' > ${log_dir_curr}/${TWSINFO_DIR}/conman_output_files/conman_sj_recnum.out 2>> $summary_log &
    fi


    #Copy Symphony, Sinfonia, StartUp and Jnextday/JnextPlan files
    echo "Copying Symphony, Sinfonia and  to ${log_dir_curr}/${TWSINFO_DIR}/plan_files_scripts directory." >> $summary_log
    for i in Symphony Sinfonia Symnew prodsked Jobtable
    do
        if [ -f ${TWS_datadir}/${i} ]
        then
            if [ ! -d ${log_dir_curr}/${TWSINFO_DIR}/plan_files_scripts ]
            then
                mkdir ${log_dir_curr}/${TWSINFO_DIR}/plan_files_scripts 2>>$summary_log
            fi

                source_item="${TWS_basePath}/${i}"
                calc_disk_space_usage_and_avail
                if [ "${ENOUGH_SPACE}" = "y" ]
                then
                cp -p ${TWS_datadir}/$i ${log_dir_curr}/${TWSINFO_DIR}/plan_files_scripts 2>>$summary_log
            fi
        fi
    done
    
    echo "Copying JnextPlan files to ${log_dir_curr}/${TWSINFO_DIR}/plan_files_scripts directory." >> $summary_log
    for i in StartUp JnextPlan ResetPlan MakePlan SwitchPlan UpdateStats CreatePostReports prodsked
    do
        if [ -f ${TWS_basePath}/${i} ]
        then
            if [ ! -d ${log_dir_curr}/${TWSINFO_DIR}/plan_files_scripts ]
            then
                mkdir ${log_dir_curr}/${TWSINFO_DIR}/plan_files_scripts 2>>$summary_log
            fi

                source_item="${TWS_basePath}/${i}"
                calc_disk_space_usage_and_avail
                if [ "${ENOUGH_SPACE}" = "y" ]
                then
                cp -p ${TWS_basePath}/$i ${log_dir_curr}/${TWSINFO_DIR}/plan_files_scripts 2>>$summary_log
            fi
        fi
    done
    
    

    # MKD 11/26/2015 Gather ${TWS_basePath}/twsinst* files and directories:
    if [ -f ${TWS_basePath}/twsinst ]
    then
        source_item="${TWS_basePath}/twsinst*"
        calc_disk_space_usage_and_avail
        if [ "${ENOUGH_SPACE}" = "y" ]
        then
            mkdir ${log_dir_curr}/${TWSINFO_DIR}/twsinst_files 2>>$summary_log
            cp -pR ${TWS_basePath}/twsinst* ${log_dir_curr}/${TWSINFO_DIR}/twsinst_files 2>>$summary_log
        fi
    fi

    #Added 02/09/09 PSJ
    #Added 02/09/09 PSJ
    #Added Copy of previous days schedlog and day of issue when -date is specified.
    if [ -d ${TWS_datadir}/schedlog ]
    then
        #mkdir ${log_dir_curr}/${TWSINFO_DIR}/schedlog_files 2>>$summary_log
        #Shifting target of schedlog files from schedlog_files to plan_files_scripts directory.
        if [ "${date_opt_used}" = "y" ]
        then
            for todaySym in `ls ${TWS_datadir}/schedlog/M${today}* 2>>$summary_log`
            do
                    source_item="${todaySym}"
                    calc_disk_space_usage_and_avail
                    if [ "${ENOUGH_SPACE}" = "y" ]
                    then
                    #echo "Copying ${todaySym} to ${log_dir_curr}/${TWSINFO_DIR}/schedlog_files directory." >> $summary_log
                    #cp -p ${today} ${log_dir_curr}/${TWSINFO_DIR}/schedlog_files 2>>$summary_log
                    echo "Copying ${todaySym} to ${log_dir_curr}/${TWSINFO_DIR}/plan_files_scripts directory." >> $summary_log
                    cp -p ${today} ${log_dir_curr}/${TWSINFO_DIR}/plan_files_scripts 2>>$summary_log
                fi
            done
            for today_plusSym in `ls ${TWS_datadir}/schedlog/M${today_plus}* 2>>$summary_log`
            do
                    source_item="${today_plusSym}"
                    calc_disk_space_usage_and_avail
                    if [ "${ENOUGH_SPACE}" = "y" ]
                    then
                    #echo "Copying ${today_plusSym} to ${log_dir_curr}/${TWSINFO_DIR}/schedlog_files directory." >> $summary_log
                    #cp -p ${today_plusSym} ${log_dir_curr}/${TWSINFO_DIR}/schedlog_files 2>>$summary_log
                    echo "Copying ${today_plusSym} to ${log_dir_curr}/${TWSINFO_DIR}/plan_files_scripts directory." >> $summary_log
                    cp -p ${today_plusSym} ${log_dir_curr}/${TWSINFO_DIR}/plan_files_scripts 2>>$summary_log
                fi
            done
        else
            #Added 01/22/09 PSJ
            #Added Copy of previous days schedlog
            for yesterdaySym in `ls ${TWS_datadir}/schedlog/M${yesterday}* 2>>$summary_log`
            do
                    source_item="${yesterdaySym}"
                    calc_disk_space_usage_and_avail
                    if [ "${ENOUGH_SPACE}" = "y" ]
                    then

                    #echo "Copying ${yesterdaySym} to ${log_dir_curr}/${TWSINFO_DIR}/schedlog_files directory." >> $summary_log
                    #cp -p ${yesterdaySym} ${log_dir_curr}/${TWSINFO_DIR}/schedlog_files 2>>$summary_log
                    echo "Copying ${yesterdaySym} to ${log_dir_curr}/${TWSINFO_DIR}/plan_files_scripts directory." >> $summary_log
                    cp -p ${yesterdaySym} ${log_dir_curr}/${TWSINFO_DIR}/plan_files_scripts 2>>$summary_log
                fi
            done
            # Added line 01/11/2010 - MKD
            for todaySym in `ls ${TWS_datadir}/schedlog/M${today}* 2>>$summary_log`
            do
                    source_item="${todaySym}"
                    calc_disk_space_usage_and_avail
                    if [ "${ENOUGH_SPACE}" = "y" ]
                then
                    #cp -p ${todaySym} ${log_dir_curr}/${TWSINFO_DIR}/schedlog_files 2>>$summary_log
                    cp -p ${todaySym} ${log_dir_curr}/${TWSINFO_DIR}/plan_files_scripts 2>>$summary_log
                fi
            done
        fi
    fi

    #Copy localopts, globalopts, jobmanrc, .jobmanrc and TWSCCLog.properties files
    echo "Copying localopts, globalopts and TWSCCLog.properties files to ${log_dir_curr}/tws_config_files directory." >> $summary_log

    for confile in localopts mozart/globalopts TWSCCLog.properties jobmanrc
    do
        if [ -f ${TWS_datadir}/${confile} ]
        then
            if [ ! -d ${log_dir_curr}/${TWSINFO_DIR}/tws_config_files ]
            then
                mkdir ${log_dir_curr}/${TWSINFO_DIR}/tws_config_files 2>>$summary_log
            fi

                source_item="${TWS_datadir}/${confile}"
                calc_disk_space_usage_and_avail
                if [ "${ENOUGH_SPACE}" = "y" ]
                then
                cp -p ${TWS_datadir}/$confile ${log_dir_curr}/${TWSINFO_DIR}/tws_config_files 2>>$summary_log
            fi
        fi
    done

    #Extract TWS Security file
    echo "Extracting TWS Security file to ${log_dir_curr}/${TWSINFO_DIR}/tws_config_files/Security_file.txt." >> $summary_log
    if [ -f ${TWS_basePath}/bin/dumpsec ]
    then
        ${TWS_basePath}/bin/dumpsec > ${log_dir_curr}/${TWSINFO_DIR}/tws_config_files/Security_file.txt 2>>$summary_log
    fi

    #Added 05/16/08 PSJ
    #Added the listing of the contents of the TWSHome/methods directory
    if [ -d ${TWS_datadir}/methods ]
    then
        mkdir -p ${log_dir_curr}/${TWSINFO_DIR}/${TWSMTHD_DIR}
        echo "Creating list of files in the ${TWS_basePath}/methods directory to ${log_dir_curr}/${TWSINFO_DIR}/${TWSMTHD_DIR}/methods_dir_list.txt." >> $summary_log
        ls -la ${TWS_datadir}/methods/* > ${log_dir_curr}/${TWSINFO_DIR}/${TWSMTHD_DIR}/methods_dir_list.txt 2>>$summary_log

        echo "Copying contents of the ${TWS_basePath}/methods directory to ${log_dir_curr}/${TWSINFO_DIR}/${TWSMTHD_DIR} directory." >> $summary_log
        for i in `ls ${TWS_datadir}/methods`
        do
            if [ -f ${TWS_datadir}/methods/$i ]
            then
                    source_item="${TWS_datadir}/methods/$i"
                    calc_disk_space_usage_and_avail
                    if [ "${ENOUGH_SPACE}" = "y" ]
                then
                    cp -p ${TWS_datadir}/methods/$i ${log_dir_curr}/${TWSINFO_DIR}/${TWSMTHD_DIR} 2>>$summary_log
                fi
            fi
        done

        #Added 05/13/08 PSJ
        #Added the searching for R3 agents.
        echo "Will search for R3 files with extension of _r3batch.opts." >> $summary_log



        TWS_MethodPath="$TWS_datadir/methods"
#       cd ${TWS_MethodPath}

        TWS_R3_FILES="$TWS_MethodPath/*r3batch.opts"
        
        ls -A $TWS_R3_FILES > /dev/null 2>&1

        # look for r3batch files
        if [ $? -eq 0 ]
        then

            echo "Script will gather R3 specific files for this instance." >> $summary_log
            echo "Copying results of r3batch -v command to ${log_dir_curr}/${TWSINFO_DIR}/${TWSMTHD_DIR}/r3batch_ver.txt" >> $summary_log
            $TWS_basePath/methods/r3batch -v > ${log_dir_curr}/${TWSINFO_DIR}/${TWSMTHD_DIR}/r3batch_ver.txt 2>&1

            echo "Disabled call to 'r3batch -t PL ...' as it is too resource intensive." >> $summary_log
#           for r3_agent in `ls ${TWS_R3_FILES} | sed 's/.*\/methods\/\(.*\)_r3batch.opts/\1/g' 2>> $summary_log`
#           do
#               $TWS_basePath/methods/r3batch -t PL -c ${r3_agent} -l \* -j \* -- \"-debug -trace\" > ${log_dir_curr}/${TWSINFO_DIR}/${TWSMTHD_DIR}/${r3_agent}_r3_batch_info.txt 2>>$summary_log &
#           done

        else
            echo "R3 definitions $TWS_R3_FILES do not exist." >> $summary_log
            echo "Script will proceed to next section." >> $summary_log
        fi
    fi

    #Creating file listsings.
    mkdir ${log_dir_curr}/${TWSINFO_DIR}/tws_file_lists
    #Extract list of TWS binaries
    if [ -d ${TWS_basePath}/bin ]
    then
        ls -la ${TWS_basePath}/bin/* > ${log_dir_curr}/${TWSINFO_DIR}/tws_file_lists/tws_binary_list.txt 2>>$summary_log
    fi
    if [ -d ${TWS_datadir} ]
    then
        ls -laR ${TWS_datadir} > ${log_dir_curr}/${TWSINFO_DIR}/tws_file_lists/tws_datadir_list.txt 2>>$summary_log
    fi
    
    #Extract list of files in ${TWS_basePath} directory
    ls -lRa ${TWS_basePath}/* > ${log_dir_curr}/${TWSINFO_DIR}/tws_file_lists/twshome_files_list.txt 2>>$summary_log
    #find ${TWS_basePath} -ls > ${log_dir_curr}/${TWSINFO_DIR}/tws_file_lists/twshome_files_list.txt 2>>$summary_log

    #Extract list of files in ${TWS_basePath}/.. directory
    if [ -d ${TWA_path} ]
    then
        ls -lRa ${TWA_path}/* > ${log_dir_curr}/${TWSINFO_DIR}/tws_file_lists/TWAhome_files_list.txt 2>>$summary_log
    fi

    #Extract list of files in ${TWS_datadir}/mozart directory
    if [ -d ${TWS_datadir}/mozart ]
    then
        ls -la ${TWS_datadir}/mozart/* > ${log_dir_curr}/${TWSINFO_DIR}/tws_file_lists/mozart_dir_list.txt 2>>$summary_log
    fi

    #Extract list of files in ${TWS_datadir}/ftbox directory
    if [ -d ${TWS_datadir}/ftbox ]
    then
        ls -lRa ${TWS_datadir}/ftbox > ${log_dir_curr}/${TWSINFO_DIR}/${TWSMSG_DIR}/ftbox_dir_list.txt 2>>$summary_log
        #find ${TWS_datadir}/ftbox -ls > ${log_dir_curr}/${TWSINFO_DIR}/${TWSMSG_DIR}/ftbox_dir_list.txt 2>>$summary_log
        cp ${log_dir_curr}/${TWSINFO_DIR}/${TWSMSG_DIR}/ftbox_dir_list.txt ${log_dir_curr}/${TWSINFO_DIR}/tws_file_lists 2>>$summary_log
    fi

    #Extract list of files in ${TWS_datadir}/pids directory
    if [ -d ${TWS_datadir}/pids ]
    then
        ls -la ${TWS_datadir}/pids/* > ${log_dir_curr}/${TWSINFO_DIR}/tws_file_lists/pids_dir_list.txt 2>>$summary_log
    fi

    #Extract list of files in ${TWS_basePath}/network directory
    if [ -d ${TWS_datadir}/network ]
    then
        ls -la ${TWS_datadir}/network/* > ${log_dir_curr}/${TWSINFO_DIR}/tws_file_lists/network_dir_list.txt 2>>$summary_log
    fi

    if [ -d ${TWS_datadir}/audit/database ] || [ -d ${TWS_datadir}/audit/plan ]
    then
        #Extract list of files in $TWS_datadir/audit/database directory for curent date and yesterday.
        mkdir ${log_dir_curr}/${TWSINFO_DIR}/audit_files
        if [ -d ${TWS_datadir}/audit/database ]
        then
            echo "Extracting list of files in ${TWS_datadir}/audit/database directory" >> $summary_log
            echo "to ${log_dir_curr}/${TWSINFO_DIR}/tws_file_lists/audit_db_dir_list.txt." >> $summary_log
            ls -la ${TWS_datadir}/audit/database/* > ${log_dir_curr}/${TWSINFO_DIR}/tws_file_lists/audit_db_dir_list.txt 2>>$summary_log
            cp ${log_dir_curr}/${TWSINFO_DIR}/tws_file_lists/audit_db_dir_list.txt ${log_dir_curr}/${TWSINFO_DIR}/audit_files 2>>$summary_log
            #Copying files in ${TWS_datadir}/audit/database directory to ${log_dir_curr}/audit/database directory
            echo "Copying ${today} and ${yesterday} files in ${TWS_datadir}/audit/database directory to ${log_dir_curr}/${TWSINFO_DIR}/audit_files directory." >> $summary_log
            if [ -f ${TWS_datadir}/audit/database/${today} ]
            then
                cp -p ${TWS_datadir}/audit/database/${today} ${log_dir_curr}/${TWSINFO_DIR}/audit_files/audit_database_${today} 2>>$summary_log
            fi

            if [ -f ${TWS_datadir}/audit/database/${yesterday} ]
            then
                cp -p ${TWS_datadir}/audit/database/${yesterday} ${log_dir_curr}/${TWSINFO_DIR}/audit_files/audit_database_${yesterday} 2>>$summary_log
            fi
        fi

        #Extract list of files in $TWS_datadir/audit/plan directory.
        if [ -d ${TWS_datadir}/audit/plan ]
        then
            echo "Extracting list of files in ${TWS_datadir}/audit/plan directory" >> $summary_log
            echo "to ${log_dir_curr}/${TWSINFO_DIR}/audit_plan_dir_list.txt." >> $summary_log
            ls -la ${TWS_datadir}/audit/plan/* > ${log_dir_curr}/${TWSINFO_DIR}/audit_files/audit_plan_dir_list.txt 2>>$summary_log
            cp ${log_dir_curr}/${TWSINFO_DIR}/audit_files/audit_plan_dir_list.txt ${log_dir_curr}/${TWSINFO_DIR}/tws_file_lists 2>>$summary_log
            #Copying ${today} and ${yesterday} files in ${TWS_datadir}/audit/plan directory to ${log_dir_curr}/${TWSINFO_DIR} directory.
            echo "Copying ${today} and ${yesterday} files in ${TWS_datadir}/audit/plan directory to ${log_dir_curr}/${TWSINFO_DIR} directory as audit_plan_${today} and audit_plan_${yesterday}." >> $summary_log
            if [ -f ${TWS_datadir}/audit/plan/${today} ]
            then
                cp -p ${TWS_datadir}/audit/plan/${today} ${log_dir_curr}/${TWSINFO_DIR}/audit_files/audit_plan_${today} 2>>$summary_log
            fi
            if [ -f ${TWS_datadir}/audit/plan/${yesterday} ]
            then
                cp -p ${TWS_datadir}/audit/plan/${yesterday} ${log_dir_curr}/${TWSINFO_DIR}/audit_files/audit_plan_${yesterday} 2>>$summary_log
            fi
        fi
    fi

    #Test for existance of ${TWS_datadir}/BmEvents.conf file
    if [ -f ${TWS_datadir}/BmEvents.conf ]
    then
        #Copy BmEvents.conf file
        echo "Copying ${TWS_datadir}/BmEvents.conf (if it exists) to ${log_dir_curr}/${TWSINFO_DIR}/tws_config_files directory." >> $summary_log
        cp -p ${TWS_datadir}/BmEvents.conf ${log_dir_curr}/${TWSINFO_DIR}/tws_config_files/BmEvents.conf 2>>$summary_log

        #Extract the BmEvents log file from BmEvents.conf file
        BMEVENTS_LOG=`grep '^FILE' ${TWS_datadir}/BmEvents.conf | awk -F\= '{print $2}'`; export BMEVENTS_LOG
        echo "Copying contents of BmEvents log file ${BMEVENTS_LOG}" >> $summary_log
        echo "to ${log_dir_curr}/${TWSINFO_DIR}/tws_config_files/BmEvents_event_log.txt file." >> $summary_log
        cp -p ${BMEVENTS_LOG} ${log_dir_curr}/${TWSINFO_DIR}/tws_config_files/BmEvents_event_log.txt 2>>$summary_log
    fi

    #Extract TWS scheduling objects to flatfiles
    if [ "${extract_db_defs}" = "y" ] && [ -f ${TWS_basePath}/bin/composer ]
    then
        mkdir ${log_dir_curr}/${TWSINFO_DIR}/composer_out_files
        if [ "${CPU_TYPE}" = "MASTER" ] || [ "${TWS_instance_type}" = "master" ]
        then
            echo "Will extract database definitions to flatfiles." >> $summary_log

            echo "Creating ${log_dir_curr}/${TWSINFO_DIR}/job_defs file." >> $summary_log
            ${TWS_basePath}/bin/composer "cr ${log_dir_curr}/${TWSINFO_DIR}/composer_out_files/job_defs jobs=@#/@/@" >> $summary_log 2>&1
            ${TWS_basePath}/bin/composer "li jobs=@#/@/@" > ${log_dir_curr}/${TWSINFO_DIR}/composer_out_files/job_list 2>> $summary_log

            echo "Creating ${log_dir_curr}/${TWSINFO_DIR}/sched_defs file." >> $summary_log
            ${TWS_basePath}/bin/composer "cr ${log_dir_curr}/${TWSINFO_DIR}/composer_out_files/sched_defs sched=@#/@/@" >> $summary_log 2>&1
            ${TWS_basePath}/bin/composer "li sched=@#/@/@" > ${log_dir_curr}/${TWSINFO_DIR}/composer_out_files/sched_list 2>> $summary_log

            echo "Creating ${log_dir_curr}/${TWSINFO_DIR}/cpu_defs file." >> $summary_log
            ${TWS_basePath}/bin/composer "cr ${log_dir_curr}/${TWSINFO_DIR}/composer_out_files/cpu_defs cpu=@" >> $summary_log 2>&1
            ${TWS_basePath}/bin/composer "li cpu=@" > ${log_dir_curr}/${TWSINFO_DIR}/composer_out_files/cpu_list 2>> $summary_log

            echo "Creating ${log_dir_curr}/${TWSINFO_DIR}/calendar_defs file." >> $summary_log
            ${TWS_basePath}/bin/composer "cr ${log_dir_curr}/${TWSINFO_DIR}/composer_out_files/calendar_defs calendars" >> $summary_log 2>&1
            ${TWS_basePath}/bin/composer "li calendar" > ${log_dir_curr}/${TWSINFO_DIR}/composer_out_files/calendar_list 2>> $summary_log

            echo "Creating ${log_dir_curr}/${TWSINFO_DIR}/parms_defs file." >> $summary_log
            ${TWS_basePath}/bin/composer "cr ${log_dir_curr}/${TWSINFO_DIR}/composer_out_files/parms_defs parms" >> $summary_log 2>&1
            ${TWS_basePath}/bin/composer "li parms" > ${log_dir_curr}/${TWSINFO_DIR}/composer_out_files/parms_list 2>> $summary_log

            echo "Creating ${log_dir_curr}/${TWSINFO_DIR}/vt_defs file." >> $summary_log
            ${TWS_basePath}/bin/composer "cr ${log_dir_curr}/${TWSINFO_DIR}/composer_out_files/vt_defs vt" >> $summary_log 2>&1
            ${TWS_basePath}/bin/composer "li vt" > ${log_dir_curr}/${TWSINFO_DIR}/composer_out_files/vt_list 2>> $summary_log

            echo "Creating ${log_dir_curr}/${TWSINFO_DIR}/resource_defs file." >> $summary_log
            ${TWS_basePath}/bin/composer "cr ${log_dir_curr}/${TWSINFO_DIR}/composer_out_files/resource_defs resources" >> $summary_log 2>&1
            ${TWS_basePath}/bin/composer "li resources" > ${log_dir_curr}/${TWSINFO_DIR}/composer_out_files/resource_list 2>> $summary_log

            echo "Creating ${log_dir_curr}/${TWSINFO_DIR}/prompt_defs file." >> $summary_log
            ${TWS_basePath}/bin/composer "cr ${log_dir_curr}/${TWSINFO_DIR}/composer_out_files/prompt_defs prompts" >> $summary_log 2>&1
            ${TWS_basePath}/bin/composer "li prompts" > ${log_dir_curr}/${TWSINFO_DIR}/composer_out_files/prompt_list 2>> $summary_log

            echo "Creating ${log_dir_curr}/${TWSINFO_DIR}/user_defs file." >> $summary_log
            ${TWS_basePath}/bin/composer "cr ${log_dir_curr}/${TWSINFO_DIR}/composer_out_files/user_defs users=@#@" >> $summary_log 2>&1
            ${TWS_basePath}/bin/composer "li users=@#@" > ${log_dir_curr}/${TWSINFO_DIR}/composer_out_files/user_list 2>> $summary_log

            echo "Creating ${log_dir_curr}/${TWSINFO_DIR}/er_defs file." >> $summary_log
            ${TWS_basePath}/bin/composer "cr ${log_dir_curr}/${TWSINFO_DIR}/composer_out_files/er_defs er=@" >> $summary_log 2>&1
            ${TWS_basePath}/bin/composer "li er=@" > ${log_dir_curr}/${TWSINFO_DIR}/composer_out_files/er_list 2>> $summary_log
#RUNCYCLEGROUP,WAT,SECURITYDOMAIN,SECURITYROLE,ACCESSCONTROLLIST
            echo "Creating ${log_dir_curr}/${TWSINFO_DIR}/rcg_defs file." >> $summary_log
            ${TWS_basePath}/bin/composer "cr ${log_dir_curr}/${TWSINFO_DIR}/composer_out_files/rcg_defs rcg=@" >> $summary_log 2>&1
            ${TWS_basePath}/bin/composer "li rcg=@" > ${log_dir_curr}/${TWSINFO_DIR}/composer_out_files/rcg_list 2>> $summary_log

            echo "Creating ${log_dir_curr}/${TWSINFO_DIR}/wat_defs file." >> $summary_log
            ${TWS_basePath}/bin/composer "cr ${log_dir_curr}/${TWSINFO_DIR}/composer_out_files/wat_defs wat=@" >> $summary_log 2>&1
            ${TWS_basePath}/bin/composer "li wat=@" > ${log_dir_curr}/${TWSINFO_DIR}/composer_out_files/wat_list 2>> $summary_log

            echo "Creating ${log_dir_curr}/${TWSINFO_DIR}/securitydomain_defs file." >> $summary_log
            ${TWS_basePath}/bin/composer "cr ${log_dir_curr}/${TWSINFO_DIR}/composer_out_files/securitydomain_defs securitydomain=@" >> $summary_log 2>&1
            ${TWS_basePath}/bin/composer "li securitydomain=@" > ${log_dir_curr}/${TWSINFO_DIR}/composer_out_files/securitydomain_list 2>> $summary_log

            echo "Creating ${log_dir_curr}/${TWSINFO_DIR}/securityrole_defs file." >> $summary_log
            ${TWS_basePath}/bin/composer "cr ${log_dir_curr}/${TWSINFO_DIR}/composer_out_files/securityrole_defs securityrole=@" >> $summary_log 2>&1
            ${TWS_basePath}/bin/composer "li securityrole=@" > ${log_dir_curr}/${TWSINFO_DIR}/composer_out_files/securityrole_list 2>> $summary_log

            echo "Creating ${log_dir_curr}/${TWSINFO_DIR}/accesscontrollist_defs file." >> $summary_log
            ${TWS_basePath}/bin/composer "cr ${log_dir_curr}/${TWSINFO_DIR}/composer_out_files/accesscontrollist_defs accesscontrollist=@" >> $summary_log 2>&1
            ${TWS_basePath}/bin/composer "li accesscontrollist=@" > ${log_dir_curr}/${TWSINFO_DIR}/composer_out_files/accesscontrollist_list 2>> $summary_log
            
            echo "Creating ${log_dir_curr}/${TWSINFO_DIR}/folder_defs file." >> $summary_log
            ${TWS_basePath}/bin/composer "cr ${log_dir_curr}/${TWSINFO_DIR}/composer_out_files/folder_defs folder=@" >> $summary_log 2>&1
            ${TWS_basePath}/bin/composer "li folder=@" > ${log_dir_curr}/${TWSINFO_DIR}/composer_out_files/folder_list 2>> $summary_log
            
        fi
    fi


    #Copy TWSRegistry.dat file etc.
    mkdir ${log_dir_curr}/tws_registry_info 2>>$summary_log
    echo "Copying TWSRegistry.dat files to ${log_dir_curr}/tws_registry_info directory." >> $summary_log
    cp -p ${TWS_REG_FILE} ${log_dir_curr}/tws_registry_info 2>>$summary_log

    #MKD 2/8/10
    if [ -d /etc/TWA ]
    then
        #Copy /etc/TWA files
        source_item="/etc/TWA"
        calc_disk_space_usage_and_avail
        if [ "${ENOUGH_SPACE}" = "y" ]
        then
            echo "Copying /etc/TWA files to ${log_dir_curr}/tws_registry_info directory." >> $summary_log
            cp -pR /etc/TWA ${log_dir_curr}/tws_registry_info 2>>$summary_log
        fi
    fi

    #Copy TWSHome/version directory contents
    echo "Copying ${TWS_basePath}/version directory contents to ${log_dir_curr}/${TWSINFO_DIR} directory." >> $summary_log
    if [ -d ${TWS_basePath}/version ]
    then
            source_item="${TWS_basePath}/version"
            calc_disk_space_usage_and_avail
            if [ "${ENOUGH_SPACE}" = "y" ]
            then
                echo "Copying ${TWS_basePath}/version to ${log_dir_curr}/${TWSINFO_DIR}" >> $summary_log
                cp -pR ${TWS_basePath}/version ${log_dir_curr}/${TWSINFO_DIR} 2>>$summary_log
            fi
    fi

    if [ -d ${TWS_datadir}/stdlist ]
    then
        mkdir -p ${log_dir_curr}/${STDLIST_DIR}
        mkdir ${log_dir_curr}/${STDLISTLOGS_DIR}
        mkdir ${log_dir_curr}/${STDLISTTRC_DIR}
        mkdir ${log_dir_curr}/${STDLISTAPPSRV_DIR}

        #Copy TWSUser and NETMAN stdlist files from stdlist/curr_date directory
        # 9/24/09 Now copy all stdlist/YYYY.MM.DD files to ${log_dir_curr}/${STDLIST_DIR}
        #echo "Copying ${TWS_datadir}/stdlist/${today2}/${LOGNAME_UC}" >> $summary_log
        #echo "to ${log_dir_curr}/${TWSLOGS_DIR}/stdlist_${today}_${LOGNAME_UC}" >> $summary_log
        if [ -d ${TWS_datadir}/stdlist/${today2} ]
        then
            source_item="${TWS_datadir}/stdlist/${today2}"
            calc_disk_space_usage_and_avail
            if [ "${ENOUGH_SPACE}" = "y" ]
            then
                echo "Copying ${TWS_datadir}/stdlist/${today2}" >> $summary_log
                echo "to ${log_dir_curr}/${STDLIST_DIR}" >> $summary_log
                cp -pr ${TWS_datadir}/stdlist/${today2} ${log_dir_curr}/${STDLIST_DIR} 2>>$summary_log
            fi
        fi

        #Copy TWSUser and NETMAN stdlist files from stdlist/previous_date directory
        #echo "Copying ${TWS_datadir}/stdlist/${yesterday2}/${LOGNAME_UC}" >> $summary_log
        #echo "to ${log_dir_curr}/${TWSLOGS_DIR}/stdlist_${yesterday}_${LOGNAME_UC}" >> $summary_log
        if [ -d ${TWS_datadir}/stdlist/${yesterday2} ]
        then
            source_item="${TWS_datadir}/stdlist/${yesterday2}"
            calc_disk_space_usage_and_avail
            if [ "${ENOUGH_SPACE}" = "y" ]
            then
                echo "Copying ${TWS_datadir}/stdlist/${yesterday2}" >> $summary_log
                echo "to ${log_dir_curr}/${STDLIST_DIR}" >> $summary_log
                cp -pr ${TWS_datadir}/stdlist/${yesterday2} ${log_dir_curr}/${STDLIST_DIR} 2>>$summary_log
            fi
        fi

        #Copy TWSMERGE and NETMAN stdlist files from stdlist/logs directory for current date
        #echo "Copying ${TWS_datadir}/stdlist/logs/${today}_TWSMERGE.log" >> $summary_log
        #echo "to ${log_dir_curr}/${TWSLOGS_DIR}/logs_${today}_TWSMERGE.log" >> $summary_log
        for i in `ls ${TWS_datadir}/stdlist/logs/${today}_*.log 2>>$summary_log`
        do
            source_item="$i"
            calc_disk_space_usage_and_avail
            if [ "${ENOUGH_SPACE}" = "y" ]
            then
                echo "Copying ${TWS_datadir}/stdlist/logs/${today}_*.log" >> $summary_log
                echo "to ${log_dir_curr}/${STDLISTLOGS_DIR}" >> $summary_log
                cp -p $i ${log_dir_curr}/${STDLISTLOGS_DIR} 2>>$summary_log
            fi
        done

        #Copy TWSMERGE and NETMAN stdlist files from stdlist/logs directory for previous date
        for i in `ls ${TWS_datadir}/stdlist/logs/${yesterday}_*.log 2>>$summary_log`
        do
            source_item="$i"
            calc_disk_space_usage_and_avail
            if [ "${ENOUGH_SPACE}" = "y" ]
            then
                echo "Copying ${TWS_datadir}/stdlist/logs/${yesterday}_*.log" >> $summary_log
            echo "to ${log_dir_curr}/${STDLISTLOGS_DIR}" >> $summary_log
                cp -p $i ${log_dir_curr}/${STDLISTLOGS_DIR} 2>>$summary_log
            fi
        done

        #Copy TWSMERGE and NETMAN stdlist files from stdlist/traces directory for current date
        for i in `ls ${TWS_datadir}/stdlist/traces/${today}_*.log 2>>$summary_log`
        do
            source_item="$i"
            calc_disk_space_usage_and_avail
            if [ "${ENOUGH_SPACE}" = "y" ]
            then
            echo "Copying ${TWS_datadir}/stdlist/traces/${today}_*.log" >> $summary_log
                echo "to ${log_dir_curr}/${STDLISTTRC_DIR}/traces_${today}_TWSMERGE.log" >> $summary_log
                cp -p $i ${log_dir_curr}/${STDLISTTRC_DIR} 2>>$summary_log
            fi
        done

        #Copy TWSMERGE and NETMAN stdlist files from stdlist/traces directory for previous date
        for i in `ls ${TWS_datadir}/stdlist/traces/${yesterday}_*.log 2>>$summary_log`
        do
            source_item="$i"
            calc_disk_space_usage_and_avail
                    if [ "${ENOUGH_SPACE}" = "y" ]
            then
                echo "Copying ${TWS_datadir}/stdlist/traces/${yesterday}_*.log" >> $summary_log
                echo "to ${log_dir_curr}/${STDLISTTRC_DIR}" >> $summary_log
                cp -p $i ${log_dir_curr}/${STDLISTTRC_DIR} 2>>$summary_log
            fi
        done

        #Copy TWSMERGE and NETMAN stdlist files from stdlist/traces directory for previous date
        for i in `ls ${TWS_datadir}/stdlist/traces/*snap* 2>>$summary_log`
        do
            source_item="$i"
            calc_disk_space_usage_and_avail
                    if [ "${ENOUGH_SPACE}" = "y" ]
            then
                echo "Copying ${TWS_datadir}/stdlist/traces/*snap*" >> $summary_log
                echo "to ${log_dir_curr}/${STDLISTTRC_DIR}" >> $summary_log
                cp -p $i ${log_dir_curr}/${STDLISTTRC_DIR} 2>>$summary_log
            fi
        done

        #Gather stdlist/JM
        if [ -d ${TWS_datadir}/stdlist/JM ]
        then
            source_item="${TWS_datadir}/stdlist/JM/*.log"
            calc_disk_space_usage_and_avail
                    if [ "${ENOUGH_SPACE}" = "y" ]
            then
                mkdir ${log_dir_curr}/${STDLIST_DIR}/JM 2>>$summary_log
                echo "Copying ${TWS_datadir}/stdlist/JM/*.log" >> $summary_log
                echo "to ${log_dir_curr}/${STDLIST_DIR}/JM" >> $summary_log
                cp -pr ${TWS_datadir}/stdlist/JM/*.log ${log_dir_curr}/${STDLIST_DIR}/JM 2>>$summary_log
                source_item="${TWS_datadir}/stdlist/JM/${today2}"
                calc_disk_space_usage_and_avail
                if [ "${ENOUGH_SPACE}" = "y" ]
                then
                    echo "Copying ${TWS_datadir}/stdlist/JM/${today2} to ${log_dir_curr}/${STDLIST_DIR}/JM" >> $summary_log
                    cp -pr ${TWS_datadir}/stdlist/JM/${today2} ${log_dir_curr}/${STDLIST_DIR}/JM 2>>$summary_log
                fi
                source_item="${TWS_datadir}/stdlist/JM/${yesterday2}"
                calc_disk_space_usage_and_avail
                if [ "${ENOUGH_SPACE}" = "y" ]
                then
                    echo "Copying ${TWS_datadir}/stdlist/JM/${yesterday2} to ${log_dir_curr}/${STDLIST_DIR}/JM" >> $summary_log
                    cp -pr ${TWS_datadir}/stdlist/JM/${yesterday2} ${log_dir_curr}/${STDLIST_DIR}/JM 2>>$summary_log
                fi
            fi
        fi
        
        #Gather stdlist/JM
        if [ -d ${TWS_datadir}/stdlist/appserver ]
        then
        	if [ -d ${TWS_datadir}/stdlist/appserver/engineServer ]
        	then
for target in audit *.log logs temp registry tranlog
do
	            source_item="${TWS_datadir}/stdlist/appserver/engineServer/${target}"
	            calc_disk_space_usage_and_avail
                if [ "${ENOUGH_SPACE}" = "y" ]
	            then
	                mkdir ${log_dir_curr}/${STDLIST_DIR}/appserver/engineServer 2>>$summary_log
	                echo "Copying ${TWS_datadir}/stdlist/appserver/engineServer" >> $summary_log
	                echo "to ${log_dir_curr}/${STDLIST_DIR}/appserver/engineServer" >> $summary_log
	                cp -pr ${TWS_datadir}/stdlist/appserver/engineServer/${target} ${log_dir_curr}/${STDLIST_DIR}/appserver/engineServer 2>>$summary_log
	            fi
done
        	fi
        	if [ -d ${TWS_datadir}/stdlist/appserver/dwcServer ]
        	then
for target in audit *.log logs temp registry tranlog
do
	            source_item="${TWS_datadir}/stdlist/appserver/dwcServer/${target}"
	            calc_disk_space_usage_and_avail
                if [ "${ENOUGH_SPACE}" = "y" ]
	            then
	                mkdir -p ${log_dir_curr}/${STDLIST_DIR}/appserver/dwcServer 2>>$summary_log
	                echo "Copying ${TWS_datadir}/stdlist/appserver/dwcServer" >> $summary_log
	                echo "to ${log_dir_curr}/${STDLIST_DIR}/appserver/dwcServer" >> $summary_log
	                cp -pr ${TWS_datadir}/stdlist/appserver/dwcServer/${target} ${log_dir_curr}/${STDLIST_DIR}/appserver/dwcServer 2>>$summary_log
	        fi
done
        	fi
        fi
        
        

        #Gather TWS/xtrace/xcli snaps
        if [ -d ${TWS_basePath}/xtrace ]
        then
            required_size=45000
            calc_disk_space_usage_and_avail
            if [ "${ENOUGH_SPACE}" = "y" ]
            then
                mkdir ${log_dir_curr}/${TWS_XTRACE_DIR}
                chmod 777 ${log_dir_curr}/${TWS_XTRACE_DIR}
                cd ${TWS_basePath}/xtrace
            #batchman
                echo "Generating xtrace snaphot files for batchman" >> $summary_log
                ./xcli -snap ${log_dir_curr}/${TWS_XTRACE_DIR}/batchman.snap_file -p batchman >> $summary_log 2>&1
                if [ -f  ${log_dir_curr}/${TWS_XTRACE_DIR}/batchman.snap_file ]
                then
                    ./xcli -format ${log_dir_curr}/${TWS_XTRACE_DIR}/batchman.snap_file -d ${TWS_basePath}/xtrace/xdb.dat -xml > ${log_dir_curr}/${TWS_XTRACE_DIR}/batchman.snap_file.xml 2>>$summary_log
                fi
            #jobman
                echo "Generating xtrace snaphot files for jobman" >> $summary_log
                ./xcli -snap ${log_dir_curr}/${TWS_XTRACE_DIR}/jobman.snap_file -p jobman >> $summary_log 2>&1
                if [ -f  ${log_dir_curr}/${TWS_XTRACE_DIR}/jobman.snap_file ]
                then
                    ./xcli -format ${log_dir_curr}/${TWS_XTRACE_DIR}/jobman.snap_file -d ${TWS_basePath}/xtrace/xdb.dat -xml > ${log_dir_curr}/${TWS_XTRACE_DIR}/jobman.snap_file.xml 2>>$summary_log
                fi
            #jobmon
                echo "Generating xtrace snaphot files for jobmon" >> $summary_log
                ./xcli -snap ${log_dir_curr}/${TWS_XTRACE_DIR}/jobmon.snap_file -p jobmon >> $summary_log 2>&1
                if [ -f  ${log_dir_curr}/${TWS_XTRACE_DIR}/jobmon.snap_file ]
                then
                    ./xcli -format ${log_dir_curr}/${TWS_XTRACE_DIR}/jobmon.snap_file -d ${TWS_basePath}/xtrace/xdb.dat -xml > ${log_dir_curr}/${TWS_XTRACE_DIR}/jobmon.snap_file.xml 2>>$summary_log
                fi
            #monman
                echo "Generating xtrace snaphot files for monman" >> $summary_log
                ./xcli -snap ${log_dir_curr}/${TWS_XTRACE_DIR}/monman.snap_file -p monman >> $summary_log 2>&1
                if [ -f  ${log_dir_curr}/${TWS_XTRACE_DIR}/monman.snap_file ]
                then
                    ./xcli -format ${log_dir_curr}/${TWS_XTRACE_DIR}/monman.snap_file -d ${TWS_basePath}/xtrace/xdb.dat -xml > ${log_dir_curr}/${TWS_XTRACE_DIR}/monman.snap_file.xml 2>>$summary_log
                fi
            #mailman
                echo "Generating xtrace snaphot files for mailman" >> $summary_log
                ./xcli -snap ${log_dir_curr}/${TWS_XTRACE_DIR}/mailman.snap_file -p mailman >> $summary_log 2>&1
                if [ -f  ${log_dir_curr}/${TWS_XTRACE_DIR}/mailman.snap_file ]
                then
                    ./xcli -format ${log_dir_curr}/${TWS_XTRACE_DIR}/mailman.snap_file -d ${TWS_basePath}/xtrace/xdb.dat -xml > ${log_dir_curr}/${TWS_XTRACE_DIR}/mailman.snap_file.xml 2>>$summary_log
                fi
            #netman
                echo "Generating xtrace snaphot files for netman" >> $summary_log
                ./xcli -snap ${log_dir_curr}/${TWS_XTRACE_DIR}/netman.snap_file -p netman >> $summary_log 2>&1
                if [ -f  ${log_dir_curr}/${TWS_XTRACE_DIR}/netman.snap_file ]
                then
                    ./xcli -format ${log_dir_curr}/${TWS_XTRACE_DIR}/netman.snap_file -d ${TWS_basePath}/xtrace/xdb.dat -xml > ${log_dir_curr}/${TWS_XTRACE_DIR}/netman.snap_file.xml 2>>$summary_log
                fi
            #writer
                echo "Generating xtrace snaphot files for writer" >> $summary_log
                ./xcli -snap ${log_dir_curr}/${TWS_XTRACE_DIR}/writer.snap_file -p writer >> $summary_log 2>&1
                if [ -f  ${log_dir_curr}/${TWS_XTRACE_DIR}/writer.snap_file ]
                then
                    ./xcli -format ${log_dir_curr}/${TWS_XTRACE_DIR}/writer.snap_file -d ${TWS_basePath}/xtrace/xdb.dat -xml > ${log_dir_curr}/${TWS_XTRACE_DIR}/writer.snap_file.xml 2>>$summary_log
                fi
            #java
                echo "Generating xtrace snaphot files for java" >> $summary_log
                ./xcli -snap ${log_dir_curr}/${TWS_XTRACE_DIR}/java.snap_file -p java >> $summary_log 2>&1
                if [ -f  ${log_dir_curr}/${TWS_XTRACE_DIR}/java.snap_file ]
                then
                    ./xcli -format ${log_dir_curr}/${TWS_XTRACE_DIR}/java.snap_file -d ${TWS_basePath}/xtrace/xdb.dat -xml > ${log_dir_curr}/${TWS_XTRACE_DIR}/java.snap_file.xml 2>>$summary_log
                fi
            #appservman
                echo "Generating xtrace snaphot files for appservman" >> $summary_log
                ./xcli -snap ${log_dir_curr}/${TWS_XTRACE_DIR}/appservman.snap_file -p appservman >> $summary_log 2>&1
                if [ -f  ${log_dir_curr}/${TWS_XTRACE_DIR}/appservman.snap_file ]
                then
                    ./xcli -format ${log_dir_curr}/${TWS_XTRACE_DIR}/appservman.snap_file -d ${TWS_basePath}/xtrace/xdb.dat -xml > ${log_dir_curr}/${TWS_XTRACE_DIR}/appservman.snap_file.xml 2>>$summary_log
                fi
                #cd - >/dev/null
            else
                echo "Not enough space in ${log_dir_curr} for xcli results." >> $summary_log 2>&1
            fi #End of if available space for xtrace

        fi #End of if ${TWS_basePath}/xtrace directory exists

    fi



    #The following will gather Tivoli information depending if pre or post TWS 8.3
    #****************************************************************
    #Added 06/20/08 PSJ
    #Added checking of TWS version
    #Added 08/07/08 PSJ
    #Added pull of data specific to 8.3 or greater
    #Extract TWS 8.3 or later optman info
    echo "Extracting  TWS 8.3 or later optman info (if applicable) to ${log_dir_curr}/${TWSINFO_DIR}/optman_ls_info.txt." >> $summary_log
    if [ -f ${TWS_basePath}/bin/optman ]
    then
        ${TWS_basePath}/bin/optman ls > ${log_dir_curr}/${TWSINFO_DIR}/optman_ls_info.txt 2>>$summary_log &
    fi

    #Added 06/20/08 PSJ
    #Added pulling of planman "showinfo" data
    #Extract planman "showinfo"
    echo "Extracting  TWS 8.3 or later planman showinfo (if applicable) to ${log_dir_curr}/${TWSINFO_DIR}/planman_showinfo.txt." >> $summary_log
    if [ -f ${TWS_basePath}/bin/planman ]
    then
        ${TWS_basePath}/bin/planman "showinfo" > ${log_dir_curr}/${TWSINFO_DIR}/planman_showinfo.txt 2>>$summary_log &
    fi

} # End gather_tws_information

gather_agent_information()
{
        if [ "${DEBUG}" = "y" ]; then set -vx; fi

    #Gather agent config/ini and log files
    if [ -d ${TWS_datadir}/ITA ]
    then
        mkdir ${log_dir_curr}/dynamic_agent 2>>$summary_log

        if [ -d ${log_dir_curr}/${STDLIST_DIR}/JM ]
        then
            cd ${log_dir_curr}/dynamic_agent
            ln -s ../${STDLIST_DIR}/JM JM_logs
            cd ${TWS_datadir}
        fi

        source_item=${TWS_datadir}/ITA
        calc_disk_space_usage_and_avail
        if [ "${ENOUGH_SPACE}" = "y" ]
        then
            cp -pR ${TWS_datadir}/ITA ${log_dir_curr}/dynamic_agent 2>>$summary_log
        fi
        find ${log_dir_curr}/dynamic_agent -type s | xargs rm 2>>$summary_log
        for j in codeset lib msg_cat icons catalog
        do
            find ${log_dir_curr}/dynamic_agent -type d -name $j | xargs rm -rf 2>>$summary_log
        done

        for dir in teb cit
        do
            if [ -d /etc/${dir} ] && [ -w /etc/${dir} ]
            then
                source_item=/etc/${dir}
                calc_disk_space_usage_and_avail
                if [ "${ENOUGH_SPACE}" = "y" ]
                then
                    mkdir ${log_dir_curr}/dynamic_agent/etc_${dir}
                    cp -pR /etc/${dir} ${log_dir_curr}/dynamic_agent/etc_${dir}
                fi
            fi
        done

        for dir in cache_data config install properties
        do
            if [ -d /opt/tivoli/cit/${dir} ] && [ -w /opt/tivoli/cit/${dir} ]
            then
                source_item=/opt/tivoli/cit/${dir}
                calc_disk_space_usage_and_avail
                if [ "${ENOUGH_SPACE}" = "y" ]
                then
                    mkdir -p ${log_dir_curr}/dynamic_agent/opt_tivoli_cit/${dir}
                    cp -pR /opt/tivoli/cit/${dir} ${log_dir_curr}/dynamic_agent/opt_tivoli_cit/${dir}
                fi
            fi
        done

        for tebctl in `ls /etc/rc.d/init.d/tebctl* 2>/dev/null; ls /etc/init.d/tebctl* 2>/dev/null`
        do
            source_item=$tebctl
            calc_disk_space_usage_and_avail
            if [ "${ENOUGH_SPACE}" = "y" ]
            then
                cp $tebctl ${log_dir_curr}/dynamic_agent
            fi
        done

        if [ -d ${TWS_datadir}/jmJobTableDir ]
        then
            mkdir ${log_dir_curr}/dynamic_agent/jmJobTableDir 2>>$summary_log
            source_item=${TWS_datadir}/jmJobTableDir
            calc_disk_space_usage_and_avail
            if [ "${ENOUGH_SPACE}" = "y" ]
            then
                echo "Copying ${TWS_datadir}/jmJobTableDir/* to ${log_dir_curr}/dynamic_agent/jmJobTableDir" >> $summary_log
                cp -pR ${TWS_datadir}/jmJobTableDir/* ${log_dir_curr}/dynamic_agent/jmJobTableDir 2>>$summary_log
            fi
        fi


    fi

    #Gather config and log files in JavaExt (new job types)...added 12/28/2016
    if [ -d ${TWS_datadir}/JavaExt ]
    then
        mkdir -p ${log_dir_curr}/dynamic_agent/JavaExt 2>>$summary_log
        cp -pR ${TWS_datadir}/JavaExt/cfg ${log_dir_curr}/dynamic_agent/JavaExt 2>>$summary_log
        cp -pR ${TWS_datadir}/JavaExt/logs ${log_dir_curr}/dynamic_agent/JavaExt 2>>$summary_log
    fi
}

gather_event_info()
{
    if [ "${DEBUG}" = "y" ]; then set -vx; fi

    if [ -d $TWS_datadir/ssm ]
    then
        mkdir -p ${log_dir_curr}/${EVENT_DIR}/ssm 2>>$summary_log
        cp -pr $TWS_datadir/ssm/log ${log_dir_curr}/${EVENT_DIR}/ssm 2>>$summary_log
        cp -pr $TWS_datadir/ssm/config ${log_dir_curr}/${EVENT_DIR}/ssm 2>>$summary_log
        cp -pr $TWS_datadir/ssm/eif ${log_dir_curr}/${EVENT_DIR}/ssm 2>>$summary_log
    fi
    #Gather monconf files
    if [ -d $TWS_datadir/monconf ]
    then
        cp -pr $TWS_datadir/monconf ${log_dir_curr}/${EVENT_DIR} 2>>$summary_log
    fi
    #Gather EIF files ... added 7/6/2012
    if [ -d $TWS_datadir/EIF ]
    then
        cp -pr $TWS_datadir/EIF ${log_dir_curr}/${EVENT_DIR}/EIF 2>>$summary_log
    fi
    if [ -f ${log_dir_curr}/${TWSINFO_DIR}/conman_output_files/conman_sc_getmon.out ]
    then
        cp -pr ${log_dir_curr}/${TWSINFO_DIR}/conman_output_files/conman_sc_getmon.out ${log_dir_curr}/${EVENT_DIR} 2>>$summary_log
    fi
    #Gather Dynamic Agent event files...added 12/28/2016
    if [ -d $TWS_datadir/EDWA ]
    then
        mkdir -p ${log_dir_curr}/${EVENT_DIR}/DynamicAgent_Event_Info/ssm 2>>$summary_log
        cp -pr $TWS_datadir/EDWA/ssm/log ${log_dir_curr}/${EVENT_DIR}/DynamicAgent_Event_Info/ssm 2>>$summary_log
        cp -pr $TWS_datadir/EDWA/ssm/config ${log_dir_curr}/${EVENT_DIR}/DynamicAgent_Event_Info/ssm 2>>$summary_log
        cp -pr $TWS_datadir/EDWA/ssm/eif ${log_dir_curr}/${EVENT_DIR}/DynamicAgent_Event_Info/ssm 2>>$summary_log
        cp -pr $TWS_datadir/EDWA/monconf ${log_dir_curr}/${EVENT_DIR}/DynamicAgent_Event_Info 2>>$summary_log
        cp -pr $TWS_datadir/EDWA/EIF ${log_dir_curr}/${EVENT_DIR}/DynamicAgent_Event_Info 2>>$summary_log
    fi

} # End gather_event_info


gather_was_information()
{
    if [ "${NO_WAS}" = "y" ]; then return; fi
    if [ "${DEBUG}" = "y" ]; then set -vx; fi
	#Added 06/20/08 PSJ
	#Added checking of TWS version
	#Changed test.  If WAS directory exists then it is 8.3 or greater and will pull file specific
	#to TWS version 8.3, 8.4 or 8.5.
    if [ "${WLP_DIR_exists}" = "y" ]
    then
        mkdir -p ${log_dir_curr}/${WLPINFO_DIR} 2>>$summary_log
	if [ -d "${TWS_wlpdir}" ]; then
	        COMP=TWS95;export COMP
	elif [ -d "${DWC_wlpdir}" ]; then
                COMP=DWC95;export COMP
	fi
echo "*****Gathering ${COMP} wlp specific information.*******" | tee -a $summary_log
        mkdir -p ${log_dir_curr}/${WLPINFO_DIR}/${COMP} 2>>$summary_log
	mkdir -p ${log_dir_curr}/${WLPINFO_DIR}/${COMP}/wlp_files 2>>$summary_log

	    echo "Copying listing of WLP config files to ${log_dir_curr}/${WLPINFO_DIR}/wlp_config_listing.txt." >> $summary_log
	    ls -lR $WLP_DIR/* > ${log_dir_curr}/${WLPINFO_DIR}/${COMP}_wlp_config_listing.txt 2>>$summary_log
	
	    echo "Copying WLP config files to ${log_dir_curr}/${WLPINFO_DIR}/${COMP} directory." >> $summary_log
	    if [ "${COMP}" == "DWC95" ]; then
		    for target in bootstrap.properties configDropins dwc_workarea jvm.options platform/configuration registry resources/properties resources/security server.env server.xml
		    do
	    source_item="${WLP_DIR}/servers/dwcServer/${target}"
	    calc_disk_space_usage_and_avail
	    if [ "${ENOUGH_SPACE}" = "y" ]
	    then
	        cp -prL ${WLP_DIR}/servers/dwcServer/${target} ${log_dir_curr}/${WLPINFO_DIR}/${COMP}/wlp_files 2>>$summary_log
	    fi
	    	    done
            elif [ "${COMP}" == "TWS95" ]; then
		    for target in bootstrap.properties configDropins jvm.options platform/configuration registry resources/properties resources/security server.env server.xml
		    do
            source_item="${WLP_DIR}/servers/engineServer/${target}"
            calc_disk_space_usage_and_avail
            if [ "${ENOUGH_SPACE}" = "y" ]
            then
                cp -prL ${WLP_DIR}/servers/engineServer/${target} ${log_dir_curr}/${WLPINFO_DIR}/${COMP}/wlp_files 2>>$summary_log
            fi

		    done
	    fi

	
	mkdir -p ${log_dir_curr}/${WLPINFO_DIR}/${COMP}/logs
	    if [ "${COMP}" == "DWC95" ]; then
		    for target in derby.log logs registry tranlog workarea/com.ibm.ws.jmx.local.address workarea/equinox.log workarea/platform
		    do
	source_item="${WLP_LOGDIR}/dwcServer"
	calc_disk_space_usage_and_avail
	if [ "${ENOUGH_SPACE}" = "y" ]
        then
		cp -prL ${WLP_LOGDIR}/dwcServer/${target} ${log_dir_curr}/${WLPINFO_DIR}/${COMP}/logs 2>>$summary_log
	fi	  
		    done
	   elif [ "${COMP}" == "TWS95" ]; then
              for target in audit *.log logs temp tranlog workarea/com.ibm.ws.jmx.local.address workarea/equinox.log workarea/platform
                    do
        source_item="${WLP_LOGDIR}/engineServer"
        calc_disk_space_usage_and_avail
        if [ "${ENOUGH_SPACE}" = "y" ]
        then
                cp -prL ${WLP_LOGDIR}/engineServer/${target} ${log_dir_curr}/${WLPINFO_DIR}/${COMP}/logs 2>>$summary_log
        fi
                    done

   fi	
	   #MKD Added gather of files under TWA/TDWB
	    if [ -d "${TWS_datadir}/broker" ]
	    then
	        mkdir ${log_dir_curr}/${WLPINFO_DIR}/${COMP}/TWA_TDWB_files 2>/dev/null
	        ls -lR ${TWS_datadir}/broker > ${log_dir_curr}/${WLPINFO_DIR}/${COMP}/TWA_TDWB_filelist.out 2>>$summary_log
	        for element in audit config logs
	        do
	            if [ -e "${TWS_datadir}/broker/${element}" ]
	                        then
	                            source_item="${TWS_datadir}/broker/${element}"
	                calc_disk_space_usage_and_avail
	                            if [ "${ENOUGH_SPACE}" = "y" ]
	                            then
	                    cp -pR ${TWS_datadir}/broker/${element} ${log_dir_curr}/${WLPINFO_DIR}/${COMP}/TWA_TDWB_files 2>>$summary_log
	                fi
	            fi
	        done
	    fi

	fi
} #End gather_was_information



gather_install_information()
{
    if [ "${DEBUG}" = "y" ]; then set -vx; fi

    echo "*****Gathering TWA install information .*************" | tee -a $summary_log

    for source_item in  /tmp/twsinst* /tmp/TWA* /tmp/tws9*
    do
        if [ -e $source_item ]
        then
            if [ ! -d ${log_dir_curr}/${TWS_INSTALL_LOGS} ]
            then
                mkdir ${log_dir_curr}/${TWS_INSTALL_LOGS}
            fi

            calc_disk_space_usage_and_avail
            if [ "${ENOUGH_SPACE}" = "y" ]
            then
                echo "Copying ${source_item} to ${log_dir_curr}." >> $summary_log
                cp -pr ${source_item} ${log_dir_curr}/${TWS_INSTALL_LOGS} 2>>$summary_log
            fi
        fi
    done

    #Gather misc install logs
    for i in `ls /tmp/*TWS*.log 2>>$summary_log`
    do
        if [ ! -d ${log_dir_curr}/${TWS_INSTALL_LOGS} ]
        then
                mkdir ${log_dir_curr}/${TWS_INSTALL_LOGS}
        fi

        if [ -f $i ]
        then
            source_item="$i"
            calc_disk_space_usage_and_avail
            if [ "${ENOUGH_SPACE}" = "y" ]
            then
                echo "Copying ${source_item} to ${log_dir_curr}." >> $summary_log
                cp -pr ${source_item} ${log_dir_curr}/${TWS_INSTALL_LOGS} 2>>$summary_log
            fi
        fi
    done


    #Gather TWA/logs for 9.x install logs. 3/10/2017
    if [ -d ${TWA_home}/logs ]
    then
        mkdir -p {log_dir_curr}/${TWS_INSTALL_LOGS}/TWA_logs 2>>$summary_log
        source_item="${TWA_home}/logs"
        calc_disk_space_usage_and_avail
        if [ "${ENOUGH_SPACE}" = "y" ]
        then
            echo "Copying ${source_item} to ${log_dir_curr}." >> $summary_log
            cp -pr ${source_item} ${log_dir_curr}/${TWS_INSTALL_LOGS}/TWA_logs 2>>$summary_log
        fi
    fi
    
    #Gather TWA/logs for 9.x install logs. 3/10/2017
    if [ -d ${TWS_datadir}/installation ]
    then
        mkdir -p {log_dir_curr}/${TWS_INSTALL_LOGS}/TWA95_instlogs 2>>$summary_log
        source_item="${TWS_datadir}/installation"
        calc_disk_space_usage_and_avail
        if [ "${ENOUGH_SPACE}" = "y" ]
        then
            echo "Copying ${source_item} to ${log_dir_curr}." >> $summary_log
            cp -pr ${source_item} ${log_dir_curr}/${TWS_INSTALL_LOGS}/TWA95_instlogs 2>>$summary_log
        fi
    fi
    
    

} # End gather_install_information

# Function to format the extract_tws_instances output uniformly
format_text()
{
    if [ "${DEBUG}" = "y" ]; then set -vx; fi
# $command is the full string sent to this function
# Formatted text is returned so that the line length does not exceed 72 chars

        title=`echo "$command" | awk -F: '{print $1":"}'`
        title_size=`echo $title | wc -c`
        if [ $title_size -ge 8 ]; then title=`echo $title | cut -c 1-8 | awk -F: '{print $1": "}'`;fi
        if [ $title_size -lt 8 ]; then title=`echo $title | awk -F: '{print $1":          "}'`;fi
        results=`echo "$command" | awk -F: '{$1=""; print $0}'`
        command="$title$results"

# If the length of the string is too great then we fold in a controlled manner
if [ `echo "$command" | wc -c` -ge 65 ]
then
        # Remove the ":" character from the first word to allow for a uniform search and replace statement
        title=`echo "$command" | awk '{print $1}' | awk -F: '{print $1}'`

        # Use the fold command to break lines at the end of a word in less than 65 characters
        command_split=`echo "$command" | fold -sw 65 | awk '{print $0}'`

        # Search across two lines of text and indent the second line
        echo "$command_split" | sed -n "
        /"$title"/ {
        N
        /\n.*/ {
        s/\("$title".*\n\)\(.*\)/\1         \2/p
        }
        }"
else
        echo "$command"
fi
}

extract_tws_instances()
{
if [ "${DEBUG}" = "y" ]; then set -vx; fi

# Display machine specific information to instances_info
# All output is being sent to OUT_FILE
# Formatting the text sent to OUT_FILE using the format_text function
echo "*****Gathering ALL TWA instance information .********" | tee -a $summary_log

OUT_FILE=${log_dir_base}/TWS_${CREATED_DATE_TIME}/TWA_instances_list;export OUT_FILE
PORT_FILE=${log_dir_base}/TWS_${CREATED_DATE_TIME}/TWA_ports_list;export PORT_FILE
echo "************ SERVER INFORMATION *************" > $OUT_FILE
echo "************ PORT INFORMATION *************" > $PORT_FILE
command=`echo "uname -a: \`uname -a\`"`; format_text >> $OUT_FILE
HOSTNAME=`uname -n`;export HOSTNAME
if [ -f /usr/bin/host ]
then
        command=`echo "host_cmd: \`host $HOSTNAME 2>/dev/null\`" 2>/dev/null`; format_text >> $OUT_FILE
        #IP=`host \`uname -n\` | tail -1 | sed 's/*\([0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\).*/\1/'`
        IP=`host 2>/dev/null \`uname -n\` | tail -1 | awk '{print $NF}'` # sed 's/*\([0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\).*/\1/'`
        command=`echo "IP_ADDRESS: $IP"`; format_text >> $OUT_FILE
        command=`echo "REV_LOOK: \`host $IP 2>/dev/null\`"`; format_text >> $OUT_FILE
elif [ -f /usr/bin/nslookup ]
then
        command=`echo "nslookup: \`nslookup $HOSTNAME | tail -3 | head -2 | xargs echo\`"`; format_text >> $OUT_FILE 2>>$support_log
        IP=`nslookup \`uname -n\` | grep "Address" | tail -1 | sed 's/.*\([0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\).*/\1/' 2>>$support_log`
        command=`echo "IP_ADDRESS: $IP"`; format_text >> $OUT_FILE
        command=`echo "REV_LOOK: \`nslookup $IP | tail -3 | head -2 | xargs echo\`"`; format_text >> $OUT_FILE 2>>$support_log
elif [ -f /usr/bin/getent ]
then
	command=`echo "getent hosts: \`getent ahostsv4 $HOSTNAME | grep STREAM\`"`; format_text >> $OUT_FILE #2>>$support_log
	IP=`getent ahostsv4 $HOSTNAME | grep STREAM | awk '{print $1}'`
	command=`echo "IP_ADDRESS: $IP"`; format_text >> $OUT_FILE
	command=`echo "REV_LOOK: \`getent hosts $IP\`"`; format_text >> $OUT_FILE #2>>$support_log
fi
# Find target TWS instance in the ${TWS_REG_FILE} file
if [ -f /etc/TWS/TWSRegistry.dat ]
then
    TWS_REG_FILE=/etc/TWS/TWSRegistry.dat; export TWS_REG_FILE
    echo $tws_user | grep _ >/dev/null 2>&1
    underRC=$?
    if [ ${underRC} -eq 0 ]
    then
        userFields=`echo $tws_user | grep _ | awk -F_ '{ total = total + NF }; END {print total}' 2>>$summary_log`
        underscoreCount=`expr \( $userFields - 1 \)`
        if [ $underscoreCount -eq 0 ]; then printOut="\$1\"_\"\$2"; fi
        if [ $underscoreCount -eq 1 ]; then printOut="\$1\"_\"\$2\"_\"\$3"; fi
        if [ $underscoreCount -eq 2 ]; then printOut="\$1\"_\"\$2\"_\"\$3\"_\"\$4"; fi
        if [ $underscoreCount -eq 3 ]; then printOut="\$1\"_\"\$2\"_\"\$3\"_\"\$4\"_\"\$5"; fi
    else
        printOut="\$1\"_\"\$2"
    fi

    for instance in `grep ${tws_user}_DN_ou ${TWS_REG_FILE} | sort | uniq | awk -F_ '{print '$printOut'}' 2>>$summary_log`
    do
            echo "************ ${tws_user} INSTANCE INFORMATION ************" >> $OUT_FILE
            echo "--FROM-- TWSRegistry.dat" >> $OUT_FILE
	        echo "${tws_user} port information" >> $PORT_FILE
            for element in UserOwner Agent PackageName InstallationPath
            do
                    command=`echo "$element:" \`grep "$instance"_DN_"$element" ${TWS_REG_FILE} | awk -F= '{print $2}'\``; format_text >> $OUT_FILE

                    if [ "$element" = "UserOwner" ]
                    then
                            TWSUSER=`grep "$instance"_DN_"$element" ${TWS_REG_FILE} | awk -F= '{print $2}'`; export TWSUSER
                    fi
                    if [ "$element" = "InstallationPath" ]
                    then
                            TWSPATH=`grep "$instance"_DN_"$element" ${TWS_REG_FILE} | awk -F= '{print $2}'`; export TWSPATH
                    fi
            done

            # For instances in TWSRegistry.dat we look for the same UserOwner in /etc/TWA/*properties
            if [ -d /etc/TWA ]; then
    		        grep -l user_name="$TWSUSER\$" /etc/TWA/twainstance*.TWA.properties >/dev/null 2>&1
            		USERINREG=$?
                    if [ ${USERINREG} -eq 0 ]; then
                            TWAINSTFILE=`grep -l user_name="$TWSUSER\$" /etc/TWA/twainstance*.TWA.properties 2>>$summary_log | head -1`
                            echo "--FROM-- $TWAINSTFILE"   >> $OUT_FILE
                            # Retrieve twainstance properties.
                            for twaelement in TWA_componentList TWS_version TWS_basePath DWC_basePath DWC_version TWS_datadir DWC_datadir TWS_wlpdir DWC_wlpdir TWS_jdbcdir DWC_jdbcdir
                            do
                                    if [ `grep $twaelement $TWAINSTFILE | wc -l` -ge 1 ]; then
                                            command=`echo \`grep $twaelement $TWAINSTFILE 2>>$summary_log | sed 's/=/:/'\``; format_text >> $OUT_FILE
                                    fi
                            done
		            TWSDATA=`grep "TWS_datadir=" ${TWAINSTFILE} | awk -F= '{print $2}'`; export TWSDATA
                    else
                    	TWSDATA=$TWSPATH; export TWSDATA
                    fi # End of if USERINREG

            # Gather local configuration information
            if [ -f ${TWS_datadir}/localopts ]; then
                    echo "--FROM-- $TWS_datadir/localopts" >> $OUT_FILE
                    #command=`echo "thiscpu:" \`grep -i "thiscpu" $TWSDATA/localopts 2>>$summary_log | awk -F= '{print $2}'\``; format_text >> $OUT_FILE
                    command=`echo "thiscpu: \`grep -i \"thiscpu\" $TWSDATA/localopts 2>>$summary_log | awk -F= '{print $2}'\`"`; format_text >> $OUT_FILE
                    command=`echo "\`grep -i \"^nm port\" $TWSDATA/localopts 2>>$summary_log | sed 's/\ *=/:\  /'\`"`; format_text >> $OUT_FILE
                    echo "  `grep -i \"^nm port\" $TWSDATA/localopts 2>>$summary_log | sed 's/\ *=/:\  /'`" >> $PORT_FILE
                    echo "  `grep -i \"^nm SSL port\" $TWSDATA/localopts 2>>$summary_log | sed 's/\ *=/:\  /'`" >> $PORT_FILE
            else
                    echo "$TWSDATA/localopts NOT found" >> $OUT_FILE
            fi # End of if localopts
            
	        if [ -f $TWSDATA/ssm/eif/tecad_snmp_eeif.conf ]; then
	            echo "  eif ServerPort: `grep ServerPort ${TWSDATA}/ssm/eif/tecad_snmp_eeif.conf 2>>$summary_log | awk -F= '{print $2}'`" >> $PORT_FILE
	        fi
	
	        if [ -f ${TWSDATA}/ITA/cpa/ita/ita.ini ]; then
	            itaIniFile=${TWSDATA}/ITA/cpa/ita/ita.ini
	        else
	            if [ -f ${TWSDATA}/ITA/bin/ita.ini ]; then
	                itaIniFile=${TWSDATA}/ITA/bin/ita.ini
	            fi
	        fi
	        if [ "$itaIniFile" != "" ]; then
	            TCP_PORT=`grep "^tcp_port" ${itaIniFile} 2>>$summary_log | awk -F= '{print $2}'`
	            if [ "${TCP_PORT}" != "" ]; then
	                if [ ${TCP_PORT} -ne 0 ]; then
	                    echo "  JobManager/ITA tcp_port: ${TCP_PORT}" >> $PORT_FILE
	                fi
	            fi
	            SSL_PORT=`grep "^ssl_port" ${itaIniFile}  2>>$summary_log| awk -F= '{print $2}'`
	            if [ "${SSL_PORT}" != "" ]; then
	                if [ ${SSL_PORT} -ne 0 ]; then
	                    echo "  JobManager/ITA ssl_port: ${SSL_PORT}" >> $PORT_FILE
	                fi
	            fi
	        fi # End of if itaIniFile

            # Gather master setting from globalopts
            if [ -f ${TWSDATA}/mozart/globalopts ]
            then
                    echo "--FROM-- $TWSDATA/mozart/globalopts" >> $OUT_FILE
                    command=`echo "master:" \`grep -i "master" $TWS_datadir/mozart/globalopts 2>>$summary_log | awk -F= '{print $2}'\``; format_text >> $OUT_FILE
            else
                    echo "$TWSDATA/mozart/globalopts NOT found" >> $OUT_FILE
            fi

            # Grab the last line of the patch.info file if it exists
            if [ -f ${TWSPATH}/version/patch.info ]
            then
                    echo "--FROM-- ${TWSPATH}/version/patch.info" >> $OUT_FILE
                    command=`echo \`tail -1 $TWSPATH/version/patch.info | awk '{print "patch: " $0}'\``; format_text >> $OUT_FILE
            fi
            # Xagent version commands
            for mfile in r3batch mvsca7 mvsopc mvsjes mcmagent
            do
                    if [ -f ${TWSPATH}/methods/${mfile} ]
                    then
		                go=yes
		
		                if [ "${mfile}" = "r3batch" ]
		                then
		                    echo "Test for libs required for r3batch.bin" >> $summary_log
		                    if [ `ldd ${TWSPATH}/methods/$mfile.bin 2>&1 | grep "not found" | wc -l` -ge 1 ] || [ `ldd ${TWSPATH}/methods/$mfile.bin 2>&1 | grep "Cannot find" | wc -l` -ge 1 ]
		                    then
		                        echo "Missing libs for r3batch.bin" >> $summary_log
		                        go=no
		                    fi
		                fi
		                if [ "${go}" = "yes" ]
		                then
		                    echo "--METHOD-- ${TWSPATH}/methods/$mfile" >> $OUT_FILE
		                    command=`echo "$mfile -v:" \`${TWSPATH}/methods/$mfile -v | xargs echo | awk -FC\) '{print $NR}' 2>>$summary_log\``; format_text >> $OUT_FILE
		                fi
                   fi # End of if mfile
            done # End of for mfile
	fi
    done

fi # End of if TWSRegistry.dat condition
#DWC information:
            if [ -d /etc/TWA ]
            then
	    	for TWAPROPFILE in `ls /etc/TWA/twainstance?.TWA.properties`
	        do
			if [ `grep TWA_componentList $TWAPROPFILE 2>>$summary_log | grep DWC | grep -v TWS` ]
               		then
                        	echo "************ STANDALONE DWC INSTANCE ************" >> $OUT_FILE
	                        echo "--FROM-- $TWAPROPFILE" >> $OUT_FILE
       		                echo `egrep "DWC_user_name" $TWAPROPFILE 2>>$summary_log | awk -F= '{print "DWC ports for "$1" "$2}'` >> $PORT_FILE
			    	for tdwcelement in EWas_service_name TWA_componentList TDWC_basePath TDWC_version EWas_server_name EWas_basePath EWas_profile_name EWas_profile_path EWas_cell_name EWas_node_name EWas_user TWA_path DWC_version DWC_basePath DWC_user_name DWC_wlpdir DWC_datadir DWC_jdbcdir
      		              	do
               		     		grep $tdwcelement $TWAPROPFILE > /dev/null 2>&1
                       			ISELEMENT=$?
		                       	if [ ${ISELEMENT} -eq 0 ]; then
						command=`echo \`grep $tdwcelement $TWAPROPFILE 2>>$summary_log | sed 's/=/:/'\``; format_text >> $OUT_FILE
					if [ "${tdwcelement}" == "DWC_basePath" ]; then
						export DWC_basePath=`grep "DWC_basePath=" $TWAPROPFILE | awk -F\= '{print $NF}'`
						if [ -f "${DWC_basePath}/usr/servers/dwcServer/configDropins/overrides/ports_variables.xml" ]
						then
							portfile="${DWC_basePath}/usr/servers/dwcServer/configDropins/overrides/ports_variables.xml"
							for portname in http.port https.port bootstrap.port bootstrap.port.sec
							do 
								command=`echo \`grep "${portname}\" value" ${portfile} 2>>$summary_log | sed 's/.*name=\"host.\(.*\)\" value=\"\([0-9]*\)\".*/\1:\2/'\``; format_text >> $PORT_FILE
							done
							
						fi
					fi
					fi
				done
			fi
		done
	    fi
}

gen_autopd()
{
    if [ "${DEBUG}" = "y" ]; then set -vx; fi
   # Function to generate xml file for data collector discovery

   # Directory <BASEdir>/autopdzip/autopd
   mkdir -p ${log_dir_base}/TWS_${CREATED_DATE_TIME}/autopdzip/autopd

   # Copy file for PMR stamping from instances_info to pmrstamp.info
   cp ${log_dir_base}/TWS_${CREATED_DATE_TIME}/TWA_instances_list ${log_dir_base}/TWS_${CREATED_DATE_TIME}/autopdzip/autopd/pmrstamp.info

   # File autopd-collection-environment-v2.xml
   AUTOPD_FILE=${log_dir_base}/TWS_${CREATED_DATE_TIME}/autopdzip/autopd/autopd-collection-environment-v2.xml

   # Create xml file

   echo '<?xml version="1.0" encoding="UTF-8"?>' > $AUTOPD_FILE
   echo '<collectionEnvironmentInfo pluginTaxonomyId="SSGSPN" toolName="tws_inst_pull_info" toolVersion="3.7" xmlns="http://www.ibm.com/autopd/collectionEnvironment" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.ibm.com/autopd/collectionEnvironment ../autoPD-collection-env.xsd" />' >> $AUTOPD_FILE

}

package_files()
{
    if [ "${DEBUG}" = "y" ]; then set -vx; fi

    #Added 02/11/09 PSJ
    #Added logging of pulled data to a file using date of pulled data.
    echo "Files for TWS instance ${tws_cpu} have been copied to the ${log_dir_curr} directory." >> $summary_log
    echo "and are listed in file ${log_dir_curr}/${today}_files.txt." >> $summary_log

    #Added 03/13/08 PSJ
    #Added display of all error or warning message(s) to text file.
    if [ "${MAIN_ERR_MSG}" != "" ]
    then
        echo "${MAIN_ERR_MSG}\n" >> ${log_dir_curr}/${today}_script_errors.txt
    fi

    echo "Will create tarfile TWS_${CREATED_DATE_TIME}.tar in the ${log_dir_base} directory." >> $summary_log

    # Test for available space:
    source_item="${log_dir_base}/TWS_${CREATED_DATE_TIME}"
    calc_disk_space_usage_and_avail
    if [ "${ENOUGH_SPACE}" = "y" ]
    then
        cd ${log_dir_base}
        tar -cf TWS_${CREATED_DATE_TIME}.tar TWS_${CREATED_DATE_TIME}
        echo "Tarfile ${CREATED_DATE_TIME}.tar was created in the ${log_dir_base} directory." >> $summary_log

        #Added 06/27/08
        #Added use of gzip for Linux_i386
        if [ "${OS}" = "LINUX_I386" ]
        then
            echo "Compressing tarfile TWS_${CREATED_DATE_TIME}.tar." >> $summary_log
            gzip ${log_dir_base}/TWS_${CREATED_DATE_TIME}.tar 2>>$summary_log

            echo "Compressed tarfile TWS_${CREATED_DATE_TIME}.tar.gz has been created" >> $summary_log
            echo "in the ${log_dir_base} directory." >> $summary_log

            echo " " | tee -a $summary_log
            echo "**Note: ${log_dir_base}/TWS_${CREATED_DATE_TIME} may contain root owned files." | tee -a $summary_log
            echo " " | tee -a $summary_log
            echo "Send ${log_dir_base}/TWS_${CREATED_DATE_TIME}.tar.gz to L2 via ecurep:" | tee -a $summary_log
        else
            echo "Compressing tarfile TWS_${CREATED_DATE_TIME}.tar." >> $summary_log
            compress ${log_dir_base}/TWS_${CREATED_DATE_TIME}.tar 2>>$summary_log

            echo "Compressed tarfile TWS_${CREATED_DATE_TIME}.tar.Z has been created" >> $summary_log
            echo "in the ${log_dir_base} directory." >> $summary_log

            echo " " | tee -a $summary_log
            echo "**Note: ${log_dir_base}/TWS_${CREATED_DATE_TIME} may contain root owned files." | tee -a $summary_log
            echo " " | tee -a $summary_log
            echo "Send ${log_dir_base}/TWS_${CREATED_DATE_TIME}.tar.Z to L2 via ecurep:" | tee -a $summary_log
        fi
    else
        echo "There is not enough space in ${log_dir_curr} to create a tar file in place." | tee -a $summary_log
        echo " " | tee -a $summary_log
        echo "Either move the ${log_dir_curr} to a filesystem with more than ${space} available or make space available in ${log_dir_curr}'s filesystem." | tee -a $summary_log
        echo "Then package the contents using:" | tee -a $summary_log
        echo "tar -cvf TWS_${CREATED_DATE_TIME}.tar TWS_${CREATED_DATE_TIME}" | tee -a $summary_log
        echo "Then compress the tar file using compress or gzip and send to L2 via ecurep" | tee -a $summary_log
    fi
} # End package_files

mail_instructions()
{
    if [ "${DEBUG}" = "y" ]; then set -vx; fi

    if [ -f ${log_dir_base}/TWS_${CREATED_DATE_TIME}.tar.Z ] || [ -f ${log_dir_base}/TWS_${CREATED_DATE_TIME}.tar.gz ]
    then

	echo "   https://www.ibm.com/support/pages/enhanced-customer-data-repository-ecurep-send-data"
	echo " "

        tarsize=`du -sk ${log_dir_base}/TWS_${CREATED_DATE_TIME}.tar* | awk '{print $1}'`

        if [ $tarsize -gt 20000 ]
        then
            echo "FYI: Datagather file is greater than 20 MB."
	    echo ""
        fi
        echo "For latest script and datagather usage:"
        echo "   http://www.ibm.com/support/docview.wss?uid=swg21295038"
        echo " "
    fi
} # End mail_instructions


#***** End Functions *****
#*************************MAIN*****************************************
#echo "OS TEST"
os_test
#echo "SET DEFAULT VARS"
set_default_vars $*
#echo "PARSE ARGS"
parse_args $*
#echo "TEST TEMP"
test_temporary_directory
#echo "SET OUTPUT vars"
set_output_vars
#echo  "exec user test"
exec_user_test
if [ "${tws_home_specified}" = "y" ]
then
    specify_home
else
    tws_user_test
    locate_home
fi
test_for_symphony
date_calculations
create_data_directories
gather_workstation_information
if [ "${TWS_basePath}" != "" ]
then
    gather_tws_information
    gather_agent_information
    gather_event_info
fi

set_was_vars
gather_was_information
gather_install_information
extract_tws_instances
gen_autopd
package_files
mail_instructions
