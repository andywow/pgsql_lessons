# PG SQL vs Clickhouse

Создадим VM - e2-mid, 60 Gb SSD (в регионе US для ускорения процесса закачки)

склонируем репозиторий на VM и скачаем небольшую часть архива поездок (10 Gb)

```
git clone https://github.com/toddwschneider/nyc-taxi-data.git
cd nyc-taxi-data
mv setup_files/raw_data_urls.txt setup_files/raw_data_urls.txt.backup
tail -20 setup_files/raw_data_urls.txt.backup > setup_files/raw_data_urls.txt
./download_raw_data.sh
...
du -ms data
10301	data
```

Установим postgresql 13 и расширение postgis на машину и потюним его:

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
synchronous_commit = off
```

Проинициализируем таблицы для загрузки:

```
./initialize_database.sh
...
CREATE INDEX
COPY 1097
COPY 4017
UPDATE 0
```

Запустим импорт данных

```
./import_trip_data.sh
```

После импорта смотрим размер занятых данных

```
nyc-taxi-data=£ \dt+
                                           List of relations
 Schema |               Name                | Type  |  Owner   | Persistence |    Size    | Description
--------+-----------------------------------+-------+----------+-------------+------------+-------------
 public | cab_types                         | table | postgres | permanent   | 16 kB      |
 public | central_park_weather_observations | table | postgres | permanent   | 440 kB     |
 public | fhv_bases                         | table | postgres | permanent   | 120 kB     |
 public | fhv_trips                         | table | postgres | permanent   | 8192 bytes |
 public | fhv_trips_staging                 | table | postgres | permanent   | 8192 bytes |
 public | green_tripdata_staging            | table | postgres | permanent   | 8192 bytes |
 public | hvfhs_licenses                    | table | postgres | permanent   | 16 kB      |
 public | nyct2010                          | table | postgres | permanent   | 3040 kB    |
 public | nyct2010_taxi_zones_mapping       | table | postgres | permanent   | 128 kB     |
 public | spatial_ref_sys                   | table | postgres | permanent   | 6976 kB    |
 public | taxi_zones                        | table | postgres | permanent   | 1776 kB    |
 public | trips                             | table | postgres | permanent   | 16 GB      |
 public | uber_trips_2014                   | table | postgres | permanent   | 8192 bytes |
 public | yellow_tripdata_staging           | table | postgres | permanent   | 8192 bytes |
(14 rows)
```

Пробуем сделать запрос из урока на БД:

```
nyc-taxi-data=£ \timing
nyc-taxi-data=£ SELECT payment_type, round(sum(tip_amount)/sum(total_amount)*100, 0) + 0 as tips_percent, count(*) as c from trips group by payment_type order by 3;
 payment_type | tips_percent |    c
--------------+--------------+----------
 5            |            1 |       47
 4            |            0 |   264230
              |            1 |   527484
 3            |            1 |   621515
 2            |            0 | 31980318
 1            |           15 | 84171598
