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
  $!out.print("import Control.Monad.Aff as STP.Aff\n");
  $!out.print("import Database.PostgreSQL as STP.PG\n");
}

multi method stmt(ImportStmt $stmt) {
  $!out.print("import {$stmt.import}\n");
}

multi method stmt(TypeStmt $stmt) {
  %!types{$stmt.sql} = $stmt.purs;
}

multi method stmt(QueryStmt $stmt) {
  sub type(Int:D $sql-type --> Str:D) {
    %!types{$sql-type} // fail "Provide a mapping for type with oid $sql-type";
  }

  sub row-type(Int:D @sql-types --> Str:D) {
    'STP.PG.Row' ~ @sql-types.elems ~ @sql-types.map({" ({type $_})"}).join;
  }

  sub kleisli(Str:D $eff --> Str:D) {
    "STP.Aff.Aff (postgreSQL :: STP.PG.POSTGRESQL | $eff)";
  }

  sub escape(Str:D $text --> Str:D) {
    $text.subst(/"\\"/, "\\\\", :g).subst(/'"'/, "\\\"", :g);
  }

  $!conn.prepare('', $stmt.query);
  my $description = $!conn.describe-prepared('');
  my $in-type = row-type($description.parameters);
  my $out-type = row-type($description.fields);
  $!out.print("{$stmt.name}\n");
  $!out.print("  :: ∀ stp_eff\n");
  $!out.print("   . STP.PG.Connection\n");
  $!out.print("  -> ($in-type)\n");
  $!out.print("  -> {kleisli 'stp_eff'} (Array ($out-type))\n");
  $!out.print("{$stmt.name} stp_conn = STP.PG.query stp_conn (STP.PG.Query ");
  $!out.print('"""' ~ escape($stmt.query) ~ '"""');
  $!out.print(")\n");
}
