use v5.10;
use strict; 
use warnings;

# ARGS:
#	0 => input file path
#	1 => tcode map

# The first argument is a TSV prepared from various materials
# Columns:
#	symbol,date,job,title_en,title_ar,tcodes,area

# The second argument is a TSV tcode map
# Columns:
#	tcode,xref,tag,string_value

use MARC;
use Hzn::Util::Date;

use Data::Dumper;

my $tmap = do {
	my %return;
	open my $fh,'<',$ARGV[1];
	while (<$fh>){
		chomp;
		my @row = split "\t";
		$return{$row[0]}{xref} = $row[1];
		$return{$row[0]}{tag} = $row[2];
		$return{$row[0]}{value} = $row[3];
	}
	\%return
};

say '<collection>';

open my $fh,'<',$ARGV[0];
while (<$fh>) {
	chomp;
	next if $. == 1;
	
	my ($sym,$date,$jobs,$title_en,$title_ar,$tcodes,$area) = split "\t";
	
	my $r = MARC::Record->new;
	
	_003: {
		$r->add_field(MARC::Field->new(tag => '003')->text('ESCWA'));
	}
	
	_008: {
		next;
	}
	
	_191: {
		$r->add_field(MARC::Field->new(tag => '191')->set_sub('a',$sym));
	}
	
	_245: {
		next unless $title_en;
		
		my $f = MARC::Field->new(tag => '245')->set_sub('a',$title_en);
		
		my $article = $1 if $title_en =~ /^(A|An|The)/;
		if ($article) {
			$f->ind2(length($article) + 1);
		}
		
		$r->add_field($f)
	}
	
	_246: {
		next unless $title_ar;
		$r->add_field(MARC::Field->new(tag => '246')->set_sub('a',$title_ar));
	}
	
	_260_269: {
		my @parts = split '/', $date;
		$date = join '-', @parts[2,0,1];
		$r->add_field(MARC::Field->new(tag => '269')->set_sub('a',$date));
		$date = Hzn::Util::Date::_269_260($date);
		$r->add_field(MARC::Field->new(tag => '260')->set_sub('a',$date));
	}
	
	_650_651: {
		for (split ';', $tcodes) {
			my ($xref,$tag,$val) = @{$tmap->{$_}}{qw<xref tag value>};
			next unless $xref;
			my $bib_tag = $tag eq '150' ? '650' : '651';
			$r->add_field(MARC::Field->new(tag => $bib_tag)->set_sub('0',$xref)->set_sub('a',$val));
		}
	}
	
	_980: {
		$r->add_field(MARC::Field->new(tag => '980')->set_sub('a','BIB'));
	}
	
	_981: {
		$r->add_field(MARC::Field->new(tag => '981')->set_sub('a','Economic Commissions')->set_sub('b','Economic and Social Commission for Western Asia'));
	}
	
	_989: {
		$r->add_field(MARC::Field->new(tag => '989')->set_sub('a','Documents and Publications'));
	}
	
	print $r->to_xml;
}

say '</collection>';