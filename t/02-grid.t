use strict;
use warnings;
use Tkx;
use Test::More;

BEGIN {
	eval { Tkx::package_require('tile'); } or do {
		plan skip_all => 'Tile is required but not available';
	};
	plan tests => 2;
}

use FindBin;
use Tkx::FindBar;

my $mw = Tkx::widget->new('.');
$mw->g_wm_title('Tkx::FindBar grid() tests');

my $findbar = $mw->new_tkx_FindBar();

my @label = map {
	$mw->new_ttk__label(
		-text   => $_,
		-width  => 5,
		-anchor => 'center',
		-relief => 'ridge',
	);
} (1 .. 9);

$label[0]->g_grid($label[1], $label[2]);
$label[3]->g_grid($findbar,  $label[5]);
$label[6]->g_grid($label[7], $label[8]);

my @slaves = grep { $_ ne $findbar } Tkx::SplitList(Tkx::grid('slaves', $mw));
my $info   = [Tkx::grid('info', $findbar)];

$findbar->hide();
is_deeply([Tkx::SplitList(Tkx::grid('slaves', $mw))], \@slaves, "hide() removes from grid");

$findbar->show();
is_deeply([Tkx::grid('info', $findbar)], $info, "show() restores original location");
