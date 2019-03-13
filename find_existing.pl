use v5.10;
use strict;
use warnings;

use List::Util qw<any>;

use lib '..\modules';
use MARC;

# Find symbols from escwa file already in undl

# ARGS:
#	0 => path to undl "excel export"
#	1 => path to escwa data file

open my $ex,'<',$ARGV[0];

my @existing = <$ex>;

my %ex;
$ex{$_} = 1 for map {(split "\t")[2]} @existing;

MARC::Set->new->iterate_xml (
	path => $ARGV[1],
	callback => sub {
		my $r = shift;
		my @syms = $r->get_values('191','a');
		for (@syms) {
			say if $ex{$_}
		}
	}
);