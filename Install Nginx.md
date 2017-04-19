#Installing on debian with nginx

chgrp -R www-data uploads
chmod -R g+w uploads/

vi /etc/nginx/sites-enabled/YOUR_CONFIG

#Installing on ubuntu with nginx

```
apt-get install git nginx mysql-server php-fpm php-mysql vim
```

```
sudo add-apt-repository ppa:certbot/certbot
sudo apt-get update
sudo apt-get install certbot
```

```
certbot certonly --webroot -w /var/www/html -d esv.miic.at
```

```
mv /etc/nginx/sites-available/default /etc/nginx/sites-available/default.pkg
```

```
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
```

```
cat >/etc/nginx/sites-available/esv <<EOL
server {
    # SSL configuration
    #
    listen 443 ssl http2 default_server;
    listen [::]:443 ssl http2 default_server;

    include ssl.conf;

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
```

```
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
```

