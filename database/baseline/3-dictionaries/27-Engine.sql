CREATE TABLE "Engine"
  ( id    SERIAL PRIMARY KEY
  , label text UNIQUE NOT NULL
  , synonyms text[]
  );

GRANT ALL ON "Engine" TO carma_db_sync;
GRANT ALL ON "Engine" TO carma_search;
GRANT ALL ON "Engine_id_seq" TO carma_db_sync;
GRANT ALL ON "Engine_id_seq" TO carma_search;

COPY "Engine" (id, label, synonyms) FROM stdin;
1	Бензин	{TSI,FSI,TFSI,HPI,CGI,JTS,IDE,GDI}
2	Дизель	{TDI,SDI,HDI,CRDI,TDCI,DCI,CDI,CDTI,JTD}
\.
