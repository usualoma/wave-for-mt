package Wave::App;

use strict;
use warnings;

use Wave::Wave;

sub cms_pre_save {
	my ($cb, $app, $obj, $orig_obj) = @_;
	if ($obj->is_wave) {
		foreach my $k ('title', 'text', 'text_more') {
			delete($obj->{changed_cols}->{$k});
		}
	}

	1;
}

sub param_edit_entry {
	my ($cb, $app, $param, $tmpl) = @_;
	my $plugin = MT->component('Wave');

	return 1 unless $param->{id};

	my $entry = MT->model('entry')->load($param->{id})
		or return 1;

	$entry->is_wave
		or return 1;

	my $wave = $entry->wave;
    my $text = $tmpl->getElementById('text');
	$text->innerHTML(<<__EOH__);
<div id="waveframe" style="height: 500px"></div>
<script src="http://wave-api.appspot.com/public/embed.js" type="text/javascript"></script>
<script type="text/javascript">
var wavePanel = new WavePanel('https://wave.google.com/wave/');
wavePanel.loadWave('@{[ $wave->wave_id ]}');
wavePanel.setUIConfig('white', 'black');
wavePanel.init(document.getElementById('waveframe'));
</script>
__EOH__

    my $title = $tmpl->getElementById('title');
	$title->innerHTML('');

	1;
}

sub param_edit_author {
	my ($cb, $app, $param, $tmpl) = @_;
	my $plugin = MT->component('Wave');

    $param->{'wave_users'} = [ map({
        my $values = $_->column_values;
        if ($_->author_id == $param->{'id'}) {
            $values->{'checked'} = 1;
        }
        $values->{'key'} = 'wave_user_' . $values->{'id'};
        $values;
    } MT->model('wave_user')->load) ];
}

sub source_edit_author {
	my ($cb, $app, $tmpl) = @_;
	my $plugin = MT->component('Wave');

    my $fieldset = <<__EOH__;
            <fieldset>
                <h3>@{[ $plugin->translate("Associate to Wave User") ]}</h3>
    <mtapp:setting
        id="wave_user_id"
        label="<__trans phrase="Wave Users">"
        content_class="field-content-text"
        show_label="0">
        <ul class="inline-list">
        <mt:loop name="wave_users">
            <li><input name="<mt:var name="key">" id="<mt:var name="key">" type="checkbox" value="1"<mt:if name="checked"> checked="checked"</mt:if><label for="<mt:var name="key">"><mt:var name="user_id"></label></li>
        </mt:loop>
        </ul>
    </mtapp:setting>
            </fieldset>
__EOH__

    $$tmpl =~ s/(<mt:setvarblock name="action_buttons">)/$fieldset$1/;
}

sub post_save_author {
	my ($cb, $obj, $original) = @_;
	my $app = MT->instance;

    foreach my $user (MT->model('wave_user')->load) {
        if ($app->param('wave_user_' . $user->id)) {
            $user->author_id($obj->id);
            $user->save;
        }
    }
}

1;
