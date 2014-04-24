﻿CREATE OR REPLACE VIEW servicesview AS
 SELECT c.id AS caseid,
    c.calldate,
    c.calltaker,
    c.comment,
    c.diagnosis1,
    c.diagnosis2,
    c.diagnosis3,
    c.diagnosis4,
    c.contact_name,
    c.contact_phone1,
    c.contact_phone2,
    c.contact_phone3,
    c.contact_phone4,
    c.contact_email,
    c.contact_contactowner,
    c.contact_ownername,
    c.contact_ownerphone1,
    c.contact_ownerphone2,
    c.contact_ownerphone3,
    c.contact_ownerphone4,
    c.contact_owneremail,
    spgm.value AS program,
    (pgm.label || ' — '::text) || coalesce(spgm.label, '') AS programlabel,
    pt.label AS programtype,
    c.car_vin,
    c.car_make,
    c.car_model,
    c.car_platenum,
    c.car_makeyear,
    c.car_color,
    c.car_mileage,
    c.car_buydate::timestamp with time zone AS car_buydate,
    trans.label AS car_transmission,
    engine.label AS car_engine,
    c.car_liters,
    carcl.label AS car_class,
    c.vinchecked,
    c.caseaddress_address,
    c.caseaddress_comment,
    c.caseaddress_coords,
    c.city,
    c.temperature,
    c.dealercause,
    c.casestatus,
    c.claim,
    c.services,
    c.actions,
    c.files AS casefiles,
    c.comments,
    c.repair,
    s.type,
    s.id,
    s.parentid,
    s.createtime,
    s.paytype,
    s.payment_expectedcost,
    s.payment_costtranscript,
    s.payment_partnercost,
    s.payment_calculatedcost,
    s.payment_limitedcost,
    s.payment_overcosted,
    s.payment_paidbyruamc,
    s.payment_paidbyclient,
    s.times_expecteddispatch,
    s.times_expectedservicestart,
    s.times_factservicestart,
    s.times_expectedserviceend,
    s.times_factserviceend,
    s.times_expecteddealerinfo,
    s.times_factdealerinfo,
    s.times_expectedserviceclosure,
    s.times_factserviceclosure,
    s.falsecall,
    s.bill_billnumber,
    s.bill_billingcost,
    s.bill_billingdate,
    s.status,
    s.clientsatisfied,
    s.files,
    s.contractor_partner,
    s.contractor_partnerid,
    s.contractor_address,
    s.contractor_coords,
    s.warrantycase,
    s.paid,
    s.scan,
    s.original,
    t.towdealer_partner,
    t.suburbanmilage,
    t.providedfor,
    t.repairenddate,
    t.techtype,
    t.towtype,
    t.towaddress_address,
    t.assignedto AS backoperator,
    p1.code AS partner_code,
    p2.code AS dealer_code,
    p3.code AS seller_code,
    p3.name AS car_seller_name,
    p4.code AS to_dealer_code,
    p4.name AS car_dealerto_name,
    contract.cardnumber AS cardnumber_cardnumber,
    contract.validsince AS car_checkupdate,
    contract.validsince AS car_warrantystart,
    contract.validuntil AS car_warrantyend,
    contract.checkperiod AS car_checkperiod,
    contract.startmileage AS car_checkupmileage
   FROM casetbl c
   LEFT JOIN "Program" pgm ON c.program = pgm.id
   LEFT JOIN "ProgramType" pt ON pgm.ptype = pt.id
   LEFT JOIN "CarClass" carcl ON c.car_class = carcl.id
   LEFT JOIN "Engine" engine ON c.car_engine = engine.id
   LEFT JOIN "Transmission" trans ON c.car_transmission = trans.id
   LEFT JOIN "SubProgram" spgm ON c.subprogram = spgm.id
   LEFT JOIN partnertbl p3 ON c.car_seller = p3.id::text
   LEFT JOIN partnertbl p4 ON c.car_dealerto = p4.id::text
   LEFT JOIN "Contract" contract ON c.contract = contract.id,
    servicetbl s
   LEFT JOIN allservicesview t ON t.id = s.id AND t.type = s.type
   LEFT JOIN partnertbl p1 ON s.contractor_partnerid = ('partner:'::text || p1.id)
   LEFT JOIN partnertbl p2 ON t.towdealer_partnerid = ('partner:'::text || p2.id)
  WHERE c.id::text = "substring"(s.parentid, ':(.*)'::text);
