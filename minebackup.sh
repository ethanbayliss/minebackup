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
    as_user "echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] Created backup log file" >> ${SERVERDIR}/backup.log"
    as_user "echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] This file will log quota errors and other errors that the script encounters" >> ${SERVERDIR}/backup.log"
  fi
  
  if [ $_size_of_all_backups -gt $quota ]
  then
    as_user "echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] Exceeded quota: ${_backup_dir}($(($(du -s ${_backup_dir} | cut -f1)/1024))MiB) > (${quota}MiB)" >> ${SERVERDIR}/backup.log"
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
    echo -ne "[$(date '+%Y-%m-%d %H:%M:%S')] Notified ${SESSIONNAME}'s users, disabled saving, saved and wrote to disk\n"
  else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ${SESSIONNAME} was not running... unable to disable ingame saving"
  fi
}

# 'Enable ingame saving' function
function mc_saveon() {
  if is_running
  then
    echo -ne "[$(date '+%Y-%m-%d %H:%M:%S')] ${SESSIONNAME} is running, re-enabling saves... "
    as_user "mark2 send -n ${SESSIONNAME} save-on"
    as_user "mark2 send -n ${SESSIONNAME} say Backup finished"
    echo -ne "[$(date '+%Y-%m-%d %H:%M:%S')] Finished backup\n"
  else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ${SERVERNAME} was not running. Not resuming saves... done"
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
    touchstatus=$?
    [ $touchstatus -eq 0 ] && echo -ne "done\n" && rm $FULLBACKUP
    [ $touchstatus -ne 0 ] && echo -ne "failed\n> ${touchtest}\n" && exit

    echo -ne "Full backup '${FULLBACKUP}' ..."
    ${RUNBACKUP_NICE} ${RUNBACKUP_IONICE} ${BIN_TAR} czf ${FULLBACKUP} ${SERVERDIR} ${_tarexcludes} >/dev/null 2>&1
    echo -ne "done\n"
  fi

  [ -d "${BACKUPDIR}" ] || mkdir -p "${BACKUPDIR}"
  echo -ne "Backing up ${SESSIONNAME}... "

  if [ -z "$(ls -A ${SERVERDIR})" ];
  then
    echo -ne "failed\n"
    echo -ne "=> Something must be wrong, SERVERDIR(\"${SERVERDIR}\") is empty.\nWon't do a backup.\n"
    exit 1
  fi

  local _excludes=""
  for i in ${RDIFF_EXCLUDES[@]}
  do
    _excludes="$_excludes --exclude ${SERVERDIR}/$i"
  done
  ${RUNBACKUP_NICE} ${RUNBACKUP_IONICE} ${BIN_RDIFF} ${_excludes} "${SERVERDIR}" "${BACKUPDIR}"
  echo -ne "done\n"
  
  
}

# 'List available backups' function
function listbackups() {
  [ ${DODEBUG} -eq 1 ] && set -x

  temptest=`${BIN_RDIFF} -l "${BACKUPDIR}" &>/dev/null`
  tempstatus=$?

  if [ $tempstatus -eq 0 ]
  then
    echo "Backups for server \"${SESSIONNAME}\""
    [ ${DODEBUG} -eq 1 ] && ${BIN_RDIFF} -l "${BACKUPDIR}"
    ${BIN_RDIFF} --list-increment-sizes "${BACKUPDIR}"
  else
    echo "Apparently no backups available"
  fi
}

# 'Restore to x' function
function restore() {
  [ ${DODEBUG} -eq 1 ] && set -x

  # Check for argument
  echo -ne "Check for valid argument ... "
  if [[ "$1" =~ ^[0-9]+$ ]]; then
    echo -ne "done\n";
    arg="${1}m"
  elif [[ "$1" == "now" ]]; then
    echo -ne "done\n";
    arg="${1}"
  else
    echo -ne "failed\n";
    echo -ne "=> Make sure your argument contains only numbers.\n"
    exit 1
  fi

  # Check for running server
  echo -ne "Check if '${SESSIONNAME}' is not running... "
  if is_running
  then
    echo -ne "failed\n"
    echo "=> Make sure to shutdown your server before you start to restore."
    exit 1
  fi

  echo -ne "done\n"

  echo -ne "Starting to restore '${arg}' ... "
  rdiffstatus=$((rdiff-backup --restore-as-of ${arg} --force $BACKUPDIR $SERVERDIR) 2>&1)
  tempstatus=$?
  [ $tempstatus -eq 0 ] && echo -ne "successful\n"
  [ $tempstatus -ne 0 ] && echo -ne "failed\n> ${rdiffstatus}\n"
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
    restore [<MINUTES>/now]   Restore to snapshot which is [MINUTES] ago. ("now" for the latest)
    crons                     List configured cronjobs.
    -debug                    Enable debug output (Must be the last argument).
EOHELP
    exit 1
  ;;
esac

exit 0
