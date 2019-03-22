use v5.10;
use strict;
use warnings;

# run this from a temp folder because it downloads the files into the pwd

# $ARGV[0] => path to tsv with symbols in first column

use Get::ODS;
use MongoDB;
use Tie::IxHash;

my $ods = Get::ODS->new;
my $db = MongoDB->connect($ARGV[1])->get_database('undlFiles')->get_collection('escwa_temp');

open my $fh,'<',$ARGV[0];
while (<$fh>) {
	chomp;
	my $sym = (split "\t")[0];
	for my $lang (qw<AR ZH EN FR RU ES>) {
		my $file = $ods->download($sym,$lang) or next;
		my $dest = "s3://undhl-dgacm/Drop/temp/$sym/$file";
		system qq|c:\\repos\\aws s3 cp "$file" "$dest"|;
		$db->insert_one (
			Tie::IxHash->new (
				symbol => $sym, 
				language => $lang, 
				uri => "http://undhl-dgacm.s3.amazonaws/Drop/$sym/$file"
			)
		)
	}
}