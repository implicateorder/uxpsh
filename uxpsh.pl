#!/opt/local/bin/perl

#------------------------------------------------------------------------------
# uxpsh -- UNIX password shell
# Author -- Dwai Lahiri
# Created -- 4/13/2004
# Credits to : Steven L. Kunz's perlmenu demo program(s)
# Note: Even though advisory exclusive write locks are in place, 
# have to make sure file doesn't get clobbered by simultaneous writes
# Modified -- 4/27/2004 -- DL
# Cleaned up some old declarations, variables, etc - 6/25/04 - DL
# Minor fixes to "cleanup" routine - 6/25/04 - DL
# SCCS Delta 1.3
# $Id: uxpsh,v 1.1 2006/01/16 18:16:02 dlahiri Exp $
#------------------------------------------------------------------------------

#use strict;			#For now, don't use strict subs
BEGIN { $Curses::OldCurses = 1; }
#use lib "/opt/perl/lib/site_perl/5.8.8/sun4-solaris";
use lib "/home/i08129r/bin";
use Curses;      #PerlMenu needs "Curses"
use perlmenu;    #Main menu package

use Crypt::Simple;
use File::Copy qw/mv cp/;
require "menuutil.pl";    #For "pause" and "print_nl" routines

my $pwfl = "/home/i08129r/.safe/uxpsh.txt";

$SIG{'INT'} = 'cleanup';    #Set Signal Handler
$| = 1;                     #Flush after every write to stdout

my $window = &initscr();

&menu_curses_application($window);
&menu_quit_routine("endwin");

#Default prefs active at start
my $numbered_flag = 1;            #Numbered menus
my $num_pref      = "numbered";
my $gopher_pref   = "default";    #Non-gopherlike arrows/scrolling
my $gopher_flag   = 0;
my $mult_pref     = "single";     #Single column menus
my $mult_flag     = 0;
my $arrow_pref    = "arrow";      #Arrow selection indicator menus
my $arrow_flag    = 1;

my $menu_default_top = 0;              # Storage for mainline top item number.
my $menu_default_row = 0;              # Storage for mainline arrow location.
my $menu_default_col = 0;              # Storage for mainline arrow location.
my $row              = my $col = 0;    # Storage for row/col for menuutil.pl
my $title_cnt = 0;    # To trigger different subtitles/bottom titles
my $default;
my $version = "v0.5";

@input_data   = ();
@display_data = ();
@protect      = ();
$bell         = "\007";
$default      = "";
my $null = "/dev/null";
my $src;
my $dest;
my $username = $ENV{LOGNAME};

while (1) {
    &menu_init(
        $numbered_flag, "UNIX Password Shell Utility $version",
        0, "", "-- WARNING $username! If you don't have permission to use this application, \n exit immediately!\n Abusers will be prosecuted to the maximum extent of the Law.\n All actions are logged and monitored. ",
        "main_menu_help"
    );

    &menu_paint_file( "/usr/bin/unix_text", 0 );
    &menu_item( "Exit this shell",                "exit" );
    &menu_item( "Search records for a hostname", "host_pw" );
    &menu_item( "host modify",                    "mod_host" );
    &menu_item( "host add",                       "add_host" );
    &menu_item( "host delete",                    "del_host" );
    my $sel =
      &menu_display( "", $menu_default_row, $menu_default_top,
        $menu_default_col );
    if ( $sel eq "exit" ) { last; }

    if ( $sel eq "%EMPTY%" ) {
        die "Not enough screen lines to display passwd shell menu\n";
    }
    if ( $sel ne "%UP%" ) {

        #Note that this assumes the "action_text" is a subroutine name
        &$sel();
    }
    if ( $sel eq "host_pw" )  { &host_pw(); }
    if ( $sel eq "mod_host" ) { &mod_host(); }
    if ( $sel eq "add_host" ) { &add_host(); }
    if ( $sel eq "del_host" ) { &del_host(); }
}
endwin;
exit;

sub main_menu_help {
    my ( $item_text, $item_tag ) = @_;

    &top_title("Password shell -- Help Screen for Specific Menu Items");
    &print_nl( "Selection \"$item_text\"", 2 );
    if ( $item_tag eq "exit" ) {
        &print_nl( "Selecting this item will immediately exit this program.",
            1 );
    }
    elsif ( $item_tag eq "host_pw" ) {
        &print_nl( "Search password for given host string -- returns value only if valid hostname in the repository",
            1 );
    }
    elsif ( $item_tag eq "mod_host" ) {
        print_nl( "Modify an existing password entry.", 1 );
    }
    elsif ( $item_tag eq "add_host" ) {
        print_nl( "Add a password entry to the encrypted repository.", 1 );
    }
    elsif ( $item_tag eq "del_host" ) {
        print_nl( "Delete a password entry from the ecrypted repository.", 1 );
    }
    pause("(Press any key to exit help)");
}

