#!/bin/sh
# Installation script for DAB receiver in Wine
# https://github.com/steve-m/rtltcpaccess

dab_md5="08596ea091409275c1350a7fa0e4a86d"
tcpacc_md5="73a6f0eab866340b7a8389e95c77e757"

get_files()
{
	if [ "`md5sum dab_setup.exe | cut -d ' ' -f 1`" != "$dab_md5" ]; then
		wget http://ftp.terratec.de/NOXON/NOXON_DAB_Stick/Updates/NOXON_DAB_Stick_DAB_MediaPlayer_Setup_4.1.0.exe -O dab_setup.exe
		[ "`md5sum dab_setup.exe | cut -d ' ' -f 1`" != "$dab_md5" ] && return 1
	fi

	if [ "`md5sum rtltcpaccess.tar.gz | cut -d ' ' -f 1`" != "$tcpacc_md5" ]; then
		wget http://steve-m.de/projects/rtl-sdr/rtltcpaccess.tar.gz -O rtltcpaccess.tar.gz
		[ "`md5sum rtltcpaccess.tar.gz | cut -d ' ' -f 1`" != "$tcpacc_md5" ] && return 2
	fi

	return 0
}

# figure out application path
app_path="`wine cmd /c echo %ProgramFiles% | tr -d '\r\n'`\NOXON Media\NOXON DAB MediaPlayer"

# grab the software
get_files
if [ "$?" != "0" ]; then
	echo "Error fetching files, aborting!"
	exit 1
fi

# install it silently
wine dab_setup.exe /S /v/qn

# Updater can make trouble with some versions of Wine, remove it (running in background with 100% CPU usage)
rm "`winepath -u "$app_path\UpdateCheck.exe"`"
rm "`winepath -u "$app_path\RTL283XACCESS.dll"`"

tar xvf rtltcpaccess.tar.gz
cp RTL283XACCESS.dll "`winepath -u "$app_path\"`"

# Add device information to registry to make it believe a device is connected via USB
wine regedit device_key.reg

echo "\nInstallation finished!\nTo run the software, start rtl_tcp first, and then start:"
echo "wine \"\`winepath -u \"$app_path\NOXON DAB MediaPlayer.exe\"\`"\"
