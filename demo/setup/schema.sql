-- =====================================================================
-- DEMO Fasa 2 · Semakan Claim Leader (data rekaan sahaja)
-- Jalankan sekali dalam Supabase > SQL Editor. Boleh dijalankan semula
-- (ia padam & bina semula semua objek demo).
-- =====================================================================
create extension if not exists pgcrypto;

-- buang objek demo lama (jika dijalankan semula)
drop table if exists public.notifications, public.claim_log, public.claim_edits, public.claim_rows, public.claims, public.profiles cascade;

-- ---------- Jadual ----------
create table public.profiles(
  id uuid primary key references auth.users(id) on delete cascade,
  staff_no text unique not null,
  name text not null,
  role text not null check (role in ('user','leader')),
  leader_id uuid references public.profiles(id)
);

create table public.claims(
  id bigserial primary key,
  user_id uuid not null references public.profiles(id) on delete cascade,
  period text not null,                 -- 'H1' (1-15) / 'H2' (16-30)
  status text not null default 'draft' check (status in ('draft','sent','fix','ok','req','open')),
  req_reason text,
  approved_at timestamptz,
  updated_at timestamptz not null default now(),
  unique(user_id,period)
);

create table public.claim_rows(
  id bigserial primary key,
  claim_id bigint not null references public.claims(id) on delete cascade,
  day int not null,
  descr text not null,
  wf text, wt text, of_ text, ot text,
  jam numeric(5,2), ph boolean not null default false,
  shift int, cto int,
  flag text, flag_key text, flag_col text,
  fixed_note text,
  unique(claim_id,day)
);

create table public.claim_edits(
  id bigserial primary key,
  claim_id bigint not null references public.claims(id) on delete cascade,
  day int not null, key text not null, label text not null,
  from_val text, to_val text, note text,
  by_role text not null, created_at timestamptz not null default now()
);

create table public.claim_log(
  id bigserial primary key,
  claim_id bigint not null references public.claims(id) on delete cascade,
  msg text not null, created_at timestamptz not null default now()
);

create table public.notifications(
  id bigserial primary key,
  to_user uuid not null references public.profiles(id) on delete cascade,
  title text not null, msg text not null,
  read boolean not null default false,
  created_at timestamptz not null default now()
);

-- ---------- Row Level Security: baca sahaja, semua tulisan melalui fungsi ----------
alter table public.profiles enable row level security;
alter table public.claims enable row level security;
alter table public.claim_rows enable row level security;
alter table public.claim_edits enable row level security;
alter table public.claim_log enable row level security;
alter table public.notifications enable row level security;

-- ---------- Pembantu ----------
create or replace function public._mins(t text) returns int language sql immutable as $$
  select (substr(t,1,2))::int*60 + (substr(t,3,2))::int $$;
create or replace function public._jam(f text,t text) returns numeric language sql immutable as $$
  select round((((public._mins(t)-public._mins(f))+1440)%1440)/60.0,2) $$;
create or replace function public._t4(v text) returns text language sql immutable as $$
  select lpad(right(regexp_replace(coalesce(v,''),'\D','','g'),4),4,'0') $$;
create or replace function public._stamp() returns text language sql stable as $$
  select to_char(now() at time zone 'Asia/Kuala_Lumpur','DD Mon, HH24MI') $$;

create or replace function public._claim(cid bigint) returns public.claims
language plpgsql security definer set search_path=public as $$
declare c claims; begin
  select * into c from claims where id=cid for update;
  if not found then raise exception 'Claim tiada'; end if;
  return c; end $$;

create or replace function public._is_owner(c public.claims) returns boolean
language sql stable as $$ select c.user_id=auth.uid() $$;
create or replace function public._is_leader(c public.claims) returns boolean
language sql stable security definer set search_path=public as $$
  select exists(select 1 from profiles p where p.id=c.user_id and p.leader_id=auth.uid()) $$;

create or replace function public._notify(uid uuid, t text, m text) returns void
language sql security definer set search_path=public as $$
  insert into notifications(to_user,title,msg) values(uid,t,m) $$;
create or replace function public._log(cid bigint, m text) returns void
language sql security definer set search_path=public as $$
  insert into claim_log(claim_id,msg) values(cid,m); update claims set updated_at=now() where id=cid $$;
