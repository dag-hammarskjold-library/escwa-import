use v5.10;
use strict;
use warnings;

binmode STDOUT, 'utf8';

# $ARGV[0] => "master" CSV
# $ARGV[1] => undl existing CSV with symbols in third column
# **@ARGV => CSVs with indclude symmols in the first line

# output: CSV to run as input to "to_marc.pl"
#	symbol,date,jobs,title_en,title_ar,tcodes

use Text::CSV;
my $csv = Text::CSV->new({binary => 1});

my $existing = do {
	my %return;
	open my $fh,'<:utf8',$ARGV[1];
	while (<$fh>) {
		chomp;
		my @row = split "\t";
		$return{$row[2]} = 1;
	}
	\%return;
};

my $to_import = do {
	my %return;
	for (@ARGV[2..$#ARGV]) {
		open my $fh,'<:utf8',$_ or die "what";
		while (<$fh>) {
			chomp;
			my @row = split "\t";
			my $sym = $row[0];
			$return{$sym}{take} = 1;
			$return{$sym}{title_ar} = $row[4] if $row[4];
		}
	}
	\%return;
};

open my $out,'>:utf8','final_data.tsv';
my $c = 0;
open my $master,'<:utf8',$ARGV[0];
while (<$master>) {
	next if $. == 1;
	chomp;
	my @row = split "\t";
	my $sym = $row[0];
	next if $existing->{$sym};
	next unless $to_import->{$sym}->{take};
	
	if (my $ar = $to_import->{$sym}->{title_ar}) {
		$row[4] = $ar;
	}
	
	say {$out} join "\t", @row[0..5];
	
	$c++;
}

