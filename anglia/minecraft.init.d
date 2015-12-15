#!/bin/bash
# /etc/init.d/minecraft
# version 0.3.2 2011-01-27 (YYYY-MM-DD)

### BEGIN INIT INFO
# Provides:   minecraft
# Required-Start: $local_fs $remote_fs
# Required-Stop:  $local_fs $remote_fs
# Should-Start:   $network
# Should-Stop:    $network
# Default-Start:  2 3 4 5
# Default-Stop:   0 1 6
# Short-Description:    Minecraft server
# Description:    Starts the minecraft server
### END INIT INFO

#Settings
SERVICE='craftbukkit.jar'
USERNAME="minecraft"
MCPATH='/srv/minecraft'
CPU_COUNT=2
INVOCATION="java -Xmx1024M -Xms1024M -XX:+UseConcMarkSweepGC -XX:+CMSIncrementalPacing -XX:ParallelGCThreads=$CPU_COUNT -XX:+AggressiveOpts -jar $SERVICE nogui -o true"
BACKUPPATH='/srv/backup/minecraft'
LEVELNAME=$(grep 'level-name' $MCPATH/server.properties | sed -e 's/.*=\(.*\)$/\1/' -e 's/ /\\ /g')

#Updates
#MC_SERVER_URL=https://s3.amazonaws.com/MinecraftDownload/launcher/minecraft_server.jar
MC_SERVER_URL=http://dl.bukkit.org/latest-rb/craftbukkit.jar

ME=`whoami`
as_user() {
  if [ $ME == $USERNAME ] ; then
    bash -c "$1"
  else
    su - $USERNAME -c "$1"
  fi
}

mc_start() {
  if ps ax | grep -v grep | grep -v -i SCREEN | grep $SERVICE > /dev/null
  then
    echo "[$(date --rfc-3339=seconds)] Tried to start but $SERVICE was already running!"
  else
    echo "[$(date --rfc-3339=seconds)] $SERVICE was not running... starting."
    cd $MCPATH

    # clear the old session.lock
    as_user "rm -f $MCPATH/$LEVELNAME/session.lock"

    #echo "[$(date --rfc-3339=seconds)] Backing up the server log"
    #if [ -f "$MCPATH/server.log" ]
    #then
    #  if [ -f "$BACKUPPATH/server_`date "+%Y.%m.%d"`.log" ]
    #  then
    #    for i in 1 2 3 4 5 6 7 8 9
    #    do
    #      if [ -f "$BACKUPPATH/server_`date "+%Y.%m.%d"`-$i.log" ]
    #      then
    #        continue
    #      else
    #        as_user "cd $MCPATH && mv server.log \"$BACKUPPATH/server_`date "+%Y.%m.%d"`-$i.log\""
    #        break
    #      fi
    #    done
    #  else
    #    as_user "cd $MCPATH && mv server.log \"$BACKUPPATH/server_`date "+%Y.%m.%d"`.log\""
    #  fi
    #  echo "[$(date --rfc-3339=seconds)] Backup complete"
    #fi
    as_user "touch $MCPATH/server.log"
    sleep 1

    as_user "cd $MCPATH && screen -dmS minecraft $INVOCATION"
    sleep 7
    if ps ax | grep -v grep | grep -v -i SCREEN | grep $SERVICE > /dev/null
    then
      echo "[$(date --rfc-3339=seconds)] $SERVICE is now running."
    else
      echo "[$(date --rfc-3339=seconds)] Could not start $SERVICE."
    fi
  fi
}

mc_saveoff() {
  if ps ax | grep -v grep | grep -v -i SCREEN | grep $SERVICE > /dev/null
  then
    echo "[$(date --rfc-3339=seconds)] $SERVICE is running... suspending saves"
    as_user "screen -p 0 -S minecraft -X eval 'stuff \"say SERVER BACKUP STARTING. Server going readonly...\"\015'"
    as_user "screen -p 0 -S minecraft -X eval 'stuff \"save-off\"\015'"
    as_user "screen -p 0 -S minecraft -X eval 'stuff \"save-all\"\015'"
    sync
    sleep 10
  else
    echo "[$(date --rfc-3339=seconds)] $SERVICE was not running. Not suspending saves."
  fi
}

mc_saveon() {
  if ps ax | grep -v grep | grep -v -i SCREEN | grep $SERVICE > /dev/null
  then
    echo "[$(date --rfc-3339=seconds)] $SERVICE is running... re-enabling saves"
    as_user "screen -p 0 -S minecraft -X eval 'stuff \"save-on\"\015'"
    as_user "screen -p 0 -S minecraft -X eval 'stuff \"say SERVER BACKUP ENDED. Server going read-write...\"\015'"
  else
    echo "[$(date --rfc-3339=seconds)] $SERVICE was not running. Not resuming saves."
  fi
}

mc_stop() {
  if ps ax | grep -v grep | grep -v -i SCREEN | grep $SERVICE > /dev/null
  then
    echo "[$(date --rfc-3339=seconds)] $SERVICE is running... stopping."
    as_user "screen -p 0 -S minecraft -X eval 'stuff \"say SERVER SHUTTING DOWN IN 10 SECONDS. Saving map...\"\015'"
    as_user "screen -p 0 -S minecraft -X eval 'stuff \"save-all\"\015'"
    sleep 10
    as_user "screen -p 0 -S minecraft -X eval 'stuff \"stop\"\015'"
    sleep 7
  else
    echo "[$(date --rfc-3339=seconds)] $SERVICE was not running."
  fi
  if ps ax | grep -v grep | grep -v -i SCREEN | grep $SERVICE > /dev/null
  then
    echo "[$(date --rfc-3339=seconds)] $SERVICE could not be shut down... still running."
  else
    echo "[$(date --rfc-3339=seconds)] $SERVICE is shut down."
  fi
}


