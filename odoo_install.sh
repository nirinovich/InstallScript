#!/bin/bash
################################################################################
# Optimized Odoo 18.0 Installation for Ubuntu 24.04 / WSL2
# Fixes the lxml_html_clean split and PEP 668 system locks.
################################################################################

## --- CONFIGURATION ---
OE_USER="odoo"
OE_HOME="/$OE_USER"
OE_HOME_EXT="/$OE_USER/${OE_USER}-server"
OE_VERSION="18.0"
OE_PORT="8069"
OE_SUPERADMIN="admin" 
GENERATE_RANDOM_PASSWORD="True"
OE_CONFIG="${OE_USER}-server"

#--------------------------------------------------
# 1. Update & System Dependencies
#--------------------------------------------------
echo -e "\n---- Preparing System ----"
sudo apt-get update -y && sudo apt-get upgrade -y
sudo apt-get install -y python3-pip python3-dev python3-venv python3-wheel \
git build-essential wget libxslt-dev libzip-dev libldap2-dev libsasl2-dev \
node-less libpng-dev libjpeg-dev gdebi libpq-dev libxml2-dev libxslt1-dev \
curl gpg lsb-release

#--------------------------------------------------
# 2. PostgreSQL 16 Setup
#--------------------------------------------------
echo -e "\n---- Installing PostgreSQL 16 ----"
sudo curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/postgresql.gpg
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
sudo apt-get update -y
sudo apt-get install -y postgresql-16 postgresql-server-dev-16

echo -e "\n---- Creating Database User ----"
sudo su - postgres -c "createuser -s $OE_USER" 2> /dev/null || true

#--------------------------------------------------
# 3. Python 3.12 / Odoo 18 Fixes (Global Install)
#--------------------------------------------------
echo -e "\n---- Installing Odoo 18 Requirements ----"
# Force global install to ensure 'odoo' user has access on Ubuntu 24.04
sudo pip3 install --break-system-packages \
    -r https://github.com/odoo/odoo/raw/${OE_VERSION}/requirements.txt

echo -e "\n---- Injecting Missing Odoo 18 Libraries ----"
sudo pip3 install --break-system-packages \
    lxml_html_clean \
    psycopg2-binary \
    num2words \
    phonenumbers \
    decorator \
    passlib \
    polib

#--------------------------------------------------
# 4. Wkhtmltopdf & NPM
#--------------------------------------------------
echo -e "\n---- Installing Wkhtmltopdf & RTL Support ----"
sudo apt-get install -y wkhtmltopdf
sudo apt-get install -y nodejs npm
sudo npm install -g rtlcss

#--------------------------------------------------
# 5. Odoo 18 Source Code & Permissions
#--------------------------------------------------
echo -e "\n---- Setting up Odoo Directories ----"
sudo adduser --system --quiet --shell=/bin/bash --home=$OE_HOME --group $OE_USER
sudo adduser $OE_USER sudo

echo -e "\n---- Cloning Odoo $OE_VERSION Source ----"
# Removing old content to prevent conflicts
sudo rm -rf $OE_HOME_EXT
sudo git clone --depth 1 --branch $OE_VERSION https://www.github.com/odoo/odoo $OE_HOME_EXT/

sudo su $OE_USER -c "mkdir -p $OE_HOME/custom/addons"
sudo mkdir -p /var/log/$OE_USER
sudo chown -R $OE_USER:$OE_USER /var/log/$OE_USER
sudo chown -R $OE_USER:$OE_USER $OE_HOME

#--------------------------------------------------
# 6. Configuration (Encapsulated)
#--------------------------------------------------
if [ "$GENERATE_RANDOM_PASSWORD" = "True" ]; then
    OE_SUPERADMIN=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)
fi

cat <<EOF | sudo tee $OE_HOME_EXT/odoo.conf
[options]
admin_passwd = $OE_SUPERADMIN
http_port = $OE_PORT
logfile = /var/log/$OE_USER/$OE_CONFIG.log
addons_path = $OE_HOME_EXT/addons,$OE_HOME/custom/addons
db_host = 127.0.0.1
EOF

sudo chown $OE_USER:$OE_USER $OE_HOME_EXT/odoo.conf
sudo chmod 640 $OE_HOME_EXT/odoo.conf

#--------------------------------------------------
# 7. Helper Scripts
#--------------------------------------------------
cat <<EOF | sudo tee $OE_HOME_EXT/start.sh
#!/bin/bash
sudo su - $OE_USER -s /bin/bash -c "$OE_HOME_EXT/odoo-bin -c $OE_HOME_EXT/odoo.conf"
EOF
sudo chmod +x $OE_HOME_EXT/start.sh

echo "-----------------------------------------------------------"
echo "Odoo 18.0 Installation Complete!"
echo "Master Password: $OE_SUPERADMIN"
echo "To start Odoo: sudo $OE_HOME_EXT/start.sh"
echo "-----------------------------------------------------------"