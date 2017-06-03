unit module SQLToPurs::Parse;

use SQLToPurs::AST;

grammar Grammar {
  rule TOP {
    <stmt>*
  }

  proto rule stmt {*}

  rule stmt:sym<module> {
    'module' <verbatim> ';'
  }

  rule stmt:sym<import> {
    'import' <verbatim> ';'
  }

  rule stmt:sym<type> {
    'type' <oid> '<->' <ident> ';'
  }

  rule stmt:sym<query> {
    'query' <ident> '=' <verbatim> ';'
  }

  token ident {
    <[A .. Z a .. z 0 .. 9]>+
  }

  token oid {
    <[0 .. 9]>+
  }

  token verbatim {
    <-[;]>*
  }
}

class Actions {
  method TOP($/) {
    make Module.new(stmts => $<stmt>.map(*.made));
  }

  method stmt:sym<module>($/) {
    make ModuleStmt.new(name => ~$<verbatim>);
  }

  method stmt:sym<import>($/) {
    make ImportStmt.new(import => ~$<verbatim>);
  }

  method stmt:sym<type>($/) {
    make TypeStmt.new(sql => +$<oid>, purs => ~$<ident>);
  }

  method stmt:sym<query>($/) {
    make QueryStmt.new(query => ~$<verbatim>);
  }
}

sub parse($target) is export {
  Grammar.parse($target, actions => Actions).made;
}
