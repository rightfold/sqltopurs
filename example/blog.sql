BEGIN TRANSACTION;

CREATE TABLE posts (
  id uuid NOT NULL,
  title text NOT NULL,
  published timestamptz,
  PRIMARY KEY (id)
);

COMMIT TRANSACTION;
