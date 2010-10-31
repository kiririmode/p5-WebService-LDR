#!perl -T
use strict;
use warnings;
use Test::More tests => 4;
use Test::Exception;
use Scalar::Util qw/looks_like_number/;

BEGIN {
    use_ok( 'WebService::LDR' ) || print "Bail out!
";
}

my $ldr = WebService::LDR->new( 
    user => 'a',
    pass => 'b',
);
isa_ok( $ldr, 'WebService::LDR' );
can_ok( $ldr, qw/unread_cnt/ );
ok( looks_like_number($ldr->unread_cnt()), 'unread count is a number');
