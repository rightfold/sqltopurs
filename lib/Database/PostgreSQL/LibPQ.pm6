unit module Database::PostgreSQL::LibPQ;

use NativeCall;

constant LIBPQ = 'pq';
our class Connection is repr('CPointer') {...}
my class Result is repr('CPointer') {...}
sub PQconnectdb(Str --> Connection) is native(LIBPQ) {*}
sub PQprepare(Connection, Str, Str, int32, Pointer[void] --> Result) is native(LIBPQ) {*}
sub PQdescribePrepared(Connection, Str --> Result) is native(LIBPQ) {*}
sub PQnparams(Result --> int32) is native(LIBPQ) {*}
sub PQparamtype(Result, int32 --> uint32) is native(LIBPQ) {*}
sub PQnfields(Result --> int32) is native(LIBPQ) {*}
sub PQftype(Result, int32 --> uint32) is native(LIBPQ) {*}
sub PQfname(Result, int32 --> Str) is native(LIBPQ) {*}
sub PQstatus(Connection --> int32) is native(LIBPQ) {*}
sub PQerrorMessage(Connection --> Str) is native(LIBPQ) {*}
sub PQresultStatus(Result --> int32) is native(LIBPQ) {*}
sub PQresultErrorMessage(Result --> Str) is native(LIBPQ) {*}

our class Field {
  has Int $.type;
  has Str $.name;
}

our class Description {
  has Int @.parameters;
  has Field @.fields;
}

class Connection {
  method new(Str:D $conn-str --> Connection:D) {
    my $handle = PQconnectdb($conn-str);
    die PQerrorMessage($handle) unless PQstatus($handle) == 0;
    $handle;
  }

  method prepare(Connection:D: Str:D $name, Str:D $query) {
    my $result = PQprepare(self, $name, $query, 0, Nil);
    $result.check(self);
  }

  method describe-prepared(Connection:D: Str:D $name --> Description:D) {
    my $result = PQdescribePrepared(self, $name);
    $result.check(self);
    my @parameters = ^PQnparams($result) .map: {PQparamtype $result, $_};
    my @fields = ^PQnfields($result) .map: {
      Field.new(
        type => PQftype($result, $_),
        name => PQfname($result, $_),
      );
    };
    Description.new(:@parameters, :@fields);
  }
}

class Result {
  method check(Result:D: Connection:D $conn) {
    die PQerrorMessage($conn) without self;
    die PQresultErrorMessage(self) unless PQresultStatus(self) == 1;
  }
}