sub host_pw {
    my $sel;
    while (1) {
        my $prow = $row;
        my $pcol = $col + 2;

        #Init a numbered menu with a title
        &menu_init( $numbered_flag,
            "Search database for host string entered here" );

        #Add item to return to main menu
        &menu_item( "Exit", "exit" );

        &menu_item( "Host string search", "get_host_str" );

        $sel =
          menu_display( "", $menu_default_row, $menu_default_top,
            $menu_default_col );
        if ( ( $sel eq "%UP%" ) || ( $sel eq "exit" ) ) { return; }
        if ( $sel eq "get_host_str" ) {
            print_nl( "    Enter the hostname you're looking for", 1 );
            &print_nl( "  Supply a null value to exit.", 2 );
            $prow = $row;
            $pcol = $col + 2;
            my $hostname = &menu_getstr( $prow, $pcol, "Enter hostname: ",
                0, $default, 20, 0 );
            last if ( $hostname eq "" );
            decreep($hostname);
        }
        &clear_screen();
    }
}

sub mod_host {
    my $sel;
    while (1) {
        my $prow = $row;
        my $pcol = $col + 2;

        #Init a numbered menu with a title
        &menu_init( $numbered_flag,
            "Modify a host/password entry in the encrypted file" );

        #Add item to return to main menu
        &menu_item( "Exit", "exit" );

        &menu_item( "Modify host/passwd entry", "mod_host_str" );

        $sel =
          menu_display( "", $menu_default_row, $menu_default_top,
            $menu_default_col );
        if ( ( $sel eq "%UP%" ) || ( $sel eq "exit" ) ) { return; }
        if ( $sel eq "mod_host_str" ) {
            print_nl( "    Enter the hostname you want to modify", 1 );
            &print_nl( "  Supply a null value to exit.", 2 );
            $prow = $row;
            $pcol = $col + 2;
            my $hostname = &menu_getstr( $prow, $pcol, "Enter hostname: ",
                0, $default, 20, 0 );
            print_nl( "    Enter the new password", 1 );
            $prow = $row;
            $pcol = $col + 2;
            my $password = &menu_getstr( $prow, $pcol, "Enter new password: ",
                0, $default, 20, 0 );
            last if ( $hostname eq "" );
            modit( $hostname, $password );
        }
        &clear_screen();
    }
}

sub add_host {
    my $sel;
    while (1) {
        my $prow = $row;
        my $pcol = $col + 2;

        #Init a numbered menu with a title
        &menu_init( $numbered_flag,
            "Add a host/password entry in the encrypted repository" );

        #Add item to return to main menu
        &menu_item( "Exit", "exit" );

        &menu_item( "Add host/passwd entry", "add_host_str" );

        $sel =
          menu_display( "", $menu_default_row, $menu_default_top,
            $menu_default_col );
        if ( ( $sel eq "%UP%" ) || ( $sel eq "exit" ) ) { return; }
        if ( $sel eq "add_host_str" ) {
            print_nl( "    Enter the hostname you want to add", 1 );
            &print_nl( "  Supply a null value to exit.", 2 );
            $prow = $row;
            $pcol = $col + 2;
            my $hostname = &menu_getstr( $prow, $pcol, "Enter hostname: ",
                0, $default, 20, 0 );
            print_nl( "    Enter the password for the given hostname", 1 );
            $prow = $row;
            $pcol = $col + 2;
            my $password = &menu_getstr( $prow, $pcol, "Enter password: ",
                0, $default, 20, 0 );
            last if ( $hostname eq "" );
            addit( $hostname, $password );
        }
        &clear_screen();
    }
}

sub del_host {
    my $sel;
    while (1) {
        my $prow = $row;
        my $pcol = $col + 2;

        #Init a numbered menu with a title
        &menu_init( $numbered_flag,
            "Delete an existing entry from encrypted repository" );

        #Add item to return to main menu
        &menu_item( "Exit", "exit" );

        &menu_item( "delete host/passwd entry", "del_host_str" );

        $sel =
          menu_display( "", $menu_default_row, $menu_default_top,
            $menu_default_col );
        if ( ( $sel eq "%UP%" ) || ( $sel eq "exit" ) ) { return; }
        if ( $sel eq "del_host_str" ) {
            print_nl( "    Enter the hostname you want to delete", 1 );
            &print_nl( "  Supply a null value to exit.", 2 );
            $prow = $row;
            $pcol = $col + 2;
            my $hostname = &menu_getstr( $prow, $pcol, "Enter host name: ",
                0, $default, 20, 0 );
            last if ( $hostname eq "" );
            delit($hostname);
        }
        &clear_screen();
    }
}

