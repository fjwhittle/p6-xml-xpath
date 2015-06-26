use v6;

unit class XML::XPath;

use XML::XPath::Grammar;
use XML::XPath::Actions;

has $.context; # Holds the current evaluation context
has XML::XPath::Actions $!actions;
has %!expr_cache;

method new ($context = Nil){
    self.bless(:$context);
}

multi method evaluate(XML::XPath:D: Str $expr, $context = Nil) {
    my $ast = %!expr_cache{$expr} //=
      XML::XPath::Grammar.parse($expr, :rule<Expr>, :$!actions).made;

    $context and temp $!context = $context;
    return $ast».($!context);
}

multi method evaluate(XML::XPath:U: Str $expr, $context = Nil) {
    return self.new.evaluate($expr, $context);
}
