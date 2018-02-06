#!/bin/sh

# Setting this, so the repo does not need to be given on the commandline:
export BORG_REPO=ssh://user@domain.com//mnt/borg/archive

# Setting this, so you won't be asked for your repository passphrase:
export BORG_PASSPHRASE='xxxxxxxxxxxx'

# or this to ask an external program to supply the passphrase:
#export BORG_PASSCOMMAND='pass show backup'

# Mount point
export BORG_MOUNTPOINT='/mnt/borg'

# some helpers and error handling:
info() { printf "\n%s %s\n\n" "$( date )" "$*" >&2; }
trap 'echo $( date ) Backup interrupted >&2; exit 2' INT TERM

# show info if that parameter was given
if [ "$1" == "info" ];
then
    borg info
    exit 0
fi

# show list if that parameter was given
if [ "$1" == "list" ];
then
    borg list
    exit 0
fi

# mount archive if that parameter was given
if [ "$1" == "mount" ];
then
    if [ "$2" == "" ];
    then
        echo $0 $1 host.name.com-2018-02-01T08:25:01
        echo
        echo Available archives:
        borg list
        exit 1
    else
        borg mount "$BORG_REPO::$2" $BORG_MOUNTPOINT
        exit 0
    fi
fi

# umount if that parameter was given
if [ "$1" == "umount" ];
then
    borg umount $BORG_MOUNTPOINT
    exit 0
fi

info "Starting backup"

# Backup the most important directories into an archive named after
# the machine this script is currently running on:

borg create                         \
    --verbose                       \
    --filter AME                    \
    --list                          \
    --stats                         \
    --show-rc                       \
    --compression lz4               \
    --exclude-caches                \
    --exclude '/home/*/.cache/*'    \
    --exclude '/var/cache/*'        \
    --exclude '/var/tmp/*'          \
    --exclude '/usr/local/directadmin/custombuild/mysql_backups' \
                                    \
    ::'{hostname}-{now}'            \
    /etc                            \
    /home                           \
    /root                           \
    /usr                            \
    /var                            \

backup_exit=$?

info "Pruning repository"

# Use the `prune` subcommand to maintain 7 daily, 4 weekly and 6 monthly
# archives of THIS machine. The '{hostname}-' prefix is very important to
# limit prune's operation to this machine's archives and not apply to
# other machines' archives also:

borg prune                          \
    --list                          \
    --prefix '{hostname}-'          \
    --show-rc                       \
    --keep-daily    7               \
    --keep-weekly   4               \
    --keep-monthly  6               \

prune_exit=$?

# use highest exit code as global exit code
global_exit=$(( backup_exit > prune_exit ? backup_exit : prune_exit ))

if [ ${global_exit} -eq 1 ];
then
    info "Backup and/or Prune finished with a warning"
fi

if [ ${global_exit} -gt 1 ];
then
    info "Backup and/or Prune finished with an error"
fi

exit ${global_exit}

