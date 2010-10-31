#!perl -T
use strict;
use warnings;
use Test::More tests => 11;
use Test::Exception;
use Scalar::Util qw/looks_like_number/;

BEGIN {
    use_ok( 'WebService::LDR' ) || print "Bail out!
";
}

SKIP: {
    skip "LDR_TEST_ID and/or LDR_TEST_PASS is not set", 10
        unless ($ENV{LDR_TEST_ID} and $ENV{LDR_TEST_PASS});

    my $rss = 'http://d.hatena.ne.jp/kiririmode/rss';
    my $ldr = WebService::LDR->new( 
        user => $ENV{LDR_TEST_ID}, 
        pass => $ENV{LDR_TEST_PASS},
    );
    isa_ok( $ldr, 'WebService::LDR' );
    lives_ok { $ldr->login } 'login success';
    can_ok( $ldr, qw/folders make_folder delete_folder/ );

    my $folders = $ldr->folders;

    my $i = 0;
    1 while ( $folders->exists("test" . $i++) );

    my $result = $ldr->make_folder("test$i");
    isa_ok( $result, 'WebService::LDR::Response::Result' );
    $folders = $ldr->folders;
    can_ok($folders, qw/name2id names exists/);
    isa_ok($folders->name2id, 'HASH');
    isa_ok($folders->names,   'ARRAY');
    ok( $folders->exists("test$i"), 'create test directory' );
    sleep 3;

    my $res = $ldr->delete_folder("test$i");
    isa_ok( $res, 'WebService::LDR::Response::Result' );
    $folders = $ldr->folders;
    ok( ! $folders->exists("test$i"), 'delete test directory' );
}
