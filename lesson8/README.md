#### 1. Настройте выполнение контрольной точки раз в 30 секунд.

В файл `/etc/postgresql/main/13/postgresql.conf` добавляем строку

```
checkpoint_timeout = 30s
```

и перезапускаем  кластер

#### 2. 10 минут c помощью утилиты pgbench подавайте нагрузку.

```
pgbench -i postgres
pgbench -c8 -P 60 -T 600 -U postgres postgres

starting vacuum...end.
progress: 60.0 s, 761.1 tps, lat 10.463 ms stddev 7.706
progress: 120.0 s, 782.4 tps, lat 10.181 ms stddev 7.235
progress: 180.0 s, 750.5 tps, lat 10.616 ms stddev 7.809
progress: 240.0 s, 770.0 tps, lat 10.346 ms stddev 7.303
progress: 300.0 s, 777.7 tps, lat 10.244 ms stddev 7.418
progress: 360.0 s, 760.9 tps, lat 10.471 ms stddev 7.545
progress: 420.0 s, 775.6 tps, lat 10.271 ms stddev 7.245
progress: 480.0 s, 759.1 tps, lat 10.495 ms stddev 7.550
progress: 540.0 s, 716.2 tps, lat 11.125 ms stddev 8.283
progress: 600.1 s, 761.9 tps, lat 10.441 ms stddev 8.295
transaction type: <builtin: TPC-B (sort of)>
scaling factor: 1
query mode: simple
number of clients: 8
number of threads: 1
duration: 600 s
number of transactions actually processed: 456983
latency average = 10.461 ms
latency stddev = 7.656 ms
tps = 761.523569 (including connections establishing)
tps = 761.526758 (excluding connections establishing)
```

#### 3. Измерьте, какой объем журнальных файлов был сгенерирован за это время. Оцените, какой объем приходится в среднем на одну контрольную точку.

```
postgres@pgsql-l7:~$ ls -l 13/main/pg_wal/
total 65540
-rw------- 1 postgres postgres 16777216 Nov 25 19:33 000000010000000000000021
-rw------- 1 postgres postgres 16777216 Nov 25 19:31 000000010000000000000022
-rw------- 1 postgres postgres 16777216 Nov 25 19:32 000000010000000000000023
-rw------- 1 postgres postgres 16777216 Nov 25 19:32 000000010000000000000024
drwx------ 2 postgres postgres     4096 Nov 25 19:11 archive_status
```

За время существования БД было создано 24 файла
Размер файлов, после изменения частоты снятия нами - 16 Мб

#### 4. Проверьте данные статистики: все ли контрольные точки выполнялись точно по расписанию. Почему так произошло?

```
select * from pg_stat_bgwriter;
```

Судя по полям `checkpoints_timed` и `checkpoints_req` все выполнилось по расписанию

#### 5. Сравните tps в синхронном/асинхронном режиме утилитой pgbench. Объясните полученный результат.

Первый тест у нас запускался в сихронном режиме. Пробуем запустить в асинхронном. Для этого включим асинхронный режим - в postgresql.conf поменяем

```
ALTER SYSTEM SET synchronous_commit = off;
SELECT pg_reload_conf();
```

запустим нагрузку еще раз

```
pgbench -c8 -P 60 -T 600 -U postgres postgres

starting vacuum...end.
progress: 60.0 s, 1851.9 tps, lat 4.236 ms stddev 1.889
progress: 120.0 s, 1823.9 tps, lat 4.303 ms stddev 2.097
progress: 180.0 s, 916.3 tps, lat 8.541 ms stddev 23.140
progress: 240.0 s, 911.2 tps, lat 8.606 ms stddev 23.224
progress: 300.0 s, 927.6 tps, lat 8.441 ms stddev 23.012
progress: 360.0 s, 926.5 tps, lat 8.487 ms stddev 23.097
progress: 420.0 s, 929.6 tps, lat 8.450 ms stddev 23.058
progress: 480.0 s, 901.8 tps, lat 8.714 ms stddev 23.390
progress: 540.0 s, 914.0 tps, lat 8.601 ms stddev 23.266
progress: 600.0 s, 924.0 tps, lat 8.481 ms stddev 23.061
transaction type: <builtin: TPC-B (sort of)>
scaling factor: 1
query mode: simple
number of clients: 8
number of threads: 1
duration: 600 s
number of transactions actually processed: 661615
latency average = 7.116 ms
latency stddev = 19.048 ms
tps = 1102.659890 (including connections establishing)
tps = 1102.664521 (excluding connections establishing)
```

Результат связан с тем, что нет постоянного ожидания записи на диск

Попробовал также выставлять fsync=off - тоже быстрее начинает работать


#### 6. Создайте новый кластер с включенной контрольной суммой страниц. Создайте таблицу. Вставьте несколько значений. Выключите кластер. Измените пару байт в таблице. Включите кластер и сделайте выборку из таблицы. Что и почему произошло? как проигнорировать ошибку и продолжить работу?

```
pg_createcluster 13 crc -- --data-checksum
pg_ctlcluster 13 crc start
psql -p 5433

postgres=# insert into test values(2);
postgres=# insert into test values(3);
postgres=# insert into test values(4);
postgres=# insert into test values(5);

postgres=# SELECT pg_relation_filepath('test');
 pg_relation_filepath
----------------------
 base/13414/16384
(1 row)

postgres=# \q

pg_ctlcluster 13 crc stop
```

редактируем данные в файле и запускаем кластер

```
dd if=/dev/zero of=/var/lib/postgresql/13/crc/base/13414/16384 oflag=dsync conv=notrunc bs=1 count=8
pg_ctlcluster 13 crc start
psql -p 5433

postgres=# select * from test;
WARNING:  page verification failed, calculated checksum 65150 but expected 387
ERROR:  invalid page in block 0 of relation base/13414/16384

postgres=# SET ignore_checksum_failure = on;
SET
postgres=# select * from test;
WARNING:  page verification failed, calculated checksum 14033 but expected 13567
 a
---
 2
 3
 4
 5
(4 rows)
```
