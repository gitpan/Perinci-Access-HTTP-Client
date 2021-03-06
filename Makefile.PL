
# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v5.019.
use strict;
use warnings;

use 5.010001;

use ExtUtils::MakeMaker 6.30;



my %WriteMakefileArgs = (
  "ABSTRACT" => "Riap::HTTP client",
  "AUTHOR" => "perlancar <perlancar\@cpan.org>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => "6.30"
  },
  "DISTNAME" => "Perinci-Access-HTTP-Client",
  "EXE_FILES" => [],
  "LICENSE" => "perl",
  "NAME" => "Perinci::Access::HTTP::Client",
  "PREREQ_PM" => {
    "JSON" => 0,
    "LWP::Protocol::http::SocketUnixAlt" => 0,
    "LWP::UserAgent" => 0,
    "Log::Any" => 0,
    "Perinci::Access::Base" => "0.32",
    "Perinci::AccessUtil" => "0.04",
    "Riap" => "v1.2.0",
    "URI" => 0,
    "URI::Split" => 0,
    "experimental" => 0
  },
  "TEST_REQUIRES" => {
    "File::Spec" => 0,
    "IO::Handle" => 0,
    "IPC::Open3" => 0,
    "Test::More" => 0
  },
  "VERSION" => "0.21",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "File::Spec" => 0,
  "IO::Handle" => 0,
  "IPC::Open3" => 0,
  "JSON" => 0,
  "LWP::Protocol::http::SocketUnixAlt" => 0,
  "LWP::UserAgent" => 0,
  "Log::Any" => 0,
  "Perinci::Access::Base" => "0.32",
  "Perinci::AccessUtil" => "0.04",
  "Riap" => "v1.2.0",
  "Test::More" => 0,
  "URI" => 0,
  "URI::Split" => 0,
  "experimental" => 0
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.63_03) } ) {
  delete $WriteMakefileArgs{TEST_REQUIRES};
  delete $WriteMakefileArgs{BUILD_REQUIRES};
  $WriteMakefileArgs{PREREQ_PM} = \%FallbackPrereqs;
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);