#mc_update() {
#  if ps ax | grep -v grep | grep -v -i SCREEN | grep $SERVICE > /dev/null
#  then
#    echo "[$(date --rfc-3339=seconds)] $SERVICE is running! Will not start update."
#  else
#    as_user "cd $MCPATH && wget -q -O $MCPATH/$SERVICE.jar.update $MC_SERVER_URL"
#    if [ -f $MCPATH/$SERVICE.jar.update ]
#    then
#      if `diff $MCPATH/$SERVICE.jar $MCPATH/$SERVICE.jar.update >/dev/null`
#        then 
#          echo "[$(date --rfc-3339=seconds)] You are already running the latest version of $SERVICE."
#        else
#          as_user "mv $MCPATH/$SERVICE.jar.update $MCPATH/$SERVICE.jar"
#          echo "[$(date --rfc-3339=seconds)] Minecraft successfully updated."
#      fi
#    else
#      echo "[$(date --rfc-3339=seconds)] Minecraft update could not be downloaded."
#    fi
#  fi
#}

mc_backup() {
  DATE=`date "+%Y-%m-%d"`
  FULLBACKUPPATH=$BACKUPPATH/$DATE

  #for d in $(echo "/srv/backup/minecraft/*" | sed -r -e 's/ /\n/g' -e 's/\/srv\/backup\/minecraft\/([0-9]{4}-[0-9]{2}-[0-9]{2})/\1/g' | grep --color=never -E '[0-9]{4}-[0-9]{2}-[0-9]{2}'); do
  #done

  mkdir -p $FULLBACKUPPATH

  echo "[$(date --rfc-3339=seconds)] Backing up minecraft $LEVELNAME"
  if [ -d "$FULLBACKUPPATH/$LEVELNAME" ]
  then
    for i in 1 2 3 4 5 6 7 8 9
    do
      if [ -d "$FULLBACKUPPATH-$i/$LEVELNAME" ]
      then
        continue
      else
        as_user "cd $MCPATH && cp -r \"$LEVELNAME\" $FULLBACKUPPATH-$i"
        as_user "cd $MCPATH && cp -r \"${LEVELNAME}_nether\" $FULLBACKUPPATH-$i"
        as_user "cd $MCPATH && cp -r \"${LEVELNAME}_the_end\" $FULLBACKUPPATH-$i"
        break
      fi
    done
  else
    as_user "cd $MCPATH && cp -r \"$LEVELNAME\" $FULLBACKUPPATH"
    as_user "cd $MCPATH && cp -r \"${LEVELNAME}_nether\" $FULLBACKUPPATH"
    as_user "cd $MCPATH && cp -r \"${LEVELNAME}_the_end\" $FULLBACKUPPATH"
    echo "[$(date --rfc-3339=seconds)] Backed up $LEVELNAME"
  fi

  echo "[$(date --rfc-3339=seconds)] Backing up the minecraft server executable"
  if [ -f "$FULLBACKUPPATH/$SERVICE" ]
  then
    for i in 1 2 3 4 5 6 7 8 9
    do
      if [ -f "$FULLBACKUPPATH-$i/$SERVICE" ]
      then
        continue
      else
        as_user "cd $MCPATH && cp $SERVICE $FULLBACKUPPATH-$i"
        break
      fi
    done
  else
    as_user "cd $MCPATH && cp $SERVICE $FULLBACKUPPATH"
  fi

  echo "[$(date --rfc-3339=seconds)] Backing up the server log"
  if [ -f "$FULLBACKUPPATH/server.log" ]
  then
    for i in 1 2 3 4 5 6 7 8 9
    do
      if [ -f "$FULLBACKUPPATH-$i/server.log" ]
      then
        continue
      else
        as_user "cd $MCPATH && cp server.log $FULLBACKUPPATH-$i"
        break
      fi
    done
  else
    as_user "cd $MCPATH && cp server.log $FULLBACKUPPATH"
  fi
  echo "[$(date --rfc-3339=seconds)] Backup complete"
}

mc_console() {
  screen -x minecraft/minecraft
}

#Start-Stop here
case "$1" in
  start)
    mc_start
    ;;
  stop)
    mc_stop
    ;;
  restart)
    mc_stop
    mc_start
    ;;
  #update)
  #  mc_stop
  #  mc_backup
  #  mc_update
  #  mc_start
  #  ;;
  backup)
    mc_saveoff
    mc_backup
    mc_saveon
    ;;
  status)
    if ps ax | grep -v grep | grep -v -i SCREEN | grep $SERVICE > /dev/null
    then
      echo "[$(date --rfc-3339=seconds)] $SERVICE is running."
    else
      echo "[$(date --rfc-3339=seconds)] $SERVICE is not running."
    fi
    ;;

  console)
    mc_console
    ;;

  *)
    echo "[$(date --rfc-3339=seconds)] Usage: /etc/init.d/minecraft {start|stop|update|backup|status|restart|console}"
    exit 1
    ;;
esac

exit 0
