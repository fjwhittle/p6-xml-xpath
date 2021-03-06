# An XPath 2.0 implementation for Perl 6

## Introduction

XML::XPath is a library for processing XPath 2.0 expressions.

For more information on XPath 2.0, see
[The W3C Specification](http://www.w3.org/TR/xpath20)

The library is currently in its infancy and needs many features added to become
useful.

## Scope

Currently three modules are provided with the library, these are:

* **XML::XPath** for evaluation of expressions,
* **XML::XPath::Grammar** for parsing expression input and
* **XML::XPath::Actions** to compile the expression AST

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
* Value and Generic (set) comparison
* Filters ( [] )
* Initial boilerplate for path expressions
* Basic name tests for child and descendant nodes
* (Nested) Comments

## Usage

```perl

	my $xp = XML::XPath.new();
	
	my Str $expr = q{"An XPath 2.0 Expression"};
	
	my @result := $xp.evaluate($expr);

	my @tresult := XML::XPath.evaluate($expr);
	
```

`evaluate(Str $expr)` produces a _List_ of results matching _`$expr`_,
be they XML::Nodes or literal values.

## Roadmap / ToDo

The currently planned implementation order is:

1. Node Tests
2. Attribute Tests
3. ...

As progress is somewhat slow at the moment, there's no ETA for anything.

## How can I help?

As they say in Perl estate; test cases, test cases, test cases; we can always
use more.  The project has now moved to a test-driven development model, so new
features will need tests first.
You're welcome to start implementing features as well.  Any pull requests are
expected to either include tests or be for something that already has tests
written.

## Author

Francis Whittle, https://github.com/fjwhittle

## Licence

[Artistic License 2.0](http://www.perlfoundation.org/artistic_license_2_0)
