#!/usr/bin/env perl6

use v6;

use XML;
use XML::XPath;

use Test;

plan 6;

my $doc = XML::Document.load('t/testdoc.xml') or die;

my $xp = XML::XPath.new($doc);

my ($root) = $xp.evaluate('/');

is $root.name, 'html', 'Document Root';

my ($head) = $xp.evaluate('head', $root);

is $head.name, 'head', 'Immediate Child node-name';

my @list_items = $xp.evaluate('//li');

is @list_items.elems, 3, 'Descendant node-name';

my ($list) = $xp.evaluate('//li/..');

is $list.name, 'ul', 'Parent node';

my ($attribute) = $xp.evaluate('//ul/@class');

is $attribute, 'list', 'Attribute';

my ($something) = $xp.evaluate('//*[@class="list"]');

is $something.name, 'ul', 'Attribute Predicate';
