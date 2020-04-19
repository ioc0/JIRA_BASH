#!/usr/bin/bash
LOG="/tmp/jira_install.log"
RESDIR="resources/"
PGHBA_PATH="/var/lib/pgsql/11/data/pg_hba.conf"
PG_REPO_URL="https://download.postgresql.org/pub/repos/yum/reporpms/EL-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm"
JIRA_INSTALLER_NAME="atlassian-jira-software-8.5.4-x64.bin"
JIRACONFL_INSTALLER_NAME="atlassian-confluence-6.13.11-x64.bin"

JIRA_INSTALLER_URL="https://product-downloads.atlassian.com/software/jira/downloads/$JIRA_INSTALLER_NAME"
JIRACONFL_INSTALLER_URL="https://product-downloads.atlassian.com/software/confluence/downloads/$JIRACONF_INSTALLER_NAME"

JIRA_RESPONSES="response.varfile_jira"
JIRACONFL_RESPONSES="response.varfile_confluence"

JIRA_SERVERXML="$RESDIR/jira_server.xml"
JIRACONFL_SERVERXML="$RESDIR/confluence_server.xml"

JIRA_DB="jiradb"
JIRA_DBROLE="jiradbuser"
JIRA_DBPASS="jiradbuserpass"
CONFL_DB="confluencedb"
CONFL_DBROLE="confluencedbuser"
CONFL_DBPASS="confluencedbuserpass"

unalias cp > /dev/null 2>&1

setupDB() {
    echo
    echo "Installing Postgres.." | tee -a $LOG
    sed -i.back1 '/\[base\]/a exclude=postgresql*' /etc/yum.repos.d/CentOS-Base.repo
    sed -i '/\[updates\]/a exclude=postgresql*' /etc/yum.repos.d/CentOS-Base.repo
    sudo yum install -y $PG_REPO_URL >> $LOG 2>&1
    yum install -y postgresql11-server >> $LOG 2>&1
    /usr/pgsql-11/bin/postgresql-11-setup initdb
    echo "Updating pg_hba.conf.." | tee -a $LOG
    cp "$RESDIR/pg_hba.conf" $PGHBA_PATH
    
    systemctl enable postgresql-11
    systemctl start postgresql-11

    echo "Done with Postgres." | tee -a $LOG
}

setupNginx() {
    echo
    nginx -v  > /dev/null 2>&1
    if [[ $? != 0 ]]; then
        echo "Installing Nginx.." | tee -a $LOG
        yum install -y epel-release  >> $LOG 2>&1
        yum install -y nginx  >> $LOG 2>&1
        echo "Testing installation: " | tee -a $LOG
        nginx -v >> $LOG
        if [[ $? = 0 ]]; then
            echo "OK"
        else
            echo "Nginx returned error. Check $LOG" 
            exit 1
        fi
        echo "Done."
    fi
    echo "Enabling nginx.."
    cp "$RESDIR/nginx.conf" /etc/nginx/nginx.conf
    systemctl enable nginx
    echo "Done with nginx."

}


setupJira() {
    echo
    echo "Installing Jira Software.." | tee -a $LOG
    if [[ -e "$RESDIR/$JIRA_INSTALLER_NAME" ]]; then
        chmod +x "$RESDIR/$JIRA_INSTALLER_NAME"
    else
        wget --directory-prefix "$RESDIR"  "$JIRA_INSTALLER_URL" 
        chmod +x "$RESDIR/$JIRA_INSTALLER_NAME"
    fi
    
    if [[ ! -e "$RESDIR/$JIRA_INSTALLER_NAME" ]]; then
        echo "Cant get $JIRA_INSTALLER_URL see log for details."
        echo "You can manually copy this file to resources\ directory to skip downloading."
        exit 1
    fi
    $RESDIR/$JIRA_INSTALLER_NAME -q -varfile $JIRA_RESPONSES >> $LOG 2>&1

    echo "Done with Jira Software." | tee -a $LOG
    
    read -p "Enter Jira Software DNS name: " JIRA_DNS
    echo "Jira Software will be available on this machine by http://$JIRA_DNS"
    #add proxy config
    cp "$RESDIR/jira_proxy.conf" /etc/nginx/conf.d/
    cp "$RESDIR/jira_server.xml" /opt/atlassian/jira/conf/server.xml
    sed -i "s/___proxy_dns_name___/$JIRA_DNS/" /etc/nginx/conf.d/jira_proxy.conf 
    sed -i "s/___proxy_dns_name___/$JIRA_DNS/" /opt/atlassian/jira/conf/server.xml

    #add db and role
    sudo -u postgres psql -c "CREATE ROLE $JIRA_DBROLE WITH LOGIN ENCRYPTED PASSWORD '$JIRA_DBPASS';" > /dev/null 2>&1
    sudo -u postgres createdb -E UNICODE -l C -T template0 $JIRA_DB > /dev/null 2>&1
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $JIRA_DB TO $JIRA_DBROLE;" > /dev/null 2>&1

}

