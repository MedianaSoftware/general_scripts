SERVER_NAME=django.medianasoftware.nl
PROJECT_NAME=mediana_website

# add project name to environment
echo PROJECT_NAME=$PROJECT_NAME >> /etc/environment

apt install nginx python3-venv

# Setup mediana user
adduser --disabled-password --gecos "" mediana
mkdir /home/mediana/.ssh
cp /root/.ssh/authorized_keys /home/mediana/.ssh/authorized_keys
chown -R mediana:mediana /home/mediana/.ssh
systemctl restart sshd

mkdir -p /home/mediana/$PROJECT_NAME/$PROJECT_NAME
mkdir -p /home/mediana/$PROJECT_NAME-logs/

echo "
ALLOWED_HOSTS = ['$SERVER_NAME']
DEBUG = False
" > /home/mediana/$PROJECT_NAME/$PROJECT_NAME/production.py

cd ~
python3 -m venv venv
source venv/bin/activate
pip install daphne django

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

# Receive code
echo "Please run \"git remote add deploy ssh://mediana@$SERVER_NAME/home/mediana/$PROJECT_NAME.git/\ && git push deploy\" in your local repository, ignore any errors"
echo "Press enter when done"
read _IGNORE

# Create daphne service
echo "Creating daphne service"
wget https://raw.githubusercontent.com/MedianaSoftware/general_scripts/master/django-daphne.service -O /etc/systemd/system/django-daphne.service
sed "s/\$DJANGO_SECRET/$DJANGO_SECRET/g" /etc/systemd/system/django-daphne.service > /etc/systemd/system/django-daphne.service
sed "s/\$PROJECT_NAME/$PROJECT_NAME/g" /etc/systemd/system/django-daphne.service > /etc/systemd/system/django-daphne.service
sed "s/\$SERVER_NAME/$SERVER_NAME/g" /etc/systemd/system/django-daphne.service > /etc/systemd/system/django-daphne.service

systemctl daemon-reload
systemctl enable django-daphne
systemctl start django-daphne
echo "Created and started daphne service"
echo 

# Set up nginx
echo "Setting up nginx"
rm /etc/nginx/sites-enabled/default
wget https://raw.githubusercontent.com/MedianaSoftware/general_scripts/master/nginx-config -O /etc/nginx/sites-available/$PROJECT_NAME
sed "s/\$PROJECT_NAME/$PROJECT_NAME/g" /etc/nginx/sites-available/$PROJECT_NAME > /etc/nginx/sites-available/$PROJECT_NAME
sed "s/\$SERVER_NAME/$SERVER_NAME/g" /etc/nginx/sites-available/$PROJECT_NAME > /etc/nginx/sites-available/$PROJECT_NAME

ln -s /etc/nginx/sites-available/$PROJECT_NAME /etc/nginx/sites-enabled/

nginx -t

mkdir -p "/var/www/$PROJECT_NAME/media/"
mkdir -p "/var/www/$PROJECT_NAME/static/"

chown -R mediana:mediana /home/mediana/$PROJECT_NAME