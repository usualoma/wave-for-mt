package Wave::XMLRPCServer;

use strict;
use warnings;

use Encode;
use MT::XMLRPCServer;

package MT::XMLRPCServer;

use MT::Util qw/ epoch2ts /;

no warnings 'redefine';

my $supportedMethodsOriginal = \&supportedMethods;
*supportedMethods = sub {
	my $list = $supportedMethodsOriginal->();
	push(@$list, 'mt.newWave', 'mt.editWave');
	$list;
};

sub _wave_decode {
	my $class = shift;
	my ($obj) = @_;

	if (! ref $obj) {
		return Encode::decode('utf8', $obj);
	}
	elsif (ref $obj eq 'HASH') {
		foreach my $k (%$obj) {
			$obj->{$k} = $class->_wave_decode($obj->{$k});
		}
	}
	elsif (ref $obj eq 'ARRAY') {
		for (my $i; $i < scalar(@$obj); $i++) {
			$obj->[$i] = $class->_wave_decode($obj->[$i]);
		}
	}

	$obj;
}

sub newWave {
	my $class = shift;
	my ($blog_id, $user, $pass, $content, $publish) = @_;

	my $mt = MT::XMLRPCServer::Util::mt_new();

	my($author, $perms) = $class->_login($user, $pass, $blog_id);
	die _fault(MT->translate("Invalid login")) unless $author;
	die _fault(MT->translate("Permission denied."))
		unless $perms && $perms->can_do('create_new_entry_via_xmlrpc_server');

	my $wave = $mt->model('wave')->new;
	$wave->set_values({
		'blog_id' => $blog_id,
		'author_id' => $author->id,
	});

	if ($content->{id}) {
		$wave->wave_id($content->{id});
		delete $content->{id};
	}
	if ($content->{blips}) {
		$wave->add_blips($class->_wave_decode($content->{blips}));
		delete $content->{blips};
	}
	foreach my $k (keys %$content) {
		$wave->$k($class->_wave_decode($content->{$k}));
	}

	$wave->save
		or return $class->error($wave->errstr);

	my $status = $class->_wave_publish($user, $pass, $wave, $publish);

	if ($status->value) {
		SOAP::Data->type(string => $wave->id);
	}
	else {
		$status;
	}
}

sub editWave {
	my $class = shift;
	my ($wave_id, $user, $pass, $content, $publish) = @_;

	my $mt = MT::XMLRPCServer::Util::mt_new();
	my $wave = $mt->model('wave')->load($wave_id)
		or return $class->error('Unkown wave');

	if ($content->{id}) {
		$wave->wave_id($content->{id});
		delete $content->{id};
	}
	if ($content->{blips}) {
		$wave->add_blips($class->_wave_decode($content->{blips}));
		delete $content->{blips};
	}
	foreach my $k (keys %$content) {
		$wave->$k($class->_wave_decode($content->{$k}));
	}

	$wave->save
		or return $class->error($wave->errstr);

	$class->_wave_publish($user, $pass, $wave, $publish);
}

sub _wave_publish {
	my $class = shift;
	my ($user, $pass, $wave, $publish) = @_;
	my $status = SOAP::Data->type(boolean => 1);

	if ($wave->publishing_unit eq 'wave') {
		my $entry_content = {
			'title' => $wave->title,
			'description' => $wave->description,
		};
		if (my $entry = $wave->entry) {
			$status = $class->_edit_entry(
				entry_id => $entry->id, user => $user, pass => $pass,
				item => $entry_content, publish => $publish
			);
		}
		else {
			if ($publish) {
				MT->add_callback('api_pre_save.entry', 1, undef, sub {
					my($cb, $app, $obj, $original) = @_;
					$obj->wave_id($wave->id);
				});
				$status = $class->_new_entry(
					blog_id => $wave->blog_id, user => $user, pass => $pass,
					item => $entry_content, publish => $publish
				);
			}
			else {
				$status = SOAP::Data->type(boolean => 1);
			}
		}
	}
	elsif ($wave->publishing_unit eq 'blip') {
#		foreach my $blip (values %{ $wave->blips }) {

        my $root_wl = $wave->root_wavelet;
        my $root_blip = $root_wl->root_blip;
		foreach my $blip ($root_blip, @{ $root_blip->child_blips }) {
			my $entry_content = {
				'title' => $blip->content,
				'description' => $blip->content,
			};
			if (my $entry = $blip->entry) {
				if ($entry->text ne $entry_content->{description}) {
					$status = $class->_edit_entry(
						entry_id => $entry->id, user => $user, pass => $pass,
						item => $entry_content, publish => $publish
					);
				}
			}
			else {
				if ($publish) {
					MT->request('wave_api_pre_save_blip', $blip);
					MT->request('wave_api_pre_save_wave', $wave);

					if (! MT->request('wave_api_pre_save')) {
						MT->add_callback('api_pre_save.entry', 1, undef, sub {
							my($cb, $app, $obj, $original) = @_;
							my $blip = MT->request('wave_api_pre_save_blip');
							my $wave = MT->request('wave_api_pre_save_wave');
							$obj->blip_id($blip->blipId);
							$obj->wave_id($wave->id);

                            my $blog = $obj->blog;
                            $obj->authored_on(&epoch2ts(
                                $blog, substr($blip->lastModifiedTime, 0, 10)
                            ));

                            my $authors = $blip->authors;
                            if (@$authors) {
                                $obj->author_id($authors->[0]->id);
                            }

                            1;
						});

						MT->request('wave_api_pre_save', 1);
					}

					$status = $class->_new_entry(
						blog_id => $wave->blog_id, user => $user, pass => $pass,
						item => $entry_content, publish => $publish
					);
				}
				else {
					$status = SOAP::Data->type(boolean => 1);
				}
			}

			last unless $status->value;
		}
	}

	return $status;
}

1;