setupJiraConfluence() {
    echo
    echo "Installing Jira Confluence.." | tee -a $LOG
    if [[ -e "$RESDIR/$JIRACONFL_INSTALLER_NAME" ]]; then
        chmod +x "$RESDIR/$JIRACONFL_INSTALLER_NAME"
    else
        wget --directory-prefix "$RESDIR"  "$JIRACONFL_INSTALLER_URL" 
        chmod +x "$RESDIR/$JIRACONFL_INSTALLER_NAME"
    fi
    
    if [[ ! -e "$RESDIR/$JIRACONFL_INSTALLER_NAME" ]]; then
        echo "Cant get $JIRACONFL_INSTALLER_URL see log for details."
        echo "You can manually copy this file to resources\ directory to skip downloading."
        exit 1
    fi
    $RESDIR/$JIRACONFL_INSTALLER_NAME -q -varfile $JIRACONFL_RESPONSES >> $LOG 2>&1

    echo "Done with Jira Confluence." | tee -a $LOG
    
    read -p "Enter Jira Confluence DNS name: " JIRACONFL_DNS
    echo "Jira Confluence will be available on this machine by http://$JIRACONFL_DNS"
    #add proxy config
    cp "$RESDIR/confluence_proxy.conf" /etc/nginx/conf.d/
    cp "$RESDIR/confluence_server.xml" /opt/atlassian/confluence/conf/server.xml
    sed -i "s/___proxy_dns_name___/$JIRA_DNS/" /etc/nginx/conf.d/confluence_proxy.conf 
    sed -i "s/___proxy_dns_name___/$JIRA_DNS/" /opt/atlassian/confluence/conf/server.xml

    #add db and role
    sudo -u postgres psql -c "CREATE ROLE $CONFL_DBROLE WITH LOGIN ENCRYPTED PASSWORD '$CONFL_DBPASS';" > /dev/null 2>&1
    sudo -u postgres createdb -E UNICODE -l C -T template0 $CONFL_DB > /dev/null 2>&1
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $CONFL_DB TO $CONFL_DBROLE;" > /dev/null 2>&1

    #add systemd unit
    cp "$RESDIR/confluence.service" /lib/systemd/system/
    chmod 664 /lib/systemd/system/confluence.service
    systemctl daemon-reload
    systemctl enable confluence.service

}

firewallOpen() {
    echo "Opening firewall for http and https.." | tee -a $LOG
    firewall-cmd --permanent --zone=public --add-service=http  | tee -a $LOG
    firewall-cmd --permanent --zone=public --add-service=https | tee -a $LOG
    firewall-cmd --reload  | tee -a $LOG
    
    echo "Changing SELinux to permissive.."  | tee -a $LOG
    setenforce 0  | tee -a $LOG
    sed -i 's/^SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config 
    
}


echo "===Started by $(whoami) at $(date)" >>  $LOG
echo "This script log file is $LOG"
[ $(whoami) != "root" ] && echo "Need root priviledges, exiting.." | tee -a $LOG && exit 1

INSTALL_OPTION=""
while [[ $INSTALL_OPTION != [123] ]]; do
    echo
    echo "1) Install Jira Service Desk and Confluence"
    echo "2) Jira Software only"
    echo "3) Jira Confluence only"
    read -p "Choice install option: " INSTALL_OPTION
done

