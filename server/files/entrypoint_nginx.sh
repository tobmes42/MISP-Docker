#!/bin/bash

MISP_APP_CONFIG_PATH=/var/www/MISP/app/Config
[ -z "$MYSQL_HOST" ] && MYSQL_HOST=db
[ -z "$MYSQL_PORT" ] && MYSQL_PORT=3306
[ -z "$MYSQL_USER" ] && MYSQL_USER=misp
[ -z "$MYSQL_PASSWORD_FILE" ] && MYSQL_PASSWORD=example || MYSQL_PASSWORD=`< $MYSQL_PASSWORD_FILE`
[ -z "$MYSQL_DATABASE" ] && MYSQL_DATABASE=misp
[ -z "$REDIS_FQDN" ] && REDIS_FQDN=redis
[ -z "$REDIS_PASSWORD_FILE" ] && REDIS_PASSWORD="redis_MISP!" || REDIS_PASSWORD=`< $REDIS_PASSWORD_FILE`
[ -z "$MISP_MODULES_FQDN" ] && MISP_MODULES_FQDN="http://misp-modules"
[ -z "$MYSQLCMD" ] && MYSQLCMD="mysql -u $MYSQL_USER -p$MYSQL_PASSWORD -P $MYSQL_PORT -h $MYSQL_HOST -r -N  $MYSQL_DATABASE"
[ -z "$ORGNAME" ] && ORGNAME=MY_ORG
[ -z "$EMAIL" ] && EMAIL="email@example.com"
[ -z "$CONTACT" ] && CONTACT="email@example.com"
[ -z "$DISABLE_EMAIL" ] && DISABLE_EMAIL="false"
[ -z "$GNUPGHOME" ] && GNUPGHOME="/gnupg"
[ -z "$GNUPG_PASSPHRASE" ] && GNUPG_PASSPHRASE="yA15^x#*xJXHW4I3oC2F3FzmD92bMpG%"
[ -z "$GNUPG_EMAIL" ] && GNUPG_EMAIL=$EMAIL

ENTRYPOINT_PID_FILE="/entrypoint_apache.install"
[ ! -f $ENTRYPOINT_PID_FILE ] && touch $ENTRYPOINT_PID_FILE

setup_cake_config(){
    sed -i "s/'host' => 'localhost'.*/'host' => '$REDIS_FQDN',          \/\/ Redis server hostname/" "/var/www/MISP/app/Plugin/CakeResque/Config/config.php"
    sed -i "s/'host' => '127.0.0.1'.*/'host' => '$REDIS_FQDN',          \/\/ Redis server hostname/" "/var/www/MISP/app/Plugin/CakeResque/Config/config.php"
    sed -i "s/'password' => null.*/'password' => '$REDIS_PASSWORD',          \/\/ Redis password/" "/var/www/MISP/app/Plugin/CakeResque/Config/config.php"
}

