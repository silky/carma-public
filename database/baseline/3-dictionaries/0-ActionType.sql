CREATE TABLE "ActionType"
  ( id    SERIAL PRIMARY KEY
  , label text NOT NULL CHECK (label <> '')
  , description text NOT NULL DEFAULT ''
  , priority int4 NOT NULL
  , limSeconds int4 NOT NULL DEFAULT 300
  );

INSERT INTO "ActionType" (label, id, priority)
VALUES ('Заказ услуги', 1, 2);

INSERT INTO "ActionType" (label, id, priority)
VALUES ('Заказ вторичной услуги', 2, 2);

INSERT INTO "ActionType" (label, id, priority)
VALUES ('Сообщить клиенту о договорённости', 3, 2);

INSERT INTO "ActionType" (label, id, priority)
VALUES ('Уточнить статус оказания услуги', 4, 4);

INSERT INTO "ActionType" (label, id, priority)
VALUES ('Оповестить клиента о поиске партнёра', 5, 2);

INSERT INTO "ActionType" (label, id, priority)
VALUES ('Уточнения после оказания услуги', 6, 2);

INSERT INTO "ActionType" (label, id, priority)
VALUES ('Закрыть заявку', 7, 4);

INSERT INTO "ActionType" (label, id, priority)
VALUES ('Уточнить информацию о ремонте у дилера/партнёра (VW, PSA)', 8, 4);

INSERT INTO "ActionType" (label, id, priority)
VALUES ('Отказ от услуги', 9, 2);

INSERT INTO "ActionType" (label, id, priority)
VALUES ('Согласование с производителем', 10, 2);

INSERT INTO "ActionType" (label, id, priority)
VALUES ('Оповещение клиента об отказе производителя', 11, 2);

INSERT INTO "ActionType" (label, id, priority)
VALUES ('Прикрепить счёт', 12, 2);

INSERT INTO "ActionType" (label, id, priority)
VALUES ('Менеджер по счетам запросил доп. информацию', 13, 4);

INSERT INTO "ActionType" (label, id, priority)
VALUES ('Проверка РКЦ', 14, 2);

INSERT INTO "ActionType" (label, id, priority)
VALUES ('Проверка директором', 15, 2);

INSERT INTO "ActionType" (label, id, priority)
VALUES ('Проверка бухгалтерией', 16, 2);

INSERT INTO "ActionType" (label, id, priority)
VALUES ('Обработка аналитиком', 17, 2);

INSERT INTO "ActionType" (label, id, priority)
VALUES ('Претензия', 18, 2);

INSERT INTO "ActionType" (label, id, priority)
VALUES ('Требуется дополнительная информация', 19, 2);

INSERT INTO "ActionType" (label, id, priority)
VALUES ('Заказ услуги через мобильное приложение', 20, 2);

INSERT INTO "ActionType" (label, id, priority)
VALUES ('Уточнить время выезда', 21, 2);

INSERT INTO "ActionType" (label, id, priority)
VALUES ('ДТП', 22, 1);

INSERT INTO "ActionType" (label, id, priority, description)
VALUES ('Согласовать опоздание партнёра', 23, 1,
  'Требуется согласовать время опоздания партнёра с клиентом');

INSERT INTO "ActionType" (label, id, priority)
VALUES ('Звонок', 100, 2);

INSERT INTO "ActionType" (label, id, priority)
VALUES ('Действие не актуально (архив)', 9000, 10);

SELECT setval(pg_get_serial_sequence('"ActionType"', 'id'), max(id)) from "ActionType";

GRANT ALL ON "ActionType" TO carma_db_sync;
