# CGI.pm - Easy to Use DBI interface for CGI scripts

# Copyright (C) 1999 Stefan Hornburg

# Author: Stefan Hornburg <racke@linuxia.de>
# Maintainer: Stefan Hornburg <racke@linuxia.de>
# Version: 0.03

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
require AutoLoader;

@ISA = qw(Exporter AutoLoader);
# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.
@EXPORT = qw(
);
$VERSION = '0.03';

use DBI;

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

=head1 DESCRIPTION

DBIx::CGI is an easy to use DBI interface for CGI scripts.
Currently only the Pg, mSQL and mysql drivers are supported.

=head1 CREATING A NEW DBI INTERFACE OBJECT

  $dbi_interface = new DBIx::CGI ($cgi qw(Pg template1));

The required parameters are a L<CGI> object, the database driver
and the database name. Additional parameters are the database user.

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

my $maintainer_adr = 'racke@linuxia.de';

# Keywords for connect()
my %kwmap = (mSQL => 'database', mysql => 'database', Pg => 'dbname');

# Whether the DBMS supports transactions
my %transactmap = (mSQL => 0, mysql => 0, Pg => 1);
  
# Statement generators for serial()
my %serialstatmap = (mSQL => sub {"SELECT _seq FROM $_[0]";},
					 Pg => sub {"SELECT NEXTVAL ('$_[1]')";});

# Statement for obtaining the table structure
my %obtstatmap = (mSQL => sub {my $table = shift;
							   "SELECT " . join (', ', @_) . " FROM $table";},
				  mysql => sub {my $table = shift;
							   "SELECT " . join (', ', @_) . " FROM $table";},
				  Pg => sub {my $table = shift;
							 "SELECT " . join (', ', @_)
							   . " FROM $table WHERE FALSE";});
  
# Supported functions
my %funcmap = (mSQL => {COUNT => 0},
			   mysql => {COUNT => 1},
			   Pg => {COUNT => 1});

# Preloaded methods go here.

