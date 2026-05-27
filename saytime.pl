#!/usr/bin/perl
#
# Copyright 2013, 2014, 2015, 2016, 2017, 2018, 2019, 2020 - saytime.pl  - D. Crompton, WA3DSP 11/30/2013
#
# Perl program to emulate and replace the app_rpt time of day
# function call. This allows for easy changes and also volume and
# tempo modifications.
#
# Call this program from a cron job and/or rpt.conf when you want to
# hear the time on your local node
#
# Example Cron job to say the time on the hour every hour:
#   Change directory and times to your liking
#
# 00 0-23 * * * cd /etc/asterisk/wa3dsp; perl saytime.pl [<wxid>] <node> > /dev/null
#
# Note in this program all sound files must be .$ext
# All combined soundfiile formats need to be the same.
# This could be changed if necessary. To use this with the
# stock Acid release you will need to convert a couple
# of the $ext files in the /sounds/rpt directory to .$ext
# using sox or another conversion program and place them
# in the sounds directory for use by this program.
# The good-xxx.$ext files and the-time-is.$ext were created
# from $ext files in the /sounds/rpt directory.
# An example sox command to do this is -
#
#  sox -t ul -r 8000 /usr/local/share/asterisk/sounds/custom/rpt/thetimeis.$ext /usr/local/share/asterisk/sounds/custom/the-time-is.$ext

# Added optional weather condition and temperature statement after time
# WA3DSP 4/2017

# Corrected temperature for eactly 100 Degrees.
# WA3DSP 7/2017

# For weather condtions and temperature Use:  saytime <locationID> <node>
# Location ID is either your zipcode or nearest airport three letter designator
# This REQUIRES the /usr/local/sbin/weather.sh script to run

# WA3DSP 12/2019
# Added header sound file. To add place wx_header sound file in /etc/asterisk/local
# This sound file can be any playable sound file type - .ul,.$ext, etc.
# EX: /etc/asterisk/local/wx_header.$ext,  /etc/asterisk/local/wx_header.ul
# This will play the header sound file prior to time and optionally temperature/condition

# WA3DSP 1/2020
# Added optional third parameter to save time and weather "1" or
# save just weather "2" $ext file. If the third parameter is present it will
# not be voiced to the node only saved as /tmp/current-time.$ext
# If the third parameter is not present or "0" time and temperature will
# be voiced to the seleted node.

# SDA 5/27/2026
# changed the base file path and changed file format to ulaw from gsm.
# I use ASL3_write_custom_sounds to write custom sound bytes using TTS.
# https://github.com/km5ht/ASL3_write_custom_sounds
# I wanted the option of selecting ulaw or gsm easily.
#
# Crontab entries or enter them manually. Pick a voice and make 
# sure it is in the environment for the rest of the world to use
# as well as /tmp/voice for other programs to grab
# This way I only have to change the voice in root crontab.
#
# TTSVOICE=en_US-amy-low.onnx
# 57 * * * * echo $TTSVOICE > /tmp/voice
#

use strict;
use warnings;
#
select (STDOUT);
$| = 1;
select (STDERR);
$| = 1;
#
# Replace with your output directory
my $outdir = "/tmp";
my $ext = "ulaw";
#my $ext = "gsm";
#
my $ampm = "PM";
#my $base = "/usr/local/share/asterisk/sounds/custom";
my $base = "/usr/share/asterisk/sounds/custom";
my $FNAME,my $error,my $day,my $hour,my $min,my $mynode,my $wx,my $wxid;
my @proglist,my @list,my $sec,my $wday,my $mon,my $year,my $greet;
my $year_1900,my $isdst,my $yday,my $min1,my $min10,my $localwxtemp10,my $localwxtemp1;
my $filename,my $Silent=0;
#
# command-line args
my $num_args = $#ARGV + 1;
# if arg number is only 1, then arg = node, else arg1 is wx ID, arg2 is node

if ($num_args == 1) {
    $mynode=$ARGV[0];
    $wx = "NO";
    $error=0;
} elsif ($num_args == 2) {
    $wxid = ($ARGV[0]);
    $wx = "YES";
    $mynode=$ARGV[1];
    $error=0;
} elsif ($num_args == 3) {
    if ($ARGV[2] < 0 || $ARGV[2] > 2) {
	$error=1;
    } else {
	$error=0;
    }
    $wxid = ($ARGV[0]);
    $wx = "YES";
    $mynode=$ARGV[1];
    $Silent=$ARGV[2];
} else {
    $error=1;
}

if ($error == 1) {
  print "\nUsage: saytime.pl [<locationid>] nodenumber [1=save time and wx, 2=save wx - both no voice]\n\n";
  exit;
}

my $localwxtemp="";

if (! -f "/usr/local/sbin/weather.sh" ) {
     $wx="NO";
}

if ($wx eq "YES") {

  @proglist = ("/usr/local/sbin/weather.sh", $wxid);
  system(@proglist);

  if (-f "$outdir/temperature") {
    open(my $fh, '<', "$outdir/temperature") or die "cannot open file";
    {
        local $/;
        $localwxtemp = <$fh>;
    }
    close($fh);
  } else {
    $localwxtemp="";
  }
}

#

