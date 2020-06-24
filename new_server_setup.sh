SERVER_NAME=medianasoftware.nl
PROJECT_NAME=mediana_website

# add project name to environment
echo PROJECT_NAME=$PROJECT_NAME >> /etc/environment

apt update
apt install -y nginx python3-venv python3-wheel gcc python3-dev

# Install certbot
apt-get install software-properties-common
add-apt-repository universe
apt-get update
apt-get install certbot python3-certbot-nginx

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

echo "
import os

ALLOWED_HOSTS = ['$SERVER_NAME']
DEBUG = False
SECRET_KEY = os.environ['DJANGO_SECRET_KEY']
STATIC_ROOT = \"/var/www/$PROJECT_NAME/static\"
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

systemctl daemon-reload
systemctl enable django-daphne

chown -R mediana:mediana /home/mediana/$PROJECT_NAME

# Receive code
echo ""
echo "Please run the following command:"
echo "git remote add deploy ssh://mediana@$SERVER_NAME/home/mediana/$PROJECT_NAME.git/ && git push deploy"
echo "in your local repository."
