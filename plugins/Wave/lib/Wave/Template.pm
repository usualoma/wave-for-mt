package Wave::Template;

use strict;
use warnings;

use Wave::Wave;
use MT::Util qw/ epoch2ts /;

sub _hdlr_if_entry_is_wave {
	my ($ctx, $args, $cond) = @_;

	my $entry = $ctx->stash('entry')
		or return $ctx->_no_entry_error();

	$entry->is_wave;
}

sub _hdlr_wave_root_wavelet {
	my ($ctx, $args, $cond) = @_;
	my $plugin = MT->component('Wave');

	my $entry = $ctx->stash('entry')
		or return $ctx->_no_entry_error();

	$entry->is_wave
		or return $ctx->error($plugin->translate('This entry is not Wave'));

	my $wavelet = $entry->wave->root_wavelet;
	$ctx->stash('wavelet', $wavelet);

	$ctx->slurp($args, $cond);
}

sub _hdlr_wavelet_root_blip {
	my ($ctx, $args, $cond) = @_;
	my $plugin = MT->component('Wave');

	my $wavelet = $ctx->stash('wavelet')
		or return $ctx->error($plugin->translate('No wavelet found.'));

	my $blip = $wavelet->root_blip
		or return $ctx->error($plugin->translate('No blip found.'));
	$ctx->stash('blip', $blip);

	$ctx->slurp($args, $cond);
}

sub _hdlr_wave_authors {
	my ($ctx, $args, $cond) = @_;
	my $plugin = MT->component('Wave');
    my $builder = $ctx->stash('builder');
    my $tokens = $ctx->stash('tokens');

	my $entry = $ctx->stash('entry')
		or return $ctx->_no_entry_error();

	$entry->is_wave
		or return $ctx->error($plugin->translate('This entry is not Wave'));

	my $authors = $entry->wave->authors;


	my $res = '';
	my $vars = $ctx->{__stash}{vars} ||= {};
	my $count = 0;
	for my $author (@$authors) {
		$count++;
		local $ctx->{__stash}{author} = $author;
		local $ctx->{__stash}{author_id} = $author->id;
		local $vars->{__first__} = $count == 1;
		local $vars->{__last__} = !defined $authors->[$count];
		local $vars->{__odd__} = ($count % 2) == 1;
		local $vars->{__even__} = ($count % 2) == 0;
		local $vars->{__counter__} = $count;
		defined(my $out = $builder->build($ctx, $tokens, $cond))
			or return $ctx->error( $builder->errstr );
		$res .= $out;
	}
	$res;
}

sub _hdlr_blip_child_blips {
	my ($ctx, $args, $cond) = @_;
    my $builder = $ctx->stash('builder');
    my $tokens = $ctx->stash('tokens');
	$ctx->stash('blip_child_blips_tokens', $tokens);

	my $plugin = MT->component('Wave');

	my $blip = $ctx->stash('blip')
		or return $ctx->error($plugin->translate('No blip found.'));

	my $blips = $blip->child_blips;


	my $res = '';
	my $vars = $ctx->{__stash}{vars} ||= {};
	my $count = 0;
	for my $blip (@$blips) {
		$count++;
		local $ctx->{__stash}{blip} = $blip;
		local $vars->{__first__} = $count == 1;
		local $vars->{__last__} = !defined $blips->[$count];
		local $vars->{__odd__} = ($count % 2) == 1;
		local $vars->{__even__} = ($count % 2) == 0;
		local $vars->{__counter__} = $count;
		defined(my $out = $builder->build($ctx, $tokens, {
			%$cond,
			BlipChildBlipsHeader => $count == 1,
			BlipChildBlipsFooter => !defined $blips->[$count],
		})) or return $ctx->error( $builder->errstr );
		$res .= $out;
	}
	$res;
}

sub _hdlr_blip_authors {
	my ($ctx, $args, $cond) = @_;
    my $builder = $ctx->stash('builder');
    my $tokens = $ctx->stash('tokens');
	my $plugin = MT->component('Wave');

	my $blip = $ctx->stash('blip')
		or return $ctx->error($plugin->translate('No blip found.'));

	my $authors = $blip->authors;


	my $res = '';
	my $vars = $ctx->{__stash}{vars} ||= {};
	my $count = 0;
	for my $author (@$authors) {
		$count++;
		local $ctx->{__stash}{author} = $author;
		local $ctx->{__stash}{author_id} = $author->id;
		local $vars->{__first__} = $count == 1;
		local $vars->{__last__} = !defined $authors->[$count];
		local $vars->{__odd__} = ($count % 2) == 1;
		local $vars->{__even__} = ($count % 2) == 0;
		local $vars->{__counter__} = $count;
		defined(my $out = $builder->build($ctx, $tokens, $cond))
			or return $ctx->error( $builder->errstr );
		$res .= $out;
	}
	$res;
}


sub _hdlr_blip_content {
	my ($ctx, $args) = @_;
	my $plugin = MT->component('Wave');

	my $blip = $ctx->stash('blip')
		or return $ctx->error($plugin->translate('No blip found.'));

	$blip->content;
}

sub _hdlr_blip_modified_date {
	my ($ctx, $args) = @_;
	my $plugin = MT->component('Wave');

	my $blog = $ctx->stash('blog');
	my $blip = $ctx->stash('blip')
		or return $ctx->error($plugin->translate('No blip found.'));

    $args->{ts} = &epoch2ts($blog, substr($blip->lastModifiedTime, 0, 10));
    return $ctx->build_date($args);
}

sub _hdlr_blip_child_blips_recurse {
	my ($ctx, $args, $cond) = @_;
	my $plugin = MT->component('Wave');
    my $builder = $ctx->stash('builder');
	my $tokens = $ctx->stash('blip_child_blips_tokens')
		or return '';

	my $blip = $ctx->stash('blip')
		or return $ctx->error($plugin->translate('No blip found.'));

    my $depth = $ctx->stash('blip_child_blips_depth') || 0;

	my $res = '';
	my $vars = $ctx->{__stash}{vars} ||= {};
	my $count = 0;
	my $children = $blip->child_blips;
	foreach my $child (@$children) {
        local $ctx->{__stash}{'blip'} = $child;

        local $ctx->{__stash}{'blip_child_blips_depth'} = $depth + 1;
		local $vars->{__depth__} = $depth + 1;

		local $vars->{__first__} = $count == 1;
		local $vars->{__last__} = !defined $children->[$count];
		local $vars->{__odd__} = ($count % 2) == 1;
		local $vars->{__even__} = ($count % 2) == 0;
		local $vars->{__counter__} = $count;
		defined(my $out = $builder->build($ctx, $tokens, $cond))
			or return $ctx->error( $builder->errstr );
		$res .= $out;
	}
	$res;
}

1;
