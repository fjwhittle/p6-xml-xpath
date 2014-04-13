# An XPath 2.0 implementation for Perl 6

## Introduction

XML::XPath is a library for processing XPath 2.0 expressions.

For more information on XPath 2.0, see
[The W3C Specification](http://www.w3.org/TR/xpath20)

The library is currently in its infancy and needs many features added to become
useful.

## Scope

Currently two modules are provided with the library, these are:

* **XML::XPath** for evaluation of expressions, and
* **XML::XPath::Grammar** for parsing expression input.

**XML::XPath::Grammar** is near complete for the XPath 2.0 specification, but
does not handle XPath 1.0 compatibility or have any explicit support for XPath
functions or related namespaces.

**XML::XPath** is in its early stages of development and lacks support for all
XML tree and comparison operations.  So far, the following is implemented:

* String and Numeric Literals
* Parenthesised sub-expressions
* Unary negation
* Numeric arithmetic and String concatenation
* Range expressions
* Set operations ( union, intersect, except )
* And, Or
* Filters ( [] ) -- fairly useless without comparison operators
* Initial boilerplate for path expressions - but don't expect it to do anything
  useful until XML can be found.
* (Nested) Comments

## Usage

```perl

	my $xp = XPath.new();
	my @result := $xp.evaluate($expr);
	
```

`evaluate(**Str** _$expr_)` produces an _Array_ of results matching _`$expr`_,
be they XML::Nodes or literal values.

## Author

Francis Whittle, https://github.com/fjwhittle

## Licence

[Artistic License 2.0](http://www.perlfoundation.org/artistic_license_2_0)
