echo "Updating snap"
sudo snap install core; sudo snap refresh core

echo "Installing certbot"
sudo snap install --classic certbot
sudo ln -s /snap/bin/certbot /usr/bin/certbot

echo "Running certbot"
sudo certbot --nginx
