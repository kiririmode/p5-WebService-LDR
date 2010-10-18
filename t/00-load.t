#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'WebService::LDR' ) || print "Bail out!
";
}

diag( "Testing WebService::LDR $WebService::LDR::VERSION, Perl $], $^X" );
