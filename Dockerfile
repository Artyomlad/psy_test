FROM alpine:3.7
RUN apk update

# install all packages (openssh, nmap, nginx)
RUN apk add openssh --no-cache && \
    apk add nmap --no-cache && \
    apk add nginx --no-cache

# Run nginx configurations
RUN adduser -D -g 'www' www && \
    mkdir /run/nginx && \
    mkdir /www && \
    chown -R www:www /var/lib/nginx && \
    chown -R www:www /www

# Copy nginx conf files:
COPY nginx.conf /etc/nginx
COPY index.html /www

# sshd conf
RUN ssh-keygen -A

# Start nginx & sshd
CMD nginx && /usr/sbin/sshd -D

EXPOSE 80
EXPOSE 22