init_misp_config(){
    [ -f $MISP_APP_CONFIG_PATH/bootstrap.php ] || runuser -u www-data -- cp $MISP_APP_CONFIG_PATH.dist/bootstrap.default.php $MISP_APP_CONFIG_PATH/bootstrap.php
    [ -f $MISP_APP_CONFIG_PATH/database.php ] || runuser -u www-data -- cp $MISP_APP_CONFIG_PATH.dist/database.default.php $MISP_APP_CONFIG_PATH/database.php
    [ -f $MISP_APP_CONFIG_PATH/core.php ] || runuser -u www-data -- cp $MISP_APP_CONFIG_PATH.dist/core.default.php $MISP_APP_CONFIG_PATH/core.php
    [ -f $MISP_APP_CONFIG_PATH/config.php ] || runuser -u www-data -- cp $MISP_APP_CONFIG_PATH.dist/config.default.php $MISP_APP_CONFIG_PATH/config.php
    [ -f $MISP_APP_CONFIG_PATH/email.php ] || runuser -u www-data -- cp $MISP_APP_CONFIG_PATH.dist/email.php $MISP_APP_CONFIG_PATH/email.php
    [ -f $MISP_APP_CONFIG_PATH/routes.php ] || runuser -u www-data -- cp $MISP_APP_CONFIG_PATH.dist/routes.php $MISP_APP_CONFIG_PATH/routes.php

    echo "Configure MISP | Set DB User, Password and Host in database.php"
    sed -i "s/localhost/$MYSQL_HOST/" $MISP_APP_CONFIG_PATH/database.php
    sed -i "s/db\s*login/$MYSQL_USER/" $MISP_APP_CONFIG_PATH/database.php
    sed -i "s/db\s*password/$MYSQL_PASSWORD/" $MISP_APP_CONFIG_PATH/database.php
    sed -i "s/'database' => 'misp'/'database' => '$MYSQL_DATABASE'/" $MISP_APP_CONFIG_PATH/database.php

    echo "Configure sane defaults"
    # Redis Connection Settings
    /var/www/MISP/app/Console/cake Admin setSetting "MISP.redis_host" "$REDIS_FQDN"
    /var/www/MISP/app/Console/cake Admin setSetting "MISP.redis_password" "$REDIS_PASSWORD"

    # General Settings
    /var/www/MISP/app/Console/cake Admin setSetting "MISP.python_bin" $(which python3)
    /var/www/MISP/app/Console/cake Admin setSetting "MISP.baseurl" "$HOSTNAME"
    /var/www/MISP/app/Console/cake Admin setSetting "MISP.external_baseurl" "$HOSTNAME"
    /var/www/MISP/app/Console/cake Admin setSetting "MISP.org" "$ORGNAME"
    /var/www/MISP/app/Console/cake Admin setSetting "MISP.email" "$EMAIL"
    /var/www/MISP/app/Console/cake Admin setSetting "MISP.contact" "$CONTACT"
    /var/www/MISP/app/Console/cake Admin setSetting "MISP.disable_emailing" "$DISABLE_EMAIL"
    /var/www/MISP/app/Console/cake Admin setSetting "MISP.log_client_ip" "true"
    /var/www/MISP/app/Console/cake Admin setSetting "MISP.log_auth" "true"
    /var/www/MISP/app/Console/cake Admin setSetting "MISP.store_api_access_time" "true"
    /var/www/MISP/app/Console/cake Admin setSetting "MISP.log_user_ips" "true"
    /var/www/MISP/app/Console/cake Admin setSetting "MISP.log_new_audit" "true"
    /var/www/MISP/app/Console/cake Admin setSetting "MISP.log_new_audit_compress" "true"
    /var/www/MISP/app/Console/cake Admin setSetting "MISP.download_gpg_from_homedir" "true"

    # GNUPG Settings
    /var/www/MISP/app/Console/cake Admin setSetting "GnuPG.email" "$GNUPG_EMAIL"
    /var/www/MISP/app/Console/cake Admin setSetting "GnuPG.homedir" "$GNUPGHOME"
    /var/www/MISP/app/Console/cake Admin setSetting "GnuPG.password" "$GNUPG_PASSPHRASE"

    # Plugin Settings
    /var/www/MISP/app/Console/cake Admin setSetting "Plugin.ZeroMQ_redis_host" "$REDIS_FQDN"
    /var/www/MISP/app/Console/cake Admin setSetting "Plugin.ZeroMQ_redis_port" 6379
    /var/www/MISP/app/Console/cake Admin setSetting "Plugin.ZeroMQ_redis_database" 1
    /var/www/MISP/app/Console/cake Admin setSetting "Plugin.ZeroMQ_redis_password" "$REDIS_PASSWORD"
    /var/www/MISP/app/Console/cake Admin setSetting "Plugin.ZeroMQ_enable" true
    /var/www/MISP/app/Console/cake Admin setSetting "Plugin.ZeroMQ_audit_notifications_enable" true
    /var/www/MISP/app/Console/cake Admin setSetting "Plugin.Enrichment_services_enable" true
    /var/www/MISP/app/Console/cake Admin setSetting "Plugin.Enrichment_services_url" "$MISP_MODULES_FQDN"
    /var/www/MISP/app/Console/cake Admin setSetting "Plugin.Import_services_enable" true
    /var/www/MISP/app/Console/cake Admin setSetting "Plugin.Import_services_url" "$MISP_MODULES_FQDN"
    /var/www/MISP/app/Console/cake Admin setSetting "Plugin.Export_services_enable" true
    /var/www/MISP/app/Console/cake Admin setSetting "Plugin.Export_services_url" "$MISP_MODULES_FQDN"
    /var/www/MISP/app/Console/cake Admin setSetting "Plugin.Cortex_services_enable" false

    echo "Change number of workers"
    if [ ! -z "$WORKERS" ] && [ "$WORKERS" -gt "1" ]; then
        sed -i "s/start --interval/start -n $WORKERS --interval/" /var/www/MISP/app/Console/worker/start.sh
    fi
}

