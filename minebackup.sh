#!/bin/bash
# minebackup was built to backup Minecraft servers using rdiff-backup 
# Copyright (C) 2013 Jonas Friedmann - License: Attribution-NonCommercial-ShareAlike 3.0 Unported
# Based on Natenom's mcontrol (https://github.com/Natenom/mcontrol)
# Edited for ethanbayliss' use on mark2 sessions

# Check if binaries exist
BINS=( "${BIN_RDIFF} ${BIN_TAR} ${BIN_NICE} ${BIN_IONICE}" )
for BIN in $BINS;
do
  type -P $BIN &>/dev/null && continue || echo "'$BIN not found! Run 'apt-get install $BIN' to fix this"; exit 1
done

# Check if $BACKUPDIR exist
if [ ! -d $BACKUPDIR ]
then
  echo "'$BACKUPDIR' doesn't exist. Run the following commands as root:"
  echo "<!--"
  echo "mkdir -p $BACKUPDIR"
  echo "chown -R $USER $BACKUPDIR"
  echo "-->"
  exit 1
fi

function warn_quota() {
  local quota=$1
  local _backup_dir="${BACKUPDIR}"
  _size_of_all_backups=$(($(du -s ${_backup_dir} | cut -f1)/1024))
  
  if [ ! -e ${SERVERDIR}/backup.log ]
  then
    as_user "touch ${SERVERDIR}/backup.log"
    as_user "echo -e \"[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] Created backup log file\" >> ${SERVERDIR}/backup.log"
    as_user "echo -e \"[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] This file will log quota errors and other errors that the script encounters\" >> ${SERVERDIR}/backup.log"
  fi
  
  if [ $_size_of_all_backups -gt $quota ]
  then
    as_user "echo -e \"[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] Exceeded quota: ${_backup_dir}($(($(du -s ${_backup_dir} | cut -f1)/1024))MiB) > (${quota}MiB)\" >> ${SERVERDIR}/backup.log"
  fi
}

# 'Check executive user' function
function as_user() {
  if [ "$(whoami)" = "${USER}" ] ; then
    /bin/bash -c "$1" 
  else
    su - ${RUNAS} -c "$1"
  fi
}

# 'Check running process' function
function is_running() {
  as_user "mark2 list | grep ${SESSIONNAME} > /dev/null"
  if [ $? -eq 0 ]
  then
    return 0 
  else
    return 1
  fi
}

# 'Disable ingame saving' function
function mc_saveoff() {
  if is_running
  then
    echo -ne "${SERVERNAME} is running, suspending saves... "
    as_user "mark2 send -n ${SESSIONNAME} say Server going into backup mode. Expect Lag..."
    as_user "mark2 send -n ${SESSIONNAME} save-off"
    as_user "mark2 send -n ${SESSIONNAME} save-all"
    sync
    sleep 10
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] Notified ${SESSIONNAME}'s users, disabled saving, saved and wrote to disk" >> ${SERVERDIR}/backup.log
  else
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] [WARNING] ${SESSIONNAME} was not running... unable to disable ingame saving" >> ${SERVERDIR}/backup.log
  fi
}

# 'Enable ingame saving' function
function mc_saveon() {
  if is_running
  then
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] ${SESSIONNAME} is running, re-enabling saves... " >> ${SERVERDIR}/backup.log
    as_user "mark2 send -n ${SESSIONNAME} save-on"
    as_user "mark2 send -n ${SESSIONNAME} say Backup finished"
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] ${SESSIONNAME} finished backup" >> ${SERVERDIR}/backup.log
  else
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] [WARNING] ${SESSIONNAME} was not running. Not resuming saves... done" >> ${SERVERDIR}/backup.log
  fi
}

