unit module SQLToPurs::AST;

class Stmt is export {
}

class ModuleStmt is Stmt is export {
  has Str $.name;
}

class ImportStmt is Stmt is export {
  has Str $.import;
}

class TypeStmt is Stmt is export {
  has Int $.sql;
  has Str $.purs;
}

class QueryStmt is Stmt is export {
  has Str $.query;
}

class Module is export {
  has Stmt @.stmts;
}
