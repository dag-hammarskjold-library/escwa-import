use v5.10;
use strict; 
use warnings;

# The original data was provided in an Excel file.
# The contents of the Excel file have been copy + pasted
# into a TSV file for easier processing. 

use MARC;
use Hzn::Util::Date;

say '<collection>';

open my $fh,'<',$ARGV[0];
while (<$fh>) {
	chomp;
	next if $. == 1;
	
	my ($sym,$date,undef,undef,undef,undef,$title_en,$title_ar) = split "\t";
	
	#say $sym unless $title_en;
	#next;
	
	my $r = MARC::Record->new;
	
	_191: {
		$r->add_field(MARC::Field->new(tag => '191')->set_sub('a',$sym));
	}
	
	_245: {
		next unless $title_en;
		
		my $f = MARC::Field->new(tag => '245')->set_sub('a',$title_en);
		
		my $article = $1 if $title_en =~ /^(A|An|The)/;
		if ($article) {
			$f->ind2(length $article);
		}
		
		$r->add_field($f)
	}
	
	_246: {
		next unless $title_ar;
		$r->add_field(MARC::Field->new(tag => '246')->set_sub('a',$title_ar));
	}
	
	_260_269: {
		my @parts = split '/', $date;
		$date = join '-', @parts[2,1,0];
		$r->add_field(MARC::Field->new(tag => '269')->set_sub('a',$date));
		$date = Hzn::Util::Date::_269_260($date);
		$r->add_field(MARC::Field->new(tag => '260')->set_sub('a',$date));
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