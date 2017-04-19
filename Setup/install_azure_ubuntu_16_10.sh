#!/bin/bash
read -p 'Please enter the domainname under which the server IS reachable (configure DNS first!): ' domainname
read -s -p 'Please enter MYSQL root password (we will autmatically create a user for the ESV):' password

esvmysqlpass=$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c${1:-32};echo;)
esvadminpass=$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c${1:-32};echo;)
esvadminhash=`php << EOF
    <?php echo password_hash("${esvadminpass}", PASSWORD_DEFAULT); ?>
EOF`

add-apt-repository ppa:certbot/certbot
apt-get update
apt-get install certbot

certbot certonly --webroot -w /var/www/html -d ${domainname}

mv /etc/nginx/sites-available/default /etc/nginx/sites-available/default.pkg

cat >/etc/nginx/sites-available/default <<EOL
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    root /var/www/html;

    server_name _;

    location /.well-known/acme-challenge/ {

        try_files $uri $uri/ =404;
    }

    location / {
        return 301 https://$host$request_uri;
    }
}
EOL

cat >/etc/nginx/sites-available/esv <<EOL
server {
    # SSL configuration
    #
    listen 443 ssl http2 default_server;
    listen [::]:443 ssl http2 default_server;

    include snippets/ssl.conf;

    root /var/www/html;

    index index.php;

    server_name _;

    location / {
        try_files $uri $uri/ =404;
    }

    # Block access to hidden" directories or files.
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }

    # Block access files accidentally left on the server.
    location ~ (\.(bak|config|sql(\.zip|\.gz|\.bz2)?|ini|log|sh|inc|swp|t3d)|~)$ {
        deny all;
        access_log off;
        log_not_found off;
    }

    # deny access to .htaccess files, if Apache's document root
    # concurs with nginx's one
    #
    location ~ /\.ht {
        deny all;
    }

    # allow and deny filled newsletter from certain ips
    # TODO: this is not the best solution - should definitely use some php-functionality
    location ~ /uploads {
        # allow some subnet...;
        # deny all;
        allow all;
    }

    #allow access to login action
    location ~ /code/actions/ {
        include snippets/myphp.conf
    }

    # deny access to other directory
    location ~ /(Setup|inc|code|dao)/ {
            deny all;
            return 404;
    }

    include snippets/myphp.conf
}
EOL

ln -s /etc/nginx/sites-available/esv /etc/nginx/sites-enabled/esv
ln -s /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default

cat >/etc/nginx/snippets/myphp.conf <<EOL
# pass the PHP scripts to FastCGI server
location ~ \.php$ {
    include snippets/fastcgi-php.conf;
    fastcgi_pass unix:/run/php/php7.0-fpm.sock;
    fastcgi_buffer_size 128k;
    fastcgi_buffers 256 16k;
    fastcgi_busy_buffers_size 256k;
    fastcgi_temp_file_write_size 256k;
}
EOL

cat >/etc/nginx/snippets/ssl.conf <<EOL
ssl_session_timeout 1d;
ssl_session_cache shared:SSL:50m;
ssl_session_tickets off;
ssl_dhparam /etc/nginx/dhparams.pem;
ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
ssl_ciphers 'ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA:ECDHE-RSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-RSA-AES256-SHA256:DHE-RSA-AES256-SHA:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA256:AES256-SHA256:AES128-SHA:AES256-SHA:!DSS';
ssl_prefer_server_ciphers on;
add_header Strict-Transport-Security max-age=15768000;
ssl_stapling on;
ssl_stapling_verify on;
ssl_certificate /etc/letsencrypt/live/${domainname}/fullchain.pem;
ssl_certificate_key /etc/letsencrypt/live/${domainname}/privkey.pem;
EOL

sed --in-place '/multi_accept/c\
multi_accept on;\
use epoll;' /etc/nginx/nginx.conf

sed --in-place 's/worker_connections 768/worker_connections 8096/g' /etc/nginx/nginx.conf

sed --in-place 's/keepalive_timeout 65/keepalive_timeout 15/g' /etc/nginx/nginx.conf

systemctl enable nginx.service
systemctl restart nginx.service

sed --in-place 's/;emergency_restart_threshold = 0/emergency_restart_threshold = 10/g' /etc/php/7.0/fpm/php-fpm.conf

sed --in-place 's/;emergency_restart_interval = 0/emergency_restart_interval = 1m/g' /etc/php/7.0/fpm/php-fpm.conf

sed --in-place 's/;process_control_timeout = 0/process_control_timeout = 10s/g' /etc/php/7.0/fpm/php-fpm.conf

sed --in-place 's/pm.max_children = 5/pm.max_children = 25/g' /etc/php/7.0/fpm/pool.d/www.conf

sed --in-place 's/pm.start_servers = 2/pm.start_servers = 12/g' /etc/php/7.0/fpm/pool.d/www.conf

sed --in-place 's/pm.min_spare_servers = 1/pm.min_spare_servers = 10/g' /etc/php/7.0/fpm/pool.d/www.conf

sed --in-place 's/pm.max_spare_servers = 3/pm.max_spare_servers = 15/g' /etc/php/7.0/fpm/pool.d/www.conf

sed --in-place 's/;pm.max_requests = 500/pm.max_requests = 500/g' /etc/php/7.0/fpm/pool.d/www.conf

git checkout https://github.com/gymdb/speechday.git /var/www/html

chown -R root:www-data /var/www/html
chmod -R 750 /var/www/html
chmod -R 770 /var/www/html/uploads

mysql -u root -p$password -e "CREATE DATABASE esv DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci;"
mysql -u root -p$password -e "GRANT SELECT,INSERT,UPDATE,DELETE,CREATE,CREATE TEMPORARY TABLES,DROP,INDEX,ALTER ON esv.* TO
esv@localhost IDENTIFIED BY '${esvmysqlpass}';"
mysql -u root -p$password -e "flush privileges;"
mysql -u root -p$password </var/www/html/Setup/database.sql

echo All set. Go to https://${domainname}. User is admin and password is ${esvadminpass}

unset password
unset esvmysqlpass
unset esvadminpass
unset esvadminhash
