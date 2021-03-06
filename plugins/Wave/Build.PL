use strict;
use warnings;
use Module::Build;
use File::Spec;
use File::Basename;
use YAML qw/ Load /;

my $class = Module::Build->subclass(
	class => 'MTToiplanPluginDirectoryBuilder',
	code => q{
		# Don't make blib
		# sub ACTION_code {};
		# Don't make blib
		sub ACTION_docs {};
		# Don't make META.yml
		sub ACTION_distmeta {
			# no warning on ACTION_distdir
			$_[0]->{metafile} = 'MANIFEST';
		};
		# Don't add MEATA.yml to MANIFEST
		sub ACTION_manifest {
			$_[0]->{metafile} = 'MANIFEST',
			$_[0]->SUPER::ACTION_manifest(@_);
		};
		sub ACTION_test {
			my $p = $_[0]->{properties};
			unshift(
				@INC,
				File::Spec->catdir($p->{base_dir}, 'extlib'),
				File::Spec->catdir($p->{base_dir}, '../../lib'),
				File::Spec->catdir($p->{base_dir}, '../../extlib'),
			);

			$_[0]->SUPER::ACTION_test(@_);
		};
		sub ACTION_upload_google {
			my ($self) = @_;
			my $prj = 'toiplan-mtplugin-directory';
			my $ver = $self->dist_version;
			my $dist_dir = $self->dist_dir;
			my $name = $self->dist_name;

			$self->depends_on('dist');
			#$self->_call_action('distdir');
			$self->ACTION_distdir;
			$self->depends_on('zipdist');
			system(
				"googlecode_upload.py -s 'Release $ver (TGZ)' -p $prj -l $name $dist_dir.tar.gz"
			);
			system(
				"googlecode_upload.py -s 'Release $ver (ZIP)' -p $prj -l $name $dist_dir.zip"
			);
			unlink("$dist_dir.tar.gz");
			unlink("$dist_dir.zip");
		};

		sub ACTION_zipdist {
			my ($self) = @_;
			my $dist_dir = $self->dist_dir;
			$self->depends_on('distdir');
			print "Creating $dist_dir.zip\n";
			system("zip -r $dist_dir.zip $dist_dir") == 0 or die $?;
			$self->delete_filetree($dist_dir);
		}

		sub ACTION_distdir {
			my ($self) = @_;

			$_[0]->SUPER::ACTION_distdir(@_);

			my $dist_dir = $self->dist_dir;
			rename($dist_dir, $self->{properties}{dist_name});
			use File::Path;
			use File::Spec;
			use File::Basename;
			my $plugins = File::Spec->catfile($dist_dir, 'plugins');
			mkpath($plugins, 1, 0755);

			my $new_dist_dir = File::Spec->catfile(
				$plugins, $self->{properties}{dist_name}
			);
			rename($self->{properties}{dist_name}, $new_dist_dir);

			foreach my $f (glob(File::Spec->catfile($new_dist_dir, 'LIC*'))) {
				rename($f, File::Spec->catfile($dist_dir, basename($f)));
			}

			if (my @statics = glob(File::Spec->catfile($new_dist_dir, 'static/*'))) {
				my $static = File::Spec->catfile(
					$dist_dir, 'mt-static/plugins'
				);
				mkpath($static, 1, 0755);

				my $d = File::Spec->catfile(
					$static, $self->{properties}{dist_name}
				);
				mkpath($d, 1, 0755);

				foreach my $f (@statics) {
					rename($f, File::Spec->catfile($d, basename($f)));
				}

				rmdir(File::Spec->catfile($new_dist_dir, 'static'));
			}

			if (my @cgis = glob(File::Spec->catfile($new_dist_dir, 'cgi/*'))) {
				foreach my $f (@cgis) {
					rename($f, File::Spec->catfile($dist_dir, basename($f)));
				}
				rmdir(File::Spec->catfile($new_dist_dir, 'cgi'));
			}

			if (my @themes = glob(File::Spec->catfile($new_dist_dir, 'theme/*'))) {
				my $theme = File::Spec->catfile(
					$dist_dir, 'theme'
				);
				mkpath($theme, 1, 0755);

#				my $d = File::Spec->catfile(
#					$theme, $self->{properties}{dist_name}
#				);
#				mkpath($d, 1, 0755);
				my $d = $theme;

				foreach my $f (@themes) {
					rename($f, File::Spec->catfile($d, basename($f)));
				}

				rmdir(File::Spec->catfile($new_dist_dir, 'theme'));
			}
		}
	}
);

my $yaml_string = do {
	open(my $fh, File::Spec->catfile(dirname(__FILE__), 'config.yaml'));
	local $/;
	<$fh>
};
$yaml_string =~ s/^(\s*)\*/$1App::\*/gm;
my $yaml = Load($yaml_string);

$yaml->{name} = 'Wave';

my $builder = $class->new(
	dist_name           => $yaml->{name},
    dist_author         => 'Movable Type ACME Plugin Project',
    dist_version        => $yaml->{version},
    module_name         => $yaml->{name} . '::App',
    license             => 'MIT License',
    add_to_cleanup      => [ $yaml->{name} . '-*' ],
);

$builder->create_build_script();
