#!/usr/bin/env perl

# Copyright notice at end.

require 'ap_tools.conf';

# $APusers	= "APusers.db";
# $clientsByMAC	= "clients_MAC.db";
# $clientsByUID	= "clients_UID.db";

###########

sub fmttime {
  local ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
  $mon++;		# They start on
  $wday++;		# 0 (zero) initially
  $year += 1900;
  return((($year<10) ? "0$year" : "$year")  .  (($mon <10) ? "0$mon"  : "$mon" )  .
         (($mday<10) ? "0$mday" : "$mday")."-".(($hour<10) ? "0$hour" : "$hour").":".
         (($min <10) ? "0$min"  : "$min" ).":".(($sec <10) ? "0$sec"  : "$sec" )     );
}

sub dbug {
  my ($tag,$msg,$lNo) = @_;
  if ($debug{$tag}) {print "" . fmttime() . " $tag\[$lNo]: $msg\n"}
}

sub mkdirs {
  foreach my $dir (@_) {
    my $path = "";
    foreach my $subdir (split(/\//, $dir)) {
      $path .= "/$subdir";
      next if (-d $path);
      mkdir("$path") || die "unable to mkdir: $path; $!\n";
} } }

###########

sub MAChex2dec {return join(".", map(hex, split(/:/,$_[0])))}

sub convert {
  my ($bare, @converted);
  foreach my $arg (@_) {
    ($bare = $arg) =~ tr/0-9a-zA-Z//cd;
    my $mode = (($bare =~ /^\d+$/) ? "numeric" : (($bare =~ /^[\da-f]+$/i) ? "hex" : "free"));
    if ($mode eq "free") {
      my @l = split(//,$arg);
      my $decStr = join(".", map(ord,@l));
      my $hexStr = "";
      foreach my $d (split(/\./,$decStr)) {
        my $h=sprintf("%x",$d);
        $hexStr .= ((length($h)==2) ? $h : "0$h") . ":";
      }
      chop($hexStr);
      push(@converted, "$arg -> $hexStr / $decStr / $arg");
    } else {
      if ($arg =~ /[-:]/) {$mode = "hex"}
      my @int;
      foreach my $sym (split(/[^\da-fA-F]/, $arg)) {
        if (($mode eq "hex") && ($arg =~ /-/) && (length($sym) > 2)) {    # xxxx-xxxx-xxxx notation
          my $p = "";
          foreach my $s (split(//, $sym)) {
            if ($p) {
              push(@int,hex("$p$s"));
              $p = "";
            } else {
              $p = $s;
          } }
        } else {
          push(@int,(($mode eq "hex") ? hex($sym) : $sym));
      } }
      my $decStr = join(".", @int);
      my ($hexStr,$str) = ("","");
      foreach my $n (@int) {
        my $h=sprintf("%x",$n);
        $hexStr .= ((length($h)==2) ? $h : "0$h") . ":";
        $str .= ((($n>=32) && ($n<=127)) ? chr($n) : ".");
      }
      chop($hexStr);
      push(@converted, "$arg -> $hexStr / $decStr / $str");
  } }
  return(@converted);
}

sub convertTo {		# to type: MAC, OID, or STR
  my ($arg,$type,$result) = @_;
  foreach my $conv (convert($arg)) {
    if ($conv =~ /^$arg -> ([\da-f:]+)[ \/]+([\d\.]+)[ \/]+(.*)$/) {
      $result = (($type eq "MAC") ? $1 : (($type eq "OID") ? $2 : (($type eq "STR") ? $3 : undef)));
  } }
  return($result);
}

sub sec2timeStamp {
  my ($sec) = @_;
  my ($ts,$hour,$min);
  if ($sec > (24*60*60)) {
    $ts = int($sec/(24*60*60)) . "+";
    $sec %= (24*60*60);
  }
  $hour = int($sec/(60*60));
  $ts .= ((($hour < 10) && !$ts) ? "0$hour" : $hour) . ":";
  $sec %= (60*60);
  $min = int($sec/60);
  $ts .= (($min < 10) ? "0$min" : $min) . ":";
  $sec %= 60;
  $ts .= (($sec < 10) ? "0$sec" : $sec);;
}

###########

sub newestSubDir {
  my ($tableDir,$newest,@result) = ("$dataDir/$_[0]");
  opendir(D, "$tableDir");
  while (my $dir = readdir(D)) {
    next unless ($dir =~ /^\d{8}-\d{2}:\d{2}:\d{2}$/);
    if ($newest lt $dir) {$newest = $dir}
  }
  return("$tableDir/$newest");
}

###########

sub lookupAPinfo {
# produces zero or more entries in %apData
  if (($>==0) || ($<==0)) {die "sorry, \"root\" won't do\n$prompt"}
  my ($searchFor, $maxNofAPs) = @_;
  my ($APdir,$lineNo,$matchNo,@header,%headerIx) = (newestSubDir($apDataSubdir), 0, 0);
  if ((length($searchFor)>=11) && (length($searchFor)<=17)) {		# it might be a MAC address
    my $copy;
    ($copy=$searchFor) =~ tr/-:.A-Fa-f0-9//cd;
    if ($copy =~ /^$searchFor$/) {
      my $mac = convertTo($searchFor,MAC);
      if (length($mac) == 17) {						# looks like it _is_ a MAC address!
        if ($mac =~ /^(.+):0([\da-f])$/) {$searchFor="$1:$2"}
        else {$searchFor=$mac; chop($searchFor)}
  } } }
  my $dontSearchFor = $false;
  if ($searchFor =~ /^\((.*\!.+)\)$/) {					# search term includes negated items
    my @searchFor, @dontSearchFor;
    foreach my $searchTerm (split(/\|/,$1)) {
      if ($searchTerm =~ /^\!(.+)/) {					# negated item: prefixed with "!"
        push(@dontSearchFor, $1);
      } else {
        push(@searchFor, $searchTerm);
      }
    }
    $searchFor     = "(" . join("|",@searchFor)     . ")";
    $dontSearchFor = "(" . join("|",@dontSearchFor) . ")";
  }
  my (%isWLC);
  opendir(D, $APdir) || die "unable to access newest $apDataSubdir; $!\n";
  while (my $file = readdir(D)) {
    next if ($file =~/^\./);
    $isWLC{$file}++;
    open(F, "<$APdir/$file") || die "unable to open/read $APdir/$file: $!\n";
    while (<F>) {
      $lineNo++;
      if ($lineNo == 1) {
        @header = split(/#/);
        if (!$#header) {$lineNo--; next}
        for (my $i=0; $i<=$#header; $i++) {
          $headerIx{$header[$i]} = $i;
        }
      } elsif (/$searchFor/i) {			# NB! may match anywhere in line => another /$searchFor/ below
        next if ($dontSearchFor && /$dontSearchFor/i);
        my @data = split(/#/);
        my $APname  = $data[$headerIx{PName}];
        my $wifiMAC = convertTo($data[$headerIx{PDot3MacAddress}],MAC);
        my $ethMAC  = convertTo($data[$headerIx{PEthernetMacAddress}],MAC);
        if ($APname =~ /^"(.+)"$/) {$APname = $1}
        next unless (($APname =~ /$searchFor/i) || ($wifiMAC =~ /$searchFor/i) || ($ethMAC =~ /$searchFor/i));
        my $mac = $wifiMAC;
        $apData{$mac}{name}	= $APname;
        $apData{$mac}{wlc}	= $file;
        $apData{$mac}{type}	= $data[$headerIx{PModel}];
        $apData{$mac}{slots}	= $data[$headerIx{PNumOfSlots}];
        $apData{$mac}{serial}	= $data[$headerIx{PSerialNumber}];
        $apData{$mac}{ip}	= $data[$headerIx{PStaticIPAddress}];
        $apData{$mac}{eth}	= $ethMAC;
        $matchNo++;
      }
      last if ($maxNofAPs && ($matchNo > $maxNofAPs));
    }
    close(F);
    last if ($maxNofAPs && ($matchNo > $maxNofAPs));
  }
  closedir(D);
  if (($matchNo == 0) && (-x $UDPSENDRCV)) {
    my $mac;
    my $lookupCmd = $UDPSENDRCV;
    foreach my $parm (keys %oracle) {$lookupCmd .= " $parm=$oracle{$parm}"}
    $lookupCmd .= " cmd[0]='?1 $searchFor' timeout=.01";
    open(LOOKUP, "$lookupCmd |");
    while (<LOOKUP>) {
      if (/wifiMAC=([\da-f:]+);/) {
        $mac = $1;
        $apData{$mac}{name}	= $searchFor;
        if (/model=([^;]+);/)	{$apData{$mac}{type}	= $1}
        if (/serial=([^;]+);/)	{$apData{$mac}{serial}	= $1}
        if (/IP=([^;]+);/)	{$apData{$mac}{ip}	= $1}
        if (/ethMAC=([^;]+);/)	{$apData{$mac}{eth}	= $1}
    } }
    close(LOOKUP);
} }

###########

sub snmpget {
  my ($APorWLC,$OID,$debug) = @_;
  my $WLC;
  if ($apData{$APorWLC}) {
    if ($apData{$APorWLC}{wlc}) {
      $WLC = $apData{$APorWLC}{wlc};
    } else {
      $WLC = $APorWLC;
    }
  } else {
    $WLC = $APorWLC;
  }
  my $result;
  dbug(snmpget, "open(GET, \"$SNMPGET $SNMPflags $SNMPmodules -c $snmpCommStr{$WLC} $WLC $OID |\")", __LINE__);
  open(GET, "$SNMPGET $SNMPflags $SNMPmodules -c $snmpCommStr{$WLC} $WLC $OID |")
        || warn "$0: error open \"$SNMPWALK\": $!\n";
  while (<GET>) {
    chomp();
    next if (/No Such Instance currently exists at this OID/);
    if (/^\S+ = \w+: (.+)$/) {
      $result = $1;
      last;
    }
  }
  close(GET);
  return($result);
}


sub snmpwalk {
  my ($APorWLC,$OID,$debug) = @_;
  my $WLC;
  if ($apData{$APorWLC}) {
    if ($apData{$APorWLC}{wlc}) {
      $WLC = $apData{$APorWLC}{wlc};
    } else {
      $WLC = $APorWLC;
    }
  } else {
    $WLC = $APorWLC;
  }
  my @result;
  dbug(snmpwalk, "open(WALK, \"$SNMPWALK $SNMPflags $SNMPwalkFlags $SNMPmodules -c $snmpCommStr{$WLC} $WLC $OID 2>&1 |\")", __LINE__);
  open(WALK, "$SNMPWALK $SNMPflags $SNMPwalkFlags $SNMPmodules -c $snmpCommStr{$WLC} $WLC $OID 2>&1 |")
        || warn "$0: error open \"$SNMPWALK\": $!\n";
  while (<WALK>) {
    chomp();
    next if (/No Such Instance currently exists at this OID/);
    next if (/Error: OID not increasing: AIRESPACE-WIRELESS-MIB::bsnMobileStationByUserMacAddress.6.[\d\.]+/ || / >= AIRESPACE-WIRELESS-MIB::bsnMobileStationByUserMacAddress.6.[\d\.]+/);
    push(@result,$_);
  }
  close(WALK);
  return(@result);
}
# TODO: remove this:
sub walk {return snmpwalk(@_)}

###########

sub initScrambleDir {
  return if (-d $scrambleDir && -f $scrambleUIDdb && -f $scrambleMACdb);
  mkdirs($scrambleDir);
  my $umask = umask();
  umask(000);
  dbmopen(%uidScramble, $scrambleUIDdb, $scrambleFMode) || die "unable to open scrambled UIDs db, $scrambleUIDdb; $!\n";
  if (!$uidScramble{"U-seq"})	{$uidScramble{"U-seq"}	= "00000"}
  dbmclose(%uidScramble);
  dbmopen(%macScramble, $scrambleMACdb, $scrambleFMode) || die "unable to open scrambled MACs db, $scrambleMACdb; $!\n";
  if (!$macScramble{"xx:seq"})	{$macScramble{"xx:seq"}	= 0}
  dbmclose(%macScramble);
  umask($umask);
# uidScramble{anb043}	-> U-00000	uidScramble{U-00000}	-> anb043
# macScramble{01:23:45}	-> xx:00:00	macScramble{xx:00:00}	-> 01:23:45
}

sub scramble {
  my ($key) = @_;
  if ($key =~ /^((([\da-f]{2}):){2}[\da-f]{2})$/) {		# MAC
    if ($macScramble{$key})	{return($macScramble{$key})}
    else {
      my $hexStr = sprintf "%4x", $macScramble{"xx:seq"};
      $macScramble{"xx:seq"}++;
      $hexStr =~ tr/ /0/;
      my @hexStr = split(//,$hexStr);
      my $hexKey = "xx:" . join("",(split(//,$hexStr))[0..1]) . ":" . join("",(split(//,$hexStr))[2..3]);
      $macScramble{$key} = $hexKey;
      $macScramble{$hexKey} = $key;
      return($hexKey);
    }
  } else {							# UID
    if    ($uidScramble{$key})	{return($uidScramble{$key})}
    else {
      my $scrambledUID = "U-" . $uidScramble{"U-seq"};
      $uidScramble{"U-seq"}++;
      $uidScramble{$key} = $scrambledUID;
      $uidScramble{$scrambledUID} = $key;
      return($scrambledUID);
} } }

sub descramble {
  my ($key) = @_;
  if    ($uidScramble{$key})	{return($uidScramble{$key})}
  elsif ($macScramble{$key})	{return($macScramble{$key})}
  else  {return($key)}
}

###########

$usage		= "usage: $0 [-ACHIMNPSW] [-abdikrstu]";

#		AP				Client
# Default	Name, EthMAC, Controller	MAC, User, SSID, AP
# A/a		All				All
#  /b						Bitrate/MCS, SS, PHY
# C		Channel, Power lvl, Ch.width
#  /d						Duplicates
# H		Hardware (type,serial,sw.port)
# I/i		IP addr				IP addr
# M		WiFi MAC (SSIDs)
# N		Nof clients (per radio)
# P		poorSNRClients
#  /r						Retries
#   s						Signal strength, SNR
#  /t						Type/manufacturer
# U/u		Un-sorted			Uptime
#
# always: timestamp (YYYYMMDD-hh:mm:ss)
#

1;

__END__

This software library is part of the AP tools software, Copyright 2019 Anders Baardsgaard, <anders.baardsgaard@uit.no>

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

