use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

my @scripts = ("./scripts/dausql.pl");
# List here scripts that should be installed

WriteMakefile(
	'NAME'	=> 'DBIx::CGI',
	'VERSION_FROM' => 'CGI.pm', # finds $VERSION
	'INSTALLMAN3DIR' => '/usr/man/man3',
	'EXE_FILES' => \@scripts
);
