#!/bin/bash

docker_compose_url="https://github.com/docker/compose/releases/download/1.27.4/docker-compose-$(uname -s)-$(uname -m)"
docker_repo_url="https://download.docker.com/linux/centos/docker-ce.repo"
git_yaml_url="https://raw.githubusercontent.com/Artyomlad/psy_test/main/app.yaml"
app_vol_mount="/mnt/logs"
sshd_port="2222"
nginx_port="8080"

# first part of docker version
docker1=19

# second part of docker version
docker2=3

# first part of docker compose version
docker_compose1=1

# second part of docker compose version
docker_compose2=27

# verify root privileges
if [ ! $(id -u) -eq 0 ]
then
    echo "Please run the script with root privileges"
    exit 1
fi

# verify internet connection
echo "Verifying network connection"

# network access to git
if [ -n "$(ping github.com -c 1 | grep "Name or service not known")" ] || [ -n "$(ping github.com -c 1 | grep "100% packet loss")" ]
then
    echo "Unable to access github.com. Please check network connection and firewall rules"
    exit 1
fi

if [ -n "$(ping download.docker.com -c 1 | grep "Name or service not known")" ] || [ -n "$(ping download.docker.com -c 1 | grep "100% packet loss")" ]
then
    echo "Unable to access download.docker.com. Please check network connection and firewall rules"
    exit 1
fi

echo "Ok"

echo "Verifying Ports"

# verify port sshd (2222)
if [ -n "$(netstat -tulpn | grep ":$sshd_port ")" ]
then
    echo "port $sshd_port is not available and required for the application. Please release this port and run the script again"
    exit 1
fi

# verify port nginx (8080)
if [ -n "$(netstat -tulpn | grep ":$nginx_port ")" ]
then
    echo "port $nginx_port is not available and required for the application. Please release this port and run the script again"
    exit 1
fi

echo "Ok"

# Verify dir app_vol_mount (/mnt/logs) exists
if [ ! -d $app_vol_mount ] 
then
    echo "Directory $app_vol_mount is required and doesn't exist"

    read -p "Do you want to create it? [Y/N]" create_dir
    case $create_dir in
        [Yy]* ) mkdir $app_vol_mount;;
        [Nn]* ) echo "Sorry, this dir is required"; exit 1;;
        * ) echo "Please answer [Y/N]"; exit 1;;
    esac
fi

# install docker
if ! docker --version &> /dev/null
then
    echo "Docker not found. Installing docker"

    yum install -y yum-utils
    yum-config-manager --add-repo $docker_repo_url
    yum install -y docker-ce docker-ce-cli containerd.io
    systemctl enable docker
    systemctl start docker
else
    echo "Docker already installed. Verifying version..."

    # docker has been installed. Need to check the version
    if [[ $(docker --version) =~ (([0-9]+)\.([0-9]+)([\.0-9]*)) ]]
    then
            docker_version=${BASH_REMATCH[1]}
            docker_version_part1=${BASH_REMATCH[2]}
            docker_version_part2=${BASH_REMATCH[3]}

            echo "docker version: $docker_version"
            # the version of docker does not meet the requirement
            if [ "$docker_version_part1" -lt $docker1 ] || ([ "$docker_version_part1" -eq $docker1 ] && [ "$docker_version_part2" -lt $docker2 ])
            then
                    echo "Unsupported docker version. Need to upgrade docker package to $docker1.$docker2.0+."
                    exit 1
            fi
    else
            echo "Failed to parse docker version."
            exit 1
    fi

    # Verify docker is running
    systemctl start docker
fi

# Verify Docker compose 
if ! docker-compose --version &> /dev/null
then
    echo "Docker compose not found. Installing docker compose"

    # install docker compose
    curl -L $docker_compose_url -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose    

else
    echo "Docker compose already installed. Verifying version..."
    
    # docker-compose has been installed, check its version
    if [[ $(docker-compose --version) =~ (([0-9]+)\.([0-9]+)([\.0-9]*)) ]]
    then
            docker_compose_version=${BASH_REMATCH[1]}
            docker_compose_version_part1=${BASH_REMATCH[2]}
            docker_compose_version_part2=${BASH_REMATCH[3]}

            echo "docker-compose version: $docker_compose_version"
            # the version of docker-compose does not meet the requirement
            if [ "$docker_compose_version_part1" -lt $docker_compose1 ] || ([ "$docker_compose_version_part1" -eq $docker_compose1 ] && [ "$docker_compose_version_part2" -lt $docker_compose2 ])
            then
                    echo "Unsupported docker-compose version. Need to upgrade docker-compose package to $docker_compose1.$docker_compose2.0+."
                    exit 1
            fi
    else
            echo "Failed to parse docker-compose version."
            exit 1
    fi
fi

# Get docker-compose yaml
curl $git_yaml_url -o /tmp/app.yaml

# Start docker-compose app
docker-compose -f /tmp/app.yaml up -d