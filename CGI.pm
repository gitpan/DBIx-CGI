# CGI.pm - Easy to Use DBI interface for CGI scripts

# Copyright (C) 1999 Stefan Hornburg, Dennis Schön

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

package DBIx::CGI;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

require Exporter;

@ISA = qw(DBIx::Easy Exporter);
# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.
@EXPORT = qw(
);
$VERSION = '0.06';

use DBI;
use DBIx::Easy;
use HTML::Entities;

=head1 NAME

DBIx::CGI - Easy to Use DBI interface for CGI scripts

=head1 SYNOPSIS

  use CGI;
  my $cgi = new CGI;
  use DBIx::CGI;
  my $dbi_interface = new DBIx::CGI ($cgi, qw(Pg template1));

  $dbi_interface -> insert ('transaction',
                   id => serial ('transaction', 'transactionid'),
                   time => \$dbi_interface -> now);

  $dbi_interface -> update ('components', "table='ram'", price => 100);
  $dbi_interface -> makemap ('components', 'id', 'price');
  $components = $dbi_interface -> rows ('components');
  $components_needed = $dbi_interface -> rows ('components', 'stock = 0');

=head1 DESCRIPTION

DBIx::CGI is an easy to use DBI interface for CGI scripts.
Currently only the Pg, mSQL and mysql drivers are supported.

=head1 CREATING A NEW DBI INTERFACE OBJECT

  $dbi_interface = new DBIx::CGI ($cgi qw(Pg template1));
  $dbi_interface = new DBIx::CGI ($cgi qw(Pg template1 racke));
  $dbi_interface = new DBIx::CGI ($cgi qw(Pg template1 racke aF3xD4_i));
  $dbi_interface = new DBIx::CGI ($cgi qw(Pg template1 racke@linuxia.net aF3xD4_i));

The required parameters are a L<CGI> object, the database driver
and the database name. Additional parameters are the database user
and the password to access the database. To specify the database host
use the USER@HOST notation for the user parameter.

=head1 ERROR HANDLING

  sub fatal {
    my ($statement, $err, $msg) = @_;
    die ("$0: Statement \"$statement\" failed (ERRNO: $err, ERRMSG: $msg)\n");
  }
  $dbi_interface -> install_handler (\&fatal);

If any of the DBI methods fails, either I<die> will be invoked
or an error handler installed with I<install_handler> will be
called.

=cut

# Variables
# =========

my $maintainer_adr = 'racke@linuxia.net';

# Preloaded methods go here.

sub new ()
  {
	my $proto = shift;
	my $class = ref ($proto) || $proto;
    my $cgi = shift;
	my $self = $class -> SUPER::new (@_);

	$self ->{CGI} = $cgi;
    return $self;
  }

# ---------------------------------------------
# METHOD: view TABLE
#
# Produces HTML table for database table TABLE.
# ---------------------------------------------

=over 4

=item view I<table> [I<name> I<value> ...]

  foreach my $table (sort $dbi_interface -> tables)
    {
    print $cgi -> h2 ('Contents of ', $cgi -> code ($table));
    print $dbi_interface -> view ($table);
    }

Produces HTML code for a table displaying the contents of the database table
I<table>. This method accepts the following options as I<name>/I<value>
pairs:

B<order>: Which column to sort the row after.

B<column_link>: URI for the column names.
A %s will be replaced by the column name.

B<limit>: Maximum number of rows to display.

B<where>: Display only rows matching this condition.

  print $dbi_interface -> view ($table,
                                order => $cgi -> param ('order') || '',
                                column_link => $cgi->url()
                                . "&order=%s",
                                where => "price > 0");

=back

=cut

sub view
  {
	my ($self, $table, %options) = @_;
	my ($view, $sth, $aref);
    my $colsub;
    my ($orderstr, $condstr) = ('', '');

    # anonymous function for cells in top row
    $colsub = sub {
        my $colname = shift;
        my $dispname;

        if (exists($options{column_link}) && $options{column_link}) {
            $dispname = $self -> {CGI}
                -> a ({href => sprintf ($options{column_link}, $colname)}, $colname);
        } else {
            $dispname = $colname;
        }
        $self -> {CGI} -> td ($dispname);
    };
    
	# get contents of the table
    if ((exists ($options{'order'}) && $options{'order'})) {
        $orderstr = " ORDER BY $options{'order'}";
    }
    if ((exists ($options{'where'}) && $options{'where'})) {
        $condstr = " WHERE $options{'where'}";
    } 
    $sth = $self -> process ("SELECT * FROM $table$condstr$orderstr");
	
	$view .= "<TABLE BORDER>\n";
	# Field Names
	$view .= $self -> {CGI}
	  -> Tr (map {&$colsub ($_)} @{$sth->{NAME}});

    my $rowno = 0;
	while ($aref = $sth -> fetch) {
        last if exists $options{'limit'} && $rowno++ >= $options{'limit'}; 
		# add table row
		$view .= $self -> {CGI}
		  -> Tr (map {$self -> {CGI}
						-> td (defined ($_) && length ($_) ? encode_entities($_) : "&nbsp;")} @$aref) . "\n";
	  }
	
	$view .= "</TABLE>\n";
	$view;
}

# -------------------------------------------------
# METHOD: cgi
#
# Returns the CGI object passed to the constructor.
# -------------------------------------------------

=over 4

=item cgi

  print $dbi_interface -> cgi() -> header();

Returns the CGI object passed to the constructor.

=back

=cut

sub cgi {$_[0]->{CGI};}

1;
__END__

# Autoload methods go here, and are processed by the autosplit program.

=head1 AUTHORS

Stefan Hornburg, racke@linuxia.net
Dennis Schön, dschoen@rio.gt.owl.de

=head1 SEE ALSO

perl(1), CGI(3), DBI(3), DBD::Pg(3), DBD::mysql(3), DBD::msql(3).

=cut
