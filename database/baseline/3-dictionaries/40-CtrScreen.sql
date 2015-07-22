create table "CtrScreen" (
  id       SERIAL PRIMARY KEY,
  value    text NOT NULL,
  label    text NOT NULL
);

insert into "CtrScreen" (id, value, label) values
 (1, 'new', 'Экран создания кейса')
,(2, 'full', 'Полный экран кейса')
;

GRANT ALL ON "CtrScreen" TO carma_db_sync;
GRANT ALL ON "CtrScreen_id_seq" TO carma_db_sync;
