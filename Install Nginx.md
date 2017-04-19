#Installing on debian with nginx

chgrp -R www-data uploads
chmod -R g+w uploads/

vi /etc/nginx/sites-enabled/YOUR_CONFIG

#Installing on ubuntu with nginx

apt-get install git nginx mysql-server php-fpm php-mysql vim