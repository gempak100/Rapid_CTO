\set ON_ERROR_STOP 0
select id as kamal from profiles where staff_no='10090001' \gset
select id as ahmad from profiles where staff_no='10090012' \gset
select id as siti from profiles where staff_no='10090015' \gset
select c.id as ca from claims c where user_id=:'ahmad' and period='H1' \gset
select c.id as cs from claims c where user_id=:'siti' and period='H1' \gset
-- sebagai AHMAD
set role authenticated; select set_config('request.jwt.claim.sub',:'ahmad',false);
\echo '--- Ahmad nampak berapa claim (patut 2):'
select count(*) from claims;
\echo '--- Ahmad nampak profil (patut 2: diri + leader):'
select staff_no from profiles order by 1;
\echo '--- Ahmad cuba baca baris Siti (patut 0):'
select count(*) from claim_rows where claim_id=:cs;
\echo '--- Ahmad cuba update terus (patut ditolak):'
update claim_rows set jam=99 where claim_id=:ca;
\echo '--- Ahmad cuba sahkan sendiri (patut ralat):'
select approve_claim(:ca);
\echo '--- Ahmad ubah sebelum hantar (patut ralat dikunci/draft):'
select user_edit_row(:ca,12,'1500','1600');
\echo '--- Ahmad hantar:'
select submit_claim(:ca);
\echo '--- Ahmad cuba hantar claim Siti (patut ralat):'
select submit_claim(:cs);
-- sebagai KAMAL
reset role; set role authenticated; select set_config('request.jwt.claim.sub',:'kamal',false);
\echo '--- Kamal nampak claim (patut 8):'
select count(*) from claims;
select leader_edit(:ca,12,'ot','OT To','1600','ikut punch card');
select ot,jam from claim_rows where claim_id=:ca and day=12;
select approve_claim(:ca);
select status from claims where id=:ca;
-- Ahmad cuba ubah selepas dikunci
reset role; set role authenticated; select set_config('request.jwt.claim.sub',:'ahmad',false);
\echo '--- Ahmad ubah selepas sah (patut ralat dikunci):'
select user_edit_row(:ca,14,'2430','2630');
select request_unlock(:ca,'14hb ada OT tambahan');
reset role; set role authenticated; select set_config('request.jwt.claim.sub',:'kamal',false);
select decide_unlock(:ca,true);
reset role; set role authenticated; select set_config('request.jwt.claim.sub',:'ahmad',false);
select user_edit_row(:ca,14,'2430','2630');
select submit_claim(:ca);
select status from claims where id=:ca;
select title,msg from notifications order by id;
\echo '--- anon (tak log masuk):'
reset role; set role anon; select set_config('request.jwt.claim.sub','',false);
select count(*) from claims;
select submit_claim(:ca);
reset role;
select msg from claim_log where claim_id=:ca order by id;
