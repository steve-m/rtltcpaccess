#!/bin/sh
# Installation script for DAB receiver in Wine
# https://github.com/steve-m/rtltcpaccess

dab_name="NOXON_DAB_MediaPlayer-v5.1.3.exe.zip"
dab_md5="95b959a321c5d25af651f308cd096c2b"
tcpacc_name="rtltcpaccess.tar.gz"
tcpacc_md5="3b4ba2c40dd62b700bf47d8937c819e8"

get_files()
{
	if [ "`md5sum $dab_name | cut -d ' ' -f 1`" != "$dab_md5" ]; then
		wget https://www.noxonradio.ch/download/NOXON_DAB_Stick/$dab_name -O $dab_name
		[ "`md5sum $dab_name | cut -d ' ' -f 1`" != "$dab_md5" ] && return 1
	fi

	if [ "`md5sum $tcpacc_name | cut -d ' ' -f 1`" != "$tcpacc_md5" ]; then
		wget https://raw.github.com/steve-m/rtltcpaccess/master/$tcpacc_name -O $tcpacc_name
		[ "`md5sum $tcpacc_name | cut -d ' ' -f 1`" != "$tcpacc_md5" ] && return 2
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
unzip -o $dab_name

# install it silently
wine NOXON_DAB_MediaPlayer-v5.1.3.exe /S

rm "$unix_path/RTL283XACCESS.dll"

tar xvf $tcpacc_name
cp RTL283XACCESS.dll "$unix_path/"

# Add device information to registry to make it believe a device is connected via USB
wine regedit device_key.reg

# Disable sending of usage statistics by setting registry variables
# Normally there appears a dialog box that asks whether to disable this
# when first starting the application, but starting with version 5 this
# seems to trigger a Wine bug where the dialog box can't be closed.

echo "REGEDIT4" > dab_settings.reg
echo "[HKEY_CURRENT_USER\Software\Fraunhofer IIS\MultimediaPlayer\Settings\App]" >> dab_settings.reg
echo "\"homecallActive\"=\"false\"" >> dab_settings.reg
echo "\"homecallConfirmed\"=\"true\"" >> dab_settings.reg

wine regedit dab_settings.reg

echo "\nInstallation finished!\nTo run the software, start rtl_tcp first, and then start:"
echo "wine \"\`winepath -u \"$app_path\NOXON_DAB_MediaPlayer.exe\"\`"\"
