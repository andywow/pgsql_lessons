#### На 1 ВМ создаем таблицы test для записи, test2 для запросов на чтение. Создаем публикацию таблицы test и подписываемся на публикацию таблицы test2 с ВМ №2.

```
# vm1 - postgres
alter user postgres with password 'asd_786';
alter system set wal_level = logical;

# vm1 - console
echo "
host    postgres     all             10.166.15.200/32                 md5
host    postgres     all             10.166.15.201/32                 md5
" >> /etc/postgresql/13/main/pg_hba.conf
echo "listen_addresses = '0.0.0.0'" >> /etc/postgresql/13/main/postgresql.conf
systemctl restart postgresql

# vm1 - postgres
create table test(a int);
create table test2(a int);
create publication test_pub for table test;
create subscription test_sub
connection 'host=10.166.15.200 port=5432 user=postgres password=asd_786 dbname=postgres'
publication test_pub WITH (copy_data = false);
```

####  На 2 ВМ создаем таблицы test2 для записи, test для запросов на чтение. Создаем публикацию таблицы test2 и подписываемся на публикацию таблицы test1 с ВМ №1.

```
# vm2 - postgres
alter user postgres with password 'asd_786';
alter system set wal_level = logical;

# vm2 - console
echo "
host    postgres     all             10.166.15.199/32                 md5
host    postgres     all             10.166.15.201/32                 md5
" >> /etc/postgresql/13/main/pg_hba.conf
echo "listen_addresses = '0.0.0.0'" >> /etc/postgresql/13/main/postgresql.conf
systemctl restart postgresql

# vm2 - postgres
create table test(a int);
create table test2(a int);
create publication test_pub for table test2;
create subscription test_sub
connection 'host=10.166.15.199 port=5432 user=postgres password=asd_786 dbname=postgres'
publication test_pub WITH (copy_data = false);
```

Попробовал вставить пару записей в таблицы - репликация работает на обоих таблицах

#### 3 ВМ использовать как реплику для чтения и бэкапов (подписаться на таблицы из ВМ №1 и №2 ). Небольшое описание, того, что получилось.

```
# vm3 - postgres
alter user postgres with password 'asd_786';
alter system set wal_level = logical;

# vm3 - console
echo "
host    postgres     all             10.166.15.199/32                 md5
host    postgres     all             10.166.15.200/32                 md5
" >> /etc/postgresql/13/main/pg_hba.conf
echo "listen_addresses = '0.0.0.0'" >> /etc/postgresql/13/main/postgresql.conf
systemctl restart postgresql
```

```
# vm3 - postgres
create table test(a int);
create table test2(a int);
create subscription test01_sub
connection 'host=10.166.15.199 port=5432 user=postgres password=asd_786 dbname=postgres'
publication test_pub WITH (copy_data = false);
create subscription test02_sub
connection 'host=10.166.15.200 port=5432 user=postgres password=asd_786 dbname=postgres'
publication test_pub WITH (copy_data = false);
```

Попробовал добавить пару записей в таблицы на первых двух хостах - репликация работает

#### * реализовать горячее реплицирование для высокой доступности на 4ВМ. Источником должна выступать ВМ №3. Написать с какими проблемами столкнулись.

```
# vm3 - console
echo "
host    replication     all             10.166.15.202/32                 md5
" >> /etc/postgresql/13/main/pg_hba.conf
systemctl restart postgresql
```

```
# vm4 - console
pg_createcluster -d /var/lib/postgresql/13/backup 13 backup
rm -rf /var/lib/postgresql/13/backup
pg_basebackup -D /var/lib/postgresql/13/backup -h 10.166.15.201 -U postgres -R
echo 'port = 5433' >> /var/lib/postgresql/13/backup/postgresql.auto.conf
pg_ctlcluster 13 backup start
```

Кластер запущен - попробовал вставить значения в обе таблицы на vm1 и vm2 - получаем результаты на vm4.