sub new ($$)
  {
	my $proto = shift;
	my $class = ref ($proto) || $proto;
	my $self = {};

	# we need three parameters
	if ($#_ <= 2 && $#_ >= 3)
	  {
		die (__PACKAGE__, ": Wrong number of parameters.\n");
	  }
	
	$self ->{CGI} = shift;
	$self ->{DRIVER} = shift;
	$self ->{DATABASE} = shift;
	$self ->{USER} = shift;
	
	$self ->{CONN} = undef;
	$self ->{HANDLER} = undef;		# error handler

	bless ($self, $class);
	
	# check if this driver is supported
	unless (exists $kwmap{$self -> {DRIVER}})
	  {
		$self -> fatal ("Sorry, DBIx::CGI doesn't support the \"",
						$self -> {DRIVER}, "\" driver.\n",
						"Please send mail to $maintainer_adr for more information.\n");
	  }

	return ($self);
  }

sub DESTROY
  {
	my $self = shift;

	if (defined ($self -> {CONN}))
	  {
		$self -> {CONN} -> disconnect ();
	  }
  }

# ------------------------------
# METHOD: fatal
#
# Error handler for this module.
# ------------------------------

sub fatal
  {
	my $self = shift;
	my $err = '';
	my $errstr = '';

	if (defined $self -> {CONN})
	  {
		$err = $DBI::err;
		$errstr = $DBI::errstr;
		
		# something has gone wrong, rollback anything
		$self -> {CONN} -> rollback ();
	  }
	
	if (defined $self -> {'HANDLER'})
	  {
		&{$self -> {'HANDLER'}} ("@_", $err, $errstr);
	  }
	elsif (defined $self -> {CONN})
	  {
		die @_, " (DBERR: $err, DBMSG: $errstr)\n";
	  }
	else
	  {
		die @_, "\n";
	  }
  }

# ---------------------------------------------------------------
# METHOD: connect
#
# Establishes the connection to the database if not already done.
# Returns database handle if successful, dies otherwise.
# ---------------------------------------------------------------

sub connect ()
  {
	my $self = shift;
	
	unless (defined $self -> {CONN})
	  {
	    $self -> {CONN} = DBI
		  -> connect ("dbi:" . $self -> {DRIVER}
					  . ":" . $kwmap{$self -> {DRIVER}} . "="
					  . $self -> {DATABASE},
					  $self -> {USER}, '',
					  {AutoCommit => !$transactmap{$self->{DRIVER}}});
		unless (defined $self -> {CONN})
		  {
			# print error message in any case
			$self -> fatal ("Connection to database \"" . $self -> {DATABASE}
			  . "\" couldn't be established");
		  }
	  }

	# no need to see SQL errors twice
	$self -> {CONN} -> {'PrintError'} = 0;
	$self -> {CONN};
  }

# -------------------------
# METHOD: process STATEMENT
# -------------------------

=head1 METHODS

=over 4

=item process I<statement>

  $sth = $dbi_interface -> process ("SELECT * FROM foo");
  print "Table foo contains ", $sth -> rows, " rows.\n";

Processes I<statement> by just combining the I<prepare> and I<execute>
steps of the DBI. Returns statement handle in case of success.

=back

=cut

sub process
  {
  my ($self, $statement) = @_;
  my ($sth, $rv);
  
  $self -> connect ();

  # prepare and execute it
  $sth = $self -> {CONN} -> prepare ($statement)
	|| $self -> fatal ("Couldn't prepare statement \"$statement\"");
  $rv = $sth -> execute ()
	|| $self -> fatal ("Couldn't execute statement \"$statement\"");

  $sth;
  }

# ------------------------------------------------------
# METHOD: insert TABLE COLUMN VALUE [COLUMN VALUE] ...
#
# Inserts the given COLUMN/VALUE pairs into TABLE.
# ------------------------------------------------------

=over 4

=item insert I<table> I<column> I<value> [I<column> I<value>] ...

  $sth = $dbi_interface -> insert ('bar', drink => 'Caipirinha');

Inserts the given I<column>/I<value> pairs into I<table>. Determines from the
SQL data type which values has to been quoted. Just pass a reference to
the value to protect values with SQL functions from quoting.

=back

=cut

sub insert ($$$;@)
  {
	my $self = shift;
	my $table = shift;
	my (@columns, @values);
	my ($statement, $sthtest, $flags);
	my ($column, $value);

	$self -> connect ();

	while ($#_ >= 0)
	  {
		$column = shift; $value = shift;
		push (@columns, $column);
		push (@values, $value);
	  }

	# get the table structure
	$sthtest = $self -> process
	  (&{$obtstatmap{$self -> {'DRIVER'}}} ($table, @columns));
	$flags = $sthtest -> {'TYPE'};

	for (my $i = 0; $i <= $#values; $i++)
	  {
		if (ref ($values[$i]) eq 'SCALAR')
		  {
			$values[$i] = ${$values[$i]};
		  }
		else
		  {
			unless ($$flags[$i] == DBI::SQL_INTEGER)
			  {
				$values[$i] = $self -> quote ($values[$i]);
			  }
		  }
	  }
	
	# now the statement
	$statement = "INSERT INTO $table ("
	  . join (', ', @columns) . ") VALUES ("
		. join (', ', @values) . ")";

	# process it
	$self -> {CONN} -> do ($statement)
	  || $self -> fatal ("Couldn't execute statement \"$statement\"");
  }

# ---------------------------------------------------------------
# METHOD: update TABLE CONDITIONS COLUMN VALUE [COLUMN VALUE] ...
#
# Inserts the given COLUMN/VALUE pairs into TABLE.
# ---------------------------------------------------------------

=over 4

=item update I<table> I<conditions> I<column> I<value> [I<column> I<value>] ...

  $dbi_interface -> update ('components', "table='ram'", price => 100);

Updates any row of I<table> which fulfill the I<conditions> by inserting the given
I<column>/I<value> pairs. .

=back

=cut

sub update
  {
	my $self = shift;
	my $table = shift;
	my $conditions = shift;
	my (@columns);
	my ($statement);
	my ($column, $value);

	# ensure that connection is established
	$self -> connect ();
	
	while ($#_ >= 0)
	  {
		$column = shift; $value = shift;
		push (@columns, $column . ' = ' . "'$value'");
	  }

	# now the statement
	$statement = "UPDATE $table SET "
	  . join (', ', @columns) . " WHERE $conditions";

	# process it
	$self -> {CONN} -> do ($statement)
	  || $self -> fatal ("Couldn't execute statement \"$statement\"");
  }

# -------------------------------
# METHOD: rows TABLE [CONDITIONS]
# -------------------------------

=over 4

=item rows I<table> [I<conditions>]

  $components = $dbi_interface -> rows ('components');
  $components_needed = $dbi_interface -> rows ('components', 'stock = 0');

Returns the number of rows within I<table> satisfying I<conditions> if any.

=back

=cut

sub rows
  {
	my $self = shift;
	my ($table, $conditions) = @_;
	my ($sth, $aref, $rows);
	my $where = '';
	
	if (defined ($conditions))
	  {
		$where = " WHERE $conditions";
	  }
	
	# use COUNT(*) if available
	if ($funcmap{$self -> {DRIVER}}->{COUNT})
	  {
		$sth = $self -> process ("SELECT COUNT(*) FROM $table$where");
		$aref = $sth->fetch;
		$rows = $$aref[0];
	  }
	else
	  {
		$sth = $self -> process ("SELECT * FROM $table$where");
		$rows = $sth -> rows;
	  }

	$rows;
  }

# -------------------------------  
# METHOD: serial TABLE SEQUENCE
# -------------------------------

=over 4

=item serial I<table> I<sequence>

Returns a serial number for I<table> by querying the next value from
I<sequence>. Depending on the DBMS one of the parameters is ignored.
This is I<sequence> for mSQL resp. I<table> for PostgreSQL. mysql
doesn't support sequences, but the AUTO_INCREMENT keyword for fields.
In this case this method returns 0 and mysql generates a serial
number for this field.

=back

=cut
  
sub serial 
  {
	my $self = shift;
	my ($table, $sequence) = @_;
	my ($statement, $sth, $rv, $resref);
	
	$self -> connect ();
    return ('0') if $self->{DRIVER} eq 'mysql';

	# get the appropriate statement
	$statement = &{$serialstatmap{$self->{DRIVER}}};

	# prepare and execute it
	$sth = $self -> process ($statement);

	unless (defined ($resref = $sth -> fetch))
	  {
		$self -> fatal ("Unexpected result for statement \"$statement\"");
	  }

	$$resref[0];
  }

# ---------------------------------------------------------
# METHOD: fill STH HASHREF [FLAG COLUMN ...]
#
# Fetches the next table row from the result stored in STH.
# ---------------------------------------------------------

=over 4

=item fill I<sth> I<hashref> [I<flag> I<column> ...]

Fetches the next table row from the result stored into I<sth>
and records the value of each field in I<hashref>. If I<flag>
is set, only the fields specified by the I<column> arguments are
considered, otherwise the fields specified by the I<column> arguments
are omitted.

=back

=cut

sub fill
  {
	my ($dbi_interface, $sth, $hashref, $flag, @columns) = @_;
	my ($fetchref);

	$fetchref = $sth -> fetchrow_hashref;
	if ($flag)
	  {
		foreach my $col (@columns)
		  {
			$$hashref{$col} = $$fetchref{$col};
		  }
	  }
	else
	  {
		foreach my $col (@columns)
		  {
			delete $$fetchref{$col};
		  }
		foreach my $col (keys %$fetchref)
		  {
			$$hashref{$col} = $$fetchref{$col};
		  }
	  }
  }

# ---------------------------------------
# METHOD: view TABLE
#
# Produces HTML table for database TABLE.
# ---------------------------------------

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
B<column_link>: URI for the column names. A %s will be replaced by the
column name.

  print $dbi_interface -> view ($table,
                                order => $cgi -> param ('order') || '',
                                column_link => $cgi->url()
                                . "&order=%s");

=back

=cut

sub view
  {
	my ($self, $table, %options) = @_;
	my ($view, $sth, $aref);
    my ($colsub);

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
    if (exists ($options{'order'}) && $options{'order'}) {
	    $sth = $self -> process ("SELECT * FROM $table ORDER BY $options{'order'}");
    } else {
	    $sth = $self -> process ("SELECT * FROM $table");
    }
	
	$view .= "<TABLE BORDER>\n";
	# Field Names
	$view .= $self -> {CGI}
	  -> Tr (map {&$colsub ($_)} @{$sth->{NAME}});
	
	while ($aref = $sth -> fetch)
	  {
		# add table row
		$view .= $self -> {CGI}
		  -> Tr (map {$self -> {CGI}
						-> td (defined ($_) && length ($_) ? $_ : "&nbsp;")} @$aref) . "\n";
	  }
	
	$view .= "</TABLE>\n";
	$view;
}

# --------------------------------------------
# METHOD: now
#
# Returns representation for the current time.
# --------------------------------------------

=head1 TIME VALUES

=over 4

=item now

  $dbi_interface -> insert ('transaction',
                   id => serial ('transaction', 'transactionid'),
                   time => \$dbi_interface -> now);

Returns representation for the current time. Uses special values of
the DBMS if possible.

=back

=cut

sub now
  {
	my $self = shift;

    # Postgres and mysql have an special value for the current time
    return 'now' if $self -> {'DRIVER'} eq 'Pg';
	return 'now()' if $self -> {'DRIVER'} eq 'mysql';
    # determine current time by yourself
	scalar (gmtime ());
  }

# --------------------------------------------------
# METHOD: money2num MONEY
#
# Converts the monetary value MONEY (e.g. $10.00) to
# a numeric one.
# --------------------------------------------------

=head1 MONETARY VALUES

=over 4

=item money2num I<money>

Converts the monetary value I<money> to a numeric one.

=back

=cut

sub money2num
  {
	my ($self, $money) = @_;

	# strip leading dollar sign
	$money =~ s/\$//;
	# remove commas
	$money =~ s/,//g;
	# ignore empty pennies
	$money =~ s/\.00$//;
	
	$money;
  }

# install error handler
sub install_handler {$_[0] -> {'HANDLER'} = $_[1];}

# direct interface to DBI
sub prepare {my $self = shift; $self -> prepare (@_);}
sub commit {$_[0] -> connect () -> commit ();}
sub quote {$_[0] -> connect () -> quote ($_[1]);}

sub tables
  {
  my $self = shift;

  # mSQL/mysql doesn't support DBI method tables yet
  if ($self -> {DRIVER} eq 'mSQL' || $self -> {DRIVER} eq 'mysql')
	{
	  $self -> connect () -> func('_ListTables');
	}
  else
	{
	  # standard method
	  $self -> connect () -> tables ();
	}
  }

1;
__END__

# Autoload methods go here, and are processed by the autosplit program.

=head1 AUTHOR

Stefan Hornburg, racke@linuxia.de

=head1 SEE ALSO

perl(1).

=cut