# Backup function
function mc_backup() {
  # Full backup (tar)!
  if [[ ${1} == "full" ]]; then

    # Build exclude string
    local _tarexcludes=""
    for i in ${RDIFF_EXCLUDES[@]}
    do
      _tarexcludes="$_tarexcludes --exclude='${SERVERDIR}/$i'"
    done

    # Check if permissions are okay
    echo -ne "Check for correct permissions ..."
    touchtest=$((touch $FULLBACKUP) >/dev/null 2>&1)
    touchINFO=$?
    [ $touchINFO -eq 0 ] && echo -ne "done\n" && rm $FULLBACKUP
    [ $touchINFO -ne 0 ] && echo -ne "failed\n> ${touchtest}\n" && exit

    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] Making a full tar of ${SERVERDIR} to ${FULLBACKUP}" >> ${SERVERDIR}/backup.log
    ${RUNBACKUP_NICE} ${RUNBACKUP_IONICE} ${BIN_TAR} czf ${FULLBACKUP} ${SERVERDIR} ${_tarexcludes} >/dev/null 2>&1
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] Successfully archived ${SERVERDIR} to ${FULLBACKUP}" >> ${SERVERDIR}/backup.log
  fi

  [ -d "${BACKUPDIR}" ] || mkdir -p "${BACKUPDIR}"
  echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] Creating rdiff of ${SESSIONNAME}... " >> ${SERVERDIR}/backup.log

  if [ -z "$(ls -A ${SERVERDIR})" ];
  then
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] Failed to create rdiff: SERVERDIR(\"${SERVERDIR}\") is empty" >> ${SERVERDIR}/backup.log
    exit 1
  fi

  local _excludes=""
  for i in ${RDIFF_EXCLUDES[@]}
  do
    _excludes="$_excludes --exclude ${SERVERDIR}/$i"
  done
  ${RUNBACKUP_NICE} ${RUNBACKUP_IONICE} ${BIN_RDIFF} ${_excludes} "${SERVERDIR}" "${BACKUPDIR}"
  if [ $? -eq 0 ]
  then
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] rdiff of ${SERVERDIR} successfully created" >> ${SERVERDIR}/backup.log
  else
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] rdiff of ${SERVERDIR} failed" >> ${SERVERDIR}/backup.log
    exit 1
  fi
  
}

# 'List available backups' function
function listbackups() {
  temptest=`${BIN_RDIFF} -l "${BACKUPDIR}" &>/dev/null`
  tempINFO=$?

  if [ $tempINFO -eq 0 ]
  then
    echo "Backups for server \"${SESSIONNAME}\""
    ${BIN_RDIFF} --list-increment-sizes "${BACKUPDIR}"
  else
    echo "Apparently no backups available"
  fi
}

# 'Restore to x' function
function restore() {
  [ ${DODEBUG} -eq 1 ] && set -x

  #Check for valid argument
  if [[ "$1" =~ ^[0-9]+$ ]]; then
    arg="${1}m"
  elif [[ "$1" == "now" ]]; then
    arg="${1}"
  else
    echo -ne "[ERROR] Make sure your argument contains only numbers.\n"
    exit 1
  fi

  # Check for running server
  echo -ne "Check if '${SESSIONNAME}' is not running... "
  if is_running
  then
    echo -ne "failed\n"
    echo "[ERROR] Make sure to shutdown your server before you start to restore."
    exit 1
  fi

  echo -ne "Starting to restore '${arg}' ... "
  rdiffINFO=$((rdiff-backup --restore-as-of ${arg} --force $BACKUPDIR $SERVERDIR) 2>&1)
  [ $? -eq 0 ] && echo -ne "successful\n"
  [ $? -ne 0 ] && echo -ne "failed\n> ${rdiffINFO}\n"
}

# 'List installed crons' function
function listcrons() {
  crontab -l | grep "minebackup"
}

#####
# Catch argument
#####
#Start-Stop here
case "${1}" in
  listbackups)
    listbackups
    ;;
  backup)
    mc_saveoff
    mc_backup "${2}"
    mc_saveon
    ;;
  restore)
    restore "${2}"
    ;;
  crons)
    listcrons
    ;;
  *)cat << EOHELP
Usage: ${0} COMMAND [ARGUMENT]

COMMANDS
    backup [full]             Backup the server.
    listbackups               List current incremental backups.
    restore [<MINUTES> OR now]   Restore to snapshot which is [MINUTES] ago. ("now" for the latest)
    crons                     List configured cronjobs.
    -debug                    Enable debug output (Must be the last argument).
EOHELP
    exit 1
  ;;
esac

exit 0