create or replace function public._plabel(p text) returns text language sql immutable as $$
  select case p when 'H1' then 'separuh bulan (1–15 Nov)' else 'hujung bulan (16–30 Nov)' end $$;
create or replace function public._name(uid uuid) returns text
language sql stable security definer set search_path=public as $$ select name from profiles where id=uid $$;
create or replace function public._leader_of(uid uuid) returns uuid
language sql stable security definer set search_path=public as $$ select leader_id from profiles where id=uid $$;

-- ---------- Polisi baca ----------
-- boleh lihat claim: pemilik, atau leader kepada pemilik
create or replace function public.can_see_claim(cid bigint) returns boolean
language sql stable security definer set search_path=public as $$
  select exists(
    select 1 from claims c join profiles p on p.id=c.user_id
    where c.id=cid and (c.user_id=auth.uid() or p.leader_id=auth.uid()))
$$;

create policy prof_read on public.profiles for select to authenticated
  using (id=auth.uid() or leader_id=auth.uid() or id=public._leader_of(auth.uid()));
create policy claims_read on public.claims for select to authenticated using (public.can_see_claim(id));
create policy rows_read on public.claim_rows for select to authenticated using (public.can_see_claim(claim_id));
create policy edits_read on public.claim_edits for select to authenticated using (public.can_see_claim(claim_id));
create policy log_read on public.claim_log for select to authenticated using (public.can_see_claim(claim_id));
create policy notif_read on public.notifications for select to authenticated using (to_user=auth.uid());
-- Tiada polisi insert/update/delete: pelanggan tidak boleh tulis terus.
grant usage on schema public to authenticated;
grant select on public.profiles, public.claims, public.claim_rows, public.claim_edits, public.claim_log, public.notifications to authenticated;
revoke all on public.profiles, public.claims, public.claim_rows, public.claim_edits, public.claim_log, public.notifications from anon;
revoke insert, update, delete, truncate on public.profiles, public.claims, public.claim_rows, public.claim_edits, public.claim_log, public.notifications from authenticated;

-- ---------- Tindakan USER ----------
create or replace function public.submit_claim(cid bigint) returns void
language plpgsql security definer set search_path=public as $$
declare c claims := _claim(cid); again boolean; begin
  if not _is_owner(c) then raise exception 'Bukan claim anda'; end if;
  if c.status not in ('draft','fix','open') then raise exception 'Claim tidak boleh dihantar dalam status %', c.status; end if;
  if c.status='fix' and exists(select 1 from claim_rows where claim_id=cid and flag is not null) then
    raise exception 'Betulkan semua hari bertanda dahulu'; end if;
  again := c.status<>'draft';
  update claims set status='sent' where id=cid;
  perform _log(cid, (case when again then 'Dihantar semula ' else 'Dihantar ' end)||_stamp());
  perform _notify(_leader_of(c.user_id), case when again then 'Dihantar semula' else 'Claim baru' end,
     _name(c.user_id)||' hantar claim '||_plabel(c.period));
end $$;

create or replace function public.user_edit_row(cid bigint, d int, new_of text, new_ot text) returns void
language plpgsql security definer set search_path=public as $$
declare c claims := _claim(cid); r claim_rows; o text; begin
  if not _is_owner(c) then raise exception 'Bukan claim anda'; end if;
  if c.status in ('ok','req') then raise exception 'Claim dikunci. Minta kebenaran leader untuk ubah.'; end if;
  if c.status='sent' then raise exception 'Claim sedang disemak leader'; end if;
  select * into r from claim_rows where claim_id=cid and day=d;
  if r.wf is null then raise exception 'Hari ini tiada kerja'; end if;
  if c.status='fix' and r.flag is null then raise exception 'Hanya hari bertanda boleh diubah'; end if;
  o := r.of_||'–'||r.ot;
  update claim_rows set of_=_t4(new_of), ot=_t4(new_ot), jam=_jam(_t4(new_of),_t4(new_ot)),
    flag=null, flag_key=null, flag_col=null,
    fixed_note='Diubah oleh user: OT '||o||' → '||_t4(new_of)||'–'||_t4(new_ot)
  where id=r.id;
  insert into claim_edits(claim_id,day,key,label,from_val,to_val,by_role) values(cid,d,'ot','OT',o,_t4(new_of)||'–'||_t4(new_ot),'user');
  perform _log(cid,'User ubah '||d||'hb OT '||o||' → '||_t4(new_of)||'–'||_t4(new_ot)||' ('||_stamp()||')');
