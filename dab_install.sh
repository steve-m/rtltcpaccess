#!/bin/sh
# Installation script for DAB receiver in Wine
# https://github.com/steve-m/rtltcpaccess

# figure out application path
app_path="`wine cmd /c echo %ProgramFiles% | tr -d '\r\n'`\NOXON Media\NOXON DAB MediaPlayer"

# grab the software
wget http://ftp.terratec.de/NOXON/NOXON_DAB_Stick/Updates/NOXON_DAB_Stick_DAB_MediaPlayer_Setup_4.1.0.exe -O dab_setup.exe

# install it silently
wine dab_setup.exe /S /v/qn

# Updater can make trouble with some versions of Wine, remove it (running in background with 100% CPU usage)
rm "`winepath -u "$app_path\UpdateCheck.exe"`"
rm "`winepath -u "$app_path\RTL283XACCESS.dll"`"

wget http://steve-m.de/projects/rtl-sdr/rtltcpaccess.tar.gz -O rtltcpaccess.tar.gz

tar xvf rtltcpaccess.tar.gz
cp RTL283XACCESS.dll "`winepath -u "$app_path\"`"

# Add device information to registry to make it believe a device is connected via USB
wine regedit device_key.reg

echo "Installation finished!"
echo "to run it, start rtl_tcp first, and then start:"
echo "wine \"\`winepath -u \"$app_path\NOXON DAB MediaPlayer.exe\"\`"\"
