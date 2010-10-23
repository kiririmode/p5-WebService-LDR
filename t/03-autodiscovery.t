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

    my $ldr = WebService::LDR->new( 
        user => $ENV{LDR_TEST_ID}, 
        pass => $ENV{LDR_TEST_PASS},
    );
    isa_ok( $ldr, 'WebService::LDR' );
    lives_ok { $ldr->login } 'login success';

    success_case($ldr);
    error_case($ldr);
}

sub success_case {
    my $ldr = shift;

    my @links = $ldr->auto_discovery( 'http://d.hatena.ne.jp/kiririmode' );
    ok( $ldr->apiKey, 'retrieves apiKey' );
    ok( @links > 0, 'auto discovery success' );
    isa_ok( $links[0], 'WebService::LDR::Response::Discovery' );

    my $link = $links[0];
    isa_ok( $link->link, 'URI' );
    isa_ok( $link->feedlink, 'URI' );
    ok( $link->title, 'title is not null' );
    ok( looks_like_number( $link->subscribers_count ), 'subscribers_count is number' );
}

sub error_case {
    my $ldr = shift;
    
    my @links = $ldr->auto_discovery( 'http://nothing' );
    ok( @links == 0, 'zero element in error case' );
}
