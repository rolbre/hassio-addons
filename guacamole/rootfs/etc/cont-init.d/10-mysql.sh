#!/command/with-contenv bashio
# ==============================================================================
# Home Assistant Community Add-on: Gucamole
# This file init the MySQL database
# ==============================================================================
declare host
declare port
declare username
declare password
declare database="guacamole"
configdir="/config/addons_config/guacamole"

bashio::log.level "$(bashio::config 'log_level' 'warning')"

if bashio::config.true 'use_database'; then

    # Require MySQL service to be available
    if ! bashio::services.available "mysql"; then
        bashio::log.error "This add-on now requires the MariaDB core add-on 2.0 or newer!"
        bashio::exit.nok "Make sure the MariaDB add-on is installed and running"
    fi

    bashio::log.info 'Enable Database Extension'
    cp -f "$configdir"/extensions-available/guacamole-auth-jdbc-mysql-1.4.0.jar "$configdir"/extensions || true

    if bashio::config.true 'use_totp'; then
        bashio::log.info 'Enable TOTP Extension'
        cp -f "$configdir"/extensions-available/guacamole-auth-totp-1.4.0.jar "$configdir"/extensions || true
    else
        bashio::log.debug 'Disable TOTP Extension'
        rm -f "$configdir"/extensions/guacamole-auth-totp-1.4.0.jar || true
    fi

    host=$(bashio::services "mysql" "host")
    password=$(bashio::services "mysql" "password")
    port=$(bashio::services "mysql" "port")
    username=$(bashio::services "mysql" "username")

    app_username="guacamole"
    app_password=$(bashio::config 'database_password')

    #Drop database based on config flag
    if bashio::config.true 'reset_database'; then
        bashio::log.warning 'Recreating database'
        echo "DROP DATABASE IF EXISTS ${database};" | mysql -h "${host}" -P "${port}" -u "${username}" -p"${password}"

        #Remove reset_database option
        bashio::addon.option 'reset_database'
    fi

    # Create database if not exists
    echo "CREATE DATABASE IF NOT EXISTS ${database};" | mysql -h "${host}" -P "${port}" -u "${username}" -p"${password}"
    mysql -h "${host}" -P "${port}" -u "${username}" -p"${password}" "${database}" </app/guacamole/schema/001-create-schema.sql
    mysql -h "${host}" -P "${port}" -u "${username}" -p"${password}" "${database}" </app/guacamole/schema/002-create-admin-user.sql

    echo "CREATE USER '${app_username}'@'localhost' IDENTIFIED BY '${app_password}';" | mysql -h "${host}" -P "${port}" -u "${username}" -p"${password}"
    echo "GRANT SELECT,INSERT,UPDATE,DELETE ON ${database}.* TO '${app_username}'@'localhost';" | mysql -h "${host}" -P "${port}" -u "${username}" -p"${password}"
    echo "FLUSH PRIVILEGES;" | mysql -h "${host}" -P "${port}" -u "${username}" -p"${password}"
else
    bashio::log.debug 'Disable Database and TOTP Extension'
    rm -f "$configdir"/extensions/guacamole-auth-jdbc-mysql-1.4.0.jar || true
    rm -f "$configdir"/extensions/guacamole-auth-totp-1.4.0.jar || true
fi
