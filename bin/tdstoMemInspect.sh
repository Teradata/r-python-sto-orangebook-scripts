#!/bin/bash
#
################################################################################
# The contents of this file are Teradata Public Content
# and have been released to the Public Domain.
# Licensed under BSD; see "license.txt" file for more information.
# Copyright (c) 2020 by Teradata
################################################################################
#
# R And Python Analytics with the SCRIPT Table Operator
# Orange Book supplementary material
# Alexander Kolovos - May 2020
#
# tdstoMemInspect: SCRIPT and ExecR Table Operators (TOs) memory inspection
# Script version: 0.8 - 2020-05-20
#
# Bash script to probe a Vantage SQL Engine node for
# 1. the existing upper memory threshold settings for the SCRIPT and ExecR TOs,
#    based on the system's ScriptMemLimit and GPLUDFServerMemSize values,
#    respectively, in the cufconfig Globally Distributed Object utility.
# 2. memory availability for non-database tasks like script execution via the 
#    SCRIPT and ExecR TOs, after accounting for the database needs.
# This script should be executed on a SQL Engine node of a Vantage
# system by a user with administrative rights.
#
# The ScriptMemLimit and GPLUDFServerMemSize are system parameters in the
# cufconfig utility that determine the upper memory limit per AMP and per query
# to be made available for SCRIPT and Exec TO users, respectively. During query
# execution of any of these TOs, if the memory demands should exceed the TO's
# corresponding memory upper limit, then the query is aborted. However, if the
# system memory resources should get depleted before the ScriptMemLimit or 
# GPLUDFServerMemSize is reached during a query, then memory swapping begins.
# As a consequence of swapping, one or more system nodes can slow down to the
# point of freezing or even crashing. It is therefore critical that available
# system resources exist in oder to use the SCRIPT and/or ExecR TOs, and that
# adequate resources are made available to these TOs per AMP and per query.
#
# The present script probes the node for system information to compute 
# the approximate available theoretical average memory per AMP on the node for
# each STO or ExecR query. This value is compared to the ScriptMemLimit and
# GPLUDFServerMemSize settings, and provides insight about the current state
# of the server with respect to the risk of a memory-related incident due to
# the SCRIPT or the ExecR TO usage.
#
# Input: 
# - Desired/target concurrency for SCRIPT/ExecR on the server
# - [Optional] QueryGrid dedicated memory size, if QueryGrid is present
# Output:
# - Available average memory per AMP on the node
# - Comparison to ScriptMemLimit and GPLUDFServerMemSize values, and assessment
#
# How to run the present script:
# The script can be executed in 2 modes. From the command line of a Bash shell
# on a SQL Engine node of the target Vantage server, run as root user:
# 1)  # ./tdstoMemInspect.sh
# or
# 2)  # ./tdstoMemInspect.sh -s
#
# In mode (1), the script automatically probes the node for the values of
# - Number of AMPs on the present node (queries the ampload utility)
# - ScriptMemLimit and GPLUDFServerMemSize (queries the cufconfig utility)
# - The node total memory (queries the /proc/meminfo file)
# - The percentage of FSG cache memory (queries the cts utility)
# and computes the output.
#
# In mode (2), the script is executed with the option "-s", which
# executes the script in simulation mode. In this mode, the user must
# specify the following, in addition to the input of mode (1):
# Additional input requested in simulation mode:
# - Assumed number of AMPs on a node
# - Assumed initial ScriptMemLimit / GPLUDFServerMemSize value
# - Assumed total memory on node
# - Assumed FSG cache percentage value
# In this manner, the user can simulate script responses for different
# environments and possible inputs.
#
# The present script serves as a utility to assist Vantage SQL Engine
# users inspect their system for memory resources availability for the
# SCRIPT or ExecR Table Operator execution. This is important, since using
# an external language with either TO requires adequate free memory per AMP
# and TO query to retain system health. For example, the Teradata R and Python
# In-nodes packages specify a minimum requirement of 1 GB per AMP per query to
# be installed by Teradata Customer Services. The recommendations made by the
# script are not binding, and may change at any instance based on the system
# loads and usage. The script can be run repeatedly at any time.
#
###############################################################################
# Release Changelog
#
# 2020-01-23   0.6   First public release
# 2020-03-25   0.7   Clarity increse in results messaging
# 2020-05-19   0.8   Include ExecR mempry parameter in output. Improve clarity.
#                    Implement stricter verdict for nodes with inadequate mem.
#                    Fixed bug that allowed for negative free memory. Fixed
#                    script behavior to account for scenario when PDE is down.
#
###############################################################################

