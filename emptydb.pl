#! /usr/bin/perl -w

# Copyright (C) 1999 Stefan Hornburg

# Author: Stefan Hornburg <racke@linuxia.net>
# Maintainer: Stefan Hornburg <racke@linuxia.net>
# Version: 0.05

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
use DBIx::CGI;

if ($#ARGV < 1) {
    die ("$0: need database driver and database name\n");
}

my %fieldmap;

my ($sth, $keyfield, $update);
my ($table, $key, $fieldnames, @values, $headline);
my (@columns, $routine);

my $dbif = new DBIx::CGI (undef, @ARGV);
$dbif -> install_handler (\&fatal);

for ($dbif->tables) {
    $dbif -> process ("DELETE FROM $_ WHERE 1 = 1");
}

sub fatal {
    my ($statement, $err, $msg) = @_;

    $sth -> finish if $sth;
    die ("$0: Statement \"$statement\" failed (ERRNO: $err, ERRMSG: $msg)\n");
}

# script documentation (POD style)

=head1 NAME

emptydb.pl - Empty SQL Databases

=head1 AUTHOR

Stefan Hornburg, racke@linuxia.net

=head1 SEE ALSO

perl(1), DBIx::CGI(3)

=cut    
