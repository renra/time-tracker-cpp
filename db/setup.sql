CREATE TABLE countries(
  id SERIAL PRIMARY KEY,
  english_name VARCHAR(50) NOT NULL
);

CREATE TABLE provinces(
  id SERIAL PRIMARY KEY,
  country_id INTEGER REFERENCES countries(id) NOT NULL,
  native_name VARCHAR(20) NOT NULL
);

CREATE TABLE cities(
  id SERIAL PRIMARY KEY,
  country_id INTEGER REFERENCES countries(id) NOT NULL,
  province_id INTEGER REFERENCES provinces(id),
  postal_code VARCHAR(10),
  name VARCHAR(50) NOT NULL
);

CREATE TABLE city_parts(
  id SERIAL PRIMARY KEY,
  name VARCHAR(50) NOT NULL,
  postal_code VARCHAR(10) NOT NULL,
  city_id INTEGER REFERENCES cities(id) NOT NULL
);

-- either city_id or city_part_id must not be null
CREATE TABLE streets(
  id SERIAL PRIMARY KEY,
  name VARCHAR(50) NOT NULL,
  city_id INTEGER REFERENCES cities(id),
  city_part_id INTEGER REFERENCES city_parts(id)
);

-- either street_id or city_id not null
CREATE TABLE house_numbers(
  id SERIAL PRIMARY KEY,
  street_id INTEGER REFERENCES streets(id),
  city_id INTEGER REFERENCES cities(id),
  value VARCHAR(10)
);

CREATE TABLE trade_subjects(
  id SERIAL PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  identification_number VARCHAR(20),
  VAT VARCHAR(20),
  me BOOLEAN DEFAULT false
);

CREATE TYPE address_type AS ENUM ('seat', 'correspondence', 'branch');

CREATE TABLE address_links(
  id SERIAL PRIMARY KEY,
  type address_type DEFAULT 'seat',
  house_number_id INTEGER REFERENCES house_numbers(id) NOT NULL,
  trade_subject_id INTEGER REFERENCES trade_subjects(id) NOT NULL
);

CREATE TABLE currencies(
  id SERIAL PRIMARY KEY,
  short_name VARCHAR(10) NOT NULL
);

CREATE TABLE banks(
  id SERIAL PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  code VARCHAR(10) NOT NULL,
  swift VARCHAR(20) NOT NULL
);

CREATE TABLE bank_accounts(
  id SERIAL PRIMARY KEY,
  name VARCHAR(40),
  number VARCHAR(20) NOT NULL,
  iban VARCHAR(40),
  bank_id INTEGER REFERENCES banks(id) NOT NULL,
  currency_id INTEGER REFERENCES currencies(id) NOT NULL
);

CREATE TABLE exchange_rates(
  id SERIAL PRIMARY KEY,
  rate FLOAT NOT NULL,
  bank_id INTEGER REFERENCES banks(id) NOT NULL,
  from_currency_id INTEGER REFERENCES currencies(id) NOT NULL,
  to_currency_id INTEGER REFERENCES currencies(id) NOT NULL,
  date date NOT NULL
);

CREATE TABLE vat_charges(
  id SERIAL PRIMARY KEY,
  country_id INTEGER REFERENCES countries(id) NOT NULL,
  percentage FLOAT NOT NULL
);

CREATE TABLE articles(
  id SERIAL PRIMARY KEY,
  name VARCHAR(255),
  description VARCHAR(255),
  unit_price FLOAT,
  currency_id INTEGER REFERENCES currencies(id),
  vat_id INTEGER REFERENCES vat_charges(id),
  supplier_id INTEGER REFERENCES trade_subjects(id)
);

CREATE TABLE invoices(
  id SERIAL PRIMARY KEY,
  sequence_number VARCHAR(100) NOT NULL,
  supplier_id INTEGER REFERENCES trade_subjects(id) NOT NULL,
  client_id INTEGER REFERENCES trade_subjects(id) NOT NULL,
  generated_on date NOT NULL,
  taxable_supply_date date NOT NULL,
  due_date date,
  currency_id INTEGER REFERENCES currencies(id) NOT NULL,
  total_computed_base_amount FLOAT,
  total_computed_vat FLOAT,
  total_corrected_base_amount FLOAT,
  total_corrected_vat FLOAT,
  reverse_charge BOOLEAN DEFAULT false,
  paid BOOLEAN DEFAULT false,
  exchange_rate_id INTEGER REFERENCES exchange_rates(id),
  note TEXT,
  original_invoice bytea,
  original_invoice_md5 varchar(100),
  translated_invoice bytea,
  translated_invoice_md5 varchar(100)
);

CREATE TABLE invoice_articles(
  id SERIAL PRIMARY KEY,
  invoice_id INTEGER REFERENCES invoices(id) NOT NULL,
  article_id INTEGER REFERENCES articles(id) NOT NULL,
  amount FLOAT NOT NULL,
  note TEXT
);

