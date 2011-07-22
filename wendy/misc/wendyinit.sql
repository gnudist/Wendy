DROP TABLE wendy_host_alias;
DROP TABLE wendy_module;
DROP TABLE wendy_user;
DROP TABLE wendy_host_language;
DROP TABLE wendy_macros;
DROP TABLE wendy_host;
DROP TABLE wendy_language;
DROP TABLE wendy_macros_type;


CREATE table wendy_language (
id int not null PRIMARY KEY,
lng varchar(8) UNIQUE,
descr varchar(32) );

CREATE TABLE wendy_host (
id serial PRIMARY KEY,
host varchar (128) UNIQUE,
defaultlng INT REFERENCES wendy_language(id) DEFAULT 1 );

CREATE TABLE wendy_host_alias (
id SERIAL PRIMARY KEY,
host INT REFERENCES wendy_host(id),
alias varchar(128) NOT NULL UNIQUE );

CREATE TABLE wendy_host_language (
id serial PRIMARY KEY,
host INT REFERENCES wendy_host(id),
lng  INT REFERENCES wendy_language(id) DEFAULT 1 );

ALTER TABLE wendy_host_language ADD CONSTRAINT hl_uniq UNIQUE(host,lng);

CREATE table wendy_macros_type (
id int NOT NULL PRIMARY KEY,
syscap varchar(16) NOT NULL UNIQUE );

INSERT INTO wendy_macros_type (id,syscap) VALUES ('1','TEXT');

CREATE TABLE wendy_macros (
id serial PRIMARY KEY,
name varchar(64),
body text,
type int NOT NULL REFERENCES wendy_macros_type(id) default 1,
host INT REFERENCES wendy_host(id),
address varchar(256),
lng INT REFERENCES wendy_language(id),
created timestamp default NOW(),
accessed timestamp,
active boolean NOT NULL default true,
ac int not null default 0 );

CREATE INDEX address_idx ON wendy_macros(address);
CREATE INDEX host_idx ON wendy_macros(host);
CREATE INDEX lng_idx ON wendy_macros(lng);
CREATE INDEX active_idx ON wendy_macros(active);

ALTER TABLE wendy_macros ADD CONSTRAINT m_uni UNIQUE(name,host,address,lng);
ALTER TABLE wendy_macros ADD CONSTRAINT m_chk CHECK(name ~ '^[A-Z_0-9-]+$');

CREATE TABLE wendy_user (
id SERIAL PRIMARY KEY,
login varchar(32) UNIQUE,
password varchar(32) );

--  This table is for module installations accounting.

CREATE TABLE wendy_module ( 
id SERIAL PRIMARY KEY,
name varchar (64) NOT NULL,
host INT REFERENCES wendy_host(id) );

ALTER TABLE wendy_module ADD CONSTRAINT mod_uni UNIQUE(name,host);

INSERT INTO wendy_language (id,lng,descr) VALUES (1, 'en', 'English (US)');
INSERT INTO wendy_language (id,lng,descr) VALUES (2, 'ru', 'Russian');
INSERT INTO wendy_language (id,lng,descr) VALUES (3, 'fr', 'French');
INSERT INTO wendy_language (id,lng,descr) VALUES (4, 'de', 'German');
INSERT INTO wendy_language (id,lng,descr) VALUES (5, 'ja', 'Japanese');
INSERT INTO wendy_language (id,lng,descr) VALUES (6, 'cn', 'Chinese');
INSERT INTO wendy_language (id,lng,descr) VALUES (7, 'et', 'Estonian');
INSERT INTO wendy_language (id,lng,descr) VALUES (8, 'ua', 'Ukrainian');
INSERT INTO wendy_language (id,lng,descr) VALUES (9, 'es', 'Spanish');

INSERT INTO wendy_host (host) VALUES('%DEFAULT_HOST%');

INSERT INTO wendy_host_language (host) VALUES ('1');

INSERT INTO wendy_macros (name,body,host,address,lng) VALUES ('TEST_MACROS','This is test macros.',1,'root',1);

INSERT INTO wendy_user (login,password) values ('root','%ROOT_PASSWORD%');

