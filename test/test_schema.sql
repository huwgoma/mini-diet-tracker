-- Reset
DROP TABLE IF EXISTS meals CASCADE;
DROP TABLE IF EXISTS foods CASCADE;
DROP TABLE IF EXISTS meal_items;
DROP FUNCTION IF EXISTS adjusted_nutrition;

-- Schema 
CREATE TABLE meals (
  id serial PRIMARY KEY,
  memo varchar(255) NOT NULL,
  logged_at timestamp NOT NULL DEFAULT NOW()::timestamp
);

CREATE TABLE foods (
  id serial PRIMARY KEY, 
  name varchar(255) NOT NULL UNIQUE,
  standard_portion numeric(10, 2) CHECK(standard_portion > 0) NOT NULL DEFAULT 100, -- grams
  calories numeric(10, 2) CHECK(calories >= 0) NOT NULL,
  protein numeric(10, 2) CHECK(protein >= 0) NOT NULL
);

CREATE TABLE meal_items (
  id serial PRIMARY KEY,
  meal_id integer NOT NULL REFERENCES meals ON DELETE CASCADE,
  food_id integer NOT NULL REFERENCES foods ON DELETE CASCADE,
  serving_size numeric(10, 2) CHECK(serving_size > 0) NOT NULL,
  UNIQUE(meal_id, food_id)
);

CREATE OR REPLACE FUNCTION ADJUST (
  nutritional_value numeric(10, 2),
  serving_size numeric(10, 2), 
  standard_portion numeric(10, 2) 
)
  RETURNS numeric(10, 2) AS $$
    BEGIN
      RETURN (nutritional_value * (serving_size / standard_portion))::numeric(10, 2);
    END;
  $$ 
LANGUAGE plpgsql;

-- Test Data
INSERT INTO foods (name, standard_portion, calories, protein)
VALUES ('Oat Milk',      DEFAULT, 48,   0.8),
       ('Chicken Thigh', DEFAULT, 144,  18.6),
       ('Egg',           34,      18.7, 3.64),
       ('Rice',          DEFAULT, 369,  6.94),
       ('Greek Yogurt',  DEFAULT, 61,   10.3),
       ('Banana',        115,     101,  0.851),
       ('Sweet Potato',  DEFAULT, 77,   1.58);

INSERT INTO meals(memo, logged_at)
VALUES ('Lunch Yesterday',  NOW() - INTERVAL '1 DAY'),
       ('Dinner Yesterday', NOW() - INTERVAL '1 DAY'),
       ('Lunch Today',      DEFAULT),
       ('Dinner Today',     DEFAULT),
       ('Lunch 2025-04-20', '2025-04-20'); -- Test: Chicken, Yogurt, Banana

INSERT INTO meal_items (meal_id, food_id, serving_size)
VALUES (1, 1, 235), (1, 3, 115),
       (2, 2, 150), (2, 4, 200),
       (3, 4, 100), (3, 2, 100), (3, 7, 100),
       (4, 4, 100), (4, 3, 35), (4, 1, 100),
       (5, 2, 100), (5, 3, 68)  
-- Test: 144 kcal, 18.6p | 37.4kcal, 7.28p 
