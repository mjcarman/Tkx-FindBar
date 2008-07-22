package Tkx::FindBar;
use strict;
use warnings;
use Tkx;
use base qw(Tkx::widget Tkx::MegaConfig);

Tkx::package_require('tile');

our $VERSION = '0.01';

# keys to ignore during Find As You Type
my %ignore = map { $_ => 1 } qw(
	F1 F2 F3 F4 F5 F6 F7 F8 F9 F10 F11 F12
	Control_L Control_R Shift_L Shift_R Alt_L Alt_R
	Caps_Lock Num_Lock Tab Break Escape	Return
	Insert Delete Home End Prior Next
	Up Down Left Right
);

# load images for toolbar buttons
INIT {
	eval { Tkx::package_require('img::png') };
	my $icofmt = $@ ? 'gif89' : 'png';

	while (<DATA>) {
		next if /^#/;
		next if /^\s*$/;
		last if /^__END__$/;
		chomp;

		my ($name, $fmt, $data) = (split /:/)[0,1,4];
		next unless $fmt eq $icofmt;
		Tkx::image('create', 'photo', $name, -data => $data);
	}
}

__PACKAGE__->_Mega("tkx_FindBar");
__PACKAGE__->_Config(
	-textwidget     => ['METHOD'],
	-highlightcolor => ['METHOD'],
);


#-------------------------------------------------------------------------------
# Method  : _Populate
# Purpose : Create a new FindBar
# Notes   :
#-------------------------------------------------------------------------------
sub _Populate {
	my ($class, $widget, $path, %opt) = @_;

	# create the megawidget
	my $self = $class->new($path)->_parent->new_ttk__frame(-name => $path);
	$self->_class($class);

	# initialize instance data
	my $data = $self->_data();
	$data->{-textwidget}     = delete $opt{-textwidget};
	$data->{-highlightcolor} = delete $opt{-highlightcolor} || '#80FF80';
	$self->_set_hightlightcolor();

	$data->{start} = '1.0';  # start index of found string
	$data->{what}  = '';     # entry text
	$data->{case}  = 0;      # case-sensitive search
	$data->{regex} = 0;      # regular expression search
	$data->{count} = 0;      # number of chars in found string


	# populate the megawidget...

	$self->new_ttk__button(
		-text      => 'Close',
		-image     => 'close16',
		-takefocus => 0,
		-style     => 'Toolbutton',
		-command   => [\&hide, $self],
	)->g_pack(-side => 'left', -anchor => 'w');

	$self->new_ttk__label(
		-name => 'lab',
		-text => 'Find:',
	)->g_pack(-side => 'left', -anchor => 'w');

	$self->new_ttk__entry(
		-name         => 'e',
		-textvariable => \$data->{what},
	)->g_pack(-side => 'left', -anchor => 'w');

	$self->new_ttk__button(
		-text      => 'Next',
		-image     => 'go-down16',
		-takefocus => 0,
		-style     => 'Toolbutton',
		-command   => [\&next, $self],
	)->g_pack(-side => 'left', -anchor => 'w');

	$self->new_ttk__button(
		-text      => 'Previous',
		-image     => 'go-up16',
		-takefocus => 0,
		-style     => 'Toolbutton',
		-command   => [\&previous, $self],
	)->g_pack(-side => 'left', -anchor => 'w');

	$self->new_ttk__checkbutton(
		-text      => 'Match Case',
		-underline => 6,
		-variable  => \$data->{case}
	)->g_pack(-side => 'left', -anchor => 'w');

	$self->new_ttk__checkbutton(
		-text      => 'Regular Expression',
		-underline => 8,
		-variable  => \$data->{regex},
	)->g_pack(-side => 'left', -anchor => 'w');

	Tkx::bind("$self.e", '<Alt-c>',      sub { $data->{case}  = ! $data->{case}  } );
	Tkx::bind("$self.e", '<Alt-e>',      sub { $data->{regex} = ! $data->{regex} } );
	Tkx::bind("$self.e", '<KeyRelease>', [\&_find, Tkx::Ev('%K'), $self, 'first', 1]);

	return $self;
}


