BEGIN {require 5.006}
use strict;
use warnings;
use Tkx;

use FindBin;
use lib "$FindBin::Bin/lib";
use Tkx::FindBar;

my $mw = Tkx::widget->new('.');
$mw->g_wm_title('FindBar Test');

my $text    = $mw->new_text(-wrap => 'word');
my $findbar = $mw->new_tkx_FindBar(-textwidget => $text);

$text->g_pack();
$findbar->g_pack(-anchor => 'w');
$findbar->hide();

$mw->g_bind('<Control-w>', \&quit);

$findbar->add_bindings($mw,
	'<Control-f>'  => 'show',
	'<Escape>'     => 'hide',
	'<F3>'         => 'next',
	'<Control-F3>' => 'previous',
);

$text->insert('end', <<EOT);
House training has changed too. You no longer whack the puppy with a rolled up newspaper when it relieves itself in the house. Now you do something more humane, called cage training. You put the puppy in a cage so small it can barely turn around. Dogs instinctively won\'t poop where they have to stand, so it learns to hold it until it poops on your terms.

I ask myself if I would prefer to be whacked with a rolled up newspaper when I pooped on the carpet or be forced to stay in a coffin-sized cage for several hours while desperately squeezing my butt cheeks together to keep the turtle in the shell. Which is more humane? I'm thinking it doesn't make any difference because my parents used both of those methods on me, and I turned out okay. 
EOT

$mw->g_focus();
Tkx::MainLoop();

sub quit { exit }
