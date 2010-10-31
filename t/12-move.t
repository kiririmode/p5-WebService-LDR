#!perl -T
use strict;
use warnings;
use Test::More tests => 7;
use Test::Exception;
use Scalar::Util qw/looks_like_number/;

BEGIN {
    use_ok( 'WebService::LDR' ) || print "Bail out!
";
}

SKIP: {
    skip "LDR_TEST_ID and/or LDR_TEST_PASS is not set", 6
        unless ($ENV{LDR_TEST_ID} and $ENV{LDR_TEST_PASS});

    my $rss = 'http://d.hatena.ne.jp/kiririmode/rss';
    my $ldr = WebService::LDR->new( 
        user => $ENV{LDR_TEST_ID}, 
        pass => $ENV{LDR_TEST_PASS},
    );
    isa_ok( $ldr, 'WebService::LDR' );
    lives_ok { $ldr->login } 'login success';
    can_ok( $ldr, qw/move_folder/ );

    my $folders = $ldr->folders;

    my $i = 0;
    1 while ( $folders->exists("test" . $i++) );
    my $result = $ldr->make_folder("test$i");

    $ldr->subscribe($rss);
    my @discoveries = $ldr->auto_discovery($rss);

    my $res = $ldr->move_folder($discoveries[0], "test$i");
    isa_ok($res, 'WebService::LDR::Response::Result');

    my @feeds = $ldr->get_feed_all($discoveries[0]);
       @feeds = grep { $_->subscribe_id == $discoveries[0]->subscribe_id } @feeds;

    cmp_ok(scalar(@feeds), '==', 1, 'moved directory is 1');
    my $feed = shift @feeds;
    cmp_ok($feed->folder, 'eq', "test$i", 'directory name moved to');

    $ldr->delete_folder("test$i");
}
