#!/usr/bin/perl

$DEBUG = 0;

$USAGE = "Usage: $0 fifo
Causes the ulogbufd which is monitoring fifo to dump its log buffer to 
a pipe and displays the buffer.\n";

$SIGNAL = "USR2";
$LOCKDIR = "/var/tmp";
$TMPFIFODIR = "/var/tmp";

defined ($MYFIFO = $ARGV[0]) or die $USAGE;

($dev, $ino) = stat($MYFIFO) or die "Can't stat $MYFIFO: $!\n";
$lockfile = $LOCKDIR . "/ulogbufd-" . $dev . $ino;

$DEBUG and warn "opening lockfile $lockfile\n";
open (LOCKFILE, $lockfile) or die "Can't open lockfile $lockfile: $!\nProbably no ulogbufd watching $MYFIFO.\n";
defined ($dpid = <LOCKFILE>) or die "Nothing to read in lockfile?\n";
$DEBUG and warn "dpid is $dpid\n";
close (LOCKFILE);
$DEBUG and warn "closed lockfile\n";

chomp($dpid);

$tmpfifo = $TMPFIFODIR . "/ulogbufd-" . $dev . $ino . $dpid . "-tmp";
$DEBUG and warn "tmpfifo is $tmpfifo\n";

$DEBUG and warn "about to send $SIGNAL signal...\n";
kill "$SIGNAL", $dpid or die "Couldn't send $SIGNAL to pid $dpid.\n";
$DEBUG and warn "signal sent";

until (open (TMPFIFO, "$tmpfifo")) { warn "Can't open $tmpfifo yet...\n"; sleep(1); }
$DEBUG and warn "yay, opened the tmpfifo";
while (<TMPFIFO>) { print $_; }
$DEBUG and warn "ok, closing the tmpfifo";
close (TMPFIFO) or warn "Can't close $tmpfifo! ($!)\n";
exit;
