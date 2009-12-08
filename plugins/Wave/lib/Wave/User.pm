package Wave::User;

use strict;
use warnings;

use JSON;

use Wave::User;
use MT::Object;
use base qw( MT::Object );

__PACKAGE__->install_properties({
	column_defs => {
		'id' => 'integer not null auto_increment',
		'user_id' => {
			type        => 'string',
			size        => 255,
			label       => 'User ID',
		},
		'author_id' => {
			type        => 'integer',
			not_null    => 0,
			label       => 'Author ID',
#			revisioned  => 1
		},
	},
	indexes => {
		user_id => 1,
		author_id => 1,
	},
	primary_key => 'id',
	datasource => 'wave_user',
	audit => 1,
});

1;
