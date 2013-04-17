rtltcpaccess
============

rtltcpaccess is a drop-in replacement for RTL283XACCESS.dll that connects
to an rtl_tcp server and streams the samples from there.
Its main purpose is to allow DAB reception on GNU/Linux and OS X through
running the Windows software in Wine, but it works on Windows as well.


Installation
---

The installation script (dab_install.sh) fetches the DAB software as well as a
pre-built version of the library which is also available from here:

http://steve-m.de/projects/rtl-sdr/rtltcpaccess.tar.gz

To get the installation script, run:

    wget https://raw.github.com/steve-m/rtltcpaccess/master/dab_install.sh
    chmod +x dab_install.sh
    ./dab_install.sh

If you want to build the library yourself, get MinGW and run 'make'.

Usage
---

Just run rtl_tcp (which comes with librtlsdr). Since the default auto-gain
setting doesn't always result in the best SNR, you might want to play with the
gain option [-g].
When rtl_tcp is running, start the DAB application.

Settings
---

By default, rtltcpaccess tries to connect to localhost:1234, you can change 
this by creating a key in the Wine registry:

    wine regedit

Those are the names of the registry keys:

    [HKEY_CURRENT_USER\Software\rtltcpaccess]
    "address"="192.168.1.1"
    "port"=dword:00009999
    "testmode"=dword:00000000

address is a string, port is a DWORD. If the testmode is enabled it checks for 
lost samples, just like rtl_test.

Credits
---

rtltcpaccess was written by Steve Markgraf <steve@steve-m.de> and is
released under the MIT License (Expat).
