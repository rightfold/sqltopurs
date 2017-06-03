# sqltopurs

You can write a SQL query, and sqltopurs will have its type inferred and a
PureScript wrapping function generated. The generated PureScript function will
take and return values corresponding to the inferred types. For example, a
query that takes an integer and a string, and returns a UUID and a Boolean,
will be translated into a PureScript function that has the corresponding types,
and invokes the query. Usage is simple; just invoke `sqltopurs` with the source
and target files before you run `pulp build`.

```bash
$ sqltopurs example/blog.stp src/Blog/Database.purs
$ pulp build
```
