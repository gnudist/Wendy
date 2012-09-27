begin ;

DROP TABLE host_alias;
DROP TABLE wemodule;
DROP TABLE weuser;
DROP TABLE hostlanguage;
DROP TABLE macros;
DROP TABLE host;
DROP TABLE language;
DROP TABLE perlproc;

commit;

begin;

CREATE table language (
id SERIAL PRIMARY KEY,
lng varchar(8) UNIQUE,
descr varchar(32) );

CREATE TABLE host (
id serial PRIMARY KEY,
host varchar (128) UNIQUE,
defaultlng INT REFERENCES language(id) DEFAULT 1 );

CREATE TABLE host_alias (
id SERIAL PRIMARY KEY,
host INT REFERENCES host(id),
alias varchar(128) NOT NULL UNIQUE );

CREATE TABLE hostlanguage (
id serial PRIMARY KEY,
host INT REFERENCES host(id),
lng  INT REFERENCES language(id) DEFAULT 1 );

ALTER TABLE hostlanguage ADD CONSTRAINT hl_uniq UNIQUE(host,lng);

CREATE TABLE macros (
id serial PRIMARY KEY,
name varchar(64),
body text,
istext boolean default true,
host INT REFERENCES host(id),
address varchar(256),
lng INT REFERENCES language(id),
created timestamp default NOW(),
accessed timestamp,
active boolean NOT NULL default true,
ac int not null default 0 );

CREATE INDEX address_idx ON macros(address);
CREATE INDEX host_idx ON macros(host);
CREATE INDEX lng_idx ON macros(lng);
CREATE INDEX active_idx ON macros(active);

ALTER TABLE macros ADD CONSTRAINT m_uni UNIQUE(name,host,address,lng);
ALTER TABLE macros ADD CONSTRAINT m_chk CHECK(name ~ '^[A-Z_0-9-]+$');

CREATE TABLE perlproc (
id SERIAL PRIMARY KEY,
name varchar(64) UNIQUE,
body text );

CREATE TABLE weuser (
id SERIAL PRIMARY KEY,
login varchar(32) UNIQUE,
password varchar(32),
host INT REFERENCES host(id),
flag INT DEFAULT 0 );

--  This table is for module installations accounting.

CREATE TABLE wemodule ( 
id SERIAL PRIMARY KEY,
name varchar (64) NOT NULL,
host INT REFERENCES host(id) );
ALTER TABLE wemodule ADD CONSTRAINT mod_uni UNIQUE(name,host);

INSERT INTO language (lng,descr) VALUES ('en', 'English');
INSERT INTO language (lng,descr) VALUES ('ru', 'Russian');
INSERT INTO language (lng,descr) VALUES ('fr', 'French');
INSERT INTO language (lng,descr) VALUES ('de', 'German');
INSERT INTO language (lng,descr) VALUES ('ja', 'Japanese');
INSERT INTO language (lng,descr) VALUES ('cn', 'Chinese');
INSERT INTO language (lng,descr) VALUES ('et', 'Estonian');
INSERT INTO language (lng,descr) VALUES ('ua', 'Ukrainian');
INSERT INTO language (lng,descr) VALUES ('es', 'Spanish');

INSERT INTO host (host) VALUES('%DEFAULT_HOST%');

INSERT INTO hostlanguage (host) VALUES ('1');

INSERT INTO macros (name,body,host,address,lng) VALUES ('TEST_MACROS','This is test macros. I love you, Wendy!',1,'root',1);
INSERT INTO macros (name,body,host,address,lng) VALUES ('ANY_TEST_MACROS','This is ANY address test macros.',1,'ANY',1);
INSERT INTO perlproc (name,body) VALUES('rand_num', 'return rand();');

INSERT INTO weuser (login,password,host) values ('root','%ROOT_PASSWORD%','1');

COMMIT;