#-------------------------------------------------------------------------------
# Method  : _config_textwidget
# Purpose : Handler for configure(-textwidget => <widget>)
# Notes   :
#-------------------------------------------------------------------------------
sub _config_textwidget {
	my $self = shift;
	my $text = shift;
	my $data = $self->_data();

	if (defined $text) {
		# Remove tag from previous text widget
		$data->{-textwidget}->tag('delete', 'highlight') if $data->{-textwidget};

		$data->{-textwidget} = $text;
		$self->_set_hightlightcolor();
	}

	return $data->{-textwidget};
}


#-------------------------------------------------------------------------------
# Method  : _config_highlightcolor
# Purpose : Handler for configure(-highlightcolor => <widget>)
# Notes   :
#-------------------------------------------------------------------------------
sub _config_highlightcolor {
	my $self  = shift;
	my $color = shift;
	my $data  = $self->_data();

	if (defined $color) {
		$data->{-highlightcolor} = $color;
		$self->_set_hightlightcolor();
	}

	return $data->{-highlightcolor};
}


#-------------------------------------------------------------------------------
# Method  : _set_hightlightcolor
# Purpose :
# Notes   :
#-------------------------------------------------------------------------------
sub _set_hightlightcolor {
	my $self = shift;
	my $data = $self->_data();

	return unless $data->{-textwidget};

	$data->{-textwidget}->tag('configure', 'highlight',
		-background => $data->{-highlightcolor},
	);
}


#---------------------------------------------------------------------------
# Method  : show
# Purpose : Display the find toolbar
# Notes   :
#---------------------------------------------------------------------------
sub show {
	my $self = shift;
	my $data = $self->_data();

	# Display the find toolbar if it isn't already visible
	if ($data->{packinfo}) {
		$self->g_pack(Tkx::SplitList($data->{packinfo}));
		$data->{packinfo} = undef;
	}

	# Focus the entry widget and select the contents so the user can
	# start typing immediately
	Tkx::focus("$self.e");
	Tkx::eval("$self.e", 'selection', 'range', 0, 'end');
}


