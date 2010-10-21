#!perl -T
use strict;
use warnings;
use Test::More tests => 5;
use Test::Exception;

BEGIN {
    use_ok( 'WebService::LDR' ) || print "Bail out!
";
}

print <<'INFO';
================================================================================
Tests require connectivity to LivedoorReader and its account (livedoor_id and 
password).  To input your account, set LDR_TEST_ID and LDR_TEST_PASS
environment variables.
ex.)
  $ export LDR_TEST_ID=your_livedoor_id
  $ export LDR_TEST_PASS=your_password"
================================================================================
INFO

SKIP: {
    skip "LDR_TEST_ID and/or LDR_TEST_PASS is not set", 4
        unless ($ENV{LDR_TEST_ID} and $ENV{LDR_TEST_PASS});

    my $ldr = WebService::LDR->new( 
        user => $ENV{LDR_TEST_ID}, 
        pass => $ENV{LDR_TEST_PASS},
    );
    isa_ok( $ldr, 'WebService::LDR' );
    can_ok( $ldr, qw/login apiKey/ );
    ok( ! defined $ldr->apiKey, 'apiKey when not logined' );
    
    lives_ok { $ldr->login } 'login success';
}
