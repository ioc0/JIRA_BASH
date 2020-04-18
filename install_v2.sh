#!/usr/bin/bash

###   Check sudo   ###
[ $(whoami) != "root" ] && echo "Run as sudo!" && exit



###    Install main packages   ###
installPackages() {
  yum update -y
  yum install -y wget
  # Java #
  yum install -y java-1.8.0-openjdk
  yum install -y java-1.8.0-openjdk-devel
  # Nginx #
  yum install -y epel-release
  yum install -y nginx
  systemctl enable nginx.service
  systemctl start nginx
}

###   Firewall   ###
firewallOpen() {
  # Nginx #
  firewall-cmd --permanent --zone=public --add-service=http
  firewall-cmd --permanent --zone=public --add-service=https
  firewall-cmd --reload
}
###   Install Jira Software   ###
installJiraSoftware() {
  # Make response.varfile #
  echo "app.jiraHome=/jira
app.install.service"'$'"Boolean=true
existingInstallationDir=/usr/local/JIRA
sys.confirmedUpdateInstallationString=false
sys.languageId=en
sys.installationDir=/opt/atlassian/jira
executeLauncherAction"'$'"Boolean=true
portChoice=custom
httpPort"'$'"Long=8080
rmiPort"'$'"Long=8005" > response.varfile

  # Install Jira #
  APPVERSION="8.5.4-x64"
  FILE_SOURCE="http://www.atlassian.com/software/jira/downloads/binary/atlassian-jira-software-${APPVERSION}.bin"
  wget $FILE_SOURCE
  chmod +x atlassian-jira-software-${APPVERSION}.bin
  ./atlassian-jira-software-${APPVERSION}.bin -q -varfile response.varfile

  # Add packages #
  #wget https://packages.atlassian.com/content/repositories/atlassian-public/com/atlassian/jira/jira-rest-java-client-api/5.2.1/jira-rest-java-client-api-5.2.1.jar
  #sudo cp jira-rest-java-client-api-5.2.1.jar /opt/atlassian/jira/lib/
  
  # Restart Jira #
  /etc/init.d/jira stop
  /etc/init.d/jira start

  # Add to Nginx #
  [ ! -d "/etc/nginx/sites-enabled" ] && mkdir -p /etc/nginx/sites-enabled
  echo "server {
    server_name ${JiraSoftwareDomainName};
    listen 80;

    access_log /var/log/nginx/jira_access.log;
    error_log /var/log/nginx/jira_error.log;

    location / {
      proxy_pass http://127.0.0.1:8080;
      proxy_set_header Host "'$host'";
      proxy_set_header X-Real-IP "'$remote_addr'";
      proxy_set_header X-Forwarded-for "'$remote_addr'";
      port_in_redirect off;
      proxy_redirect http://127.0.0.1:8080/ /;
      proxy_connect_timeout 600;
    }
  }" > /etc/nginx/sites-enabled/${JiraSoftwareDomainName}
  # Add link in nginx.conf #
  mv /etc/nginx/nginx.conf /etc/nginx/nginx.conf.back
  while IFS= read line
  do
    echo "$line" >> /etc/nginx/nginx.conf
    if [ "${line}" == "http {" ]; then
      echo "    include /etc/nginx/sites-enabled/${JiraSoftwareDomainName};" >> /etc/nginx/nginx.conf
    fi
  done </etc/nginx/nginx.conf.back
  # Reload nginx #
  systemctl reload nginx.service

}
###NEED TO BE IMPLEMENTED###
installConfluence(){
###   INSTALLING..   ###
echo "Installing Confluence"
}
installBoth(){
echo "Installing Both"
}



###   Read Data   ###
INSTALL_OPTION=""
while [[ $INSTALL_OPTION != [123] ]]; do
    echo
    echo "1) Install Jira and Confluence"
    echo "2) Jira Desk only"
    echo "3) Jira Confluence only"
    read -p "Choose install option: " INSTALL_OPTION
done



###   INSTALLING..   ###

# Jira Software #
if [ $INSTALL_OPTION == "1" ]; then
  echo "Installing Main Packages.."
  #installPackages
  #firewallOpen
  #echo "Installing Jira Software.."
  #installJiraSoftware
fi

if [ $INSTALL_OPTION == "2" ]; then
  echo "Installing JIRA Packages.."
  #installPackages
  #firewallOpen
  #echo "Installing Jira Software.."
  #installJiraSoftware
fi
if [ $INSTALL_OPTION == "3" ]; then
  echo "Installing CONFLUENCE Packages.."
  #installPackages
  #firewallOpen
  #echo "Installing Jira Software.."
  #installJiraSoftware
fi

