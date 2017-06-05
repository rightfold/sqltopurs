unit class SQLToPurs::Codegen;

use Database::PostgreSQL::LibPQ;
use SQLToPurs::AST;

has Database::PostgreSQL::LibPQ::Connection $!conn;
has IO::Handle $!out;
has Str %!types{Int};

method new($conn, $out, %types) {
  self.bless(:$conn, :$out, :%types);
}

submethod BUILD(:$!conn, :$!out, :%!types) {
}

proto method stmt(SQLToPurs::Codegen:D: Stmt:D $stmt) {*}

multi method stmt(ModuleStmt $stmt) {
  $!out.print("module {$stmt.name} where\n");
  $!out.print("import Control.Applicative (pure) as STP.A\n");
  $!out.print("import Control.Apply ((<*>)) as STP.A\n");
  $!out.print("import Control.Monad.Aff (Aff) as STP.A\n");
  $!out.print("import Data.Array (length) as STP.A\n");
  $!out.print("import Data.Either (Either(Left)) as STP.E\n");
  $!out.print("import Data.Eq (class Eq) as STP.E\n");
  $!out.print("import Data.Function ((\$)) as STP.F\n");
  $!out.print("import Data.Functor (map) as STP.F\n");
  $!out.print("import Data.Generic.Rep as STP.G\n");
  $!out.print("import Data.Generic.Rep.Show as STP.G.S\n");
  $!out.print("import Data.Ord as STP.O\n");
  $!out.print("import Data.Semigroup ((<>)) as STP.S\n");
  $!out.print("import Data.Show (class Show, show) as STP.S\n");
  $!out.print("import Database.PostgreSQL as STP.P\n");
}

multi method stmt(ImportStmt $stmt) {
  $!out.print("import {$stmt.import}\n");
}

multi method stmt(TypeStmt $stmt) {
  %!types{$stmt.sql} = $stmt.purs;
}

multi method stmt(QueryStmt $stmt) {
  multi type(Int:D $sql-type --> Str:D) {
    %!types{$sql-type} // fail "Provide a mapping for type with oid $sql-type";
  }

  multi type(Database::PostgreSQL::LibPQ::Field:D $field --> Str:D) {
    type($field.type);
  }

  sub kleisli(Str:D $eff --> Str:D) {
    "STP.A.Aff (postgreSQL :: STP.P.POSTGRESQL | $eff)";
  }

  sub vars(Int:D $n --> Seq:D) {
    ('a', 'b' ... *)[^$n].map('stp_var_' ~ *);
  }

  sub escape(Str:D $text --> Str:D) {
    $text.subst(/"\\"/, "\\\\", :g).subst(/'"'/, "\\" ~ '"', :g);
  }

  $!conn.prepare('', $stmt.query);
  my $description = $!conn.describe-prepared('');

  my $in = $stmt.name.tc ~ 'In';
  my $out = $stmt.name.tc ~ 'Out';

  $!out.print("data $in = $in");
  $!out.print($description.parameters.map({" ({type $_})"}).join(''));
  $!out.print("\n");

  $!out.print("newtype $out = $out \{");
  $!out.print($description.fields.map({"{$_.name} :: {type $_}"}).join(', '));
  $!out.print("\}\n");

  $!out.print("instance toSQLRow$in :: STP.P.ToSQLRow $in where\n");
  $!out.print("  toSQLRow ($in");
  $!out.print(vars($description.parameters.elems).map(' ' ~ *).join());
  $!out.print(") =\n    [");
  $!out.print(vars($description.parameters.elems).map('STP.P.toSQLValue ' ~ *).join(', '));
  $!out.print("]\n");

  $!out.print("instance fromSQLRow$out :: STP.P.FromSQLRow $out where\n");
  $!out.print('  fromSQLRow [');
  $!out.print(vars($description.fields.elems).join(', '));
  $!out.print("] =\n");
  if $description.fields.elems {
    $!out.print("    STP.F.map $out STP.F.\$\n");
    $!out.print('      STP.A.pure {');
    $!out.print($description.fields.map({"{$_.name}: _"}).join(', '));
    $!out.print("\}\n");
    for vars($description.fields.elems) {
      $!out.print("      STP.A.<*> STP.P.fromSQLValue $_\n");
    }
  } else {
    $!out.print("     STP.A.pure ($out \{\})\n");
  }
  $!out.print('  fromSQLRow stp_xs = STP.E.Left ("Row has " STP.S.<> STP.S.show stp_n STP.S.<> ');
  $!out.print("\"fields, expecting {$description.fields.elems}.\")\n");
  $!out.print("    where stp_n = STP.A.length stp_xs\n");

  for {$in => $stmt.derive-in, $out => $stmt.derive-out}.kv -> $adt, @classes {
    for @classes {
      when 'Eq' { $!out.print("derive instance eq$adt :: STP.E.Eq $adt\n"); }
      when 'Ord' { $!out.print("derive instance ord$adt :: STP.O.Ord $adt\n"); }
      when 'Show' {
        $!out.print("instance show$adt :: STP.S.Show $adt where\n");
        $!out.print("  show = STP.G.S.genericShow\n");
      }
      when 'Generic' { $!out.print("derive instance generic$adt :: STP.G.Generic $adt _\n"); }
      default { fail "Cannot derive an instance for $_" }
    }
  }

  $!out.print("{$stmt.name}\n");
  $!out.print("  :: ∀ stp_eff\n");
  $!out.print("   . STP.P.Connection\n");
  $!out.print("  -> $in\n");
  $!out.print("  -> {kleisli 'stp_eff'} (Array $out)\n");
  $!out.print("{$stmt.name} stp_conn = STP.P.query stp_conn (STP.P.Query ");
  $!out.print('"""' ~ escape($stmt.query) ~ '"""');
  $!out.print(")\n");
}
