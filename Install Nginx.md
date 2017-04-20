#Installing on debian with nginx

chgrp -R www-data uploads
chmod -R g+w uploads/

vi /etc/nginx/sites-enabled/YOUR_CONFIG

#Installing on ubuntu 16.10 with nginx (tested on azure virtual machine)
Install prerequisites:
```
sudo apt-get install git nginx mysql-server php-fpm php-mysql vim
```

Download the install skript:
```
wget https://raw.githubusercontent.com/cmiicbrg/speechday/brg_deploy/Setup/install_azure_ubuntu_16_10.sh
```

Make it executable:
```
chmod +x install_azure_ubuntu_16_10.sh
```
And go:
```
./install_azure_ubuntu_16_10.sh
```