CREATE TYPE report_type AS ENUM (
  'vat',
  'reverse_charge',
  'social',
  'health',
  'income'
);

CREATE TABLE reports(
  id SERIAL PRIMARY KEY,
  date date NOT NULL,
  type report_type NOT NULL,
  to_pay FLOAT,
  to_receive FLOAT
);

CREATE TYPE payment_type AS ENUM (
  'vat',
  'health_insurance',
  'social_insurance',
  'income_tax',
  'invoice',
  'salary'
);

CREATE TABLE payments(
  id SERIAL PRIMARY KEY,
  date date NOT NULL,
  amount FLOAT DEFAULT 0.0,
  type payment_type NOT NULL,
  currency_id INTEGER REFERENCES currencies(id) NOT NULL,
  bank_account_id INTEGER REFERENCES bank_accounts(id),
  sender_id INTEGER REFERENCES trade_subjects(id) NOT NULL,
  receiver_id INTEGER REFERENCES trade_subjects(id) NOT NULL,
  vat_report_id INTEGER REFERENCES reports(id),
  income_report_id INTEGER REFERENCES reports(id)
);

CREATE TABLE invoice_payments(
  id SERIAL PRIMARY KEY,
  amount FLOAT DEFAULT 0.0,   -- DROP this
  payment_id INTEGER REFERENCES payments(id) NOT NULL,
  invoice_id INTEGER REFERENCES invoices(id) NOT NULL,
  exchange_rate_id INTEGER REFERENCES exchange_rates(id)
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

CREATE view incoming_invoices as
  SELECT i.id, i.sequence_number, ts.name as supplier, i.generated_on,
    i.taxable_supply_date, i.total_corrected_base_amount as base,
    i.total_corrected_vat as vat, i.reverse_charge, i.note,
    c.short_name as currency

    from invoices as i
    JOIN trade_subjects as ts on ts.id = i.supplier_id
    JOIN currencies as c ON c.id = i.currency_id
    where i.client_id IN (select id from trade_subjects where me = true)
    order by i.taxable_supply_date DESC;

CREATE view outgoing_invoices as
  SELECT i.id, i.sequence_number, ts.name as client, i.generated_on,
    i.taxable_supply_date, i.total_corrected_base_amount as base,
    i.total_corrected_vat as vat, i.reverse_charge, i.note,
    c.short_name as currency,
    (select coalesce( (select rate from exchange_rates where id = i.exchange_rate_id), 1) )*i.total_corrected_base_amount as base_in_czk,
    (select coalesce( (select rate from exchange_rates where id = i.exchange_rate_id), 1) )*(i.total_corrected_base_amount + i.total_corrected_vat) as total_in_czk

    from invoices as i
    JOIN trade_subjects as ts on ts.id = i.client_id
    JOIN currencies as c ON c.id = i.currency_id
    where i.supplier_id IN (select id from trade_subjects where me = true)
    order by i.taxable_supply_date DESC;

CREATE view incoming_payments as
  SELECT p.id, p.date, ts.name as supplier,
    p.amount, c.short_name as currency,
    (select sum(coalesce(er.rate, 1)*ip.amount) from invoice_payments as ip LEFT OUTER JOIN exchange_rates as er ON er.id = ip.exchange_rate_id where ip.payment_id = p.id) as in_czk

    from payments as p
    JOIN trade_subjects as ts on ts.id = p.sender_id
    JOIN currencies as c ON c.id = p.currency_id
    where p.receiver_id IN (select id from trade_subjects where me = true)
    order by p.date DESC;

CREATE view outgoing_payments as
  SELECT p.id, p.date, ts.name as client,
    p.amount, c.short_name as currency,
    (select sum(coalesce(er.rate, 1)*ip.amount) from invoice_payments as ip LEFT OUTER JOIN exchange_rates as er ON er.id = ip.exchange_rate_id where ip.payment_id = p.id) as in_czk

    from payments as p
    JOIN trade_subjects as ts on ts.id = p.receiver_id
    JOIN currencies as c ON c.id = p.currency_id
    where p.sender_id IN (select id from trade_subjects where me = true)
    order by p.date DESC;

CREATE view recent_tasks as SELECT * FROM tasks ORDER by id DESC LIMIT 3;
CREATE view today_stuff as SELECT * FROM day_entries WHERE date = now()::date;

CREATE view current_task as
  SELECT c.id as client_id, p.id as project_id, t.id as task_id,
    c.name as client_name, p.name as project_name, t.name as task_name

    from day_entries de
    JOIN tasks t on de.task_id = t.id
    JOIN projects p on t.project_id = p.id
    JOIN trade_subjects c on p.trade_subject_id = c.id
    where de.stop is null
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
