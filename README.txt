About AP tools:
The core of the software is three scripts, written in perl: APlist, APuser and APclients.
Before use you must copy these scripts to a directory on a u**x computer, called the management host below.
The scripts are used to request data (via SNMP) from your wireless LAN controller(s),
and present the data to you on the command line (CLI).

 -- Requirements / gotchas

(1) The code is written to interact with the Cisco "Airespace" family of wireless LAN controllers (WLCs).
If your installation is from another vendor, or even Cisco Meraki, then this code is useless for you.
And even if you do have the "right" platform, consider carefully how much you should trust the results,
see e.g. https://twitter.com/porceTwits/status/1169421521770573825

(2) The netSNMP software package is required on the management host, specifically snmpget, snmptable and snmpwalk.
The wget program is also used, with missing functionality if absent (see point (7) below).

(3) A number of SNMP MIBs must be installed on the management host:
  - AIRESPACE-REF-MIB
  - AIRESPACE-WIRELESS-MIB
  - CISCO-LWAPP-AP-MIB
  - CISCO-LWAPP-DOT11-CLIENT-MIB
  - CISCO-LWAPP-CDP-MIB
They can be downloaded from ftp://ftp.cisco.com/pub/mibs/supportlists/wlc/wlc-supportlist.html
They should be copied to one of the directories named in the $MIBpath variable in the AP_tools.conf file.
(initially /usr/share/snmp/mibs/ or /usr/local/share/snmp/mibs/)

(4) SNMP community string(s) must be available in a text file
Default location: /usr/local/etc/WLC-cstr.txt, changeable in the AP_tools.conf file.
Each line should contain a WLC name and a community string, separated by white space.
Take care:
  - do not store RW community strings in this file, only RO
  - restrict access (file permissions) to the file down to the group of people that are
    intended to use the AP tools software, and generally use the principle of least privilege.
Also, the management host should have SNMP read access to the WLCs, and not be restricted by ACLs etc.

(5) A directory for data storage should be present
Default location: $ENV{HOME}/wifiData, changeable in the AP_tools.conf file.
Change to a static directory name if the AP tools are to be used by more than one person.
This directory should be owned by the user that runs the seeding operation (see next point)

(6) The list of APs needs to be "seeded" before the AP tools can produce any output.
Seeding is accomplished by the command (could be run as a daily cron job):
	APinit APs

(7) The -t option (type) displays the type of the client devices, as assumed by WLC.
Additionally the vendor of the wifi chipset may be displayed, if OUI data has been downloaded.
Run this command to download (could be run as a weekly cron job):
	APinit OUI


 -- Suggested steps

(1) Verify that netSNMP is installed. If not, install it.
	root@host:~/#which snmpget snmpwalk snmptable

(2) Copy perl files to /usr/local/bin/

(3) Copy MIB files to /usr/local/share/snmp/mibs/

(4) Create a user ID to own the data files
	root@host:~/#adduser
	Username: wifimgr
	Full name: Wi-Fi Manager
	(etc)

(5) Create /usr/local/etc/WLC-cstr.txt with SNMP RO community strings, and make it owned by UID=wifimgr
	root@host:~/#chown wifimgr /usr/local/etc/WLC-cstr.txt
	root@host:~/#chmod 06000   /usr/local/etc/WLC-cstr.txt
NB! This access restriction may cause problems for other users. "chmod 0644" may be used to resolve.

(6) Seed the list of APs
	[wifimgr@host ~]$ AP_init APs

(7) If you want to include chip vendors, and "which wget" checks out
	[wifimgr@host ~]$ AP_init OUI
(don't worry if it's "unable to open the count file")

(8) Crontab:
	30      7,16    *       *       *       /bin/sh -c '/usr/local/scripts/ap_init debug=off APs'
	22      19      *       *       0       /bin/sh -c '/usr/local/scripts/ap_init debug=off OUI'


Copyright:
The AP tools software is Copyright 2019 Anders Baardsgaard, <anders.baardsgaard@uit.no>

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.

