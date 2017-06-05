unit module Database::PostgreSQL::LibPQ;

use NativeCall;

constant LIBPQ = 'pq';
our class Connection is repr('CPointer') {...}
my class Result is repr('CPointer') {...}
sub PQconnectdb(Str --> Connection) is native(LIBPQ) {*}
sub PQprepare(Connection, Str, Str, int32, Pointer[void] --> Result) is native(LIBPQ) {*}
sub PQdescribePrepared(Connection, Str --> Result) is native(LIBPQ) {*}
sub PQnparams(Connection --> int32) is native(LIBPQ) {*}
sub PQparamtype(Connection, int32 --> uint32) is native(LIBPQ) {*}
sub PQnfields(Connection --> int32) is native(LIBPQ) {*}
sub PQftype(Connection, int32 --> uint32) is native(LIBPQ) {*}
sub PQstatus(Connection --> int32) is native(LIBPQ) {*}
sub PQerrorMessage(Connection --> Str) is native(LIBPQ) {*}
sub PQresultStatus(Result --> int32) is native(LIBPQ) {*}
sub PQresultErrorMessage(Result --> Str) is native(LIBPQ) {*}

our class Description {
  has Int @.parameters;
  has Int @.fields;
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
    my @fields = ^PQnfields($result) .map: {PQftype $result, $_};
    Description.new(:@parameters, :@fields);
  }
}

class Result {
  method check(Result:D: Connection:D $conn) {
    die PQerrorMessage($conn) without self;
    die PQresultErrorMessage(self) unless PQresultStatus(self) == 1;
  }
}
