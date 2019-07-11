#!/bin/bash
#Author : Harsh Patel
#Date of creation : 11 july 2019
#------------------------------Package installation----------------------------
PACKAGES="firewalld nginx mariadb-server mariadb-client php-fpm php-mysql php-curl php-gd php-intl php-mbstring php-soap php-xml php-xmlrpc php-zip unzip"
for i in $PACKAGES;
do
	sudo dpkg --status $i | grep "install ok installed" &> /dev/null
	if [ $? -eq 0 ];
	then
		echo "$i already installed"
	else
		echo "Do you want to install $i "
		read -p "Y for Yes or N for No : " answer
		if [ $answer == "Y" ];
		then
			sudo apt-get install -y $i
		else
			exit
		fi
	fi
done

#-----------------------------firewall add service-----------------------------

sudo firewall-cmd --list-all | grep "http" &> /dev/null
if [ $? -eq 0 ];
then
        echo "HTTP Service is already added!!!"
else
        firewall-cmd --permanent --add-service=http
        firewall-cmd --reload
fi
sudo firewall-cmd --list-all
#-------------------------------get domain name--------------------------------

function jumpto
{
    label=$1
    cmd=$(sed -n "/$label:/{:a;n;p;ba};" $0 | grep -v ':$')
    eval "$cmd"
    exit
}

get_domain:

echo "Enter the Domain Name : "
read domain

grep "127.0.0.1 $domain" /etc/hosts &> /dev/null
if [ $? -eq 0 ];
then
        echo "Entry for $domain already Exist!!!"
        echo "Do you want to enter another domain name? "
        read -p "Y for yes or N for No : " ans
        if [ $ans == "Y" ];
        then
          jumpto get_domain
        fi
        else
        echo "127.0.0.1 $domain" >> /etc/hosts
fi

#----------------------------Nginx file configuration--------------------------

sudo touch /etc/nginx/sites-available/$domain
echo " server {
        listen 80;
        root /var/www/wordpress;
        index index.php index.html index.htm index.nginx-debian.html;
        server_name $domain;

        location / {
                try_files \$uri \$uri/ /index.php\$is_args\$args;
        }

        location ~ \.php$ {
                include snippets/fastcgi-php.conf;
                fastcgi_pass unix:/var/run/php/php7.2-fpm.sock;
       }

        location ~ /\.ht {
                deny all;
        }
}" > /etc/nginx/sites-available/$domain

sudo nginx -t
sudo ln -s /etc/nginx/sites-available/$domain /etc/nginx/sites-enabled/
sudo unlink /etc/nginx/sites-enabled/default
#----------------------------Download Wordpress file---------------------------
echo "----------------------Downloading Wordpress file------------------------"
cd /var/www/
ls -a | grep "^latest" &> /dev/null
if [ $? -eq 0 ];
then
        echo " File already exist!!! "

else
        wget https://wordpress.org/latest.zip
fi

echo"---------------------------Extracting file-------------------------------"

unzip latest.zip
cp /var/www/wordpress/wp-config-sample.php /var/www/wordpress/wp-config.php
sudo chown -R www-data:www-data /var/www/wordpress

#-------------------------------mysql installation-----------------------------
echo "-----------------------mysql_secure_installation------------------------"
echo "Enter the password for root : "
read root_pass

sudo mysql --user=root <<EOF 
UPDATE mysql.user SET authentication_string=PASSWORD('$root_pass') WHERE User='root';
DELETE FROM mysql.user WHERE User=''; 
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1'); 
DROP DATABASE IF EXISTS test; DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%'; 
FLUSH PRIVILEGES; 
EOF
#-----------------------------Adding new database-----------------------------
echo "---------------------Enter database credentials-------------------------"
echo "Enter database name : "
read dbname
echo "Enter User name : "
read dbuser
echo "Enter password for user : "
read dbpass

echo "Enter your database root user password"
sudo mysql -u root -p <<EOF
CREATE DATABASE $dbname;
CREATE USER '$dbuser'@'localhost' IDENTIFIED BY '$dbpass';
GRANT ALL PRIVILEGES ON $dbname.* TO '$dbuser'@'localhost';
EOF
#----------------------------- wp-config.php edit------------------------------
echo "--------------database configuration in wp-config.php file-------------"
sudo perl -pi -e "s/database_name_here/$dbname/g" /var/www/wordpress/wp-config.php
sudo perl -pi -e "s/username_here/$dbuser/g" /var/www/wordpress/wp-config.php
sudo perl -pi -e "s/password_here/$dbpass/g" /var/www/wordpress/wp-config.php
sudo wget -q -O - https://api.wordpress.org/secret-key/1.1/salt/ >> /var/www/wordpress/wp-config.php
#-----------------------------------------------------------------------------
echo "----------------------restart services----------------------------------"
sudo systemctl restart nginx
sudo systemctl restart php7.2-fpm
#-----------------------------------------------------------------------------