(6 rows)
Time: 481006.150 ms (08:01.006)
```

Теперь попробуем тоже самое в БД clickhouse. Экспортируем данные из БД postgres в CSV:

```
COPY
(
    SELECT trips.id,
           trips.vendor_id,
           trips.pickup_datetime,
           trips.dropoff_datetime,
           trips.store_and_fwd_flag,
           trips.rate_code_id,
           trips.pickup_longitude,
           trips.pickup_latitude,
           trips.dropoff_longitude,
           trips.dropoff_latitude,
           trips.passenger_count,
           trips.trip_distance,
           trips.fare_amount,
           trips.extra,
           trips.mta_tax,
           trips.tip_amount,
           trips.tolls_amount,
           trips.ehail_fee,
           trips.improvement_surcharge,
           trips.total_amount,
           trips.payment_type,
           trips.trip_type,

           cab_types.type cab_type,

           pick_up.gid pickup_nyct2010_gid,
           pick_up.ctlabel pickup_ctlabel,
           pick_up.borocode pickup_borocode,
           pick_up.boroname pickup_boroname,
           pick_up.ct2010 pickup_ct2010,
           pick_up.boroct2010 pickup_boroct2010,
           pick_up.cdeligibil pickup_cdeligibil,
           pick_up.ntacode pickup_ntacode,
           pick_up.ntaname pickup_ntaname,
           pick_up.puma pickup_puma,

           drop_off.gid dropoff_nyct2010_gid,
           drop_off.ctlabel dropoff_ctlabel,
           drop_off.borocode dropoff_borocode,
           drop_off.boroname dropoff_boroname,
           drop_off.ct2010 dropoff_ct2010,
           drop_off.boroct2010 dropoff_boroct2010,
           drop_off.cdeligibil dropoff_cdeligibil,
           drop_off.ntacode dropoff_ntacode,
           drop_off.ntaname dropoff_ntaname,
           drop_off.puma dropoff_puma
    FROM trips
    LEFT JOIN cab_types
        ON trips.cab_type_id = cab_types.id
    LEFT JOIN nyct2010 pick_up
        ON pick_up.gid = trips.pickup_nyct2010_gid
    LEFT JOIN nyct2010 drop_off
        ON drop_off.gid = trips.dropoff_nyct2010_gid
) TO '/tmp/pgexport.csv';
COPY 117565192
Time: 938005.180 ms (15:38.005)
```

Скопируем данный файл rsync-ом на VM c clickhouse.
Создадим в Clickhouse временную таблицу:

```
CREATE TABLE trips
(
trip_id                 UInt32,
vendor_id               String,
pickup_datetime         DateTime,
dropoff_datetime        Nullable(DateTime),
store_and_fwd_flag      Nullable(FixedString(1)),
rate_code_id            Nullable(UInt8),
pickup_longitude        Nullable(Float64),
pickup_latitude         Nullable(Float64),
dropoff_longitude       Nullable(Float64),
dropoff_latitude        Nullable(Float64),
passenger_count         Nullable(UInt8),
trip_distance           Nullable(Float64),
fare_amount             Nullable(Float32),
extra                   Nullable(Float32),
mta_tax                 Nullable(Float32),
tip_amount              Nullable(Float32),
tolls_amount            Nullable(Float32),
ehail_fee               Nullable(Float32),
improvement_surcharge   Nullable(Float32),
total_amount            Nullable(Float32),
payment_type            Nullable(String),
trip_type               Nullable(UInt8),
cab_type                Nullable(String),
pickup_nyct2010_gid     Nullable(UInt8),
pickup_ctlabel          Nullable(String),
pickup_borocode         Nullable(UInt8),
pickup_boroname         Nullable(String),
pickup_ct2010           Nullable(String),
pickup_boroct2010       Nullable(String),
pickup_cdeligibil       Nullable(FixedString(1)),
pickup_ntacode          Nullable(String),
pickup_ntaname          Nullable(String),
pickup_puma             Nullable(String),
dropoff_nyct2010_gid    Nullable(UInt8),
dropoff_ctlabel         Nullable(String),
dropoff_borocode        Nullable(UInt8),
dropoff_boroname        Nullable(String),
dropoff_ct2010          Nullable(String),
dropoff_boroct2010      Nullable(String),
dropoff_cdeligibil      Nullable(String),
dropoff_ntacode         Nullable(String),
dropoff_ntaname         Nullable(String),
dropoff_puma            Nullable(String)
) ENGINE = Log;
```

импортируем данные из CSV в Clickhouse:
```
clickhouse client --query "INSERT INTO trips FORMAT TabSeparated" < pgexport.csv
```

Сделаем запрос из таблицы данного типа
```
clickhouse.us-central1-a.c.postgres2020-19870421.internal :) SELECT payment_type, round(sum(tip_amount)/sum(total_amount)*100, 0) + 0 as tips_percent, count(*) as c from trips group by payment_type order by 3;

SELECT
    payment_type,
    round((sum(tip_amount) / sum(total_amount)) * 100, 0) + 0 AS tips_percent,
    count(*) AS c
FROM trips
GROUP BY payment_type
ORDER BY 3 ASC

Query id: 3c9779c2-6f57-49c3-82a5-f63baf3f1bec

┌─payment_type─┬─tips_percent─┬────────c─┐
│ 3            │            1 │   621515 │
│ 5            │            1 │       47 │
│ ᴺᵁᴸᴸ         │            1 │   527484 │
│ 4            │            0 │   264230 │
│ 2            │            0 │ 31980318 │
│ 1            │           15 │ 84171598 │
└──────────────┴──────────────┴──────────┘

6 rows in set. Elapsed: 18.920 sec. Processed 117.57 million rows, 2.47 GB (6.21 million rows/s., 130.46 MB/s.)
```
