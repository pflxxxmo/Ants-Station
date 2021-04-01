#!/bin/bash

source "variables.sh"

if ! [ $(id -u) = 0 ]; then
    echo -e "\e[91mThis script must be run as root\e[39m"
    exit 1
fi

echo
echo "$(tput setaf 5)******  GPL3 LICENSE:  ******$(tput sgr 0)"
echo

echo 'All scripts/files in the ants repository are Copyright (C) 2021 Kononovich Maxim'
echo
echo "This program comes with ABSOLUTELY NO WARRANTY express or implied."
echo "This is free software and you are welcome to redistribute it under certain conditions."

read -p "Press ENTER to accept GPL v3 license terms to continue or terminate this bash shell to exit script"


echo
echo "$(tput setaf 5)****** AP Configuration: ******$(tput sgr 0)"
echo

echo
echo "$(tput setaf 2)****** Install all the required software ******$(tput sgr 0)"
echo

apt install dnsmasq hostapd ansible

echo
echo "$(tput setaf 1)****** Stop hostapd and dnsmasq services ******$(tput sgr 0)"
echo

systemctl stop dnsmasq
systemctl stop hostapd

echo
echo "$(tput setaf 3)****** Set static ip for $INTERFACE ******$(tput sgr 0)"
echo

echo "interface $INTERFACE" >> /etc/dhcpcd.conf
echo "    static ip_address=$STATICIP" >> /etc/dhcpcd.conf
echo "    nohook wpa_supplicant" >> /etc/dhcpcd.conf

service dhcpcd restart

sudo mv /etc/dnsmasq.conf /etc/dnsmasq.conf.orig
echo "interface=$INTERFACE" > /etc/dnsmasq.conf
echo "dhcp-range=$STARTIP,$STOPIP,$MASK,$TIME" >> /etc/dnsmasq.conf

systemctl start dnsmasq

echo
echo "$(tput setaf 3)****** Configuring access point with SSID $SSID ******$(tput sgr 0)"
echo

cat << EOF > /etc/hostapd/hostapd.conf
interface=$INTERFACE
ctrl_interface=/var/run/hostapd
driver=nl80211
ssid=$SSID
hw_mode=g
channel=7
wmm_enabled=0
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=$PASS
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP
EOF

echo 'DAEMON_CONF="/etc/hostapd/hostapd.conf"' >> /etc/default/hostapd

sudo systemctl unmask hostapd
sudo systemctl enable hostapd
sudo systemctl start hostapd

sed -i "s/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g" /tc/sysctl.conf

echo
echo "$(tput setaf 4)****** Configure routing from $ROUTEINTERFACE to $INTERFACE ******$(tput sgr 0)"
echo

iptables -t nat -A  POSTROUTING -o $ROUTEINTERFACE -j MASQUERADE

sh -c "iptables-save > /etc/iptables.ipv4.nat"

mv /etc/rc.local /etc/rc.local.bak
mv rc.local /etc/rc.local

$PREFIX=/dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 6 | head -n 1
echo
echo "$(tput setaf 6)****** Set hostname as $HOSTNAME-$PREFIX ******$(tput sgr 0)"
echo
raspi-config nonint do_hostname $HOSTNAME-$PREFIX

echo
echo "$(tput setaf 1)****** Set add cron job ******$(tput sgr 0)"
echo

chmod +x /home/pi/get_clients.sh
(crontab -l ; echo "*/10 * * * * /home/pi/get_clients.sh") | sort - | uniq - | crontab - 


echo
echo "$(tput setaf 1)****** Reboot system in 5 seconds ******$(tput sgr 0)"
read -p "****** Press ENTER to accept ******"
sleep 5
reboot