echo
read -p "Update the system with yum update?(it is recomended but may take while) [y/n]: " YUM_UPDATE
if [[ $YUM_UPDATE = "y" ]]; then
    echo "Updating system.." | tee -a $LOG
        yum update -y  >> $LOG 2>&1
    echo "Done with update." | tee -a $LOG
fi

if ! type wget  > /dev/null 2>&1; then
    echo "Installing wget.." | tee -a $LOG
    yum install -y wget  >> $LOG 2>&1
    [ $? = 0 ] || exit 1
    echo "Done with wget." | tee -a $LOG
fi

firewallOpen
setupNginx
setupDB

if [[ $INSTALL_OPTION == 1 ]]; then
    setupJira
    setupJiraConfluence
    echo "Starting services.." | tee -a $LOG
    systemctl start nginx | tee -a $LOG
    systemctl restart jira | tee -a $LOG
    systemctl restart confluence | tee -a $LOG
    echo
    echo "Jira Software is available at http://$JIRA_DNS" | tee -a $LOG
    echo "Note that $JIRA_DNS should be pointed to this machine ip address in your DNS." | tee -a $LOG
    echo  | tee -a $LOG
    echo "Postgresql is ready for your Jira Software: " | tee -a $LOG
    echo "Hostname: 127.0.0.1" | tee -a $LOG
    echo "Port: 5432" | tee -a $LOG
    echo "Database: $JIRA_DB" | tee -a $LOG
    echo "Username: $JIRA_DBROLE" | tee -a $LOG
    echo "Password: $JIRA_DBPASS" | tee -a $LOG
    echo
    echo "Jira Confluence is available at http://$JIRACONFL_DNS" | tee -a $LOG
    echo "Note that $JIRACONFL_DNS should be pointed to this machine ip address in your DNS." | tee -a $LOG
    echo  | tee -a $LOG
    echo "Postgresql is ready for your Jira Confluence: " | tee -a $LOG
    echo "Hostname: 127.0.0.1" | tee -a $LOG
    echo "Port: 5432" | tee -a $LOG
    echo "Database: $CONFL_DB" | tee -a $LOG
    echo "Username: $CONFL_DBROLE" | tee -a $LOG
    echo "Password: $CONFL_DBPASS" | tee -a $LOG
    
elif [[ $INSTALL_OPTION == 2 ]]; then
    setupJira
    echo "Starting services.." | tee -a $LOG
    systemctl start nginx | tee -a $LOG
    systemctl restart jira | tee -a $LOG
    echo
    echo "Jira ServiceDesk is available at http://$JIRA_DNS" | tee -a $LOG
    echo "Note that $JIRA_DNS should be pointed to this machine ip address in your DNS." | tee -a $LOG
    echo  | tee -a $LOG
    echo "Postgresql is ready for your Jira Service Desk: " | tee -a $LOG
    echo "Hostname: 127.0.0.1" | tee -a $LOG
    echo "Port: 5432" | tee -a $LOG
    echo "Database: $JIRA_DB" | tee -a $LOG
    echo "Username: $JIRA_DBROLE" | tee -a $LOG
    echo "Password: $JIRA_DBPASS" | tee -a $LOG
elif [[ $INSTALL_OPTION == 3 ]]; then
    setupJiraConfluence
    echo "Starting services.." | tee -a $LOG
    systemctl start nginx | tee -a $LOG
    systemctl restart confluence | tee -a $LOG
    echo
    echo "Jira Confluence is available at http://$JIRACONFL_DNS" | tee -a $LOG
    echo "Note that $JIRACONFL_DNS should be pointed to this machine ip address in your DNS." | tee -a $LOG
    echo  | tee -a $LOG
    echo "Postgresql is ready for your Jira Confluence: " | tee -a $LOG
    echo "Hostname: 127.0.0.1" | tee -a $LOG
    echo "Port: 5432" | tee -a $LOG
    echo "Database: $CONFL_DB" | tee -a $LOG
    echo "Username: $CONFL_DBROLE" | tee -a $LOG
    echo "Password: $CONFL_DBPASS" | tee -a $LOG
fi



echo "Installation finished. Check $LOG for details."
echo "Exiting normally."
exit 0

##########################################################
