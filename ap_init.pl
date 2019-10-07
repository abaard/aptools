#!/usr/bin/env perl

# Copyright notice at end.

use DB_File;
use File::Basename;
use Cwd;
use FindBin qw($Bin);
FindBin::again();
BEGIN {
  my %INC;
  foreach my $dirname (@INC) {$INC{$dirname}++}
  foreach my $dirname (dirname(__FILE__), $Bin, dirname($0), "/usr/local/scripts", "/usr/local/bin", getcwd()) {
    next if ($INC{$dirname});
    next unless (-d $dirname);
    push(@INC, $dirname);
    $INC{$dirname}++;
} }

require 'ap_common.pl';

$usage		= "usage: $0 [debug=(on|off)] (AP|OUI)\n"
		. "\tAPs\tdownload AP inventory to $dataDir/$apDataSubdir/\n"
		. "\tOUI\tdownload vendor MAC address inventory to $OUIdir/\n";

######################

sub initAPs {
  dbug(init, "Looking up APs registered with WLCs...", __LINE__);
  foreach my $snmpTable ($apDataSubdir) {
    my $dir = "$dataDir/$snmpTable/" . fmttime();
    mkdirs($dir);
    foreach my $wlc (keys %snmpCommStr) {
      dbug(init, "\t$wlc", __LINE__);
      open(WLCDATA, ">$dir/$wlc") || die "unable to open/write WLC data file $dir/$wlc; $!\n";
      open(SNMPTABLE, "$SNMPTABLE $SNMPflags $SNMPtabFlags $SNMPmodules -c $snmpCommStr{$wlc} $wlc $snmpTable |");
      while (<SNMPTABLE>) {
        if (/#/) {
          if (/^index/) {print WLCDATA; next}
          my ($change,@val) = ($false,split(/#/));
          for (my $i=0; $i<=$#val; $i++) {
            if (($val[$i] =~ /^([\da-f]{1,2}:){5}[\da-f]{1,2}$/) && (length($val[$i])<17)) {
              $val[$i] = convertTo($val[$i],MAC);
              $change = $true;
          } }
          if ($change) {
            print WLCDATA join("#",@val), "\n";
          } else {
            print WLCDATA;
      } } }
      close(SNMPTABLE);
      close(WLCDATA);
  } }
  dbug(init, "done.", __LINE__);
}

sub initOUI {
  if (! -x $WGET) {
    warn "unable to locate/run wget\n";
  } else {
    mkdirs($OUIdir);
    my $oldFile = "${OUIfile}-OLD";
    rename($OUIfile, $oldFile) || warn "unable to rename OUI file ($OUIfile); $!\n";
    chdir($OUIdir);
    open(FETCH, "$WGET --output-document=$OUIfile $OUIsrc |") || die "unable to use $WGET to fetch $OUIsrc; $!\n";
    while (<FETCH>) {
      chomp;
      dbug(init, $_, __LINE__);
    }
    close(FETCH);
    if ((stat($OUIfile))[7] > ((stat($oldFile)))[7]) {		# compare file sizes, new file bigger?
      my (%newMacMap,$nofEntries) = ((),0);
      open(IEEE, "<$OUIfile");
      while (<IEEE>) {
        next unless (/^([\dA-F]{2})-([\dA-F]{2})-([\dA-F]{2})\s+\(hex\)\s+(.+)$/);
        $newMacMap{"$1:$2:$3"}        = $4;
        $newMacMap{lc("$1:$2:$3")}    = $4;
        $nofEntries++;
      }
      close(IEEE);
      open(COUNT, "<$OUIcount") || warn "unable to open the count file, $OUIcount; $!\n";
      while (<COUNT>) {
        next unless (/^.* (\d+)$/);
        $prevCount = $1;
      }
      close(COUNT);
      if ($nofEntries > $prevCount) {				# second check: verify #entries increased
        dbmopen(%macMap, "$OUIdb", 0644) || warn "unable to open OUI db, $OUIdb; $!\n";
        %macMap = %newMacMap;
        dbmclose(%macMap);
        open(COUNT, ">>$OUIcount") || warn "unable to open count file, $OUIcount; $!\n";
        print COUNT "" . localtime(time()) . " $nofEntries\n";
        close(COUNT);
      }
    } else {
      rename($OUIfile, "$OUIfile-failed." . time());
      rename($oldFile,  $OUIfile);
} } }

######################

my %doInit, $debug;
while ($ARGV[0] =~ /^(\S+)$/) {
  my $parm = $1;
  if    ($parm =~ /^APs?$/i)		{$doInit{APs}	= $true}
  elsif ($parm =~ /^OUI$/i)		{$doInit{OUI}	= $true}
  elsif ($parm =~ /^debug=(on|off)$/)	{$debug = $1}
  else {die $usage}
  shift;
}

if ($debug) {
  foreach my $opt (keys %debug) {$debug{$opt} = (($debug eq "on") ? $true : $false)}
}

if ($doInit{APs})	{initAPs}
if ($doInit{OUI})	{initOUI}
if (! keys %doInit)	{die "init WHAT?\n\n$usage"}

__END__

This program is part of the AP tools software, Copyright 2019 Anders Baardsgaard, <anders.baardsgaard@uit.no>

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

