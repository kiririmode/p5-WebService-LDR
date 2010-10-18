use inc::Module::Install;

name     'WebService-LDR';
all_from 'lib/WebService/LDR.pm';
author   q{kiririmode <kiririmode@gmail.com>};
license  'perl';

build_requires 'Test::More';

auto_install;

WriteAll;

