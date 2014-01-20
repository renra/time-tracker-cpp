CREATE TABLE currencies(
  id SERIAL PRIMARY KEY,
  short_name VARCHAR(10) NOT NULL
);

CREATE TABLE banks(
  id SERIAL PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  code VARCHAR(10) NOT NULL,
  swift VARCHAR(10) NOT NULL
);

CREATE TABLE bank_accounts(
  id SERIAL PRIMARY KEY,
  name VARCHAR(40),
  number VARCHAR(20),
  iban VARCHAR(40),
  bank_id INTEGER REFERENCES banks(id),
  currency_id INTEGER REFERENCES currencies(id)
);

CREATE TABLE countries(
  id SERIAL PRIMARY KEY,
  english_name VARCHAR(50)
);

CREATE TABLE provinces(
  id SERIAL PRIMARY KEY,
  country_id INTEGER REFERENCES countries(id) NOT NULL,
  native_name VARCHAR(20)
);

CREATE TABLE cities(
  id SERIAL PRIMARY KEY,
  country_id INTEGER REFERENCES countries(id),
  province_id INTEGER REFERENCES provinces(id),
  postal_code VARCHAR(10),
  name VARCHAR(50)
);

CREATE TABLE streets(
  id SERIAL PRIMARY KEY,
  name VARCHAR(50),
  city_id INTEGER REFERENCES cities(id)
);

CREATE TABLE house_numbers(
  id SERIAL PRIMARY KEY,
  street_id INTEGER REFERENCES streets(id),
  value VARCHAR(10)
);

CREATE TABLE trade_subjects(
  id SERIAL PRIMARY KEY,
  name VARCHAR(255),
  house_number_id INTEGER REFERENCES house_numbers(id),
  identification_number VARCHAR(20),
  VAT VARCHAR(20)
);

CREATE TABLE projects(
  id SERIAL PRIMARY KEY,
  trade_subject_id INTEGER REFERENCES trade_subjects(id),
  name VARCHAR(255)
);

CREATE TABLE tasks(
  id SERIAL PRIMARY KEY,
  project_id INTEGER REFERENCES projects(id),
  name VARCHAR(255),
  link VARCHAR(255)
);

CREATE TABLE day_entries(
  id SERIAL PRIMARY KEY,
  task_id INTEGER REFERENCES tasks(id),
  date DATE,
  start TIME,
  stop TIME,
  invoiced BOOLEAN DEFAULT false
);

CREATE TABLE vat_charges(
  id SERIAL PRIMARY KEY,
  country_id INTEGER REFERENCES countries(id) NOT NULL,
  percentage FLOAT NOT NULL
);

CREATE TABLE accepted_payments(
  id SERIAL PRIMARY KEY,
  date date,
  total_amount FLOAT,
  base_amount FLOAT,
  vat FLOAT,
  vat_id INTEGER REFERENCES vat_charges(id),
  trade_subject_id INTEGER REFERENCES trade_subjects(id) NOT NULL,
  amount FLOAT
);

CREATE TABLE outbound_payments(
  id SERIAL PRIMARY KEY,
  date date,
  total_amount FLOAT,
  base_amount FLOAT,
  vat FLOAT,
  vat_id INTEGER REFERENCES vat_charges(id),
  trade_subject_id INTEGER REFERENCES trade_subjects(id),
  receipt_id VARCHAR(40),
  description TEXT
);

CREATE TABLE invoices(
  id SERIAL PRIMARY KEY,
  sequence_number VARCHAR(10),
  trade_subject_id INTEGER REFERENCES trade_subjects(id) NOT NULL,
  total_time TIME
);

CREATE view day_overview as SELECT date, sum(stop - start)
  AS total from day_entries
  WHERE start is not null and stop is not null
  group by date order by date;

CREATE view month_overview as SELECT extract(YEAR from date) as year,
  extract(MONTH from date) as month, sum(total) from day_overview
  group by year, month;

CREATE view year_overview as SELECT year, sum(sum)
  from month_overview group by year;

CREATE view task_overview as SELECT ts.id as trade_subject_id,
  trade_subject.name as trade_subject_name,
  p.id as project_id, p.name as project_name, t.id as task_id,
  t.name as task_name, sum(de.stop-de.start) as total from tasks as t
  JOIN day_entries as de on t.id = de.task_id
  JOIN projects as p on p.id = t.project_id
  JOIN trade_subjects as ts on ts.id = p.trade_subject_id
  WHERE de.stop is not null group by t.id, p.id, ts.id;

CREATE view project_overview as SELECT trade_subject_name, project_id,
  project_name,
  sum(total) from task_overview group by project_id, project_name,
  trade_subject_name;

CREATE view trade_subject_overview as SELECT trade_subject_id,
  trade_subject_name, sum(total)
  from task_overview group by project_id, trade_subject_id, trade_subject_name;
