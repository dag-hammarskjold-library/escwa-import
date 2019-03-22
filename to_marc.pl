use v5.10;
use strict; 
use warnings;
use boolean;

# ARGS:
#	0 => input file path
#	1 => tcode map
#   2 => Mongo connection string

# The first argument is a TSV prepared from various materials
# Columns:
#	symbol,date,job,title_en,title_ar,tcodes,area

# The second argument is a TSV tcode map
# Columns:
#	tcode,xref,tag,string_value

use MongoDB;
use URI::Escape;
use Time::Piece;
use Data::Dumper;

use MARC;
use Get::ODS;
use Hzn::Util::Date;

use constant ISO_TO_STR => {
	# unicode normalization form C (NFC)
	AR => 'العربية',
	ZH => '中文',
	EN => 'English',
	FR => 'Français',
	RU => 'Русский',
	ES => 'Español',
	#DE => 'Deutsch',
	DE => 'Other',
};

my $db = MongoDB->connect($ARGV[2])->get_database('undlFiles')->get_collection('escwa_temp');

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
	
	my ($sym,$date,$job,$title_en,$title_ar,$tcodes,$area) = split "\t";
	
	my $r = MARC::Record->new;
	
	# controlfields are at the end
	
	_029: {
		# looks like job numbers are for the Arabic file
		$r->add_field(MARC::Field->new(tag => '029')->set_sub('a','JN')->set_sub('b',"$job A"));
	}
	
	_091: {
		# $r->add_field(MARC::Field->new(tag => '091')->set_sub('a','GEN'));
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
		} else {
			$f->ind2('0');
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
		$r->add_field (
			MARC::Field->new(tag => '981')
				->set_sub('a','Economic Commissions')
				->set_sub('b','Economic and Social Commission for Western Asia')
		);
	}
	
	_989: {
		$r->add_field(MARC::Field->new(tag => '989')->set_sub('a','Documents and Publications'));
	}
	
	_FFT: {
		#next;
		my $cur = $db->find({symbol => $sym});
		while (my $doc = $cur->next) {
			my ($lang,$uri) = @{$doc}{qw<language uri>};
			{
				# clean the urls
				$uri =~ s|aws/Drop/|aws.com/Drop/temp/|;
				if ($uri =~ m|(https?://.*?/)(.*)|) { 
					if (uri_unescape($2) eq $2) {
						$uri = $1.uri_escape($2);
						$uri =~ s/%2F/\//g;
					} 
				}
			}
			my $fn = clean_fn($sym.'.pdf');
			my $f = MARC::Field->new(tag => 'FFT');
			$f->set_sub('a',$uri);
			$f->set_sub('n',$fn);
			$f->set_sub('d',ISO_TO_STR->{$lang});
			$r->add_field($f);
		}
	}
	
	_003: {
		$r->add_field(MARC::Field->new(tag => '003')->text('ESCWA'));
	}
	
	_008: {
		$r->fixed_length_data_elements('|' x 40);
		my $dt = gmtime;
		$r->date_entered_on_file($dt->strftime('%y%m%d'));
		my $pubdt = Time::Piece->strptime($r->get_value('269','a'),'%Y-%m-%d');
		$r->type_of_date_publication_status('s');
		$r->date_1($pubdt->strftime('%Y'));
		$r->language('eng');
		$r->cataloging_source('d');
	}
	
	_000: {
		$r->record_status('c');
		$r->encoding_level('#');
		$r->type_of_record('a');
		$r->bibliographic_level('m');
		$r->character_encoding_scheme('a');
		$r->descriptive_cataloging_form('a');
	}
	
	print $r->to_xml;
	#print $r->to_mrk;
}

say '</collection>';

###

sub clean_fn {
	# scrub illegal characters for saving on Invenio's filesystem
	my $fn = shift;
	my @s = split '\.', $fn;
	$fn = join '-', @s[0..$#s-1];
	my $ext = $s[-1];
	$fn =~ s/\s//g;
	$fn =~ tr/\/[];/_^^&/;
	$fn .= ".$ext";
	return $fn;
}