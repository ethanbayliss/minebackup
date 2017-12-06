minebackup.sh - Edited for use of /mnt/mchost-backups and mark2 sessions
=============

Bash script to backup Minecraft servers using `rdiff-backup` CPU and I/O friendly.

# Commands

    minebackup backup [full]             Backup the server.
    minebackup listbackups               List current incremental backups.
    minebackup restore [<MINUTES>/now]   Restore to snapshot [MINUTES] ago. ("now" for the latest)
    minebackup crons                     List configured cronjobs.

# Configuration

This script uses bash environment variables to store settings. Run settings.sh with the adjusted values for each server before running the script

Make sure you made all adjustments as your needs for the following variables:

* `SESSIONNAME`
* `SERVERDIR`
* `BACKUPDIR`
* `FULLBACKUP`
* `BACKUP_QUOTA_MiB`

You can also override:

* `RUNBACKUP_NICE` (`${BIN_NICE} -n19` by default)
* `RUNBACKUP_IONICE` (`${BIN_IONICE} -c 3` by default)
* `SAY_BACKUP_START` (`Backup started...` by default)
* `SAY_BACKUP_FINISHED` (`Backup successfully finished.` by default)

# Installation

## Bash script

    cd /usr/local/src
    git clone https://github.com/ethanbayliss/minebackup.git
    ln -s /usr/local/src/minebackup/minebackup.sh /usr/bin/minebackup
    #In my case I am using a mounted drive that is rcloned to gdrive every night
    mkdir -p /mnt/mchost-backups/minecraft
    chown -R ${USER} /mnt/mchost-backups/

## Cron job examples

To open the crontab in your default editor:

    crontab -e

---

Differential backup every 15 minutes, fullbackup every day at 0:00 am:

    */15 * * * * /opt/minecraft/backupsettings.sh && minebackup backup
    0 0 * * * /opt/minecraft/backupsettings.sh && minebackup backup full

Differential backup every 5 minutes, fullbackup 2 days at 5:30 am:

    */5 * * * * /opt/minecraft/backupsettings.sh && minebackup backup
    30 5 */2 * * /opt/minecraft/backupsettings.sh && minebackup backup full

Differential backup every 30 minutes, fullbackup every 7 days at 6:45 pm:

    */30 * * * * /opt/minecraft/backupsettings.sh && minebackup backup
    45 18 */7 * * /opt/minecraft/backupsettings.sh && minebackup backup full

# Dependencies

You need `rdiff-backup`, `nice`, `ionice` and `tar` binaries to use all features of minebackup.sh:

    apt-get install rdiff-backup tar

(`nice` and `ionice` are preinstalled on Debian derivates)
