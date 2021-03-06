CREATE TABLE "SmsTemplate"
  (id       SERIAL PRIMARY KEY
  ,label    text NOT NULL DEFAULT ''
  ,text     text NOT NULL DEFAULT ''
  ,isActive bool NOT NULL DEFAULT false
  );

GRANT ALL ON "SmsTemplate" TO carma_db_sync;
GRANT ALL ON "SmsTemplate_id_seq" TO carma_db_sync;

insert into "SmsTemplate" (id, label, text, isActive) values
  (1, 'Сообщение о заказе услуги', 'Добрый день! Номер Вашей заявки $case.id$. Помощь прибудет к Вам в $service.times_expectedServiceStart$.', 't')
, (2, 'Сообщение в случае отказа от услуги', 'Спасибо за обращение на горячую линию $program_info$! Удачной дороги!', 't')
, (3, 'Финальное сообщение', 'Спасибо за обращение на горячую линию $program_info$! Удачной дороги!', 't')
, (4, 'По вашей просьбе создана заявка', 'По вашей просьбе создана заявка №$case.id$.', 't')
, (5, 'Эвакуатор приедет по адресу', 'Эвакуатор приедет по адресу: $case.caseAddress_address$.', 't')
, (6, 'Сообщение с контактами Дилера', 'Дилер [ВСТАВИТЬ НАЗВАНИЕ ДИЛЕРА] контактный тел. [ВСТАВИТЬ ТЕЛЕФОН ДИЛЕРА]. Адрес сервиса [ВСТАВИТЬ ФАКТИЧЕСКИЙ АДРЕС]. Часы работы [ВСТАВИТЬ ЧАСЫ РАБОТЫ]', 't')
, (7, 'Сообщение МпП', 'РАМК не может найти партнёра по  $service.type$ в городе $case.city$. Номер случая $case.id$.', 't')
, (8, 'Сообщение с просьбой перезвонить', 'Перезвоните, пожалуйста, на горячую линию $program_info$ по телефону $program_contact_info$', 't')
, (9, 'Сообщение с контактной информацией', '$program_info$ контактный телефон: $program_contact_info$', 't')
, (10,'Услуга "Трезвый водитель"', 'К вам прибыл Трезвый Водитель. Пожалуйста, перезвоните по номеру 88002501218 для подтверждения заказа услуги. Трезвый водитель будет вас ожидать в течении 15 минут, после чего заказ будет отменён', 't')
, (13,'Сообщение при создании кейса', 'Спасибо за обращение в $program_info$. Номер заявки $case.id$.', 't')
;

SELECT setval(pg_get_serial_sequence('"SmsTemplate"', 'id'), max(id)) from "SmsTemplate";
