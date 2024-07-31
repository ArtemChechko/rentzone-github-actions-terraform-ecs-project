# Use the latest version of the Amazon Linux base image
FROM amazonlinux:2 AS builder

# Update all installed packages to their latest versions and install necessary packages in one go
RUN yum update -y && \
    yum install -y unzip wget httpd amazon-linux-extras git && \
    amazon-linux-extras enable php7.4 && \
    yum clean metadata && \
    yum install -y php php-common php-pear php-cgi php-curl php-mbstring php-gd php-mysqlnd php-gettext php-json php-xml php-fpm php-intl php-zip && \
    wget https://repo.mysql.com/mysql80-community-release-el7-3.noarch.rpm && \
    rpm --import https://repo.mysql.com/RPM-GPG-KEY-mysql-2023 && \
    yum localinstall mysql80-community-release-el7-3.noarch.rpm -y && \
    yum install mysql-community-server -y && \
    yum clean all && \
    rm -rf /var/cache/yum

# Change directory to the html directory
WORKDIR /var/www/html

# Set the build argument directive
ARG PERSONAL_ACCESS_TOKEN
ARG GITHUB_USERNAME
ARG REPOSITORY_NAME
ARG WEB_FILE_ZIP
ARG WEB_FILE_UNZIP
ARG DOMAIN_NAME
ARG RDS_ENDPOINT
ARG RDS_DB_NAME
ARG RDS_DB_USERNAME
ARG RDS_DB_PASSWORD

# Use the build argument to set environment variables 
ENV PERSONAL_ACCESS_TOKEN=$PERSONAL_ACCESS_TOKEN
ENV GITHUB_USERNAME=$GITHUB_USERNAME
ENV REPOSITORY_NAME=$REPOSITORY_NAME
ENV WEB_FILE_ZIP=$WEB_FILE_ZIP
ENV WEB_FILE_UNZIP=$WEB_FILE_UNZIP
ENV DOMAIN_NAME=$DOMAIN_NAME
ENV RDS_ENDPOINT=$RDS_ENDPOINT
ENV RDS_DB_NAME=$RDS_DB_NAME
ENV RDS_DB_USERNAME=$RDS_DB_USERNAME
ENV RDS_DB_PASSWORD=$RDS_DB_PASSWORD

# Clone the GitHub repository and set up the application
RUN git clone https://$PERSONAL_ACCESS_TOKEN@github.com/$GITHUB_USERNAME/$REPOSITORY_NAME.git && \
    unzip $REPOSITORY_NAME/$WEB_FILE_ZIP -d $REPOSITORY_NAME/ && \
    cp -av $REPOSITORY_NAME/$WEB_FILE_UNZIP/. /var/www/html && \
    rm -rf $REPOSITORY_NAME && \
    sed -i '/<Directory "\/var\/www\/html">/,/<\/Directory>/ s/AllowOverride None/AllowOverride All/' /etc/httpd/conf/httpd.conf && \
    chmod -R 777 /var/www/html && \
    chmod -R 777 storage/ && \
    sed -i '/^APP_ENV=/ s/=.*$/=production/' .env && \
    sed -i "/^APP_URL=/ s/=.*$/=https:\/\/$DOMAIN_NAME\//" .env && \
    sed -i "/^DB_HOST=/ s/=.*$/=$RDS_ENDPOINT/" .env && \
    sed -i "/^DB_DATABASE=/ s/=.*$/=$RDS_DB_NAME/" .env && \
    sed -i "/^DB_USERNAME=/ s/=.*$/=$RDS_DB_USERNAME/" .env && \
    sed -i "/^DB_PASSWORD=/ s/=.*$/=$RDS_DB_PASSWORD/" .env

# Create a minimal image with only the necessary packages and files
FROM amazonlinux:2

# Copy only the necessary files from the builder stage
COPY --from=builder /var/www/html /var/www/html
COPY --from=builder /etc/httpd /etc/httpd
COPY --from=builder /usr/lib64/mysql /usr/lib64/mysql
COPY --from=builder /var/lib/mysql /var/lib/mysql
COPY --from=builder /var/log/mysql /var/log/mysql
COPY --from=builder /usr/lib64/php /usr/lib64/php
COPY --from=builder /usr/share/php /usr/share/php
COPY --from=builder /usr/sbin/httpd /usr/sbin/httpd
COPY --from=builder /usr/bin/php /usr/bin/php
COPY --from=builder /usr/bin/mysql /usr/bin/mysql
COPY --from=builder /usr/bin/mysqld_safe /usr/bin/mysqld_safe
COPY --from=builder /etc/php.ini /etc/php.ini

# Copy the AppServiceProvider.php file
COPY AppServiceProvider.php /var/www/html/app/Providers/AppServiceProvider.php

# Expose the default Apache and MySQL ports
EXPOSE 80 3306

# Start Apache and MySQL
ENTRYPOINT ["/usr/sbin/httpd", "-D", "FOREGROUND"]


