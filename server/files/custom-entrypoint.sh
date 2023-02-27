#!/bin/bash

MISP_APP_CONFIG_PATH=/var/www/MISP/app/Config
[ -z "$GNUPGHOME" ] && GNUPGHOME="/gnupg"
[ -z "$GNUPG_PASSPHRASE" ] && GNUPG_PASSPHRASE="yA15^x#*xJXHW4I3oC2F3FzmD92bMpG%"
[ -z "$GNUPG_EMAIL" ] && GNUPG_EMAIL=$EMAIL
[ -z "$OIDC_ENABLED" ] && OIDC_ENABLED="false"

if [[ ! -f "${GNUPGHOME}/trustdb.gpg" ]]; then
  echo -e "\nCreating Home Directory for GNUPG: ${GNUPGHOME}"
  mkdir -p ${GNUPGHOME}
  gpg --batch --gen-key <<EOF
%echo Generating GNUPG key...
Key-Type: 1
Key-Length: 4096
Subkey-Type: 1
Subkey-Length: 4096
Passphrase: ${GNUPG_PASSPHRASE}
Name-Real: MISP Admin
Name-Email: ${GNUPG_EMAIL}
Expire-Date: 0
%commit
%echo Generated GNUPG Key!
EOF
  echo -e "\nChanging ownership of ${GNUPGHOME} to user www-data..."
  chown -R www-data:www-data /gnupg
  ls -l /gnupg
  echo -e "\nDone configuring GNUPG!"
fi

# Enable OIDC Auth
if [[ "${OIDC_ENABLED}" == "true" ]]; then
  echo -e "\nEnabling OIDC Authentication..."
  sed -i -e "s|// CakePlugin::load('CertAuth');|CakePlugin::load('OidcAuth');|g" $MISP_APP_CONFIG_PATH/bootstrap.php
  sed -i -e "/'salt'/a\    'auth' => array('OidcAuth.Oidc')," $MISP_APP_CONFIG_PATH/config.php
  sed -i -e "$ i\   'OidcAuth' => [\n\
    'offline_access' => true,\n\
    'check_user_validity' => 300,\n\
    'provider_url' => \'${OIDC_PROVIDER_URL}\',\n\
    'client_id' => '${OIDC_CLIENT_ID}',\n\
    'client_secret' => '${OIDC_CLIENT_SECRET}',\n\
    'role_mapper' => [ // if user has multiple roles, first role that match will be assigned to user\n\
        'misp-user' => 3, // User\n\
        'misp-admin' => 1, // Admin\n\
    ],\n\
    'default_org' => '${ORGNAME:-"MY_ORG"}',\n\
  ]," $MISP_APP_CONFIG_PATH/config.php
  cat $MISP_APP_CONFIG_PATH/config.php | grep -i OidcAuth -A 12
  echo -e "\nEnabled OIDC Authentication!"
fi

echo -e "\nChanging config.php,bootstrap.php ownership to user www-data..."
chown www-data:www-data $MISP_APP_CONFIG_PATH/config.php $MISP_APP_CONFIG_PATH/bootstrap.php
echo -e "Ownership changed!\n"

[[ ! -f "/var/www/MISP/app/tmp/logs/debug.log" ]] && runuser -u www-data -- touch /var/www/MISP/app/tmp/logs/debug.log && echo -e "\nCreated debug log file!" || echo -e "\nDebug log file already exists."
[[ ! -f "/var/www/MISP/app/tmp/logs/error.log" ]] && runuser -u www-data -- touch /var/www/MISP/app/tmp/logs/error.log && echo -e "\nCreated error log file!" || echo -e "\nError log file already exists."
echo "\n=====> Streaming MISP Logs <====="
tail -F /var/www/MISP/app/tmp/logs/debug.log /var/www/MISP/app/tmp/logs/error.log &