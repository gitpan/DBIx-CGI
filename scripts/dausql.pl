#! /usr/bin/perl -w

# dausql - Display Database Tables on the Localhost

# Copyright (C) 1999 Stefan Hornburg and Dennis Schön

# Authors: Stefan Hornburg <racke@linuxia.net>
#          Dennis Schön <dschoen@rio.gt.owl.de>
# Maintainer: Stefan Hornburg <racke@linuxia.net>
# Version: 0.06

# This file is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the
# Free Software Foundation; either version 2, or (at your option) any
# later version.

# This file is distributed in the hope that it will be
# useful, but WITHOUT ANY WARRANTY; without even the implied warranty
# of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this file; see the file COPYING.  If not, write to the Free
# Software Foundation, 675 Mass Ave, Cambridge, MA 02139, USA.

use strict;

use CGI::Extratags;
my $cgi = new CGI::Extratags;
use DBIx::CGI;

# GLOBAL VARIABLES
my $max_entries = 500; # Avoid Netscape Crashes
my $dispfunc; # selected diplay routine
my $formfunc; # select form routine
my $editfunc; # selected edit routine
my @supported_drivers= ('Pg','mysql','msql');


# CHECK PARAMETERS AND SELECT FORM AND DISPLAY ROUTINE
if ($cgi -> param ('search_bases')) {
  $formfunc = sub { form_bases ($cgi -> param ('driver'))};
}
elsif ($cgi -> param ('search_tables')) {
  $formfunc = sub { form_tables ($cgi -> param ('driver'),
				 $cgi -> param ('base'),
				 $cgi -> param ('login'),
				 $cgi -> param ('password'))};
}
elsif ($cgi -> param ('display') && ($cgi -> param ('routine') eq 'View')) {
  $formfunc = sub { form_tables ($cgi -> param ('driver'),
				 $cgi -> param ('base'),
				 $cgi -> param ('login'),
				 $cgi -> param ('password'),
				 $cgi -> param ('table'))};
  
  $dispfunc = sub { disp_table ($cgi -> param ('driver'),
				$cgi -> param ('base'),
				$cgi -> param ('table'),
				$cgi -> param ('login'),
				$cgi -> param ('password'),
				$cgi -> param ('order'))};
}
elsif ($cgi -> param ('display') && ($cgi -> param ('routine') eq 'Edit')) {
	$editfunc = sub { edit_disp_table ()};
}
else {
  $formfunc = sub { form_drivers ()};
}



# DISPLAY HTML PAGE
print $cgi -> header ();
print $cgi -> start_html ('-title' => "dausql 0.06",
                          '-author' => 'racke@linuxia.net and dschoen@rio.gt.owl.de');
print $cgi -> start_form ();
print $cgi -> start_table ();
&$formfunc if $formfunc;
print $cgi -> end_table ();
&$editfunc if $editfunc;
&$dispfunc if $dispfunc;
print $cgi -> end_form ();

print <<'EOF';
<HR><ADDRESS>&copy; 1999 by Stefan Hornburg 
<A HREF="mailto:racke@linuxia.net">&lt;racke@linuxia.net&gt</A> 
and Dennis Sch&ouml;n
<A HREF="mailto:dschoen@rio.gt.owl.de">&lt;dschoen@rio.gt.owl.de&gt;</A><BR>
</ADDRESS><HR>
EOF

print $cgi -> end_html ();

# FORM ROUTINES

# -----------------------------------------------
# FUNCTION: form_drivers
#
# Displays the Form with a popup menu for Drivers
# -----------------------------------------------

sub form_drivers
  {
    my @drivers;
    foreach my $i (DBI->available_drivers) {
      if (grep {$_ eq $i} @supported_drivers)  {push(@drivers,$i)}
    }
    print $cgi -> hidden (-name=>'drivers',
			  -value=>\@drivers);  
    
    print $cgi -> row ('Database Driver:',
		       $cgi -> popup_menu (-name=>'driver',
					    -values=>\@drivers),
		       '',
		       'Login:',
		       $cgi -> textfield (-name=>'login'),
		       '',
		       'Password:',
		       $cgi -> password_field (-name=>'password'));
    print $cgi -> row ('Database:',
		       $cgi -> textfield (-name=>'base'),
		       $cgi -> submit (-name=>'search_bases',
					-value=>'Search Databases'));
    print $cgi -> row ('Table:',
		       $cgi -> textfield (-name=>'table'),
		       $cgi -> submit (-name=>'search_tables',
					-value=>'Search Tables'));
    print $cgi -> row ($cgi -> submit (-name=>'display',
				       -value=>'Display Table'),
		       '',
		       "<p align=right>Select Display routine:</p>",
		       $cgi -> popup_menu (-name=>'routine',
					   -value=>['View','Edit']));
  }
    


# ---------------------------------------------------------
# FUNCTION: form_bases
#
# Displays the Form with a popup menu for Drivers and bases
# ---------------------------------------------------------

