sudo apt-get update
sudo apt-get install postgresql postgresql-contrib
sudo apt-get install libpq-dev python3-dev
pip install psycopg2
sudo -u postgres psql

# CREATE DATABASE mydb;
# CREATE USER myuser WITH ENCRYPTED PASSWORD 'mypass';

# ALTER ROLE myuser SET client_encoding TO 'utf8';
# ALTER ROLE myuser SET default_transaction_isolation TO 'read committed';
# ALTER ROLE myuser SET timezone TO 'UTC';

# GRANT ALL PRIVILEGES ON DATABASE mydb TO myuser;

#DATABASES = {
#    'default': {
#        'ENGINE': 'django.db.backends.postgresql_psycopg2',
#        'NAME': 'mydb',
#        'USER': 'myuser',
#        'PASSWORD': 'mypass',
#        'HOST': 'localhost',
#        'PORT': '',
#    }
#}
