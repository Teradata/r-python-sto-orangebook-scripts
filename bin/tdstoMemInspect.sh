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
# Alexander Kolovos - January 2020
#
# tdstoMemInspect: SCRIPT Table Operator memory inspection
# Script version: 0.6 - 2020-01-23
#
# Bash script to probe a Vantage SQL Engine node for
# 1. the SCRIPT TO upper memory threshold setting, based on the system's
#    ScriptMemLimit value in the cufconfig Globally Distributed Object utility.
# 2. memory availability, after accounting for the database needs.
# This script should be executed on a SQL Engine node of a Vantage
# system by a user with administrative rights.
#
# The ScriptMemLimit is a system setting in the cufconfig utility
# that determines the upper limit for the memory per AMP and per 
# SCRIPT TO query to be made available for SCRIPT TO users. If the memory
# demands during a SCRIPT TO execution exceed this threshold, then
# the query is aborted. However, if the system memory resources get
# depleted in the process before the ScriptMemLimit is reached,
# then the server can crash.
#
# The present script probes the node for system information to compute 
# the approximate available theoretical average memory per AMP on the node.
# This value is compared to the ScriptMemLimit setting, and provides insight
# about the current state of the server with respect to the risk of a
# memory-related incident due to SCRIPT TO usage.
#
# Input: 
# - Desired/target concurrency for SCRIPT/ExecR on the server
# - [Optional] QueryGrid dedicated memory size, if QueryGrid is present
# Output:
# - Available average memory per AMP on the node
# - Comparison to ScriptMemLimit value and assessment
#
# How to run the present script:
# The script can be executed in 2 modes. From the command line of a
# Bash shell on a SQL Engine node of the target Vantage server, run:
# 1)  # ./tdstoMemInspect.sh
# or
# 2)  # ./tdstoMemInspect.sh -s
#
# In mode (1), the script automatically probes the node for the values of
# - Number of AMPs on the present node (queries the ampload utility)
# - ScriptMemLimit (queries the cufconfig utility)
# - The node total memory (queries the /proc/meminfo file)
# - The percentage of FSG cache memory (queries the cts utility)
# and computes the output.
#
# In mode (2), the script is executed with the option "-s", which
# executes the script in simulation mode. In this mode, the user must
# specify the following, in additino to the input of mode (1):
# Additional input requested in simulation mode:
# - Assumed number of AMPs on a node
# - Assumed ScriptMemLimit value
# - Assumed total memory on node
# - Assumed FSG cache percentage value
# In this manner, the user can simulate script responses for different
# environments and possible inputs.
#
# The present script serves as a utility to assist Vantage SQL Engine
# users inspect their system with respect to memory resources availability
# for SCRIPT Table Operator execution. The recommendations made by the
# script are not binding, may change at any instance based on the system
# loads and usage, and only aim to help users understand their system
# memory resources in conjunction to the SCRIPT TO at any given instance.
#
###############################################################################

# Script version
ver=0
subver=6
scrdate="2020-01-23"
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
    echo "Please provide values for all variables"
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
        echo "tdstoMemInspect: SCRIPT Table Operator memory inspection"
        echo "Error: Node only supports this script in simulation mode."
        echo "       Please execute the script as 'tdstoMemInspect.sh -s'."
        echo "Process complete. Exiting."
        exit 0
    fi
fi

cufconfigExists=$( type cufconfig &> /dev/null && echo 1 || echo 0 )
if [[ $cufconfigExists == 0 ]] ; then
    if [[ $isSimulation == 0 ]]; then
        echo "tdstoMemInspect: SCRIPT Table Operator memory inspection"
        echo "Error: Node only supports this script in simulation mode."
        echo "       Please execute the script as 'tdstoMemInspect.sh -s'."
        echo "Process complete. Exiting."
        exit 0
    fi
fi

echo "tdstoMemInspect: System memory inspection"
echo "                 for the SCRIPT (and ExecR) Table Operator"
echo "Bash script to probe a system for suitable SCRIPT upper memory threshold"
echo "* Based on current ScriptMemLimit value, and memory availability on node"
echo "* Accounts for SCRIPT concurrency setting, FSG cache, AMPs, QueryGrid"
echo "* Assumes $percForSTO% of non-FSG cache free memory for SCRIPT; ignores other loads"

echo ""

read -p "Enter desired SCRIPT/ExecR concurrency: " nConcurr
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
memConsumedByAmpMB=$( echo "scale=2; 39. * $nAmps" | bc )
memConsumedByAmpGB=$( echo "scale=2; $memConsumedByAmpMB / 1024." | bc )
echo ""

if [[ $1 == 0 ]]; then
  echo "Simulated System Information:"
else
  echo "System Information:"
fi
echo -e "* Number of AMPs on node            : $nAmps"
echo -e "* SCRIPT concurrent queries setting : $nConcurr"
echo -e "* Total memory on node in GB        : $totMemGB"
echo -e "* FSG cache memory percentage       : $fsgVal"
echo -e "* Memory consumed on node AMPs in GB: $memConsumedByAmpGB"
echo -e "* ScriptMemLimit in GB              : $scrMemLimGB"

echo ""

if [ $nConcurr -gt 1 ]; then
  echo "For the above configuration and concurrency settings, theoretically:"
else
  echo "For the above configuration, theoretically:"
fi

