#!perl -T
use strict;
use warnings;
use Test::More tests => 8;
use Test::Exception;
use Scalar::Util qw/looks_like_number/;

BEGIN {
    use_ok( 'WebService::LDR' ) || print "Bail out!
";
}

SKIP: {
    skip "LDR_TEST_ID and/or LDR_TEST_PASS is not set", 7
        unless ($ENV{LDR_TEST_ID} and $ENV{LDR_TEST_PASS});

    my $rss = 'http://d.hatena.ne.jp/kiririmode/rss';
    my $ldr = WebService::LDR->new( 
        user => $ENV{LDR_TEST_ID}, 
        pass => $ENV{LDR_TEST_PASS},
    );
    isa_ok( $ldr, 'WebService::LDR' );
    lives_ok { $ldr->login } 'login success';
    can_ok( $ldr, qw/folders/ );

    my $folders = $ldr->folders;
    isa_ok($folders, 'WebService::LDR::Response::Folders');
    can_ok($folders, qw/name2id names exists/);
    isa_ok($folders->name2id, 'HASH');
    isa_ok($folders->names,   'ARRAY');
}