init_mysql(){
    # Test when MySQL is ready....
    # wait for Database come ready
    isDBup () {
        echo "SHOW STATUS" | $MYSQLCMD 1>/dev/null
        echo $?
    }

    isDBinitDone () {
        # Table attributes has existed since at least v2.1
        echo "DESCRIBE attributes" | $MYSQLCMD 1>/dev/null
        echo $?
    }

    RETRY=10
    until [ $(isDBup) -eq 0 ] || [ $RETRY -le 0 ] ; do
        echo "Waiting for database to come up"
        sleep 5
        RETRY=$(( RETRY - 1))
    done
    if [ $RETRY -le 0 ]; then
        >&2 echo "Error: Could not connect to Database on $MYSQL_HOST:$MYSQL_PORT"
        exit 1
    fi

    if [ $(isDBinitDone) -eq 0 ]; then
        echo "Database has already been initialized"
    else
        echo "Database has not been initialized, importing MySQL scheme..."
        $MYSQLCMD < /var/www/MISP/INSTALL/MYSQL.sql
    fi
}

# Things we should do when MISP starts
echo "Setup MySQL..." && init_mysql

# Things that should ALWAYS happen
echo "Configure Cake | Change Redis host to $REDIS_FQDN ... " && setup_cake_config

# Things we should do if we're configuring MISP via ENV
echo "Configure MISP | Initialize misp base config..." && init_misp_config

echo "Configure MISP | Enforce permissions ..."
echo "... chmod 600 /var/www/MISP/app/Config/config.php /var/www/MISP/app/Config/database.php /var/www/MISP/app/Config/email.php ... " && chmod 600 /var/www/MISP/app/Config/config.php /var/www/MISP/app/Config/database.php /var/www/MISP/app/Config/email.php

# Work around https://github.com/MISP/MISP/issues/5608
if [[ ! -f /var/www/MISP/PyMISP/pymisp/data/describeTypes.json ]]; then
    echo -e "\nAdding Workaround..."
    runuser -u www-data -- mkdir -p /var/www/MISP/PyMISP/pymisp/data/
    runuser -u www-data -- ln -s /usr/local/lib/python3.7/dist-packages/pymisp/data/describeTypes.json /var/www/MISP/PyMISP/pymisp/data/describeTypes.json
fi

if [[ ! -L "/etc/nginx/sites-enabled/misp80" ]]; then
    echo "Configure NGINX | Disabling Port 80 Redirect"
    ln -s /etc/nginx/sites-available/misp80-noredir /etc/nginx/sites-enabled/misp80
else
    echo "Configure NGINX | Port 80 already configured"
fi

if [[ "$DISIPV6" == true ]]; then
    echo "Configure NGINX | Disabling IPv6"
    sed -i "s/listen \[\:\:\]/\#listen \[\:\:\]/" /etc/nginx/sites-enabled/misp80
fi

if [[ -x /custom-entrypoint.sh ]]; then
    /custom-entrypoint.sh
fi

# delete pid file
[ -f $ENTRYPOINT_PID_FILE ] && rm $ENTRYPOINT_PID_FILE

# Start NGINX
nginx -g 'daemon off;'
