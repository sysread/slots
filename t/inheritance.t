package P1;
use Types::Standard -types;
use slot x => Int, rw => 1;
use slot y => Int, rw => 1;
1;

package P2;
use Types::Standard -types;
use parent -norequire, 'P1';
use slot z => Int, rw => 1;
1;

package P3;
use Types::Standard -types;
use parent -norequire, 'P1';
use slot x => StrMatch[qr/[13579]$/], rw => 0, req => 1;
use slot y => StrMatch[qr/[13579]$/], rw => 1;
use slot z => StrMatch[qr/[13579]$/], rw => 1;
1;


package main;

use Test2::V0;
use Test2;

ok my $p2 = P2->new(x => 10, y => 20, z => 30), 'ctor';
is $p2->x, 10, 'get slot: x';
is $p2->y, 20, 'get slot: y';
is $p2->z, 30, 'get slot: z';
ok $p2->isa('P2'), 'isa P2';
ok $p2->isa('P1'), 'isa P1';
ok dies{ P2->new(x => 10, y => 20, z => 'foo') }, 'ctor: dies on invalid slot type';
ok dies{ P2->new(x => 'foo', y => 20, z => 30) }, 'ctor: dies on invalid parent slot type';

ok(dies{ P3->new(x => 10, y => 20, z => 30) }, 'ctor: dies on stricter child type');

ok(P3->new(x => 'a7', y => '39', z => '0x35'), 'ctor: ok on less strict child type');
ok(dies{ P3->new(y => '39', z => '0x35') }, 'ctor: dies on stricter child req');
ok(dies{ P3->new(x => 'a7', y => '39', z => '0x35')->x(45) }, 'setter: dies on stricter child rw');

done_testing;
