#!/bin/sh
# Installation script for DAB receiver in Wine
# https://github.com/steve-m/rtltcpaccess

dab_md5="a25b2303badbea40df5e2e2ff58486a3"
tcpacc_md5="73a6f0eab866340b7a8389e95c77e757"

get_files()
{
	if [ "`md5sum DABPlayer5.01.zip | cut -d ' ' -f 1`" != "$dab_md5" ]; then
		wget http://ftp.noxonradio.de/NOXON/NOXON_DAB_Stick/Updates/DABPlayer5.01.zip -O DABPlayer5.01.zip
		[ "`md5sum DABPlayer5.01.zip | cut -d ' ' -f 1`" != "$dab_md5" ] && return 1
	fi

	if [ "`md5sum rtltcpaccess.tar.gz | cut -d ' ' -f 1`" != "$tcpacc_md5" ]; then
		wget http://steve-m.de/projects/rtl-sdr/rtltcpaccess.tar.gz -O rtltcpaccess.tar.gz
		[ "`md5sum rtltcpaccess.tar.gz | cut -d ' ' -f 1`" != "$tcpacc_md5" ] && return 2
	fi

	return 0
}

wine --version
if [ "$?" != "0" ]; then
	echo "Wine needs to be installed!"
	exit 1
fi

# figure out application path
app_path="`wine cmd /c echo %ProgramFiles% | tr -d '\r\n'`\NOXON\DAB Media Player"
unix_path="`winepath -u "$app_path"`"

mkdir /tmp/dab_install
cd /tmp/dab_install/

# grab the software
get_files
if [ "$?" != "0" ]; then
	echo "Error fetching files, aborting!"
	exit 1
fi

# unpack the archive
unzip -o DABPlayer5.01.zip

# install it silently
wine msiexec /i DABStickInstaller5.01.msi /qn

rm "$unix_path/RTL283XACCESS.dll"

tar xvf rtltcpaccess.tar.gz
cp RTL283XACCESS.dll "$unix_path/"

# Add device information to registry to make it believe a device is connected via USB
wine regedit device_key.reg

# Disable sending of usage statistics by setting registry variables
# Normally there appears a dialog box that asks whether to disable this
# when first starting the application, but starting with version 5 this
# seems to trigger a Wine bug where the dialog box can't be closed.

echo "REGEDIT4\n" > dab_settings.reg
echo "[HKEY_CURRENT_USER\Software\Fraunhofer IIS\MultimediaPlayer\Settings\App]" >> dab_settings.reg
echo "\"homecallActive\"=\"false\"" >> dab_settings.reg
echo "\"homecallConfirmed\"=\"true\"" >> dab_settings.reg

wine regedit dab_settings.reg

echo "\nInstallation finished!\nTo run the software, start rtl_tcp first, and then start:"
echo "wine \"\`winepath -u \"$app_path\NOXON_DAB_MediaPlayer.exe\"\`"\"