end $$;

create or replace function public.request_unlock(cid bigint, reason text) returns void
language plpgsql security definer set search_path=public as $$
declare c claims := _claim(cid); begin
  if not _is_owner(c) then raise exception 'Bukan claim anda'; end if;
  if c.status<>'ok' then raise exception 'Hanya claim yang disahkan perlu kebenaran'; end if;
  if coalesce(trim(reason),'')='' then raise exception 'Sila tulis sebab'; end if;
  update claims set status='req', req_reason=reason where id=cid;
  perform _log(cid,'Minta kebenaran ubah '||_stamp()||': '||reason);
  perform _notify(_leader_of(c.user_id),'Minta kebenaran ubah',_name(c.user_id)||': '||reason);
end $$;

-- ---------- Tindakan LEADER ----------
create or replace function public.leader_flag(cid bigint, d int, k text, col text, comment text) returns void
language plpgsql security definer set search_path=public as $$
declare c claims := _claim(cid); begin
  if not _is_leader(c) then raise exception 'Bukan ahli kumpulan anda'; end if;
  if c.status<>'sent' then raise exception 'Claim tidak dalam semakan'; end if;
  update claim_rows set flag=coalesce(nullif(trim(comment),''),'Sila semak semula.'), flag_key=k, flag_col=col, fixed_note=null
   where claim_id=cid and day=d;
end $$;

create or replace function public.leader_unflag(cid bigint, d int) returns void
language plpgsql security definer set search_path=public as $$
declare c claims := _claim(cid); begin
  if not _is_leader(c) or c.status<>'sent' then raise exception 'Tidak dibenarkan'; end if;
  update claim_rows set flag=null, flag_key=null, flag_col=null where claim_id=cid and day=d;
end $$;

create or replace function public.leader_edit(cid bigint, d int, k text, lab text, val text, note text) returns void
language plpgsql security definer set search_path=public as $$
declare c claims := _claim(cid); r claim_rows; fromv text; tov text := trim(coalesce(val,'')); begin
  if not _is_leader(c) then raise exception 'Bukan ahli kumpulan anda'; end if;
  if c.status<>'sent' then raise exception 'Claim tidak dalam semakan'; end if;
  select * into r from claim_rows where claim_id=cid and day=d;
  if k in ('wf','wt','of','ot') then tov := _t4(tov); end if;
  fromv := case k when 'desc' then r.descr when 'wf' then r.wf when 'wt' then r.wt when 'of' then r.of_ when 'ot' then r.ot
                  when 'on' then r.jam::text when 'op' then r.jam::text when 'shift' then r.shift::text when 'cto' then r.cto::text
                  else null end;
  if k not in ('desc','wf','wt','of','ot','on','op','shift','cto') then raise exception 'Petak ini dikira sistem'; end if;
  if coalesce(fromv,'')=tov then return; end if;
  update claim_rows set
    descr = case when k='desc' then tov else descr end,
    wf = case when k='wf' then tov else wf end, wt = case when k='wt' then tov else wt end,
    of_ = case when k='of' then tov else of_ end, ot = case when k='ot' then tov else ot end,
    shift = case when k='shift' then nullif(tov,'')::int else shift end,
    cto = case when k='cto' then nullif(tov,'')::int else cto end,
    jam = case when k in ('on','op') then nullif(tov,'')::numeric
               when k in ('of','ot') then _jam(case when k='of' then tov else of_ end, case when k='ot' then tov else ot end)
               else jam end,
    flag=null, flag_key=null, flag_col=null
  where id=r.id;
  insert into claim_edits(claim_id,day,key,label,from_val,to_val,note,by_role) values(cid,d,k,lab,coalesce(fromv,'(kosong)'),tov,note,'leader');
  perform _log(cid,'Leader ubah '||d||'hb '||lab||': '||coalesce(fromv,'-')||' → '||tov||' ('||_stamp()||')');
  perform _notify(c.user_id,'Leader betulkan claim',_name(auth.uid())||' ubah '||d||'hb '||lab||': '||coalesce(fromv,'-')||' → '||tov);
