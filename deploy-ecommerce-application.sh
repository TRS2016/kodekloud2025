#!/bin/bash

function isPackageInstalled() {

    package=$1

    if ! rpm -q $package &>/dev/null
    then
        echo "$1 not installed. Installing..."
        sudo yum install -y $package
        installation_status=$?

    else
        echo "$package is already installed"
        installation_status=0
    fi
}

function isServiceRunning() {

    service=$1


    if [[ $installation_status -eq 0 ]]
    then
        sudo systemctl status $service &>/dev/null
        running_status=$?
        if [[ $running_status = 0 ]]
        then
            echo "$service is running"
        else
            echo "$service is not active"
            sudo systemctl start $service
            sudo systemctl enable $service
        fi
    else
        echo "$service is not installed."
    fi
    
}

function configureFirewall() {
    port=$1
    sudo firewall-cmd --permanent --zone=public --add-port=$port
    sudo firewall-cmd --reload
}

# Deploy Pre-Requisites
# 1. Install FirewallD
isPackageInstalled firewalld
isServiceRunning firewalld


# Deploy and Configure Database
# 1. Install MariaDB
isPackageInstalled mariadb-server
isServiceRunning mariadb

# 2. Configure firewall for Database
configureFirewall 3306/tcp

# 3. Configure Database
sudo mysql <<-EOF
CREATE DATABASE ecomdb;
CREATE USER 'ecomuser'@'localhost' IDENTIFIED BY 'ecompassword';
GRANT ALL PRIVILEGES ON *.* TO 'ecomuser'@'localhost';
FLUSH PRIVILEGES;
EOF


# 4. Load Product Inventory Information to database
# Create the db-load-script.sql
cat > db-load-script.sql <<-EOF
USE ecomdb;
CREATE TABLE products (id mediumint(8) unsigned NOT NULL auto_increment,Name varchar(255) default NULL,Price varchar(255) default NULL, ImageUrl varchar(255) default NULL,PRIMARY KEY (id)) AUTO_INCREMENT=1;

INSERT INTO products (Name,Price,ImageUrl) VALUES ("Laptop","100","c-1.png"),("Drone","200","c-2.png"),("VR","300","c-3.png"),("Tablet","50","c-5.png"),("Watch","90","c-6.png"),("Phone Covers","20","c-7.png"),("Phone","80","c-8.png"),("Laptop","150","c-4.png");

EOF

# Run sql script
sudo mysql < db-load-script.sql

# Deploy and Configure Web
# 1. Install required packages
isPackageInstalled 'httpd php php-mysqlnd'
configureFirewall 80/tcp

# 2. Configure httpd
# Change DirectoryIndex index.html to DirectoryIndex index.php to make the php page the default page
sudo sed -i 's/index.html/index.php/g' /etc/httpd/conf/httpd.conf

# 3. Start httpd
isServiceRunning httpd

# 4. Download code
isPackageInstalled git
sudo git clone https://github.com/kodekloudhub/learning-app-ecommerce.git /var/www/html/

# 5. Create and Configure the .env File
# change file owner
sudo chown bob:bob /var/www/html/

# Create and configure the .env file
cat > /var/www/html/.env <<-EOF
DB_HOST=localhost
DB_USER=ecomuser
DB_PASSWORD=ecompassword
DB_NAME=ecomdb
EOF

# 6. Update index.php
# Update the index.php file to load the environment variables from the .env file 
# and use them to connect to the database.




