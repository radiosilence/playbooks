#!/bin/bash

PRIM_USER=jcleveland
SSH_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDipps3qoDk/jY3FGypRPOBgVwprVBqtzfCVYDRFxkMg8l2CmU9tU2w6TTa+VnaUuHyzukCnI0StZhkEuVB+tuae6j6Xsl5iMiZLD0Wl2AmqT5Hf2mR39ILJTm/PHxEiNsaWLbLzRuqpXNhjCDOBdZn/hXNDLdXVFw2gYffuBuZk0hsV0Shi8fPrNCj4NhghFZUNIBmeOoyqzWDQf2iHreDRTNmNL6uYBaVqs9m2KlUg41uEQ0rarFyi3nBj9zGjhJev4yxCBFvrUfBsyfxpfgSsNdf29R5KJ3EhQREf5vAnL5GkT0KKWP1yzDoW4JVS5j43W07brm/X5/gJVwltGl5MqiopWG6MQG/26htgBoywH22wBj5N1g7lYfJP8oT/fBqbnvJdFp4lJO8kNmgGESC4YWHtraUSpmG9EdKQ9sJMw7QhGNLTVKTtefmaA7PznzGITk8qZ8qsrx6pzL1p8zLMX5fmKV7D+43QcNmQ9H2Ajohd8NXlvYMSiBUhmLhBYyx3GGR7cOnjMhkpH19uqp/ZYXSQIkuik9YmrTLPVouC8ePOxm6aMyTnpWfbNLoq1ECnKxeDxDchwrYyK2mR7aLXhiVCMWXKR+CzDhZHl/iZZcn/pq7VtDRr+1c/hMuNqDELCEfTDVJew/Q07SJKEhmn7zhGn/4NwZOdNaUY4LS8Q== jamescleveland@gmail.com"
wget -O - http://repos.blackflags.co.uk/debian/jc-blackflags.gpg.key|apt-key add -

iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
iptables -A INPUT -p tcp -m tcp --dport 22 -j ACCEPT
iptables -A INPUT -p tcp -m tcp --dport 80 -j ACCEPT
iptables -A INPUT -p tcp -m tcp --dport 443 -j ACCEPT
iptables -A INPUT -j DROP

iptables-save > /etc/iptables.rules

cat > /etc/network/if-pre-up.d/iptables <<END
#!/bin/sh
/sbin/iptables-restore < /etc/iptables.rules
END
chmod +x /etc/network/if-pre-up.d/iptables

cat > /etc/network/if-post-down.d/iptables <<END
#!/bin/sh
/sbin/iptables-save > /etc/iptables.rules
END
chmod +x /etc/network/if-post-down.d/iptables

cat > /etc/apt/sources.list <<ENDSOURCES
deb http://http.debian.net/debian/ wheezy main non-free contrib
deb http://security.debian.org/ wheezy/updates main non-free contrib
deb http://http.debian.net/debian/ wheezy-updates main non-free contrib
deb http://repos.blackflags.co.uk/debian/ wheezy main
ENDSOURCES

apt-get update

export DEBIAN_FRONTEND=noninteractive
apt-get install -y \
    build-essential \
    curl \
    git \
    libjpeg-dev \
    libmemcached-dev \
    python2.7-dev \
    memcached \
    mercurial \
    nginx-common \
    nginx-extras \
    nodejs \
    postfix \
    postgresql-9.1 \
    postgresql-server-dev-9.1 \
    python2.7 \
    python-virtualenv \
    redis-server \
    sudo \
    vim \
    zlib1g-dev \
    zsh

ln -s /usr/bin/nodejs /usr/bin/node

cat > /etc/nginx/nginx.conf <<ENDNGINX
user www-data;
worker_processes  8;
events {
    worker_connections  1024;
}
http {
    include  mime.types;
    default_type  application/octet-stream;

    sendfile  on;
    tcp_nopush  on;
    keepalive_timeout  65;
    types_hash_max_size  2048;
    
    access_log  /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;
    
    gzip  on;
    gzip_disable  "msie6";
    gzip_static  on;
    gzip_comp_level 9;
    gzip_min_length  1000;
    gzip_vary  on;
    gzip_types text/css text/plain text/javascript application/x-javascript
        application/x-json image/svg+xml application/x-font-ttf
        application/x-font-opentype font/woff application/octet-stream
        application/vnd.ms-fontobject;

    include /etc/nginx/servers/*/*.conf;
    include /srv/*/*/nginx.conf;
}
ENDNGINX

mkdir /etc/nginx/servers
mkdir /etc/nginx/certs

/etc/init.d/nginx restart

useradd deploy -m -s /bin/bash
useradd $PRIM_USER -m -s /bin/bash
gpasswd -a $PRIM_USER sudo
mkdir /home/$PRIM_USER/.ssh
chmod 700 /home/$PRIM_USER/.ssh

