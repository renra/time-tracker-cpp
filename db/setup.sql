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

CREATE TABLE bank_account_transfers(
  id SERIAL PRIMARY KEY,
  from_bank_account_id INTEGER REFERENCES bank_accounts(id),
  to_bank_account_id INTEGER REFERENCES bank_accounts(id),
  original_amount FLOAT,
  transferred_amount FLOAT,
  exchange_rate FLOAT
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
  identification_number VARCHAR(20),
  VAT VARCHAR(20)
);

CREATE TABLE address_links(
  id SERIAL PRIMARY KEY,
  house_number_id INTEGER REFERENCES house_numbers(id) NOT NULL,
  trade_subject_id INTEGER REFERENCES trade_subjects(id) NOT NULL
);


CREATE TABLE projects(
  id SERIAL PRIMARY KEY,
  trade_subject_id INTEGER REFERENCES trade_subjects(id),
  name VARCHAR(255)
);

CREATE TABLE task_types(
  id SERIAL PRIMARY KEY,
  name VARCHAR(100) UNIQUE
);

CREATE TABLE tasks(
  id SERIAL PRIMARY KEY,
  project_id INTEGER REFERENCES projects(id),
  name VARCHAR(255),
  link VARCHAR(255),
  task_type_id INTEGER REFERENCES task_types(id)
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
  currency_id INTEGER REFERENCES currencies(id),
  bank_account_id INTEGER REFERENCES bank_accounts(id),
  trade_subject_id INTEGER REFERENCES trade_subjects(id) NOT NULL
);

CREATE TABLE outbound_payments(
  id SERIAL PRIMARY KEY,
  date date,
  total_amount FLOAT,
  base_amount FLOAT,
  vat FLOAT,
  vat_id INTEGER REFERENCES vat_charges(id),
  currency_id INTEGER REFERENCES currencies(id),
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

CREATE view recent_tasks as SELECT * FROM tasks ORDER by id DESC LIMIT 3;
CREATE view today_stuff as SELECT * FROM day_entries WHERE date = now()::date;

CREATE view current_task as
  SELECT c.id as client_id, p.id as project_id, t.id as task_id,
    c.name as client_name, p.name as project_name, t.name as task_name

    from day_entries de
    JOIN tasks t on de.task_id = t.id
    JOIN projects p on t.project_id = p.id
    JOIN trade_subjects c on p.trade_subject_id = c.id
    where de.task_id is not null and
    t.project_id is not null and
    p.trade_subject_id is not null and
    de.stop is null
    order by de.id DESC limit 1;


CREATE view day_time_reports as
  SELECT c.id as client_id, p.id as project_id, t.id as task_id,
    c.name as client_name, p.name as project_name, t.name as task_name,
    de.date, sum(de.stop - de.start) as total

    from day_entries de
    JOIN tasks t on t.id = de.task_id
    JOIN projects p on t.project_id = p.id
    JOIN trade_subjects c on p.trade_subject_id = c.id
    WHERE de.start is not null and de.stop is not null
    and de.task_id is not null and t.project_id is not null and
    p.trade_subject_id is not null
    group by de.date, t.id, p.id, c.id order by de.date DESC;

CREATE view day_overview as SELECT date, sum(total) as total
  FROM day_time_reports
  GROUP BY date ORDER by date DESC;

CREATE view recent_days as SELECT * FROM day_overview ORDER by date DESC LIMIT 7;
CREATE view today as SELECT * FROM day_time_reports WHERE date = now()::date;

CREATE view month_time_reports as
  SELECT client_id, project_id,
  extract(YEAR from date) as year, extract(MONTH from date) as month,
  client_name, project_name,
  sum(total) from day_time_reports
  group by year, month, client_id, client_name, project_id, project_name
  order by year, month desc;

CREATE view month_overview as
  SELECT year, month, sum(sum) from month_time_reports
  group by year, month
  order by year, month desc;

CREATE view this_month as SELECT * from month_time_reports where
  year = extract(YEAR from now()::date) and
  month = extract(MONTH from now()::date);

CREATE view year_time_reports as
  SELECT client_id, project_id, year,
  client_name, project_name, sum(sum) from month_time_reports
  group by year, client_id, project_id, client_name, project_name
  order by year desc;

CREATE view year_overview as
  SELECT year, sum(sum) from year_time_reports
  group by year order by year  desc;

CREATE view this_year as SELECT * from year_time_reports where
  year = extract(YEAR from now()::date);

CREATE view task_overview as
  SELECT c.id as client_id, c.name as client_name,
    p.id as project_id, p.name as project_name,
    t.name as task_name, sum(de.stop - de.start) as total, link
    from tasks t
    JOIN day_entries as de on t.id = de.task_id
    JOIN projects as p on p.id = t.project_id
    JOIN trade_subjects as c on c.id = p.trade_subject_id
    WHERE de.stop is not null and de.start is not null and
    de.task_id is not null and t.project_id is not null and
    p.trade_subject_id is not null
    group by t.id, p.id, c.id;

CREATE view project_overview as SELECT client_id, project_id,
  client_name, project_name,
  sum(total)
  from task_overview group by project_id, project_name, client_id, client_name;

CREATE view client_overview as SELECT client_id, client_name, sum(total)
  from task_overview
  group by project_id, client_id, client_name;
