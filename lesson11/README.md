## Нагрузочное тестирование и тюнинг PostgreSQL
Цель: - делать нагрузочное тестирование PostgreSQL
• настраивать параметры PostgreSQL для достижения максимальной производительности
• сделать проект <firstname>-<lastname>-<yyyymmdd>-10
• сделать инстанс Google Cloud Engine типа e2-medium с ОС Ubuntu 20.04
• поставить на него PostgreSQL 13 из пакетов собираемых postgres.org
• настроить кластер PostgreSQL 13 на максимальную производительность не
обращая внимание на возможные проблемы с надежностью в случае
аварийной перезагрузки виртуальной машины
• нагрузить кластер через утилиту
https://github.com/Percona-Lab/sysbench-tpcc (требует установки
https://github.com/akopytov/sysbench)
• написать какого значения tps удалось достичь, показать какие параметры в
какие значения устанавливали и почему

Создадим instance psotgresql (e2-med) c hdd диском на 100 Гб

Небольшая настройка postgresql:
```
echo "
host    postgres     all             10.166.15.204/32                 md5
" >> /etc/postgresql/13/main/pg_hba.conf
echo "listen_addresses = '0.0.0.0'" >> /etc/postgresql/13/main/postgresql.conf
systemctl restart postgresql
```

Устанавливаем фреймворк тестирования на соседней машине:

```
curl -s https://packagecloud.io/install/repositories/akopytov/sysbench/script.deb.sh | sudo bash
sudo apt -y install sysbench
curl -Lo f.zip https://github.com/Percona-Lab/sysbench-tpcc/archive/master.zip
unzip f.zip
```

Запустим скрипт подготовки БД

```
./tpcc.lua --pgsql-user=postgres --pgsql-password=asd_786 --pgsql-db=postgres --pgsql-host=10.166.15.206 --pgsql-port=5432 --time=60 --threads=10 --report-interval=1 --tables=10 --scale=1 --db-driver=pgsql prepare
```

Первоначально проведем тесты без оптимизации, чтобы было с чем сравнивать

```
./tpcc.lua --pgsql-user=postgres --pgsql-password=asd_786 --pgsql-db=postgres --pgsql-host=10.166.15.206 --pgsql-port=5432 --time=60 --threads=10 --report-interval=1 --tables=10 --scale=1 --db-driver=pgsql run
...

[ 51s ] thds: 10 tps: 303.04 qps: 8670.06 (r/w/o: 3923.48/4054.50/692.08) lat (ms,95%): 77.19 err/s 46.01 reconn/s: 0.00
[ 52s ] thds: 10 tps: 276.98 qps: 8688.42 (r/w/o: 3938.73/4141.72/607.96) lat (ms,95%): 82.96 err/s 26.00 reconn/s: 0.00
[ 53s ] thds: 10 tps: 189.04 qps: 6080.41 (r/w/o: 2791.65/2848.66/440.10) lat (ms,95%): 127.81 err/s 31.01 reconn/s: 0.00
[ 54s ] thds: 10 tps: 216.97 qps: 6830.06 (r/w/o: 3119.57/3228.55/481.93) lat (ms,95%): 90.78 err/s 25.00 reconn/s: 0.00
[ 55s ] thds: 10 tps: 240.03 qps: 7261.05 (r/w/o: 3277.47/3425.50/558.08) lat (ms,95%): 86.00 err/s 41.01 reconn/s: 0.00
[ 56s ] thds: 10 tps: 275.02 qps: 7498.60 (r/w/o: 3384.27/3456.28/658.05) lat (ms,95%): 78.60 err/s 56.00 reconn/s: 0.00
[ 57s ] thds: 10 tps: 223.94 qps: 6395.30 (r/w/o: 2870.24/3007.20/517.86) lat (ms,95%): 89.16 err/s 37.99 reconn/s: 0.00
[ 58s ] thds: 10 tps: 254.03 qps: 7747.95 (r/w/o: 3505.43/3650.45/592.07) lat (ms,95%): 81.48 err/s 41.01 reconn/s: 0.00
[ 59s ] thds: 10 tps: 281.96 qps: 8754.82 (r/w/o: 3995.46/4121.44/637.91) lat (ms,95%): 80.03 err/s 37.99 reconn/s: 0.00
[ 60s ] thds: 10 tps: 267.02 qps: 7996.57 (r/w/o: 3608.26/3779.27/609.04) lat (ms,95%): 84.47 err/s 42.00 reconn/s: 0.00
SQL statistics:
    queries performed:
        read:                            232799
        write:                           241045
        other:                           38708
        total:                           512552
    transactions:                        17134  (285.18 per sec.)
    queries:                             512552 (8531.06 per sec.)
    ignored errors:                      2285   (38.03 per sec.)
    reconnects:                          0      (0.00 per sec.)

General statistics:
    total time:                          60.0791s
    total number of events:              17134

Latency (ms):
         min:                                    1.44
         avg:                                   35.04
         max:                                  192.71
         95th percentile:                       80.03
         sum:                               600333.50

Threads fairness:
    events (avg/stddev):           1713.4000/42.03
    execution time (avg/stddev):   60.0333/0.02

```

Выполним очистку данных.

```
./tpcc.lua --pgsql-user=postgres --pgsql-password=asd_786 --pgsql-db=postgres --pgsql-host=10.166.15.206 --pgsql-port=5432  --time=60 --threads=10 --report-interval=1 --tables=10 --scale=100 --db-driver=pgsql cleanup
```

