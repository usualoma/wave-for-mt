#!/usr/bin/perl

use strict;
use warnings;
use utf8;

use Data::Dumper;
use RPC::XML::Client;

my ($req, $res);

my $client = RPC::XML::Client->new(
#	'http://miya.bakersterrace.net/~taku/mt50/mt-wave.cgi'
	'http://localhost/~taku/mt50/mt-wave.cgi'
);


$req = RPC::XML::request->new(
	'mt.newWave',
	RPC::XML::string->new('85'),
	RPC::XML::string->new('taku'),
	RPC::XML::string->new('taku'),
	RPC::XML::struct->new(
		'id' => RPC::XML::string->new('12345'),
		'publishing_unit' => RPC::XML::string->new('wave'),
		'participants' => RPC::XML::array->new(
            RPC::XML::string->new('aabbccc'),
            RPC::XML::string->new('dddeeef'),
        ),
	),
	RPC::XML::boolean->new('true'),
);

$res = $client->send_request($req);
die "Error: $res" unless ref $res;
my $wave_id = $res->value;

$req = RPC::XML::request->new(
	'mt.editWave',
	RPC::XML::string->new($wave_id),
	RPC::XML::string->new('taku'),
	RPC::XML::string->new('taku'),
	RPC::XML::struct->new(
		'participants' => RPC::XML::array->new(
            RPC::XML::string->new('aabbccc'),
            RPC::XML::string->new('dddeeef'),
        ),
		'title' => RPC::XML::string->new('TitleTitle'),
		'blips' => RPC::XML::string->new('{}'),
		'publishing_unit' => RPC::XML::string->new('wave'),
	),
	RPC::XML::boolean->new('true'),
);
$res = $client->send_request($req);
die "Error: $res" unless ref $res;
die Dumper($res);