nonFSGperc=$( echo "scale=2; (100 - $fsgVal) / 100." | bc )
memAvailNonFSGMB=$( echo "scale=2; $totMemMB * $nonFSGperc" | bc )
memAvailMB1=$( echo "scale=2; $memAvailNonFSGMB - $memConsumedByAmpMB" | bc )

memAvailMB=$( echo "scale=2; ($memAvailMB1 - $qgMemMB) * $percForSTO / 100." | bc )
memAvailGB=$( echo "scale=2; $memAvailMB / 1024." | bc )

echo -e "  Non-FSG cache free memory on node is:\t$memAvailMB MB \t( $memAvailGB GB )"
memAvailPerAmpMB=$( echo "scale=2; $memAvailMB / $nAmps" | bc )
memAvailPerAmpGB=$( echo "scale=2; $memAvailGB / $nAmps" | bc )
memAvailPerAmpPerQueryMB=$( echo "scale=2; $memAvailPerAmpMB / $nConcurr" | bc )
memAvailPerAmpPerQueryGB=$( echo "scale=2; $memAvailPerAmpPerQueryMB / 1024." | bc )

echo -e "    Per AMP per STO (or ExecR) query:"
echo -e "    Average free memory:\t\t$memAvailPerAmpPerQueryMB MB \t( $memAvailPerAmpPerQueryGB GB )"
#if [ $nConcurr -gt 1 ]; then
#  echo -e "    and per concurrent query:\t$memAvailPerAmpPerQueryMB MB \t( $memAvailPerAmpPerQueryGB GB )"
#fi

memNeededMB=$( echo "scale=2; $nConcurr * $scrMemLimMB * $nAmps" | bc )
memNeededGB=$( echo "scale=2; $memNeededMB / 1024." | bc )
memNeededPerAmpMB=$( echo "scale=2; $memNeededMB / $nAmps" | bc )
memNeededPerAmpGB=$( echo "scale=2; $memNeededGB / $nAmps" | bc )
echo -e "    SCRIPT allowed up to:\t\t$scrMemLimMB MB \t( $scrMemLimGB GB )" 

echo ""

scriptMemLimBytesSugBytes=$( echo "$memAvailPerAmpPerQueryMB * 1024 * 1024" | bc )

# Compute suggested memory size for present node for STO to have at least 1 GB
tmp1=$( echo "scale=6; $nAmps / ($percForSTO / 100.)" | bc )
tmp2=$( echo "scale=6; $qgMemMB / 1024." | bc )
tmp3=$( echo "scale=6; $tmp1 + $memConsumedByAmpGB + $tmp2" | bc ) 
memSuggOnNodeGB=$( echo "scale=2; $nConcurr * $tmp3 / $nonFSGperc" | bc )

# Provide assessment and recommendations
    echo "Non-FSG cache free memory per AMP per STO/ExecR query is $memAvailPerAmpPerQueryMB MB."
# A. NeededMem < 500 MB
if [ $(echo $memAvailPerAmpPerQueryMB/1 | bc) -lt $minNeededPerAmpPerQueryMB ]; then
  echo "The minimum requirement for SCRIPT (or ExecR) is $minNeededPerAmpPerQueryMB MB."
  echo "Consider increasing the node memory to at least $( echo "$memSuggOnNodeGB" | bc ) GB"
  echo "to attain the recommended value of 1 GB."
  if [ $nConcurr -gt 1 ]; then
      echo "Alternatively, consider decreasing concurrency and re-check."
  fi
  echo "If you should attempt to use SCRIPT on the system, then exercise"
  echo "high caution and monitor your nodes memory very closely."
  echo "    Suggested ScriptMemLimit value:"
  echo "        0.5 GB (536870912 bytes)."
else
  # B. 500 MB < NeededMem < 1 GB
  if [ $(echo $memAvailPerAmpPerQueryMB / 1 | bc) -lt $minSuggestedPerAmpPerQueryMB ]; then
    echo "This value is lower than the recommended 1 GB. To attain this level,"
    echo "consider increasing the node memory to at least $( echo $memSuggOnNodeGB / 1 | bc ) GB."
    if [ $nConcurr -gt 1 ]; then
      echo "Alternatively, consider decreasing concurrency and re-check."
    fi
    echo "Always exercise caution and monitor nodes memory closely when using SCRIPT." 
    echo "    Suggested ScriptMemLimit value:"
    echo "        No higher than about $( echo "$scriptMemLimBytesSugBytes / 1" | bc) bytes ( $memAvailPerAmpPerQueryMB MB )"
  # C. 1 GB < NeededMem
  else
    echo "The ScriptMemLimit parameter can be safely increased to this value."
    echo "Re-check your system, if the concurrency settings are modified."
    echo "Always exercise caution and monitor nodes memory closely when using SCRIPT."
    echo "    Suggested ScriptMemLimit value:"
    if [ $maxSTOvalueMB -lt $(echo "$memAvailPerAmpPerQueryMB / 1" | bc) ]; then
      echo "        3.5 GB (3758096384 bytes)"
    else
      echo "        No higher than about $( echo "$scriptMemLimBytesSugBytes / 1" | bc) bytes ( $memAvailPerAmpPerQueryMB MB )"
    fi
  fi
fi
echo "    If ExecR is used, then specify similar value for GPLUDFServerMemSize."

echo ""
echo "Process complete. Exiting."
