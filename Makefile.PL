use inc::Module::Install;

name     'WebService-LDR';
all_from 'lib/WebService/LDR.pm';
author   q{kiririmode <kiririmode@gmail.com>};
license  'perl';

requires 'WWW::Mechanize' => 0;
requires 'JSON' => 0;
requires 'Scalar::Util' => 0;
requires 'Try::Tiny' => 0;
requires 'Class::Accessor::Fast' => 0;
requires 'DateTime' => 0;
requires 'Crypt::SSLeay' => 0;

test_requires 'Test::Exception' => 0;

build_requires 'Test::More';

auto_install;

WriteAll;

