#!/usr/bin/env perl6

use XML::XPath;
use XML;
use Test;

plan 3;

my $doc = XML::Document.load('t/testdoc.xml') or die;

my $xp = XML::XPath.new($doc);

my @r = $xp.evaluate('//li[@class="list-item"] intersect //li[@data-test="test"]');

is (@r.elems, @r[0]<class data-test>), (1, 'list-item', 'test'), 'intersect';

@r = $xp.evaluate('//li except //li[@class="list-item"][@data-test="test"]');

is (@r.elems, @r»<class>), (2, 'list-item', Any), 'except';

dies-ok { $xp.evaluate('(1, 2, 3, 4) intersect (2, 3, 4, 5)') }, 'fails on non-XML data type'