# Script version
ver=0
subver=8
scrdate="2020-05-20"
#
# Some parameters
#
# Minimum memory needed per AMP per SCRIPT/ExecR query in MB
minSuggestedPerAmpPerQueryMB=1000
minNeededPerAmpPerQueryMB=500
maxSTOvalueMB=3584
#
# Percentage of available memory on node to allow for STO/ExecR usage
# after accounting for memory needed by database, FSG cache, AMPs, QueryGrid
# Observe that we allow a 100*(1 - percForSTO) % to be left available
# at all times to prevent the node memory from being entirely consumed by  
# SCRIPT/ExecR.
percForSTO=85

isSimulation=0
if [[ $# > 0 ]]; then
  if [[ $1 == "-s" ]]; then
    isSimulation=1
    echo "*** Simulation mode ***"
    echo "Please provide values for all variables as prompted"
  elif [[ $1 == "-v" ]]; then
    echo "tdstoMemInspect: Script version $ver.$subver ($scrdate)"
    exit 0
  elif [[ $1 == "-h" ]] || [[ $1 == "-help" ]]; then
    echo "tdstoMemInspect: Script help menu:"
    echo "  To run the script, invoke it by name on the command line in the"
    echo "      directory where it resides, or by specifying its full path."
    echo "      Ensure the user has execute permission for the script file."
    echo "  Syntax: 'tdstoMemInspect.sh <option>'"
    echo "  No option : Assess theoretical node free memory on current system"
    echo "         -s : Assess theoretical node free memory on simulated system"
    echo "         -v : Script version"
    echo "         -h : This menu"
    exit 0
  else
    echo "tdstoMemInspect: Unknown script argument(s). Use '-h' option for help."
    exit 0
  fi
    echo ""
fi

amploadExists=$( type ampload &> /dev/null && echo 1 || echo 0 )
if [[ $amploadExists == 0 ]] ; then
    if [[ $isSimulation == 0 ]]; then
        echo "tdstoMemInspect: SCRIPT and ExecR Table Operators memory inspection"
        echo "Error: Node only supports this script in simulation mode."
        echo "       Please execute the script as 'tdstoMemInspect.sh -s'."
        echo "Process complete. Exiting."
        exit 0
    fi
fi

cufconfigExists=$( type cufconfig &> /dev/null && echo 1 || echo 0 )
if [[ $cufconfigExists == 0 ]] ; then
    if [[ $isSimulation == 0 ]]; then
        echo "tdstoMemInspect: SCRIPT and ExecR Table Operators memory inspection"
        echo "Error: Node only supports this script in simulation mode."
        echo "       Please execute the script as 'tdstoMemInspect.sh -s'."
        echo "Process complete. Exiting."
        exit 0
    fi
fi

if [[ $isSimulation == 0 ]]; then
  # Before proceeding with a real probe, check whether database is up
  pdeState=$(pdestate -a | grep DOWN | awk '{print $3}')
  if [[ $pdeState == *"DOWN"* ]]; then
     echo "tdstoMemInspect: PDE is down."
     echo "Error: To run this script in non-simulation mode, database must be running."
     echo "       Please start the database before running the script again,"
     echo "       or run the script in simulation mode as 'tdstoMemInspect.sh -s'."
     echo "Process complete. Exiting."
     exit 0
  fi
fi

echo "tdstoMemInspect: System memory inspection"
echo "                 for the SCRIPT and ExecR Table Operators (TOs)"
echo "Probes a system so you can specify suitable TO upper memory thresholds"
echo "* Inspects current ScriptMemLimit and GPLUDFServerMemSize values"
echo "* Accounts for node FSG cache, AMPs, QueryGrid memory consumptions"
echo "* Allows for SCRIPT/ExecR concurrency specification"
echo "* Calculates non-FSG cache (non-database reserved) free memory on node"
echo "* Assumes up to $percForSTO% of non-FSG cache free memory to be available to TO"
echo "* Note: Ignores other loads"

echo ""

read -p "Enter desired SCRIPT/ExecR concurrency. Specify 1, if not known: " nConcurr
while [[ -z $nConcurr ]] || [[ $nConcurr -le 0 ]]; do
  read -p "You must specify a positive number of concurrent queries: " nConcurr
done

read -p "If QueryGrid is used, then specify memory in MB, else press [Return]: "  qgMemMB
if [[ -z $qgMemMB ]]; then
  qgMemMB=0
else
  while [[ $( echo "$qgMemMB / 1" | bc) -lt 0 ]]; do
    read -p "You must specify a non-negative QueryGrid memory size or [Return]: " qgMemMB
  done
  if [[ -z $qgMemMB ]]; then
    qgMemMB=0
  fi
fi

if [[ $isSimulation == 1 ]]; then
  read -p "Enter number of AMPs on node: " nAmps
  while [[ -z $nAmps ]] || [[ $nAmps -le 0 ]]; do
    read -p "You must specify a positive number of AMPs: " nAmps
  done

  read -p "Enter the node's total memory in GB: " totMemGB
  while [[ -z $totMemGB ]] || [[ $( echo "$totMemGB / 1" | bc) -le 0 ]]; do
    read -p "You must specify a positive node total memory size: " totMemGB
  done
  totMemMB=$( echo "scale=2; $totMemGB * 1024." | bc )

  read -p "Enter percentage of FSG cache memory [1-99]: " fsgVal
  while [[ -z $fsgVal ]] || [[ $fsgVal -le 0 ]] || [[ $fsgVal -gt 99 ]]; do
    read -p "You must specify an FSG cache percentage in [1-99]: " fsgVal
  done

  read -p "Enter ScriptMemLimit (SCRIPT memory limit) in MB: " scrMemLimMB
  while [[ -z $scrMemLimMB ]] || [[ $( echo "$scrMemLimMB / 1" | bc) -le 0 ]]; do
    read -p "You must specify a positive ScriptMemLimit memory size: " scrMemLimMB
  done

  read -p "Enter GPLUDFServerMemSize (ExecR memory limit) in MB: " gpludfMemLimMB
  while [[ -z $gpludfMemLimMB ]] || [[ $( echo "$gpludfMemLimMB / 1" | bc) -le 0 ]]; do
    read -p "You must specify a positive GPLUDFServerMemSize memory size: " gpludfMemLimMB
  done
else
  # Collect system info: Use "ampload" to get number of AMPs on current node.
  nAmpsHeader=$(ampload | wc | awk '{print $1}')
  nAmps=$( echo "$nAmpsHeader - 3" | bc )

  # Collect system info: Use "cufconfig" to get line with ScriptMemLimit info.
  cufconfig -o > tmp1
  # Get output line with ScriptMemLimit info from cufconfig
  grep 'ScriptMemLimit' tmp1 > tmp2
  # Get total node memory in KB (previous-to-last argument in line)
  scrMemLimBytes=$(cat tmp2 | awk '{print $NF}')
  scrMemLimMB=$( echo "scale=2; $scrMemLimBytes / 1024. / 1024." | bc )
  #
  # Get output line with GPLUDFServerMemSize info from cufconfig
  grep 'GPLUDFServerMemSize' tmp1 > tmp2
  # Get total node memory in KB (previous-to-last argument in line)
  gpludfMemLimBytes=$(cat tmp2 | awk '{print $NF}')
  gpludfMemLimMB=$( echo "scale=2; $gpludfMemLimBytes / 1024. / 1024." | bc )
  rm tmp1
  rm tmp2

  # Collect system info: Use "meminfo: to get total memory info about node.
  grep 'MemTotal' /proc/meminfo > tmp1
  # Get total node memory in KB (previous-to-last argument in line)
  totMemKB=$(cat tmp1 | awk '{print $(NF - 1)}')
  totMemMB=$( echo "scale=2; $totMemKB / 1024." | bc )
  totMemGB=$( echo "scale=2; $totMemMB / 1024." | bc )
  rm tmp1

  # Collect system info: Use call to ctl to get output with FSG cache info.
  ctl <<< 'scr dbs' > tmp1
  # Get output line with FSG cache info from ctl
  grep "FSG cache Percent" tmp1 > tmp2
  # Get FSG cache percentage value (last argument in line)
  fsgVal=$(cat tmp2 | awk '{print $NF}')

  rm tmp1
  rm tmp2
fi

scrMemLimGB=$( echo "scale=2; $scrMemLimMB / 1024." | bc )
gpludfMemLimGB=$( echo "scale=2; $gpludfMemLimMB / 1024." | bc )
memConsumedByAmpMB=$( echo "scale=2; 39. * $nAmps" | bc )
memConsumedByAmpGB=$( echo "scale=2; $memConsumedByAmpMB / 1024." | bc )
echo ""

if [[ $1 == 0 ]]; then
  echo "Simulated System Information:"
else
  echo "System Information:"
fi
echo -e "* Number of AMPs on node             : $nAmps"
echo -e "* SCRIPT concurrent queries setting  : $nConcurr"
echo -e "* Total memory on node               : $totMemGB GB"
echo -e "* FSG cache memory percentage        : $fsgVal %"
echo -e "* Memory consumed on node AMPs       : $memConsumedByAmpGB GB"
echo -e "* ScriptMemLimit      (for SCRIPT)   : $scrMemLimGB GB"
echo -e "* GPLUDFServerMemSize (for ExecR )   : $gpludfMemLimGB GB"

nonFSGperc=$( echo "scale=2; (100 - $fsgVal) / 100." | bc )
memAvailNonFSGMB=$( echo "scale=2; $totMemMB * $nonFSGperc" | bc )
memAvailMB1=$( echo "scale=2; $memAvailNonFSGMB - $memConsumedByAmpMB" | bc )

memAvailMB=$( echo "scale=2; ($memAvailMB1 - $qgMemMB) * $percForSTO / 100." | bc )
# Sanity check: memAvailMB must be non-negative
if [[ $( echo "$memAvailMB / 1" | bc) -lt 0 ]]; then
   memAvailMB=0
   echo ""
   echo "tdstoMemInspect warning: Calculations indicate zero free memory for node."
   echo "                         Check your input for correctness in the above"
   echo "                         system information. Re-run the script, if needed."
fi

memAvailGB=$( echo "scale=2; $memAvailMB / 1024." | bc )

echo ""

if [ $nConcurr -gt 1 ]; then
  echo "For the above configuration and concurrency settings, theoretically:"
else
  echo "For the above configuration, theoretically:"
fi

echo -e "  Non-FSG cache free memory on node is:\t\t$memAvailMB MB \t( $memAvailGB GB )"
memAvailPerAmpMB=$( echo "scale=2; $memAvailMB / $nAmps" | bc )
memAvailPerAmpGB=$( echo "scale=2; $memAvailGB / $nAmps" | bc )
memAvailPerAmpPerQueryMB=$( echo "scale=2; $memAvailPerAmpMB / $nConcurr" | bc )
memAvailPerAmpPerQueryGB=$( echo "scale=2; $memAvailPerAmpPerQueryMB / 1024." | bc )

echo -e "    Avg available per AMP per STO/ExecR query:\t$memAvailPerAmpPerQueryMB MB \t( $memAvailPerAmpPerQueryGB GB )"
#if [ $nConcurr -gt 1 ]; then
#  echo -e "    and per concurrent query:\t$memAvailPerAmpPerQueryMB MB \t( $memAvailPerAmpPerQueryGB GB )"
#fi

memNeededMB=$( echo "scale=2; $nConcurr * $scrMemLimMB * $nAmps" | bc )
memNeededGB=$( echo "scale=2; $memNeededMB / 1024." | bc )
memNeededPerAmpMB=$( echo "scale=2; $memNeededMB / $nAmps" | bc )
memNeededPerAmpGB=$( echo "scale=2; $memNeededGB / $nAmps" | bc )
#echo -e "    SCRIPT is currently allowed up to:\t$scrMemLimMB MB \t( $scrMemLimGB GB )" 

echo ""

scriptMemLimBytesSugBytes=$( echo "$memAvailPerAmpPerQueryMB * 1024 * 1024" | bc )

# Compute suggested memory size for present node for STO to have at least 1 GB
tmp1=$( echo "scale=6; $nAmps / ($percForSTO / 100.)" | bc )
tmp2=$( echo "scale=6; $qgMemMB / 1024." | bc )
tmp3=$( echo "scale=6; $tmp1 + $memConsumedByAmpGB + $tmp2" | bc ) 
memSuggOnNodeGB=$( echo "scale=2; $nConcurr * $tmp3 / $nonFSGperc" | bc )

# Provide assessment and recommendations
# When not running a simulation, implement hard line on no-compliant systems

# If system memory inadequate
if [ $(echo $memAvailPerAmpPerQueryMB/1 | bc) -lt $minSuggestedPerAmpPerQueryMB ]; then
  # When running a simulation
  if [[ $isSimulation == 1 ]]; then
    echo "The minimum available memory requirement for STO/ExecR is 1 GB/AMP/query."
    echo "For nodes with the simulated specs, recommendation would be to refrain from"
    echo "installing the Teradata R/Python in-nodes packages until requirement is met."
    echo "To attain 1 GB/AMP/query of average free memory, you could consider"
    if [ $nConcurr -gt 1 ]; then
      echo "- decreasing concurrency (specifying 1 is strongly suggested) and re-check"
    fi
    echo "- increasing the node memory to at least $( echo "$memSuggOnNodeGB" | bc ) GB"
    echo "- lowering the system's FSG cache memory percentage, if possible"
    echo " "
    echo "Notes:"
    echo "If you should test running R/Python scripts with SCRIPT/ExecR on dev nodes"
    echo "with the simulated specs, then exercise highest caution and monitor memory"
    echo "very closely. In cufconfig utility, ScriptMemLimit and GPLUDFServerMemSize"
    echo "values should be specified to no less than 536870912 (0.5 GB)."
    echo "    Suggested values to specify in the cufconfig utility:"
    # A. NeededMem < 500 MB
    if [ $(echo $memAvailPerAmpPerQueryMB/1 | bc) -lt $minNeededPerAmpPerQueryMB ]; then
      echo -e "        ScriptMemLimit:      536870912 \t( 0.5 GB )"
      echo -e "        GPLUDFServerMemSize: 536870912 \t( 0.5 GB )"
    # B. 500 MB <= NeededMem < 1 GB
    else
      echo -e "        ScriptMemLimit:      $( echo "$scriptMemLimBytesSugBytes / 1" | bc) \t( $memAvailPerAmpPerQueryGB GB )"
      echo -e "        GPLUDFServerMemSize: $( echo "$scriptMemLimBytesSugBytes / 1" | bc) \t( $memAvailPerAmpPerQueryGB GB )"
    fi
    echo "In absence of database workloads on development nodes, for testing R/Python"
    echo "scripts with SCRIPT/ExecR you might experiment with even higher values for"
    echo "ScriptMemLimit and GPLUDFServerMemSize. Any allowance above $(echo $memAvailPerAmpPerQueryMB/1 | bc) MB will"
    echo "consume FSG cache allocated memory, so you are warned about potential system"
    echo "performance impact and instability. Never attempt this on production nodes."
  # When probing an actual system
  else
    echo "The minimum available memory requirement for STO/ExecR is 1 GB/AMP/query."
    echo "Do not install Teradata R/Python in-nodes packages until requirement is met."
    echo "To attain 1 GB/AMP/query of average free memory, consider"
    if [ $nConcurr -gt 1 ]; then
      echo "- decreasing concurrency (specifying 1 is strongly suggested) and re-check"
    fi
    echo "- increasing the node memory to at least $( echo "$memSuggOnNodeGB" | bc ) GB"
    echo "- lowering the system's FSG cache memory percentage, if possible"
  fi 
# Else system has adequate memory resources
else
  echo "The min available 1 GB/AMP/query memory requirement for STO/ExecR is met."
  echo "The ScriptMemLimit and GPLUDFServerMemSize parameters can be safely"
  echo "specified to a value up to the above average available estimate."
  echo "    Suggested values to specify in the cufconfig utility:"
  if [ $maxSTOvalueMB -lt $(echo "$memAvailPerAmpPerQueryMB / 1" | bc) ]; then
    echo -e "        ScriptMemLimit:      3758096384 \t( 3.5 GB )"
    echo -e "        GPLUDFServerMemSize: 3758096384 \t( 3.5 GB )"
  else
    echo -e "        ScriptMemLimit:      $( echo "$scriptMemLimBytesSugBytes / 1" | bc) \t( $memAvailPerAmpPerQueryGB GB )"
    echo -e "        GPLUDFServerMemSize: $( echo "$scriptMemLimBytesSugBytes / 1" | bc) \t( $memAvailPerAmpPerQueryGB GB )"
  fi
  echo "Re-run this script on the node, if the concurrency settings are modified."
  echo "Always exercise caution and monitor memory closely when using SCRIPT/ExecR."
fi
echo ""
echo "Process complete. Exiting."
