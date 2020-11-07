**- посмотреть текущий уровень изоляции: show transaction isolation level**

read commited

**- начать новую транзакцию в обоих сессиях с дефолтным (не меняя) уровнем изоляции**

START TRANSACTION;

**- в первой сессии добавить новую запись**
**insert into persons(first_name, second_name) values('sergey', 'sergeev');**

**- сделать select * from persons во второй сессии**

**- видите ли вы новую запись и если да то почему?**

нет

**- завершить первую транзакцию - commit;**

COMMIT;

**- сделать select * from persons во второй сессии**
**- видите ли вы новую запись и если да то почему?**

да, т.к. у нас уровень изоляции read commited, который предполагает, что мы видим все закомиченные изменения

**- завершите транзакцию во второй сессии**
**- начать новые но уже repeatable read транзации - set transaction isolation level repeatable read;**

set transaction isolation level repeatable read;

**- в первой сессии добавить новую запись**
**insert into persons(first_name, second_name) values('sveta', 'svetova');**

insert into persons(first_name, second_name) values('sveta', 'svetova');

**- сделать select * from persons во второй сессии**
**- видите ли вы новую запись и если да то почему?**

нет

**- завершить первую транзакцию - commit;**

commit;

**- сделать select * from persons во второй сессии**
**- видите ли вы новую запись и если да то почему?**

нет

**- завершить вторую транзакцию**
**- сделать select * from persons во второй сессии**
**- видите ли вы новую запись и если да то почему?**

да, т.к. уровень изоляции repeatable read предполагает, что мы видим изменения только сделанные до начала нашей транзакции или внутри нашей транзакции. Изменения сделанные другими транзакциями мы не видим

**- остановите виртуальную машину но не удаляйте ее**