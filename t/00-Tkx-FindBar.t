use strict;
use warnings;
use Tkx;
use Test::More;

BEGIN {
	eval { Tkx::package_require('tile'); } or do {
		BAIL_OUT('Tile is required but not available');
	};
	plan tests => 2;

	use_ok('Tkx::FindBar');
}

my $mw = Tkx::widget->new('.');
my $findbar = $mw->new_tkx_FindBar();
ok($findbar, 'new');
