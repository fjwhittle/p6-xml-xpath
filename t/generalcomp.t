#!/usr/bin/env perl6

use XML::XPath;
use Test;

plan 7;

my $xp = XML::XPath.new;

# General Comparisons

my @r = $xp.evaluate('(1, 2) < 2, (1, 2) < (1, 2), (1, 2) < 1');

is @r, (True, True, False), 'General comparison <';

@r = $xp.evaluate('(1, 2) <= (1, 2), (1, 2) <= (2, 3), (3, 4) <= (1, 2)');

is @r, (True, True, False), 'General comparison <=';

@r = $xp.evaluate('(1, 2) = (2, 3), (1, 2) = (1, 2), (1, 2) = (3, 4)');

is @r, (True, True, False), 'General comparison =';

@r = $xp.evaluate('(1, 2) != (3, 4), (1, 2) != (2, 3), (1, 2) != (1, 2)');

is @r, (True, True, False), 'General comparison !=';

@r = $xp.evaluate('(1, 2) >= (2, 3), (1, 2) >= (1, 2), (1, 2) >= (3, 4)');

is @r, (True, True, False), 'General comparison >=';

@r = $xp.evaluate('(1, 2) > (2, 3), (1, 2) > (1, 2), (1, 3) > (3, 4)');

is @r, (False, True, False), 'General comparison >';

@r = $xp.evaluate('(1 to 4) != (1, 2, 3, 4), 1 to 4 != (1, 2, 3)');

is @r, (False, True), 'Range comparison !=';
