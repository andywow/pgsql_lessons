#### 1. Настройте сервер так, чтобы в журнал сообщений сбрасывалась информация о блокировках, удерживаемых более 200 миллисекунд. Воспроизведите ситуацию, при которой в журнале появятся такие сообщения.

```
alter system set deadlock_timeout=200;
alter system set log_lock_waits=on;
select pg_reload_conf();
```

#### 2. Смоделируйте ситуацию обновления одной и той же строки тремя командами UPDATE в разных сеансах. Изучите возникшие блокировки в представлении pg_locks и убедитесь, что все они понятны. Пришлите список блокировок и объясните, что значит каждая.

```
# session 01
create table test (a int);
insert into test values(1);
insert into test values(2);
insert into test values(3);
insert into test values(4);
\set AUTOCOMMIT off
update test set a=6 where a=1;
```

```
# session 2
\set AUTOCOMMIT off
update test set a=7 where a=1;
```

```
# session 3
\set AUTOCOMMIT off
update test set a=8 where a=1;
```

```
# session 1

postgres=*#
postgres=*# select
postgres-*#   lock.locktype,
postgres-*#   lock.relation::regclass,
postgres-*#   lock.mode,
postgres-*#   lock.transactionid as tid,
postgres-*#   lock.virtualtransaction as vtid,
postgres-*#   lock.pid,
postgres-*#   lock.granted
postgres-*# from pg_catalog.pg_locks lock;

   locktype    | relation |       mode       | tid | vtid | pid  | granted
---------------+----------+------------------+-----+------+------+---------
 relation      | test     | RowExclusiveLock |     | 5/3  | 6422 | t
 virtualxid    |          | ExclusiveLock    |     | 5/3  | 6422 | t
 relation      | test     | RowExclusiveLock |     | 4/15 | 6413 | t
 virtualxid    |          | ExclusiveLock    |     | 4/15 | 6413 | t
 relation      | pg_locks | AccessShareLock  |     | 3/25 | 6158 | t
 relation      | test     | RowExclusiveLock |     | 3/25 | 6158 | t
 virtualxid    |          | ExclusiveLock    |     | 3/25 | 6158 | t
 transactionid |          | ExclusiveLock    | 493 | 3/25 | 6158 | t
 transactionid |          | ExclusiveLock    | 495 | 4/15 | 6413 | t
 tuple         | test     | ExclusiveLock    |     | 4/15 | 6413 | f
 tuple         | test     | ExclusiveLock    |     | 5/3  | 6422 | t
 transactionid |          | ShareLock        | 493 | 5/3  | 6422 | f
 transactionid |          | ExclusiveLock    | 494 | 5/3  | 6422 | t

```
Видим 3 pid-а - по количеству наших сессий
Выполнив `select pg_backend_pid();` увидим, что id первой сессии = 6158;

У нее есть (все права granted):
- AccessShareLock на view pg_locks, из которой мы делаем селект
- RowExclusiveLock на строку, которую мы заапдейтили в рамках транзакции
- ExclusiveLock на свою транзакцию
- ExclusiveLock на virtualxid для своей транзакции (такой идентификатор появляется у каждой транзакции потенциально меняющей состояние базы данных)

Для остальных 2-х сессий есть:
- ExclusiveLock на свою транзакцию (granted)
- ExclusiveLock на virtualxid для своей транзакции (granted)
- lock-а с типом tuple в режиме ExclusiveLock - это как раз ожидание блокировки нашей строки

```
 transactionid |          | ShareLock        | 493 | 5/3  | 6422 | f
```
показывает, что транзация 2-й сессии просит выдать ShareLock на транзацию 1-й сессии

3-я же транзация не получила доступа tuple (granted = f) и поэтому нет ожидания доступа к транзакции



#### 3. Воспроизведите взаимоблокировку трех транзакций. Можно ли разобраться в ситуации постфактум, изучая журнал сообщений?

```
# session 1
select pg_advisory_lock(1);
```

```
# session 2
select pg_advisory_lock(2);
```

```
# session 3
select pg_advisory_lock(3);
```

```
# session 1
select pg_advisory_lock(2);
```

```
# session 2
select pg_advisory_lock(3);
```

```
# session 3
select pg_advisory_lock(1);

ERROR:  deadlock detected
DETAIL:  Process 6158 waits for ExclusiveLock on advisory lock [13414,0,1,1]; blocked by process 6413.
Process 6413 waits for ExclusiveLock on advisory lock [13414,0,2,1]; blocked by process 6422.
Process 6422 waits for ExclusiveLock on advisory lock [13414,0,3,1]; blocked by process 6158.
HINT:  See server log for query details.
```

По логу сервиса видна история блокировок:

```
2020-12-03 22:34:40.605 UTC [6413] postgres@postgres LOG:  process 6413 still waiting for ExclusiveLock on advisory lock [13414,0,2,1] after 200.143 ms
2020-12-03 22:34:40.605 UTC [6413] postgres@postgres DETAIL:  Process holding the lock: 6422. Wait queue: 6413.
2020-12-03 22:34:40.605 UTC [6413] postgres@postgres STATEMENT:  select pg_advisory_lock(2);
2020-12-03 22:34:44.107 UTC [6422] postgres@postgres LOG:  process 6422 still waiting for ExclusiveLock on advisory lock [13414,0,3,1] after 200.199 ms
2020-12-03 22:34:44.107 UTC [6422] postgres@postgres DETAIL:  Process holding the lock: 6158. Wait queue: 6422.
2020-12-03 22:34:44.107 UTC [6422] postgres@postgres STATEMENT:  select pg_advisory_lock(3);
2020-12-03 22:34:48.193 UTC [6158] postgres@postgres LOG:  process 6158 detected deadlock while waiting for ExclusiveLock on advisory lock [13414,0,1,1] after 200.204 ms
2020-12-03 22:34:48.193 UTC [6158] postgres@postgres DETAIL:  Process holding the lock: 6413. Wait queue: .
2020-12-03 22:34:48.193 UTC [6158] postgres@postgres STATEMENT:  select pg_advisory_lock(1);
2020-12-03 22:34:48.193 UTC [6158] postgres@postgres ERROR:  deadlock detected
2020-12-03 22:34:48.193 UTC [6158] postgres@postgres DETAIL:  Process 6158 waits for ExclusiveLock on advisory lock [13414,0,1,1]; blocked by process 6413.
	Process 6413 waits for ExclusiveLock on advisory lock [13414,0,2,1]; blocked by process 6422.
	Process 6422 waits for ExclusiveLock on advisory lock [13414,0,3,1]; blocked by process 6158.
	Process 6158: select pg_advisory_lock(1);
	Process 6413: select pg_advisory_lock(2);
	Process 6422: select pg_advisory_lock(3);
```

```
select pg_advisory_unlock_all();
```

#### 4. Могут ли две транзакции, выполняющие единственную команду UPDATE одной и той же таблицы (без where), заблокировать друг друга?

```
insert into test SELECT generate_series(1,10000000) AS a;
commit;
```

У меня не получилось сэмулировать такую ситуацию.

* Попробуйте воспроизвести такую ситуацию.
