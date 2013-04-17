#!/bin/sh

########################################################################
# Note: Some older Wine installations use "C:\Program Files" instead   #
# of "C:\Program Files (x86)", you might need to change that!          #
########################################################################

# run a dummy wine command to make sure installation is initialized
winepath

# grab the software
wget http://ftp.terratec.de/NOXON/NOXON_DAB_Stick/Updates/NOXON_DAB_Stick_DAB_MediaPlayer_Setup_4.1.0.exe -O dab_setup.exe

# install it silently
wine dab_setup.exe /S /v/qn

# Updater can make trouble with some versions of Wine, remove it (running in background with 100% CPU usage)
rm "`winepath -u "C:\Program Files (x86)\NOXON Media\NOXON DAB MediaPlayer\UpdateCheck.exe"`"
rm "`winepath -u "C:\Program Files (x86)\NOXON Media\NOXON DAB MediaPlayer\RTL283XACCESS.dll"`"

wget http://steve-m.de/projects/rtl-sdr/rtltcpaccess.tar.gz -O rtltcpaccess.tar.gz

tar xvf rtltcpaccess.tar.gz
cp RTL283XACCESS.dll "`winepath -u "C:\Program Files (x86)\NOXON Media\NOXON DAB MediaPlayer\"`"

# Add device information to registry to make it believe a device is connected via USB
wine regedit device_key.reg

echo "Installation finished!"
echo "to run it, start rtl_tcp first, and then start:"
echo 'wine "`winepath -u "C:\Program Files (x86)\NOXON Media\NOXON DAB MediaPlayer\NOXON DAB MediaPlayer.exe"`"'