Далее выполним настройку БД в соответствии с рекомендациями конфигуратора

```
max_connections = 20
shared_buffers = 1GB
effective_cache_size = 3GB
maintenance_work_mem = 512MB
checkpoint_completion_target = 0.9
wal_buffers = 16MB
default_statistics_target = 500
random_page_cost = 4
effective_io_concurrency = 2
work_mem = 26214kB
min_wal_size = 4GB
max_wal_size = 16GB
```

и перезапустим БД

Сделаем подготовку таблиц и запустим тест заново

```
[ 42s ] thds: 10 tps: 331.02 qps: 10172.63 (r/w/o: 4617.29/4810.30/745.05) lat (ms,95%): 71.83 err/s 43.00 reconn/s: 0.00
[ 43s ] thds: 10 tps: 342.98 qps: 10035.35 (r/w/o: 4554.70/4716.69/763.95) lat (ms,95%): 71.83 err/s 40.00 reconn/s: 0.00
[ 44s ] thds: 10 tps: 339.03 qps: 10131.96 (r/w/o: 4617.44/4758.45/756.07) lat (ms,95%): 71.83 err/s 43.00 reconn/s: 0.00
[ 45s ] thds: 10 tps: 356.04 qps: 10138.04 (r/w/o: 4567.47/4766.49/804.08) lat (ms,95%): 71.83 err/s 47.00 reconn/s: 0.00
[ 46s ] thds: 10 tps: 364.88 qps: 10231.74 (r/w/o: 4623.53/4768.48/839.73) lat (ms,95%): 66.84 err/s 56.98 reconn/s: 0.00
[ 47s ] thds: 10 tps: 358.07 qps: 10182.11 (r/w/o: 4630.96/4742.99/808.17) lat (ms,95%): 70.55 err/s 47.01 reconn/s: 0.00
[ 48s ] thds: 10 tps: 333.00 qps: 10159.11 (r/w/o: 4609.05/4806.05/744.01) lat (ms,95%): 75.82 err/s 40.00 reconn/s: 0.00
[ 49s ] thds: 10 tps: 374.93 qps: 10053.20 (r/w/o: 4522.19/4671.16/859.85) lat (ms,95%): 71.83 err/s 55.99 reconn/s: 0.00
[ 50s ] thds: 10 tps: 344.01 qps: 10408.21 (r/w/o: 4730.09/4916.10/762.02) lat (ms,95%): 69.29 err/s 40.00 reconn/s: 0.00
[ 51s ] thds: 10 tps: 344.91 qps: 10190.22 (r/w/o: 4622.74/4795.69/771.79) lat (ms,95%): 73.13 err/s 43.99 reconn/s: 0.00
[ 52s ] thds: 10 tps: 337.12 qps: 9789.44 (r/w/o: 4451.56/4577.61/760.27) lat (ms,95%): 69.29 err/s 44.02 reconn/s: 0.00
[ 53s ] thds: 10 tps: 352.00 qps: 9613.10 (r/w/o: 4318.04/4493.05/802.01) lat (ms,95%): 77.19 err/s 50.00 reconn/s: 0.00
[ 54s ] thds: 10 tps: 353.98 qps: 10384.52 (r/w/o: 4686.79/4889.78/807.96) lat (ms,95%): 64.47 err/s 52.00 reconn/s: 0.00
[ 55s ] thds: 10 tps: 342.00 qps: 10008.11 (r/w/o: 4549.05/4685.05/774.01) lat (ms,95%): 71.83 err/s 46.00 reconn/s: 0.00
[ 56s ] thds: 10 tps: 319.07 qps: 9448.96 (r/w/o: 4297.89/4432.92/718.15) lat (ms,95%): 75.82 err/s 44.01 reconn/s: 0.00
[ 57s ] thds: 10 tps: 281.95 qps: 8410.55 (r/w/o: 3806.34/3980.31/623.89) lat (ms,95%): 84.47 err/s 30.99 reconn/s: 0.00
[ 58s ] thds: 10 tps: 290.98 qps: 8423.35 (r/w/o: 3789.71/3964.69/668.95) lat (ms,95%): 94.10 err/s 45.00 reconn/s: 0.00
[ 59s ] thds: 10 tps: 273.04 qps: 8455.21 (r/w/o: 3837.55/4000.57/617.09) lat (ms,95%): 87.56 err/s 34.00 reconn/s: 0.00
[ 60s ] thds: 10 tps: 275.95 qps: 8222.45 (r/w/o: 3710.30/3900.26/611.88) lat (ms,95%): 97.55 err/s 29.99 reconn/s: 0.00
SQL statistics:
    queries performed:
        read:                            267568
        write:                           277363
        other:                           44788
        total:                           589719
    transactions:                        19924  (331.49 per sec.)
    queries:                             589719 (9811.53 per sec.)
    ignored errors:                      2559   (42.58 per sec.)
    reconnects:                          0      (0.00 per sec.)

General statistics:
    total time:                          60.1031s
    total number of events:              19924

Latency (ms):
         min:                                    1.61
         avg:                                   30.13
         max:                                  218.06
         95th percentile:                       74.46
         sum:                               600365.51

Threads fairness:
    events (avg/stddev):           1992.4000/109.28
    execution time (avg/stddev):   60.0366/0.03
```

Получили небольшой прирост производительности
