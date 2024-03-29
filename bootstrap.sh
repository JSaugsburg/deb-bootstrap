#!/usr/bin/env bash

# Volume einhänge -> Pfade vor Installation überprüfen
mkfs.ext4 -F /dev/disk/by-id/scsi-0HC_Volume_3793738
mount -o discard,defaults /dev/disk/by-id/scsi-0HC_Volume_3793738 /home
echo "/dev/disk/by-id/scsi-0HC_Volume_3793738 /home             ext4 discard,nofail,defaults 0 0" >> /etc/fstab

# Systemupgrade
apt --quiet update && apt --quiet --yes upgrade

# Keymap setzen
# Workaround für bekannten Debian Bug -> https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=790955
wget https://mirrors.edge.kernel.org/pub/linux/utils/kbd/kbd-2.5.1.tar.gz -O /tmp/kbd-2.5.1.tar.gz
cd /tmp/ && tar xzf kbd-2.5.1.tar.gz
mkdir -p /usr/share/keymaps
cp -Rp /tmp/kbd-2.5.1/data/keymaps/* /usr/share/keymaps/
localectl set-keymap de-latin1

# Locale setzen
localectl set-locale de_DE.UTF-8

# Zeitzone
timedatectl set-ntp true
timedatectl set-timezone 'Europe/Berlin'

# User und PW setzen
read -p "Wie soll der User heißen? [sepp]: " name
name=${name:-sepp}
read -p "Passwort für $name angeben: " pw
# pw wird als textfile in /tmp abgespeichert -> Löschen!
echo "$pw" > "/tmp/${name}_pw"
# User kommt in sudoer Gruppe
useradd -m -g sudo -s /bin/bash "$name" >/dev/null 2>&1 ||
  usermod -a -G sudo "$name" && mkdir -p /home/"$name" && chown "$name":sudo /home/"$name"
echo "$name:$pw" | chpasswd

# SSH
# Root ssh Login wird deaktiviert
sed -i '/PermitRootLogin/s/^/#/' /etc/ssh/sshd_config
systemctl reload sshd

# keepass per sftp
# https://blog.huggenknubbel.de/die-keepass-datenbank-immer-und-ueberall-synchron-halten

echo "SFTP einrichten? (y/n)"
select yn in "y" "n"; do
    case $yn in
        y )
        useradd -M sftpuser -s /bin/false >/dev/null 2>&1
        read -p "Passwort für sftpuser angeben: " pw
        echo "sftpuser:$pw" | chpasswd
        echo "Match User sftpuser" >> /etc/ssh/sshd_config
        echo -e "\tPasswordAuthentication yes" >> /etc/ssh/sshd_config
        echo -e "\tForceCommand internal-sftp" >> /etc/ssh/sshd_config
        echo -e "\tChrootDirectory %h" >> /etc/ssh/sshd_config
        echo -e "\tAllowTCPForwarding no" >> /etc/ssh/sshd_config
        sed -i 's,/usr/lib/openssh/sftp-server,internal-sftp,' /etc/ssh/sshd_config
        mkdir -p /home/sftpuser/uploads
        chown -R sftpuser:sftpuser /home/sftpuser/uploads
        chmod 755 /home/sftpuser
        break ;;
        n ) exit;;
    esac
done

# Software
# Emailwiz
apt-get install -y certbot

cd /tmp
curl -LO lukesmith.xyz/emailwiz.sh
chmod 755 emailwiz.sh
./emailwiz.sh
