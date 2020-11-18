#### 1 создайте новый кластер PostgresSQL 13 (на выбор #### GCE, CloudSQL)
#### 2 зайдите в созданный кластер под пользователем postgres
psql
#### 3 создайте новую базу данных testdb
create database testdb;
#### 4 зайдите в созданную базу данных под пользователем postgres
\c testdb
#### 5 создайте новую схему testnm
create schema testnm;
#### 6 создайте новую таблицу t1 с одной колонкой c1 типа integer
create table t1(c1 integer);
#### 7 вставьте строку со значением c1=1
insert into t1 values(1);
#### 8 создайте новую роль readonly
create role readonly;
#### 9 дайте новой роли право на подключение к базе данных testdb
grant connect on database testdb to readonly;
#### 10 дайте новой роли право на использование схемы testnm
grant usage on schema testnm to readonly;
#### 11 дайте новой роли право на select для всех таблиц схемы testnm
grant select on all tables in schema testnm to readonly;
#### 12 создайте пользователя testread с паролем test123
create role testread with login password 'test123';
#### 13 дайте поль readonly пользователю testread
grant readonly to testread;
#### 14 зайдите под пользователем testread в базу данных testdb
psql -h 127.0.0.1 -p 5432 -U testread -W testdb
#### 15 сделайте select * from t1;
#### 16 получилось? (могло если вы делали сами не по шпаргалке и не упустили один существенный момент про который позже)
нет
#### 17 напишите что именно произошло в тексте домашнего задания
ERROR:  permission denied for table t1
#### 18 у вас есть идеи почему? ведь права то дали?
нет, т.к таблица создана в public
#### 19 посмотрите на список таблиц
\dt
#### 20 подсказка в шпаргалке под пунктом 20
#### 21 а почему так получилось с таблицей (если делали сами и без шпаргалки то может у вас все нормально)
потому что в
testdb => SHOW search_path;
   search_path

 "$user", public
(1 row)
#### 22 вернитесь в базу данных testdb под пользователем postgres
psql testdb
#### 23 удалите таблицу t1
drop table t1;
#### 24 создайте ее заново но уже с явным указанием имени схемы testnm
create table testnm.t1(c1 integer);
#### 25 вставьте строку со значением c1=1
insert into testnm.t1 values(1);
#### 26 зайдите под пользователем testread в базу данных testdb
\c testread testdb 127.0.0.1 5432
// чтобы работало как у вас необходимо добавить строку
local   testdb          testread                                md5
// в файл pg_hba.conf и сделать reload
#### 27 сделайте select * from testnm.t1;
#### 28 получилось?
нет
#### 29 есть идеи почему? если нет #### смотрите шпаргалку
нет в search_path
#### 30 как сделать так чтобы такое больше не повторялось? если нет идей #### смотрите шпаргалку
#### 31 сделайте select * from testnm.t1;
ERROR:  permission denied for table t1
#### 32 получилось?
нет
#### 33 есть идеи почему? если нет #### смотрите шпаргалку
понял из шпаргалки - потому что grant select on all tables in schema testnm TO readonly дал доступ только для существующих на тот момент времени таблиц а t1 пересоздавалась
#### 31 сделайте select * from testnm.t1;
#### 32 получилось?
да
#### 33 ура!
#### 34 теперь попробуйте выполнить команду create table t2(c1 integer); insert into t2 values (2);
#### 35 а как так? нам же никто прав на создание таблиц и insert в них под ролью readonly?
\dt #### создалось в public схеме
#### 36 есть идеи как убрать эти права? если нет #### смотрите шпаргалку
revoke create on schema public from public;
revoke all on database testdb from public
#### 37 если вы справились сами то расскажите что сделали и почему, если смотрели шпаргалку #### объясните что сделали и почему выполнив указанные в ней команды
забрали права на создание таблиц в схеме public
забрали все права у роли public на БД testdb
#### 38 теперь попробуйте выполнить команду create table t3(c1 integer); insert into t2 values (2);
ERROR:  permission denied for schema public
#### 39 расскажите что получилось и почему
забрали права на public, а больше у нас нет живых схем в search_path
