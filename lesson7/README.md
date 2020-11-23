#### - настроит параметры autovacuum для достижения максимального уровня устойчивой производительности
#### - создать GCE инстанс типа e2-medium и standard disk 10GB
#### - установить на него PostgreSQL 13 с дефолтными настройками
#### - применить параметры настройки PostgreSQL из прикрепленного к материалам занятия файла

```
max_connections = 40
shared_buffers = 1GB
effective_cache_size = 3GB
maintenance_work_mem = 512MB
checkpoint_completion_target = 0.9
wal_buffers = 16MB
default_statistics_target = 500
random_page_cost = 4
effective_io_concurrency = 2
work_mem = 6553kB
min_wal_size = 4GB
max_wal_size = 16GB
```

#### - выполнить pgbench -i postgres
#### - запустить pgbench -c8 -P 60 -T 3600 -U postgres postgres
#### - дать отработать до конца
#### - зафиксировать среднее значение tps в последней ⅙ части работы

```
progress: 3060.0 s, 439.0 tps, lat 18.124 ms stddev 26.297
progress: 3120.0 s, 438.6 tps, lat 18.128 ms stddev 26.431
progress: 3180.0 s, 424.2 tps, lat 18.761 ms stddev 27.005
progress: 3240.0 s, 441.4 tps, lat 18.048 ms stddev 26.776
progress: 3300.0 s, 395.5 tps, lat 20.120 ms stddev 28.116
progress: 3360.0 s, 435.3 tps, lat 18.271 ms stddev 26.625
progress: 3420.0 s, 430.8 tps, lat 18.465 ms stddev 26.519
progress: 3480.0 s, 417.5 tps, lat 19.049 ms stddev 26.993
progress: 3540.0 s, 436.4 tps, lat 18.230 ms stddev 26.748
progress: 3600.0 s, 430.0 tps, lat 18.462 ms stddev 26.830
```

Среднее значение: 429

#### - а дальше настроить autovacuum максимально эффективно
#### - так чтобы получить максимально ровное значение tps на горизонте часа

Попробовал применить параметры и перезапустить БД

```
log_autovacuum_min_duration = 0
autovacuum_max_workers = 10
autovacuum_naptime = 15s
autovacuum_vacuum_threshold = 25
autovacuum_vacuum_scale_factor = 0.1
autovacuum_vacuum_cost_delay = 10
autovacuum_vacuum_cost_limit = 1000
```

и вот что получилось

```
progress: 3060.0 s, 441.1 tps, lat 18.042 ms stddev 26.654
progress: 3120.0 s, 431.9 tps, lat 18.442 ms stddev 26.884
progress: 3180.0 s, 441.1 tps, lat 18.034 ms stddev 26.462
progress: 3240.0 s, 438.7 tps, lat 18.127 ms stddev 26.729
progress: 3300.0 s, 389.3 tps, lat 20.465 ms stddev 28.678
progress: 3360.0 s, 495.6 tps, lat 16.081 ms stddev 21.455
progress: 3420.0 s, 439.3 tps, lat 18.110 ms stddev 26.894
progress: 3480.0 s, 437.9 tps, lat 18.185 ms stddev 26.941
progress: 3540.0 s, 436.2 tps, lat 18.259 ms stddev 26.659
progress: 3600.0 s, 436.8 tps, lat 18.224 ms stddev 26.597
```

Среднее значение: 438
