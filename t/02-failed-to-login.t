#!perl -T
use strict;
use warnings;
use Test::More tests => 7;
use Test::Exception;

BEGIN {
    use_ok( 'WebService::LDR' ) || print "Bail out!
";
}

throws_ok { WebService::LDR->new( pass => 'b' ) } qr/missing/, "username is missing";
throws_ok { WebService::LDR->new( user => 'a' ) } qr/missing/, "password is missing";

my $ldr = WebService::LDR->new( 
    user => 'a',
    pass => 'b'
);
isa_ok( $ldr, 'WebService::LDR' );
ok( ! defined $ldr->apiKey, 'undefined apiKey when not logined' );

throws_ok { $ldr->login } qr/Failed to login LivedoorReader/, "failed to login with invalid account info";
ok( ! defined $ldr->apiKey, 'undefined sid when failed to logined' );