#---------------------------------------------------------------------------
# Method  : hide
# Purpose : Hide the find toolbar
# Notes   :
#---------------------------------------------------------------------------
sub hide {
	my $self = shift;
	my $data = $self->_data();

	# Clear any lingering highlights from found text
	$data->{-textwidget}->tag('remove', 'highlight', '0.0', 'end')
		if defined $data->{-textwidget};

	return if $data->{packinfo};  # already hidden

	# Remember currrent pack options
	$data->{packinfo} = Tkx::pack('info', $self);

	# Remember current place in pack order
	# pack('info', ...) doesn't include -before or -after so we need to
	# synthesize them using the slave list from our pack master.
	my ($master) = $data->{packinfo} =~ /-in (\.\w*)/;
	my @slave    = Tkx::SplitList(Tkx::pack('slaves', $master));
	for (my $i = 0; $i < @slave; $i++) {
		next unless $slave[$i] eq $self->_mpath;
		if    ($i > 0      ) { $data->{packinfo} .= " -after $slave[$i-1]"  }
		elsif ($i < $#slave) { $data->{packinfo} .= " -before $slave[$i+1]" }
		# else it's the only thing in the slaves!
		last;
	}

	# Hide the find toolbar
	Tkx::pack('forget', $self);
}


#---------------------------------------------------------------------------
# Method  : first/next/previous
# Purpose : public wrappers for specific searches
# Notes   :
#---------------------------------------------------------------------------
sub first    { _find('', $_[0], 'first', 0) }
sub next     { _find('', $_[0], 'next',  0) }
sub previous { _find('', $_[0], 'prev',  0) }


#-------------------------------------------------------------------------------
# Subroutine : _find
# Purpose    : Search in text widget
# Notes      : Private sub, NOT A METHOD because the keysym must be the
#              first arg for Tkx::Ev to work when binding.
#-------------------------------------------------------------------------------
sub _find {
	my $keysym = shift;  # which key was pressed
	my $self   = shift;  # megawidget instance
	my $which  = shift;  # first|next|prev
	my $fayt   = shift;  # "find as you type" call from a KeyRelease event
	my $data   = $self->_data();

	return unless defined $data->{-textwidget};  # search where?

	# Ignore KeyRelease events triggered by control keys
	return if $fayt && $ignore{$keysym};
	#status('key = ' . $keysym);  # used for debugging the ignore list

	# Restart new searches at the beginning. Advance the start position for
	# 'next' searches so we don't find the same text again.
	$data->{start}  = '1.0'       if $which eq 'first';
	$data->{start} .= '+ 1 chars' if $which eq 'next';

	# Build search options
	my @how = ('-count' => \$data->{count});
	push @how, '-backwards' if $which eq 'prev';
	push @how, '-regex'     if   $data->{regex};
	push @how, '-nocase'    if ! $data->{case};

	# Clear any results from the last search
	$data->{-textwidget}->tag('remove', 'highlight', '0.0', 'end');

	# Search for text
	# The eval{} is to catch exceptions caused by incomplete or invalid
	# regular expressions when the -regex option is used. Note that we can't
	# pre-check the regex because it's being evaluated by Tcl, not Perl, and
	# there are subtle syntax differences.
	my $i = eval { $data->{-textwidget}->search(@how, $data->{what}, $data->{start}) };

	if ($@) {
		# invalid regex (presumably)
		Tkx::eval("$self.e", 'configure', -foreground => 'red');
	}
	elsif ($i) {
		# text found / normal mode / no indication
		Tkx::eval("$self.e", 'configure', -foreground => 'black');

		# Highlight the match, scroll to it, and reset the start
		# position for finding the prev/next instance
		$data->{-textwidget}->tag('add', 'highlight', $i, "$i + $data->{count} chars");
		$data->{-textwidget}->see($i);
		$data->{start} = $i;
	}
	else {
		# text not found
		Tkx::eval("$self.e", 'configure', -foreground => '#808080');
	}
}


1;


__DATA__
#name:format:height:width:data
close16:png:16:16:iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAABmJLR0QA/wD/AP+gvaeTAAAACXBIWXMAAA3XAAAN1wFCKJt4AAAAB3RJTUUH1QwDARgOPQO6ugAAAZNJREFUOMudk71SGzEUhT/J9hriPEDGBTCTN2B4Axc0FHQ01KFPCbUzjtN7Jn3SU/IuTIoQ90S7lvfPq5Nis2vIuonV6M5I57v3niuZ2Xz6AfjKHsta+5HZfKp912w+Vb+hLZfL/8o+Ho8BaAEqinovSyhLqCoUAkgYa6HXg34f0+/DYNCCtgDva3FRQFliJIwECIwFa1BvUIuH0Q7AagVZBkXB8fk5AE/39wAcXV4C8OvhAUURGr0hhPAPYL0Gv8LmRUtvhO2dOIYowlqznUQTmDSF3zFyjp+LRce0p8UC4xzEMawzqqp6XQFpipK4biPPOwA9P6MowhweYkZv2xbaCvAekgQ5x8ntbQdwfHeHnCM4h9ae/G+SrQdZSogTzNq3oh/X14B4/+07AME5zGYDabpjCmmG/AolCY9XVyhN63ECjxcXmIMDzGgEIaAs2wHI8/otrGpI8L72QsI0vUtYa18BWg+Gp6eogUkgIYk6VHMAEsOzs24F7yYTmEw65jVuA2w2mzZ+aeLN5y+f9vrOwM0fpocVsnebVZ4AAAAASUVORK5CYII=
close16:gif89:16:16:R0lGODlhEAAQAOYAANnZ2YiKhYqMh////+Pj4/39/eLd3eHY2OHT0+HQ0ODOzuDNzeHPz+HS0uHW1uLa2uLf3+DHx+DCwuHBweHAwOHAv+HDwuDGx+HLzODGxuC+vuC4uOGvr+K3t+G9veDIx/v7+9+8vN+xsOGqquGpqeK/vuCzs9+houCbm+CVleGVleKamuGhoeK1tvj4+OCqqt6UlN+MjN+FheCEhOCKiuGTk+Osrfb29uCfn96Hh959fd97e9+EhOKiou/v79+Xltx5et1vb9xbW9xbWt1sbN53d+KZmd6OjttubtthYdpWVtlNTdlISNpISNpLS9tTU9xeXt1qauGRkd2Hh9pjY9lVVdhISNY9PdY2NtY1Ndc7O9hERNlSUttgYOCJieS5udljY9dHR9Y8PNU1NdU0NdY6OtlRUdtfX+e9vfz8/Pr6+v///////////////////////////////////////////////////////////////////////////////////yH5BAEAAAAALAAAAAAQABAAAAfSgAGCg4SFAgGAA4KDhIQBAQOABIKDhIIFAQEDBgYHCAkKCwwNDg8QBQEBAw0LERITFBUTFhcYDQUBAQMZGhsDAxwcAwMdHh8gAQEDISIjgAOCgyQcJSABAQMmJygpgwMqKywtLgEBAy8wMTKDAzM0NTY3AQEDODk6g4M7PD0+AQEDP0BBgkJDgkRFRj4BAQNHSElKS0xNTk9QUVI+AQEDU1RVVldYWVpbXF1ePgEBA19gVWFiY2RlW2ZnaD4BAQOAaYKDampqNzc3PoABgoOEhYKBADs=
go-down16:png:16:16:iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAABHNCSVQICAgIfAhkiAAAABl0RVh0U29mdHdhcmUAd3d3Lmlua3NjYXBlLm9yZ5vuPBoAAAI9SURBVDiNhZNNaBNBGIbfmezmD2vAYNJD/MGq9SIaj0m04MGL8SIULx4q4kEU6qFV8SoI0hU8qVCEnBQholJTW3Kx1lUItS0Ue6hVtFTNmq79C+kms7Ofh9Yamxjf4zffPPO+880wIkK14t1qHoQw6onB0HtEc3VJqWkihG9dSMN2BGxHYMkqYMkyAQB3H92oAdcCADDGkJt5jrJdQqE4g49zY2g/eLWuKV6vWB3Ko/jrbmwIABGIHBARFO5uCFASl1WdHMTW7btgOSS9kmxIsrFcNlG9Fu9S1w0yjjcKOUhFQi3Riyev+xSXCiLHK0mCmAS4RFEWoHo5uMJw/tQ1LwgQooJ0NlWaX5xLMSJColtNt0WPJ49Ek573+VeQXECijBV7EdPzORBoLRZH2/bTGJ0YKU9Ojfe97hHtfC1yx8uxjPHFmKJIcC+IVwCXjUJlGqqPwe3jUH0uRCNHYS6YNPlh3CDCmfVL1DVRBCH5cPCe5eVNCPiDKNFPlF2LcHs53D4Xtm3Zg5CvBdmhjEUOkromin9NQdfEREWsdD4YvFPaETgAm5WgelZP3rwpgP2hY+jLPi4JUenUNTFRd4y6JnpnjU8vhscGRGswAa4wKG6OQ+ETyL17W/lhfuvXNdHb8B2Qg46hkYHvprFAu5ti2OWPwfy6TLlRPe/I1dwNAbomiiSRzGSfWVuxD0GnFU/7n1iO/JO7Wmzjb/yteJd6LtK88zYAzOY/X9po/b8AADh8Rb0PAMM3xdl/9fwCc0oSKoZoHMsAAAAASUVORK5CYII=
go-down16:gif89:16:16:R0lGODlhEAAQAOYAANnZ2Tp0BDpzBMfesMPcq7/aprHSkaPKfsjfsY2+X4a6VXGuN06aBsffsXiyQYy9XYW5VHy0Rzt1BDt2BMXdrYm8WYK4UG+tNFaJJ8Lbqsber8Lcqoi9VoK6TWOqH1OiCKXOf6TNfqTMfp/HeEuCGDt0BHqlT7jWm42+XYrAWIfAUX68QlqrDFmrC1mqClipDJfHaGWaNJm/danRg4nCUofDTWm2Hl+0DV6zDYnFToS3VUB4DbHTkJjMZX3CO2K5D2W8D2W9EHvFMp/OcT94CleMJrfblHnDMWfAEWrFEnPJH6jbeFKJHnqqTKDWbWnEEm7LFKXgbHKoPzx2BI2/XY3RTJDVTpLFX0J6DqLRdKPTdUJ7DlaLJP///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////yH5BAEAAAAALAAAAAAQABAAAAe+gACCAAGAAoKDAYAAgoOCAgMEBQYHBwKEhAIICQoLDAcChIQCDQkKDgwHAoSEAgMPEBEMBwKEEgICAhMUFRYXDAcTAgICEgIYGRoUGxwdHh8gISIjJAIAJSYnKCkqKywtLi8wMSWCAgEyMzQ1Njc3ODk6EgKDAjs8PT4/QEFCQ0QChAACRUZHSEmASktMAoAAgoMAEk1OT1BRUlOEhAITVFVWV1MChIQAAlhZWlsChISDAlxcAoSEhABTU4SDgQA7
go-up16:png:16:16:iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAABHNCSVQICAgIfAhkiAAAABl0RVh0U29mdHdhcmUAd3d3Lmlua3NjYXBlLm9yZ5vuPBoAAAIeSURBVDiNlZNPaBNBFMa/N7sz2Y2FemhM/9GCBO3BQCqo0NWKaERiRS0UcmtKyUmQYhbBq8dSkaAXD0VPHqVC8eJNKl5EUNBDKbQqlZQ0iaaaJtnZGQ9RrCGp9h3f++bHfN+bIa012tXJm3weAJZmvel2GtZu4Lg83d8VSfZ1HUw6Lk/vCeC4PBoQ+7JXzkwGx0aTwYAIZh2XR/8L4Li8A4TFiXPT1paXx5a3ifjIJQuERcflHf8EEOHR6HCipzc0SJ9LH/Cx9B6dnZ0UGzrRDcLDXQGOy9P9ByKJs0fH+Ur+DQzGYTKOV2sLiA0dF6H9PYnmPNiOw1HB7Wwq4drr5WVo8iCEiTp9xzYV8S7/HBdOXw2apvgrD7bT99RYxlLkoSJLEAEBHuAoy3UI20BBrqKoVnH+1EWL2J882G/f8WPj3Yf6YpSvrMHkBjg3UFEFVI2vEDaDsBmWv71AuDdERw4Ph4k18qCRjJke6I5kb0zcsQUPQEHCh4fXuQW8LTyDZBUQIyQGMtBaQymgXq/h8dP5SrG0OWMSQ+pTbsWeuXe54Ymjevf6E6ssc/CNbXDBwEyCwQlzD25XZU1bv+wHiSFlLs16TtMmtNYKpfoXMINgcAYeaEBkTVsv5zza9R0AgNI+ftSLjSv7GrKuoFXrP2O2avpKolrbhjI1oBV8SfC9PQCkLxEfvAZiADECEfYAIGzcuj8ZbiUmwkZz7ycw98XbttCaIgAAAABJRU5ErkJggg==
go-up16:gif89:16:16:R0lGODlhEAAQAOYAANnZ2Tt1BDpzBFeJKFaJJkF5D6fKh6LHfkF5Djp0BJa9cprFcpXCaoazWzt0BHilTrDSkX20SHaxP2qcO1eKKLvXoIy9X4C2TXqzRFyiGprEcU+EHUB4DbfUnKDJeou+Woa8UXS0OFOjCGyvLJfDbj53CqHEgLXVl5bFaZHFYIvDVmawHVmsC1mrC4XBTYS0VX+pVsffsKDLd5rKbJbKY4HBQ16zDV+1DV+0DV+yD5vOamecNViLKMrgtdDlvM7luMvls5fNY2i6GWS8D2W+EK/cg67bgqzZgqbTe0yEGDx4BMvmsonJS2W9EGnDEWvHErLhhD56BcrlsHjDMWfAEWzIE3HPFbTlhcjkrW29H2a/EGrFEm3JE7PjhMXiqWW2FmO6D2a+EGfBEbDeg8HfparVgavXga3agq3Zgv///////////////////////////////////////////////////////////////////////////////////////////yH5BAEAAAAALAAAAAAQABAAAAfBgACCgwABAYSEhAACAwQChISDAgUGBwgChIQAAgkKCwwNCQKEhA4PEBESDBMJhIMCFBUWFxgZGhsChAACHB0eHyAhIiMkJQKDAgkmJygpKissLS4vAQKCDjAxMjM0NTY3ODk6OwEAAjw9Pj9AQUJDREVGR0hJAgECAgJKS0xNToBPUFECAgIBAAAAAAJSU1RVVlcCgACCg4ICWFlaW1xdAoSEAl5fYGFiYwKEhAJkZWZHZ2gChIQJgAKCgw4AAAAAgQA7

__END__
# Below is stub documentation for your module. You'd better edit it!

=pod

=head1 NAME

Tkx::FindBar - Perl Tkx extension for an incremental search toolbar.

=head1 SYNOPSIS

   use Tkx;
   use Tkx::FindBar;

   my $mw      = Tkx::widget->new('.');
   my $text    = $mw->new_text();
   my $findbar = $mw->new_tkx_FindBar(-textwidget => $text);

   $text->g_pack();
   $findbar->g_pack();
   $findbar->hide();  # remove until requested by user

   Tkx::bind($mw, '<Control-f>',  sub { $findbar->show()     } );
   Tkx::bind($mw, '<Escape>',     sub { $findbar->hide()     } );
   Tkx::bind($mw, '<F3>',         sub { $findbar->next()     } );
   Tkx::bind($mw, '<Control-F3>', sub { $findbar->previous() } );

   Tkx::MainLoop();

=head1 DESCRIPTION

Tkx::FindBar is a Tkx megawidget that provides a toolbar for searching 
in a text widget. The search is done incrementally (also known as "find 
as you type.") The toolbar may be hidden and shown on demand. It uses 
tiled (themed) widgets.

Tkx::FindBar was inspired by the great find toolbar in Mozilla Firefox.

=head1 WIDGET-SPECIFIC OPTIONS

=head2 C<-textwidget =E<gt> I<widget>>

Defines the text widget to search in.

=head2 C<-highlightcolor =E<gt> I<color>>

Defines the background color for highlighting found text.

=head1 METHODS

=head2 C<hide>

Hides the FindBar widget.

=head2 C<show>

Shows the FindBar widget.

=head2 C<first>

Finds the first instance of the search text.

=head2 C<next>

Finds the next instance of the search text. (Searches forwards.)

=head2 C<previous>

Finds the previous instance of the search text. (Searches backwards.)

=head1 BUGS

The C<show> and C<hide> methods only work with the L<pack> geometry
manager. The grid and place geometry managers are not supported.

=head1 AUTHOR

Michael Carman, E<lt>mjcarman@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2008 by Michael Carman

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.0 or,
at your option, any later version of Perl 5 you may have available.

The icons are Copyright (C) the L<Tango Desktop
Project|http://tango.freedesktop.org/Tango_Desktop_Project>. They are
used under the terms of the L<Creative Commons Attribution-Share Alike
License|http://creativecommons.org/licenses/by-sa/2.5/>. They're a heck
of a lot better than anything I could come up with, so I'm grateful for
being able to use them. Thanks, guys!

=cut