end $$;

create or replace function public.ask_fix(cid bigint) returns void
language plpgsql security definer set search_path=public as $$
declare c claims := _claim(cid); days text; begin
  if not _is_leader(c) or c.status<>'sent' then raise exception 'Tidak dibenarkan'; end if;
  select string_agg(day||'hb',', ' order by day) into days from claim_rows where claim_id=cid and flag is not null;
  if days is null then raise exception 'Tiada hari bertanda'; end if;
  update claims set status='fix' where id=cid;
  perform _log(cid,'Leader minta betulkan '||days||' ('||_stamp()||')');
  perform _notify(c.user_id,'Perlu betul',_name(auth.uid())||' minta anda betulkan '||days);
end $$;

create or replace function public.approve_claim(cid bigint) returns void
language plpgsql security definer set search_path=public as $$
declare c claims := _claim(cid); n int; begin
  if not _is_leader(c) or c.status<>'sent' then raise exception 'Tidak dibenarkan'; end if;
  if exists(select 1 from claim_rows where claim_id=cid and flag is not null) then raise exception 'Masih ada hari bertanda'; end if;
  select count(*) into n from claim_edits where claim_id=cid and by_role='leader';
  update claims set status='ok', approved_at=now(), req_reason=null where id=cid;
  update claim_rows set fixed_note=null where claim_id=cid;
  perform _log(cid,'Disahkan oleh leader '||_stamp());
  perform _notify(c.user_id,'Disahkan','Claim '||_plabel(c.period)||' anda telah disahkan oleh '||_name(auth.uid())
     ||case when n>0 then ' (dengan '||n||' pembetulan oleh leader)' else '' end);
end $$;

create or replace function public.decide_unlock(cid bigint, allow boolean) returns void
language plpgsql security definer set search_path=public as $$
declare c claims := _claim(cid); begin
  if not _is_leader(c) or c.status<>'req' then raise exception 'Tidak dibenarkan'; end if;
  if allow then
    update claims set status='open', approved_at=null where id=cid;
    perform _log(cid,'Leader benarkan ubah '||_stamp()||' · tandatangan dibuang');
    perform _notify(c.user_id,'Kebenaran diberi',_name(auth.uid())||' benarkan anda ubah claim '||_plabel(c.period));
  else
    update claims set status='ok', req_reason=null where id=cid;
    perform _log(cid,'Leader tolak permohonan ubah '||_stamp());
    perform _notify(c.user_id,'Permohonan ditolak',_name(auth.uid())||' tolak permohonan ubah. Claim kekal seperti disahkan.');
  end if;
end $$;

create or replace function public.remind_user(uid uuid) returns void
language plpgsql security definer set search_path=public as $$ begin
  if _leader_of(uid) is distinct from auth.uid() then raise exception 'Bukan ahli kumpulan anda'; end if;
  perform _notify(uid,'Peringatan',_name(auth.uid())||': sila hantar claim anda sebelum tarikh akhir');
end $$;

create or replace function public.mark_read() returns void
language sql security definer set search_path=public as $$
  update notifications set read=true where to_user=auth.uid() and not read $$;

-- ---------- Data demo (rekaan) ----------
create or replace function public._seed_rows(cid bigint, seed int, d1 int, d2 int, planted boolean) returns void
language plpgsql security definer set search_path=public as $$
declare pat text[] := array['A1','A1','B1','B1','OFF','REST','A2','A2','B2','B2','OFF','A3','REST','B3','B3'];
  code text; d int; t text[]; begin
  for d in d1..d2 loop
    code := pat[((d-1+seed)%15)+1];
    if code in ('OFF','REST') then insert into claim_rows(claim_id,day,descr) values(cid,d,code); continue; end if;
    t := case code when 'A1' then array['0400','1300','1300','1400','20'] when 'A2' then array['0430','1330','1330','1430','20']
         when 'A3' then array['0600','1500','1500','1600','20'] when 'B1' then array['1330','2230','2230','2330','15']
         when 'B2' then array['1430','2330','2330','2430','15'] else array['1530','2430','2430','2530','15'] end;
    insert into claim_rows(claim_id,day,descr,wf,wt,of_,ot,jam,ph,shift,cto)
    values(cid,d,code||' *Excess Working'||case when d=8 then E'\n*PH DEEPAVALI' else '' end,t[1],t[2],t[3],t[4],1,d=8,t[5]::int,20);
  end loop;
  if planted then update claim_rows set ot=lpad((substr(of_,1,2)::int+2)::text,2,'0')||substr(of_,3,2), jam=2
    where claim_id=cid and day=12 and wf is not null; end if;
