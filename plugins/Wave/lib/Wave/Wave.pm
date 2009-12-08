package MT::Entry;

use strict;
use warnings;

sub wave {
	my $self = shift;

	return undef unless $self->id;
	return MT->model('wave')->load($self->wave_id);
}

sub is_wave {
	my $self = shift;

	return $self->wave_id && ! $self->blip_id;
}

package Wave::Blip;

use JSON;

use MT::Author;
use MT::Object;
use base qw( MT::Object );

__PACKAGE__->install_properties({
	column_defs => {
		'id' => 'integer not null auto_increment',
	},
	primary_key => 'id',
	datasource => 'blilp',
});

sub AUTOLOAD {
	my $self = shift;
	my $method = our $AUTOLOAD;
	$method =~ s/.*:://o;

	$self->{$method};
}

sub child_blips {
	my $self = shift;
	my $blips = $self->{wave}->blips;
	my @children;
	foreach my $id (@{ $self->{childBlipIds} }) {
		push(@children, $blips->{$id}) if $blips->{$id};
	}
	\@children;
}

sub authors {
	my $self = shift;

	[ MT->model('author')->load(undef, {
        'join' => MT->model('wave_user')->join_on('author_id', {
            user_id => $self->contributors
        })
    }) ]
}

sub entry {
	my $self = shift;
	MT->model('entry')->load({
        'wave_id' => $self->waveId,
        'blip_id' => $self->blipId,
    });
}

package Wave::Wavelet;

use JSON;

use MT::Object;
use base qw( MT::Object );

__PACKAGE__->install_properties({
	column_defs => {
		'id' => 'integer not null auto_increment',
	},
	primary_key => 'id',
	datasource => 'wavelet',
});

sub wave {
	my $self = shift;
	$self->{wave} = shift if @_;
	$self->{wave};
}

sub root_blip {
	my $self = shift;
	my $wave = $self->{wave};
	my $blips = $wave->blips;
	$blips->{$self->{rootBlipId}};
}

package Wave::Wave;

use strict;
use warnings;

use JSON;

use MT::Author;
use MT::Object;
use base qw( MT::Object );

__PACKAGE__->install_properties({
	column_defs => {
		'id' => 'integer not null auto_increment',
		'blog_id' => 'integer not null',
		'wave_id' => {
			type        => 'text',
			not_null    => 1,
			label       => 'ID',
		},
		'author_id' => {
			type        => 'integer',
			not_null    => 1,
			label       => 'Author',
#			revisioned  => 1
		},
		'publishing_unit' => {
			type        => 'text',
			label       => 'PublishingUnit',
#			revisioned  => 1
		},
		'participants' => {
			type        => 'text',
			label       => 'Participants',
#			revisioned  => 1
		},
		'title' => {
			type        => 'string',
			size        => 255,
			label       => 'Title',
#			revisioned  => 1
		},
		'root_wavelet' => {
			type        => 'text',
			label       => 'Root Wavelet',
#			revisioned  => 1
		},
		'blips' => {
			type        => 'text',
			label       => 'Blips',
#			revisioned  => 1
		},
	},
	indexes => {
		author_id => 1,
		entry_id => 1,
		created_on => 1,
		modified_on => 1,
#		blog_id => 1,
#		title => 1,
	},
	child_of => 'MT::Blog',

	primary_key => 'id',
	datasource => 'wave',
	audit => 1,
});

sub participants {
	my $self = shift;
	$_[0] = JSON::to_json($_[0]) if $_[0] && ref $_[0];
	$self->SUPER::participants(@_);
}

sub root_wavelet {
	my $self = shift;
	if (@_) {
		$_[0] = JSON::to_json($_[0]) if ref $_[0];
		return $self->SUPER::root_wavelet(@_);
	}

	if (! $self->{root_wavelet}) {
		my $root_wavelet = Wave::Wavelet->new;
		$root_wavelet->wave($self);

		my $hash = $self->SUPER::root_wavelet || {};
        if (! ref $hash) {
		    $hash = JSON::from_json($hash);
        }
		foreach my $k (%$hash) {
			$root_wavelet->{$k} = $hash->{$k};
		}

		$self->{root_wavelet} = $root_wavelet;
	}
	return $self->{root_wavelet};
}

sub blips {
	my $self = shift;
	if (@_) {
		$_[0] = JSON::to_json($_[0]) if ref $_[0];
		return $self->SUPER::blips(@_);
	}

	if (! $self->{blips}) {
		my $data = $self->SUPER::blips || {};
        if (! ref $data) {
		    $data = JSON::from_json($data);
        }
		foreach my $k (%$data) {
			my $d = $data->{$k};
			my $blip = Wave::Blip->new;
			$blip->{wave} = $self;
			foreach my $k (%$d) {
				$blip->{$k} = $d->{$k};
			}
			$data->{$k} = $blip;
		}
		$self->{blips} = $data;
	}

	return $self->{blips};
}

sub description {
	my $self = shift;
	my $blips = $self->SUPER::blips;
	if (ref $blips) {
		JSON::to_json($blips);
	}
	else {
		$blips;
	}
}

sub entry {
	my $self = shift;
	MT->model('entry')->load({ 'wave_id' => $self->id });
}

sub entries {
	my $self = shift;
	$self->entry(@_);
}

sub authors {
	my $self = shift;
    my $ids = $self->SUPER::participants;
    if (! ref($ids)) {
		$ids = JSON::from_json($ids);
    }

	[ MT->model('author')->load(undef, {
        'join' => MT->model('wave_user')->join_on('author_id', {
            user_id => $ids
        })
    }) ]
}

sub add_blips {
	my $self = shift;
	my ($blips) = @_;

	my $current = $self->SUPER::blips || {};
	if (! ref $current) {
		$current = JSON::from_json($current);
	}

	foreach my $k (keys %$blips) {
		$current->{$k} = $blips->{$k};
	}

	$self->blips($current);
}

__PACKAGE__->add_trigger('post_save', sub{
	my($obj, $original) = @_;

	my $participants = $obj->SUPER::participants || [];
	if (! ref $participants) {
		$participants = JSON::from_json($participants);
	}

    foreach my $p (@$participants) {
        my $tmp = MT->model('wave_user')->get_by_key({
            'user_id' => $p,
        });
        $tmp->save unless $tmp->id;
    }
    
	1;
});

1;
