CREATE TABLE categories (
id serial PRIMARY KEY,
name text NOT NULL,
amount numeric(6,2)
);

CREATE TABLE purchases (
id serial PRIMARY KEY,
category_id integer REFERENCES categories (id),
date DATE,
amount numeric(6, 2)
);

# Note - update the CREATE TABLE above with this
ALTER TABLE purchases
ADD CONSTRAINT fk_cat_purchase_id
FOREIGN KEY (category_id)
REFERENCES categories (id)
ON DELETE CASCADE
ON UPDATE CASCADE;


CREATE TABLE income (
amount numeric(10, 2) DEFAULT 0.00 NOT NULL
);

INSERT INTO income (amount)
VALUES             (0.00);