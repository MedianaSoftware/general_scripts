read -p "Enter server name (eg medianasoftware.nl): " SERVER_NAME
SERVER_NAME=${SERVER_NAME:-medianasoftware.nl}

read -p "Enter project name: " PROJECT_NAME
PROJECT_NAME=${PROJECT_NAME:-django}

read -p "Should this be a postgres server? (y/n): " SETUP_POSTGRES
SETUP_POSTGRES=${SETUP_POSTGRES:-n}

read -p "Setup cerbot for HTTPS? (y/n): " SETUP_CERTBOT
SETUP_CERTBOT=${SETUP_CERTBOT:-n}

# add project name to environment
echo PROJECT_NAME=$PROJECT_NAME >> /etc/environment

apt update
apt install -y nginx python3-venv python3-wheel gcc python3-dev

# Install certbot
apt-get install -y software-properties-common
add-apt-repository universe
apt-get update
apt-get install -y certbot python3-certbot-nginx

# Setup mediana user
adduser --disabled-password --gecos "" mediana
echo 'mediana ALL=(ALL) NOPASSWD: ALL' | sudo EDITOR='tee -a' visudo
usermod -aG sudo mediana

mkdir /home/mediana/.ssh
cp /root/.ssh/authorized_keys /home/mediana/.ssh/authorized_keys
chown -R mediana:mediana /home/mediana/.ssh
systemctl restart sshd

# Setup project dirs and config 
mkdir -p /home/mediana/$PROJECT_NAME/$PROJECT_NAME
mkdir -p /home/mediana/$PROJECT_NAME-logs/
mkdir -p /home/mediana/database-backups/

# Setup Firewall
apt install -y ufw
ufw default deny
ufw allow 443
ufw allow 80
ufw allow 22
ufw enable

# Setup production.py
echo "
import os

ALLOWED_HOSTS = ['$SERVER_NAME']
DEBUG = False
SECRET_KEY = os.environ.get('DJANGO_SECRET_KEY', 'asjklfhaskldjfhasjklfhklasjdhf')
STATIC_ROOT = \"/var/www/$PROJECT_NAME/static\"

LOG_BASE_PATH = \"/home/mediana/$PROJECT_NAME-logs/\"
LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'formatters': {
        'verbose': {
            'format': '{asctime} [{levelname}] {filename}:{lineno}:{funcName} {message}',
            'style': '{',
        },
        'simple': {
            'format': '{message}',
            'style': '{',
        },
        'graylog': {
            'format': '[%(asctime)s][$(pathname)s]',
        },
    },
    'handlers': {
        'file': {
            'level': 'DEBUG',
            'class': 'logging.FileHandler',
            'filename': LOG_BASE_PATH + './debug.log',
            'formatter': 'verbose',
        },
        'console': {
            'level': 'INFO',
            'class': 'logging.StreamHandler',
            'formatter': 'simple',
        },
    },
    'loggers': {
        '': {
            'handlers': ['console', 'file'],
            'level': 'DEBUG',
        },
    },
}

" > /home/mediana/$PROJECT_NAME/$PROJECT_NAME/production.py

cd ~
python3 -m venv /home/mediana/venv
source /home/mediana/venv/bin/activate
pip3 install wheel daphne django

# Create repository
mkdir -p /home/mediana/$PROJECT_NAME.git
cd /home/mediana/$PROJECT_NAME.git
git init --bare

# Create django secret key
DJANGO_SECRET=$(python -c 'from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())')

# Create hook
echo "Creating deployment hook"
cd /home/mediana/$PROJECT_NAME.git/hooks
wget https://raw.githubusercontent.com/MedianaSoftware/general_scripts/master/post-receive -O /home/mediana/$PROJECT_NAME.git/hooks/post-receive
chmod +x post-receive
chown -R mediana:mediana /home/mediana/

# Create daphne service
echo "Creating daphne service"
wget https://raw.githubusercontent.com/MedianaSoftware/general_scripts/master/django-daphne.service -O /etc/systemd/system/django-daphne.service
sed -i "s/\$DJANGO_SECRET/$DJANGO_SECRET/g" /etc/systemd/system/django-daphne.service
sed -i "s/\$PROJECT_NAME/$PROJECT_NAME/g" /etc/systemd/system/django-daphne.service
sed -i "s/\$SERVER_NAME/$SERVER_NAME/g" /etc/systemd/system/django-daphne.service
echo "Created daphne service"
echo 

# Set up nginx
echo "Setting up nginx"
rm /etc/nginx/sites-enabled/default
wget https://raw.githubusercontent.com/MedianaSoftware/general_scripts/master/nginx-config -O /etc/nginx/sites-available/$PROJECT_NAME
sed -i "s/\$PROJECT_NAME/$PROJECT_NAME/g" /etc/nginx/sites-available/$PROJECT_NAME
sed -i "s/\$SERVER_NAME/$SERVER_NAME/g" /etc/nginx/sites-available/$PROJECT_NAME

ln -s /etc/nginx/sites-available/$PROJECT_NAME /etc/nginx/sites-enabled/

nginx -t
systemctl restart nginx

mkdir -p "/var/www/$PROJECT_NAME/media/"
mkdir -p "/var/www/$PROJECT_NAME/static/"
chown -R mediana:mediana "/var/www/$PROJECT_NAME/static/"
chown -R mediana:mediana "/var/www/$PROJECT_NAME/static/"

# Unused directory?
mkdir -p "/var/www/static"
chown -R mediana:mediana "/var/www/static/"

if [ $SETUP_POSTGRES = "y" ]
then
    echo "Installing postgres..."
    wget https://github.com/MedianaSoftware/general_scripts/blob/master/setup_postgres.sh -O /home/mediana/setup_postgres.sh
    bash /home/mediana/setup_postgres.sh
fi

if [ $SETUP_CERTBOT = "y" ]
then
    echo "Setting up certbot..."
    wget https://github.com/MedianaSoftware/general_scripts/blob/master/setup_certbot.sh -O /home/mediana/setup_certbot.sh
    bash /home/mediana/setup_certbot.sh
fi

systemctl daemon-reload
systemctl enable django-daphne

chown -R mediana:mediana /home/mediana/$PROJECT_NAME

echo "Dont forget to add the following to settings.py:"
echo """
try:
    from .local import * 
except ImportError:
    try:
        from .staging import *
    except ImportError:
        try:
            from .production import *
        except ImportError:
            pass
"""

# Receive code
echo ""
echo "Then, please run the following command:"
echo "git remote add deploy ssh://mediana@$SERVER_NAME/home/mediana/$PROJECT_NAME.git/ && git push deploy"
echo "in your local repository."
