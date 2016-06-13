use v6;

unit class XML::XPath;

use XML::XPath::Grammar;
use XML::XPath::Actions;

has $!context; # Holds the current evaluation context;
has Str $!sep = '';

my %expr_cache = ();

method cache() {
    %expr_cache;
}

method new ($init_context = Nil){
    self.bless(:context($init_context));
}

submethod BUILD (:$!context) { }

multi method evaluate(XML::XPath:D: Str $expr, $context = Nil) {
    my $ast := %expr_cache{$expr} //=
      XML::XPath::Grammar.parse($expr, :rule<Expr>, :actions(XML::XPath::Actions)).made;

    $context and temp $!context = $context;

    $ast.($!context);
}

multi method evaluate(XML::XPath:U: Str $expr, $context = Nil) {
    return self.new.evaluate($expr, $context);
}
