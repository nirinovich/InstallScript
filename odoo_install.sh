#!/bin/bash
################################################################################
# Script for installing Odoo 18.0 on WSL2 (Ubuntu)
# Adapted for Nikita - Encapsulated Config & Group Permissions
################################################################################

OE_USER="odoo"
# We'll use /odoo as the base as per your preference
OE_HOME="/$OE_USER"
OE_HOME_EXT="/$OE_USER/${OE_USER}-server"
OE_PORT="8069"
OE_VERSION="18.0"
IS_ENTERPRISE="False"
INSTALL_WKHTMLTOPDF="True"
INSTALL_POSTGRESQL_SIXTEEN="True"
INSTALL_NGINX="False" # We use Windows Caddy/Servy instead
GENERATE_RANDOM_PASSWORD="True"
OE_SUPERADMIN="admin"

# --- NEW: CONFIG LOCATION ---
# Moving from /etc/ to the Odoo folder itself
OE_CONFIG_PATH="$OE_HOME_EXT/odoo.conf"

#--------------------------------------------------
# Update & Base Dependencies
#--------------------------------------------------
sudo apt-get update && sudo apt-get upgrade -y
sudo apt-get install -y python3-pip python3-dev python3-venv git build-essential libpq-dev libxml2-dev libxslt1-dev libldap2-dev libsasl2-dev libjpeg-dev zlib1g-dev nodejs npm

#--------------------------------------------------
# User Management (The "Nikita" Fix)
#--------------------------------------------------
echo -e "\n---- Setting up Users ----"
# Create Odoo system user if not exists
sudo adduser --system --quiet --shell=/bin/bash --home=$OE_HOME --group $OE_USER

# ADD CURRENT USER (nikita) TO ODOO GROUP
# This allows you to edit files without permission denied errors
sudo usermod -aG $OE_USER $USER 
sudo adduser $OE_USER sudo

#--------------------------------------------------
# Install PostgreSQL
#--------------------------------------------------
if [ "$INSTALL_POSTGRESQL_SIXTEEN" = "True" ]; then
    sudo curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc|sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/postgresql.gpg
    sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
    sudo apt-get update && sudo apt-get install -y postgresql-16
fi
sudo su - postgres -c "createuser -s $OE_USER" || true

#--------------------------------------------------
# Install Odoo Core
#--------------------------------------------------
sudo mkdir -p $OE_HOME_EXT
sudo git clone --depth 1 --branch $OE_VERSION https://www.github.com/odoo/odoo $OE_HOME_EXT/

# Install Python Requirements
pip3 install --break-system-packages --user -r $OE_HOME_EXT/requirements.txt

#--------------------------------------------------
# Create Encapsulated Config
#--------------------------------------------------
echo -e "\n---- Creating Config in $OE_CONFIG_PATH ----"
if [ $GENERATE_RANDOM_PASSWORD = "True" ]; then
    OE_SUPERADMIN=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)
fi

sudo touch $OE_CONFIG_PATH
cat <<EOF | sudo tee $OE_CONFIG_PATH
[options]
admin_passwd = $OE_SUPERADMIN
http_port = $OE_PORT
logfile = $OE_HOME_EXT/odoo.log
addons_path = $OE_HOME_EXT/addons,$OE_HOME/custom/addons
db_host = 127.0.0.1
proxy_mode = True
xmlrpc_interface = 0.0.0.0
EOF

#--------------------------------------------------
# Final Permissions (The most important part)
#--------------------------------------------------
echo -e "\n---- Fixing Permissions for Nikita & Odoo ----"
sudo chown -R $OE_USER:$OE_USER $OE_HOME
# Allow group (Nikita) to write to addons and config
sudo chmod -R 775 $OE_HOME
# Ensure odoo-bin is executable
sudo chmod +x $OE_HOME_EXT/odoo-bin

echo "Done! Use this to start Odoo manually: "
echo "sudo su - $OE_USER -c '$OE_HOME_EXT/odoo-bin -c $OE_CONFIG_PATH'"