echo $SSH_KEY > /home/$PRIM_USER/.ssh/authorized_keys 
chmod 600 /home/$PRIM_USER/.ssh/*
chown $PRIM_USER:$PRIM_USER /home/$PRIM_USER/.ssh -R

cat > /etc/sudoers <<ENDSUDO
Defaults    env_reset
Defaults    mail_badpass
Defaults    secure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
root    ALL=(ALL:ALL) ALL
%sudo   ALL=(ALL:ALL) ALL
ENDSUDO

UWSGI_ENV=/opt/uwsgi
virtualenv $UWSGI_ENV
$UWSGI_ENV/bin/pip install uwsgi
mkdir -p $UWSG_ENV/etc/uwsgi.d
cat > /opt/uwsgi/etc/uwsgi.d/fastrouter.ini <<'ENDFRUITER'
[uwsgi]
shared-socket = 127.0.0.1:3031
fastrouter-subscription-server = 127.0.0.1:2626
fastrouter = =0
master = true
processes = 4
fastrouter-cheap = true
ENDFRUITER
chown nobody:nogroup /opt/uwsgi/etc/uwsgi.d/*.ini

cat > /etc/init.d/uwsgi <<'ENDUWSGI'
#!/usr/bin/env bash

### BEGIN INIT INFO
# Provides:          uwsgi
# Required-Start:    $all
# Required-Stop:     $all
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: starts the uwsgi app server
# Description:       starts uwsgi app server using start-stop-daemon
### END INIT INFO
set -e

. /lib/lsb/init-functions

PATH=/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
DAEMON=/opt/uwsgi/bin/uwsgi
RUN=/var/run/uwsgi
ENABLED_CONFIGS_DIR=/srv/*/*/uwsgi.*
USER=deploy
GROUP=www-data
NAME=uwsgi
DESC=uWSGI
VERSION=$NAME
OP=$1

[[ -x $DAEMON ]] || exit 0
[[ -d $RUN ]] || mkdir $RUN && chown $USER $RUN


DAEMON_OPTS=""

# Include uwsgi defaults if available
if [[ -f /etc/default/$VERSION ]]; then
    . /etc/default/$VERSION
fi

do_pid_check()
{
    local PIDFILE=$1
    [[ -f $PIDFILE ]] || return 0
    local PID=$(cat $PIDFILE)
    for p in $(pgrep $VERSION); do
        [[ $p == $PID ]] && return 1
    done
    return 0
}


do_start()
{
    local PIDFILE=$RUN/$VERSION.pid
    local START_OPTS=" \
        --pidfile $PIDFILE \
    --daemonize /var/log/$NAME \
    --emperor-tyrant \
    --enable-threads \
        "
    if do_pid_check $PIDFILE; then
        $DAEMON $DAEMON_OPTS $START_OPTS --emperor "$ENABLED_CONFIGS_DIR" --emperor "/opt/uwsgi/etc/uwsgi.d/*.ini"
    else
        echo "Already running!"
    fi
}

send_sig()
{
    local PIDFILE=$RUN/$VERSION.pid
    set +e
    [[ -f $PIDFILE ]] && kill $1 $(cat $PIDFILE) > /dev/null 2>&1
    set -e
}

wait_and_clean_pidfile()
{
    local PIDFILE=$RUN/$VERSION.pid
    until do_pid_check $PIDFILE; do
        echo -n "";
    done
    rm -f $PIDFILE
}

do_stop()
{
    send_sig -3
    wait_and_clean_pidfile
}

do_reload()
{
    send_sig -1
}

do_force_reload()
{
    send_sig -15
}

get_status()
{
    send_sig -10
}


case "$OP" in
    start)
        log_daemon_msg "Starting $DESC" "$NAME"
        do_start
    log_end_msg $?
        ;;
    stop)
        log_daemon_msg "Stopping $DESC" "$NAME"
        do_stop
    log_end_msg $?
        ;;
    reload)
        log_daemon_msg "Reloading $DESC" "$NAME"
        do_reload
    log_end_msg $?
        ;;
    force-reload)
        log_daemon_msg "Force-reloading $DESC" "$NAME"
        do_reload
        do_force_reload
    log_end_msg $?
       ;;
    restart)
        log_daemon_msg "Restarting $DESC" "$NAME"
        do_stop
        sleep 1
        do_start
    log_end_msg $?
        ;;
    status)
        get_status
        ;;
    *)
        N=/etc/init.d/$NAME
        echo "Usage: $N {start|stop|restart|reload|force-reload|status"
            "|enable|disable}">&2
        exit 1
        ;;
esac
exit 0
ENDUWSGI
chmod +x /etc/init.d/uwsgi
/etc/init.d/uwsgi start
update-rc.d uwsgi defaults

cat > /etc/ssh/sshd_config <<ENDSSHD
Port 22
Protocol 2
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_dsa_key
HostKey /etc/ssh/ssh_host_ecdsa_key
UsePrivilegeSeparation yes
KeyRegenerationInterval 3600
ServerKeyBits 768
SyslogFacility AUTH
LogLevel INFO
LoginGraceTime 120
PermitRootLogin no
StrictModes yes
RSAAuthentication yes
PubkeyAuthentication yes
IgnoreRhosts yes
RhostsRSAAuthentication no
HostbasedAuthentication no
PermitEmptyPasswords no
ChallengeResponseAuthentication no
PasswordAuthentication no
PrintMotd no
PrintLastLog yes
TCPKeepAlive yes
AcceptEnv LANG LC_*
Subsystem sftp /usr/lib/openssh/sftp-server
UsePAM yes
ENDSSHD

/etc/init.d/ssh restart

mkdir /srv
chown deploy:www-data /srv

cat > /etc/postgresql/9.1/main/pg_hba.conf <<ENDHBA
local   all             postgres                                peer
local   all             all                                     md5
host    all             all             127.0.0.1/32            md5
host    all             all             ::1/128                 md5
ENDHBA

/etc/init.d/postgresql restart