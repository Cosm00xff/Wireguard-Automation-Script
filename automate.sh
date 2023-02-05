#!/bin/bash

# Preprocessor Variables
export SERV_IP_ADDR="77.73.69.183"
export AUTO_CONFIG_HOME="/root/Automate_Func/"

function menu {
echo "
======================================
|     Automated WireGuard Script     |
|        Named Peers with IDs        |
======================================"

echo "
      * Pick an Option *
      1) Manage User(s)
      2) Create User
      3) Delete User
      4) Check Services
      5) Installation
      6) Exit
      "
      read -p "Enter a choice: " menuChoice
      
      if [[ $menuChoice -eq 1 ]]
      then
        echo "manageUsers"
      elif [[ $menuChoice -eq 2 ]]
      then
        createUser
      elif [[ $menuChoice -eq 3 ]]
      then
        echo "deleteUser"
      elif [[ $menuChoice -eq 4 ]]
      then
        echo "checkServices"
      elif [[ $menuChoice -eq 5 ]]
      then
        installation
      elif [[ $menuChoice -eq 6 ]]
      then
        quitProgram
      else
        echo "Input error, exiting..."
        quitProgram
      fi
}

function createInterface {
    read -p "Please enter a name for the server interface: " serverInterfaceName
    wg genkey | tee /etc/wireguard/${serverInterfaceName}_private.key | wg pubkey | tee /etc/wireguard/${serverInterfaceName}_public.key

    echo "[Interface]
Address = 10.10.10.1/24
SaveConfig = true
PrivateKey = $(cat /etc/wireguard/${serverInterfaceName}_private.key)
ListenPort = 51820

[Peer]
PublicKey = $(cat /etc/wireguard/${serverInterfaceName}_private.key)
AllowedIPs = 10.10.10.2/32" > /etc/wireguard/${serverInterfaceName}.conf

    chmod 600 /etc/wireguard/ -R
}

# function manageUsers { echo "HELLO" }
function createUser { 
    read -p "Please enter a name for new client configuration: " clientName
    wg genkey | tee /etc/wireguard/${clientName}_private.key | wg pubkey | tee /etc/wireguard/${clientName}_public.key

echo "[Interface]
Address = 10.10.10.2/24
DNS = 10.10.10.1
PrivateKey = $(cat /etc/wireguard/${clientName}_private.key)

[Peer]
PublicKey =  $(cat /etc/wireguard/${clientName}_public.key)
AllowedIPs = 0.0.0.0/0
Endpoint = $SERV_IP_ADDR:51820
PersistentKeepalive = 25" > /etc/wireguard/${clientName}.conf

    chmod 600 /etc/wireguard/ -R
}

function deleteUser {
    read -p "Enter a user to delete: " userName
}

# function checkServices { echo "HELLO" }
function installation {
    # Install required packages
    yum update && yum upgrade -y
    yum install redhat-lsb-core -y
    yum install epel-release -y
    yum install yum-plugin-elrepo -y
    yum install kmod-wireguard -y
    yum install wireguard-tools -y
    yum install bind -y
    yum install nano -y

    # PKI Configuration
    mkdir -p /etc/wireguard/
    chmod 600 /etc/wireguard/ -R

    # Configure Wireguard Server Interface
    createInterface

    # Enable IP Forwarding
    echo "# sysctl settings are defined through files in
# /usr/lib/sysctl.d/, /run/sysctl.d/, and /etc/sysctl.d/.
#
# Vendors settings live in /usr/lib/sysctl.d/.
# To override a whole file, create a new file with the same in
# /etc/sysctl.d/ and put new settings there. To override
# only specific settings, add a file with a lexically later
# name in /etc/sysctl.d/ and put new settings there.
#
# For more information, see sysctl.conf(5) and sysctl.d(5).
net.ipv4.ip_forward = 1" > /etc/sysctl.conf

    sysctl -p

    # Configure IP Masquerading
    firewall-cmd --zone=public --permanent --add-masquerade
    systemctl reload firewalld

    # Install a DNS Resolver
    systemctl start named
    systemctl enable named
    cd $AUTO_CONFIG_HOME
    cp /root/Automate_Func/named.conf /etc/named.conf
    chmod 777 /etc/named.conf
    systemctl restart named
    systemctl status named
    firewall-cmd --zone=public --permanent --add-rich-rule='rule family="ipv4" source address="10.10.10.0/24" accept'

    # Open Wireguard Service Port in Firewall
    firewall-cmd --permanent --add-port=51820/udp
    systemctl reload firewalld

    echo "Installation Complete, returning to menu!"
    echo ""
    menu
}

function quitProgram {
    echo "Exiting..."
    exit 
}

menu