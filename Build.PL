
use strict;
use warnings;

use Module::Build 0.3601;


my %module_build_args = (
  "build_requires" => {
    "Module::Build" => "0.3601"
  },
  "configure_requires" => {
    "Module::Build" => "0.3601"
  },
  "dist_abstract" => "Riap::HTTP client",
  "dist_author" => [
    "Steven Haryanto <stevenharyanto\@gmail.com>"
  ],
  "dist_name" => "Perinci-Access-HTTP-Client",
  "dist_version" => "0.11",
  "license" => "perl",
  "module_name" => "Perinci::Access::HTTP::Client",
  "recommends" => {},
  "recursive_test_files" => 1,
  "requires" => {
    "JSON" => 0,
    "LWP::UserAgent" => 0,
    "Log::Any" => 0,
    "Perinci::Access::Base" => "0.19",
    "Riap" => "v1.1.11",
    "URI" => 0,
    "perl" => "5.010001"
  },
  "script_files" => [],
  "test_requires" => {
    "Capture::Tiny" => 0,
    "Test::More" => "0.88",
    "blib" => 0
  }
);


unless ( eval { Module::Build->VERSION(0.4004) } ) {
  my $tr = delete $module_build_args{test_requires};
  my $br = $module_build_args{build_requires};
  for my $mod ( keys %$tr ) {
    if ( exists $br->{$mod} ) {
      $br->{$mod} = $tr->{$mod} if $tr->{$mod} > $br->{$mod};
    }
    else {
      $br->{$mod} = $tr->{$mod};
    }
  }
}

my $build = Module::Build->new(%module_build_args);

$build->create_build_script;