$filename = '/etc/asterisk/local/saytime_header';
if ( <$filename.*> ) {
	@proglist = ("/usr/sbin/asterisk", "-rx", "rpt localplay " . $mynode . " /etc/asterisk/local/saytime_header");
	system(@proglist);
}

@list = ($sec,$min,$hour,$day,$mon,$year_1900,$wday,$yday,$isdst)=localtime;
#
if ($Silent != "2") {
#
if ($hour < 12) {
  $greet = "Good Morning";
  $ampm = "AM";
  $FNAME = $base . "/good-morning.$ext ";
 }
elsif ($hour >= 12 && $hour < 18) {
  $greet = "Good Afternoon";
  $FNAME = $base . "/good-afternoon.$ext ";
 }
else {
  $greet = "Good Evening";
  $FNAME = $base . "/good-evening.$ext ";
}

if ($hour > 12) { $hour = $hour-12 };
if ($hour == 0) { $hour = 12 };
$FNAME = $FNAME . $base . "/the-time-is.$ext ";
$FNAME = $FNAME . $base . "/digits/" . $hour . ".$ext ";

if ($min != 0) {
#  $FNAME = $FNAME . $base . "/digits/oclock.$ext ";
# } else {
  if ($min < 10) {
    $FNAME = $FNAME . $base . "/digits/oh.$ext ";
    $FNAME = $FNAME . $base . "/digits/" . $min . ".$ext ";
  }
  elsif ($min < 20) {
    $FNAME = $FNAME . $base . "/digits/" . $min . ".$ext ";
  } else {
    $min10 = substr ($min,0,1) . "0";
    $FNAME = $FNAME . $base . "/digits/" . $min10 . ".$ext ";
    $min1 = substr ($min,1,1);
    if ($min1 > 0) {
      $FNAME = $FNAME . $base . "/digits/" . $min1 . ".$ext ";
    }
  }
}

if ($ampm =~ "AM") {
  $FNAME = $FNAME . $base . "/digits/a-m.$ext ";
} else {
  $FNAME = $FNAME . $base . "/digits/p-m.$ext ";
}
} else {
 $FNAME = "";
}

if ($wx eq "YES") {
    $FNAME = $FNAME . $base . "/silence/1.$ext ";

if (-e "$outdir/condition.$ext") {
    $FNAME = $FNAME . $base . "/weather.$ext ";
    $FNAME = $FNAME . $base . "/conditions.$ext ";
    $FNAME = $FNAME . "$outdir/condition.$ext ";
}
if ($localwxtemp ne "" ) {
    $FNAME = $FNAME . $base . "/wx/temperature.$ext ";

    if ($localwxtemp < -1 ) {
        $FNAME = $FNAME . $base . "/digits/minus.$ext ";
        $localwxtemp=int(abs($localwxtemp));
    } else {
        $localwxtemp=int($localwxtemp);
    }

    if ($localwxtemp >= 100) {
        $FNAME = $FNAME . $base . "/digits/" . "1" . ".$ext ";
        $FNAME = $FNAME . $base . "/digits/" . "hundred" . ".$ext ";
        if ($localwxtemp > 100) {
           $localwxtemp=($localwxtemp-100);
        }
    }

    if ($localwxtemp < 20) {
        $FNAME = $FNAME . $base . "/digits/" . $localwxtemp . ".$ext ";
    } elsif ($localwxtemp != 100)
        {
        $localwxtemp10 = substr ($localwxtemp,0,1) . "0";
        $FNAME = $FNAME . $base . "/digits/" . $localwxtemp10 . ".$ext ";
        $localwxtemp1 = substr ($localwxtemp,1,1);
        if ($localwxtemp1 > 0) {
          $FNAME = $FNAME . $base . "/digits/" . $localwxtemp1 . ".$ext ";
        }
    }
    $FNAME = $FNAME . $base . "/degrees.$ext ";
 }
}

#
# Following lines concatenate all of the files to one output file
#
@proglist = ("cat " . $FNAME . " > " . $outdir . "/current-time.$ext");
system(@proglist);
#
# Following lines process the output file with sox to lower the volume
# negative numbers lower than -1 reduce the volume - see Sox man page
# Other processing could be done if necessary
#
# REMOVED V1.5 - use telemetry levels
#
#@proglist = ("nice -19 sox --temp /tmp " . $outdir . "/temp.$ext " . $outdir . "/current-time.$ext vol -0.35");
#system(@proglist);
#
# Say the time on the local node
#
if ($Silent == "0") {
	@proglist = ("/usr/sbin/asterisk", "-rx", "rpt localplay " . $mynode . " " . $outdir . "/current-time");
	system(@proglist);
	sleep 5; # We must sleep so asterisk can read the file before we clean up
#
# Note that unlinking the audio file may prevent it from playing when the system is busy.
#
#	sleep(2);
#	unlink "$outdir/current-time.$ext";
} elsif ($Silent == "1")
	{ print "\nSaved time and weather sound file to $outdir/current-time.$ext\n\n"
} elsif ($Silent == "2")
	{ print "\nSaved weather sound file to $outdir/current-time.$ext\n\n"
}

# Cleanup /tmp files
unlink "$outdir/temperature";
unlink "$outdir/condition.$ext";
if ($Silent != "1" && $Silent != "2") {
    unlink "$outdir/current-time.$ext";
}

# end of saytime.pl