sub handleit {
    my $string = shift;
    if ( !&display_entry($string) ) {
        &new_line(1);
        &pause(
            "  Login \"$string\" not found - Press any key to continue $bell");
        $default = $string;
    }
    else { $default = ""; }
}

sub decreep {
    require 'menuutil.pl';
    my $host = shift;
    my @arr;
    chomp $host;
    open( SRCHPWFL, "< $pwfl" ) || die "Unable to open $pwfl: $!\n";
    for (<SRCHPWFL>) {
        if ( $_ =~ m/^$host/i ) {
            @arr = split( ':', $_ );
            my $password = decrypt( $arr[1] );
            menu_display("Password for $arr[0] is : $password");
        }
    }
    close(SRCHPWFL);
}

sub modit {
    my ( $host, $password ) = @_;
    my @arr;
    my $date = qx/date '+%m%d%Y%H%M'/;
    chomp $date;
    $src  = $pwfl;
    $dest = $pwfl . "." . $date;
    chomp $dest;
    cp( "$src", "$dest" );
    open( MOD1PWFL, "< $dest" ) || menu_display("Unable to open $dest: $!\n");
    open( MODPWFL,  ">> $src" ) || menu_display("Unable to open $src: $!\n");
    system("> $src");    #Zero out the actual password file
    flock(MODPWFL, 2) or menu_display("Unable to get an exclusive write lock on $src: $! \n");

    if ( ( !-z $host ) && ( !-z $password ) ) {
        my $encrypted = encrypt($password);
        for (<MOD1PWFL>) {
	    print MODPWFL "$_" and next if /^#/;
	    my @lsplit = split(':', $_);
            if ( $lsplit[0] eq $host ) {
                $lsplit[1] = $encrypted;
		print MODPWFL "# $username Modified $host entry -- $date \n";
                print MODPWFL "$host:$lsplit[1]\n";
            }
            else {
                print MODPWFL "$_";
            }
        }
    }
    close(MOD1PWFL);
    close(MODPWFL);
}

sub addit {
    my ( $host, $password ) = @_;
    my $date = qx/date '+%m%d%Y%H%M'/;
    chomp $date;
    $src  = $pwfl;
    $dest = $pwfl . "." . $date;
    chomp $dest;
    cp( "$src", "$dest" );
    open(READPWFL, "< $dest");
    open( ADDPWFL, ">> $src" ) || menu_display("Unable to open $src : $!\n");
    flock(ADDPWFL, 2) or menu_display("Unable to get an exclusive write lock on: $src \n");

    if ( ( !-z $host ) && ( !-z $password ) ) {
        my $encrypted = encrypt($password);
        for (<READPWFL>) {
	    next  if /^#/o;
	    my @lsplit = split(':',$_);
	    if ( $lsplit[0]  eq $host ) {
		menu_display("$host already has an entry in : $src \n");
		return 1;
	    }
        }
        if ($? != 1) {
	    print ADDPWFL "# $username added entry for $host - $date \n";
       	    print ADDPWFL "$host:$encrypted\n";
	}
    }
    close(ADDPWFL);
}

sub delit {
    my $host = shift;
    my @arr;
    chomp $host;
    my $date = qx/date '+%m%d%Y%H%M'/;
    chomp $date;
    $src  = $pwfl;
    $dest = $pwfl . "." . $date;
    chomp $dest;
    cp( "$src", "$dest" );
    open( DEL1PWFL, "< $dest" ) || menu_display("Unable to open $dest: $!\n");
    open( DELPWFL,  ">> $src" ) || menu_display("Unable to open $src: $!\n");
    system("> $src");    #Zero out actual pw file
    flock(DELPWFL, 2) or menu_display("Unable to get an exclusive write lock on : $src \n");

    for (<DEL1PWFL>) {
	print DELPWFL "$_" and next  if /^#/;
	my @lsplit = split(':',$_);
        if ( $lsplit[0] ne  $host ) {
            print DELPWFL "$_" ;
        }
	else {
	    print DELPWFL "# $username deleted entry for $host - $date \n";
	}
    }
    close(DEL1PWFL);
    close(DELPWFL);
}

sub cleanup {
    &clear_screen;
    wrefresh;
    endwin;
    exit;
}

sub inwait {
    ReadMode('cbreak');
    if ( defined( $char = ReadKey(-1) ) ) {
        print $char;
    }
    else {
        print "No input waiting\n";
    }
    ReadMode('normal');
}