sub form_bases
  {
    my ($driver) = @_;
    
    my @drivers = $cgi -> param ('drivers');
    print $cgi -> hidden (-name=>'drivers',
			  -value=>\@drivers);   
    
    print $cgi -> row ('Database Driver:',
		       $cgi -> popup_menu (-name=>'driver',
					   -values=>\@drivers),
		       '',
		       'Login:',
		       $cgi -> textfield (-name=>'login'),
		       '',
		       'Password:',
		       $cgi -> password_field (-name=>'password'));
    
    my @bases = map {s/^dbi:$driver:(dbname=)?//i; $_}
      (DBI->data_sources($driver));
    print $cgi -> hidden (-name=>'bases', 
			  -value=>\@bases,
			  -override=>1);
    
    print $cgi -> row ('Database:',
		       $cgi -> popup_menu (-name=>'base',
					   -value=>\@bases),
		       $cgi -> submit (-name=>'search_bases',
				       -value=>'Search Databases'));
    print $cgi -> row ('Table:',
		       $cgi -> textfield (-name=>'table'),
		       $cgi -> submit (-name=>'search_tables',
				       -value=>'Search Tables'));
    print $cgi -> row ($cgi -> submit (-name=>'display',
				       -value=>'Display Table'),
		       '',
		       "<p align=right>Select Display routine:</p>",
		       $cgi -> popup_menu (-name=>'routine',
					   -value=>['View','Edit']));
  }



# ----------------------------------------------------------------
# FUNCTION: form_tables
#
# Displays the Form with a popup menu for Drivers, Bases and Tables
# ----------------------------------------------------------------

sub form_tables
  {
    my ($driver, $base, $login, $password, $table) = @_;
    
    my @drivers = $cgi -> param ('drivers');
    print $cgi -> hidden (-name=>'drivers',
			  -value=>\@drivers);
    
    print $cgi -> row ('Database Driver:',
		       $cgi -> popup_menu (-name=>'driver',
					   -values=>\@drivers),
		       '',
		       'Login:',
		       $cgi -> textfield (-name=>'login'),
		       '',
		       'Password:',
		       $cgi -> password_field (-name=>'password'));
    
    my @bases;
    if ($cgi -> param ('bases')) { 
      @bases = $cgi -> param ('bases');
    }
    else {
      @bases = map {s/^dbi:$driver:(dbname=)?//i; $_}
	(DBI->data_sources($driver)); 
    } 
    print $cgi -> hidden (-name=>'bases',
			  -value=>\@bases,
			  -override=>1); 
    
    print $cgi -> row ('Database:',
		       $cgi -> popup_menu (-name=>'base',
					    -value=>\@bases),
		       $cgi -> submit (-name=>'search_bases',
					-value=>'Search Databases'));

    # establish connection to DBMS
    my $dbif = new DBIx::CGI ($cgi, $driver, $base, $login, $password);
    $dbif -> install_handler (\&dbi_fatal);
    
    my @tables;
    if ($dbif -> tables) {      
      if ($cgi -> param ('tables')) {
	@tables = $cgi -> param ('tables');
	print $cgi -> hidden (-name=>'tables',
			      -value=>\@tables,
			      -override=>1); 
      }
      else {                                  
	@tables = $dbif -> tables;
	print $cgi -> hidden (-name=>'tables',
			      -value=>\@tables,
			      -override=>1);
      }
      
      print $cgi -> row ('Table:',
			 $cgi -> popup_menu (-name=>'table',
					     -value=>\@tables),
			 $cgi -> submit (-name=>'search_tables',
					 -value=>'Search Tables'));    
    }
    else {
      print $cgi -> row ("No Tables!",
			 "",
			 $cgi -> submit (-name=>'search_tables',
					 -value=>'Search Tables'));  
    }
    print $cgi -> row ($cgi -> submit (-name=>'display',
				       -value=>'Display Table'),
		       '',
		       "<p align=right>Select Display routine:</p>",
		       $cgi -> popup_menu (-name=>'routine',
					   -value=>['View','Edit']));
  }




# DISPLAY ROUTINES

# --------------------------
# FUNCTION: disp_table
#
# Displays the Table Entries 
# --------------------------

sub disp_table
  {
    my ($driver, $base, $table, $login, $password, $order) = @_;

    # establish connection to DBMS
    my $dbif = new DBIx::CGI ($cgi, $driver, $base, $login, $password);
    $dbif -> install_handler (\&dbi_fatal);
    
    my @orders;
    my $tbh = $dbif -> process ("SELECT * FROM $table WHERE 1 = 0");
    
    @orders = @{$tbh -> {NAME}};
    
    if ($order) {
      unless (grep {$_ eq $order} @orders) {$order = undef}
    }
    
    print $cgi -> row ("Order by:",
		       $cgi -> popup_menu (-name=>'order',
					    -value=>\@orders));
    print $cgi -> row ($dbif -> view ($table,
				      order => $order || '',
				      limit => $max_entries));		 
  }



# EDIT ROUTINES

# ----------------------------------
# FUNCTION: edit_disp_table
#
# Display and edit the table entries 
# ----------------------------------

sub edit_disp_table {
print <<'EOF';
Sorry, Edit routines not yet implemented.<BR>
If you're interested, put code in dausql.pl line 316 and mail patches to Stefan Hornburg <A HREF="mailto:racke@linuxia.net">&lt;racke@linuxia.net&gt</A> 
and Dennis Sch&ouml;n
<A HREF="mailto:dschoen@rio.gt.owl.de">&lt;dschoen@rio.gt.owl.de&gt;</A><BR>
<HR>
&copy; 1999 by Stefan Hornburg and Dennis Sch&ouml;n
EOF
exit;
}




# SOME USEFUL ROUTINES

# ------------------------------
# FUNCTION: dbi_fatal
#
# Error handler for DBI routines
# ------------------------------

sub dbi_fatal {
  my ($statement, $err, $msg) = @_;
  print "<PRE>$statement\n<BR>$msg</PRE>\n";
  exit;
}
