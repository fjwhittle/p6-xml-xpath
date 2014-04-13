#!/usr/bin/env perl6

use XML::XPath;
use Test;

plan 6;

my $xp = XML::XPath.new;

my @r = $xp.evaluate(q{ 1 + 1, 4 - 2, 4 div 2, 5 idiv 2, 6 mod 4, 2 * 1 });

is @r[0], 2, 'Addition';

is @r[1], 2, 'Subtraction';

is @r[2], 2, 'Division';

is @r[3], 2, 'Integer Division';

is @r[4], 2, 'Modulus';

is @r[5], 2, 'Multiplication';
