BEGIN { require 5.006 }
use ExtUtils::MakeMaker;

WriteMakefile(
	NAME          => 'Tkx::FindBar',
	AUTHOR        => 'Michael J. Carman	<mjcarman@cpan.org>',
	VERSION_FROM  => 'lib/Tkx/FindBar.pm',
	ABSTRACT_FROM => 'lib/Tkx/FindBar.pm',
	PREREQ_PM     => {
		'Tkx' => 0,
	},
);
