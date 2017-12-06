#!/bin/bash
#####
# Settings
#####

# Binary names
BIN_RDIFF="rdiff-backup"
BIN_TAR="tar"
BIN_NICE="nice"
BIN_IONICE="ionice"

# nice and ionice settings
RUNBACKUP_NICE="${BIN_NICE} -n19"
RUNBACKUP_IONICE="${BIN_IONICE} -c 3"

# Messages
SAY_BACKUP_START="Backup started...feel the lag"
SAY_BACKUP_FINISHED="Backup successfully finished."

# Mark session name
SESSIONNAME="minecraft"
# Server root directory
SERVERDIR="/opt/${SESSIONNAME}"
# Backup directory
BACKUPDIR="/mnt/mchost-backups/${SESSIONNAME}/"
# Filename for full backup (using tar)
FULLBACKUP="${BACKUPDIR}/$(date +%Y%m%d).tar.gz"
# Quota for backup directory
BACKUP_QUOTA_MiB=40000

# Exclude the following files/directories in backups
RDIFF_EXCLUDES=(plugins/dynmap/web/tiles/ plugins/WorldEdit/)

## Overridable configurations (remove "#" to activate)
RUNBACKUP_NICE="${BIN_NICE} -n19"
RUNBACKUP_IONICE="${BIN_IONICE} -c 3"

SAY_BACKUP_START="$(date '+%Y-%m-%d %H:%M:%S') Backup started...feel the lag"
SAY_BACKUP_FINISHED="$(date '+%Y-%m-%d %H:%M:%S') Backup successfully finished."