end $$;

-- Tetapkan semula data demo (leader sahaja boleh panggil)
create or replace function public.reset_demo() returns void
language plpgsql security definer set search_path=public as $$
declare p record; cid bigint; i int := 0; begin
  if auth.uid() is not null and not exists(select 1 from profiles where id=auth.uid() and role='leader') then
    raise exception 'Leader sahaja'; end if;
  delete from claims; delete from notifications;
  for p in select * from profiles where role='user' order by staff_no loop
    insert into claims(user_id,period) values(p.id,'H1') returning id into cid;
    perform _seed_rows(cid, i*2, 1, 15, p.staff_no='10090012');
    insert into claims(user_id,period) values(p.id,'H2') returning id into cid;
    perform _seed_rows(cid, i*2, 16, 30, false);
    i := i+1;
  end loop;
end $$;

-- Akaun demo: 1 leader + 4 user. Kata laluan semua: Demo2026!
do $$
declare acc record; uid uuid; lid uuid; begin
  delete from auth.users where email like '%@demo-claim.test';
  for acc in select * from (values
    ('10090001','KAMAL BIN ROSLI','leader'),
    ('10090012','AHMAD FAIZ BIN OMAR','user'),
    ('10090015','SITI NURHALIZA BT RAHMAN','user'),
    ('10090018','MOHD HAKIM BIN YUSOF','user'),
    ('10090024','LIM WEI JIE','user')) v(staff_no,name,role)
  loop
    uid := gen_random_uuid();
    insert into auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
      raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,email_change,email_change_token_new,recovery_token)
    values('00000000-0000-0000-0000-000000000000',uid,'authenticated','authenticated',acc.staff_no||'@demo-claim.test',
      crypt('Demo2026!',gen_salt('bf')),now(),'{"provider":"email","providers":["email"]}','{}',now(),now(),'','','','');
    insert into auth.identities(id,user_id,provider_id,identity_data,provider,last_sign_in_at,created_at,updated_at)
    values(gen_random_uuid(),uid,uid::text,jsonb_build_object('sub',uid::text,'email',acc.staff_no||'@demo-claim.test','email_verified',true),'email',now(),now(),now());
    if acc.role='leader' then lid := uid; end if;
    insert into public.profiles(id,staff_no,name,role,leader_id) values(uid,acc.staff_no,acc.name,acc.role,case when acc.role='user' then lid end);
  end loop;
end $$;

select public.reset_demo();

-- Fungsi boleh dipanggil oleh pengguna log masuk sahaja
revoke execute on all functions in schema public from anon, authenticated, public;
alter default privileges in schema public revoke execute on functions from anon, authenticated, public;
grant execute on function public.submit_claim(bigint), public.user_edit_row(bigint,int,text,text), public.request_unlock(bigint,text),
  public.leader_flag(bigint,int,text,text,text), public.leader_unflag(bigint,int), public.leader_edit(bigint,int,text,text,text,text),
  public.ask_fix(bigint), public.approve_claim(bigint), public.decide_unlock(bigint,boolean), public.remind_user(uuid),
  public.mark_read(), public.reset_demo(), public.can_see_claim(bigint), public._leader_of(uuid) to authenticated;
-- search_path tetap untuk fungsi pembantu (advisor Supabase)
alter function public._mins(text) set search_path=public;
alter function public._jam(text,text) set search_path=public;
alter function public._t4(text) set search_path=public;
alter function public._stamp() set search_path=public;
alter function public._plabel(text) set search_path=public;
alter function public._is_owner(public.claims) set search_path=public;

-- Realtime (kemas kini terus di skrin lain)
do $$ begin
  begin alter publication supabase_realtime add table public.claims, public.claim_rows, public.notifications, public.claim_log, public.claim_edits;
  exception when others then null; end;
end $$;
