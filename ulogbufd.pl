#!/usr/bin/perl -w

$DEBUG = 0;

# --- GLOBAL VARIABLES ---
$LOCKDIR = "/var/tmp";
$TMPFIFODIR = "/var/tmp";
$MAXLINES = 100;
@logq = ();
$lines = @logq;

$CLEAR_FILE_ON_DUMP = 0;
$CLEAR_QUEUE_ON_DUMP = 0;

$USAGE = "Usage: $0 fifo dumpfile
Receipt of SIGUSR1 causes the log buffer to be dumped to file.
Receipt of SIGUSR2 causes the log buffer to be dumped to the lockfifo.
Receipt of SIGHUP causes the log buffer to be cleared.\n";


# --- REAL CODE ---
initialize();
main();
exit;


# --- SUBROUTINES ---
sub initialize {
	defined ($MYFIFO = $ARGV[0]) or die "$USAGE";
	defined ($dumpfile = $ARGV[1]) or die "$USAGE";

	$0 = "ulogbufd: $MYFIFO";  # Probably not portable.  Oh well.

	($dev, $ino) = stat($MYFIFO) or die "Can't stat $MYFIFO: $!\n";
	$lockfile = $LOCKDIR . "/ulogbufd-" . $dev . $ino;
	$tmpfifo = $TMPFIFODIR . "/ulogbufd-" . $dev . $ino . $$ . "-tmp";
	$DEBUG and warn "looking at $lockfile";
	if (-e "$LOCKDIR/ulogbufd-$dev$ino") { die "Another ulogbufd is watching $MYFIFO.\n"; }
	# We could check to see if it's really true, but portable methods wouldn't be very
	# useful and useful methods wouldn't be very portable...
	else { open (LOCKFILE, ">$lockfile") or die "Can't create lockfile $lockfile: $!\n"; }
	print LOCKFILE "$$\n";
	close (LOCKFILE);

	# These signal handlers must be installed between the creation of the lockfile and the opening of the FIFO or we open ourselves to ugly race conditions.  This solution means that we might create a lockfile only to remove it again a fraction of a second later, but the alternatives are either creating a lockfile that doesn't get removed if we die, or not creating a lockfile until something actually gets written to the FIFO.
	$SIG{INT} = 'cleanup';
	$SIG{TERM} = 'cleanup';
	$SIG{USR1} = 'qfiledump';
	$SIG{USR2} = 'qqdump';
	$SIG{HUP} = sub { $DEBUG and warn "got a HUP; clearing log queue"; @logq = () };  # clear the buffer 
	$DEBUG and warn "signal handlers installed\n";

	open (FH, "+<$MYFIFO") or die "Can't open $MYFIFO: $!\n";  # Our dirty secret: it doesn't actually have to be a FIFO!
	# The + in the open is there not because we really want to write 
	# anything, but because we _don't_ want to block.  Doing this helps
	# a lot with race problems.
	$DEBUG and warn "FH is opened\n";
	$DEBUG and warn "whoo, finally bugging out of initialize()\n";
}

sub main {
	while (1) {
       		if (defined ($newline = <FH>)) {
                	push (@logq, $newline);
                	$lines = @logq;
                	if ($lines > $MAXLINES) { shift (@logq); }
        	}
	        else { sleep(1); }
	} 
}

sub qfiledump {
	$DEBUG and warn "entering qfiledump";
	if ($CLEAR_FILE_ON_DUMP) { open (DUMPFILE, ">$dumpfile") or warn "Can't open dumpfile $dumpfile: $!\n"; }
	else { open (DUMPFILE, ">>$dumpfile") or warn "Can't open dumpfile $dumpfile: $!\n"; }
	print DUMPFILE @logq;
	close (DUMPFILE) or warn "Can't close dumpfile $dumpfile: $!\n";
	if ($CLEAR_QUEUE_ON_DUMP) { @logq=(); }
}

sub qqdump {
	$DEBUG and warn "Entering qqdump";
	# dump buffer to FIFO
	system ("mkfifo", "$tmpfifo") and warn "Can't create temporary pipe $tmpfifo: $!\n";
	# Stupid shell semantics!
	open (DUMPFIFO, ">$tmpfifo") or warn "Can't open temporary pipe $tmpfifo: $!\n";
	$DEBUG and warn "about to dump logq to tmpfifo";
	print DUMPFIFO @logq;
	$DEBUG and warn "finished dumping logq to tmpfifo";
	close (DUMPFIFO) or warn "Can't close temporary pipe $tmpfifo: $!\n";
	unlink $tmpfifo or warn "Can't unlink temporary pipe $tmpfifo: $!\n";
	if ($CLEAR_QUEUE_ON_DUMP) { @logq=(); }
}

sub cleanup {
	$DEBUG and local($mysig) = @_;
	$DEBUG and warn "Oops, got a SIG$mysig\n";
	if (-e "$tmpfifo") { $DEBUG and warn "unlinking my temporary pipe"; unlink $tmpfifo;}
	$DEBUG and warn "unlinking my lockfile\n";
	unlink $lockfile or warn "Can't unlink lockfile $lockfile: $!"; 
	exit;
}
