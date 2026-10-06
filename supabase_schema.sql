-- ================================================================
-- اسکریپت ساخت جدول‌ها و امنیت سطح-ردیف (RLS) برای سیستم ردیابی عملکرد
-- این را در Supabase Dashboard -> SQL Editor -> New query پیست کنید و Run بزنید
-- ================================================================

create extension if not exists "pgcrypto";

-- پروفایل هر کاربر (ادمین یا مسئول)
create table if not exists profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null,
  role text not null check (role in ('admin','staff')) default 'staff',
  created_at timestamptz default now()
);

-- زیرگروه‌ها
create table if not exists groups (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  created_at timestamptz default now()
);

-- اختصاص هر مسئول به یک یا چند زیرگروه
create table if not exists staff_groups (
  staff_id uuid references profiles(id) on delete cascade,
  group_id uuid references groups(id) on delete cascade,
  primary key (staff_id, group_id)
);

-- دانش‌آموزان
create table if not exists students (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  cls text,
  group_id uuid references groups(id),
  active boolean default true,
  goal numeric,
  created_at timestamptz default now()
);

-- داده روزانه هر دانش‌آموز
create table if not exists days (
  id uuid primary key default gen_random_uuid(),
  student_id uuid references students(id) on delete cascade,
  date date not null,
  q numeric,
  qa boolean default false,
  h numeric,
  s int,
  lg boolean,
  hw int,
  ex int,
  unique(student_id, date)
);

-- آزمون‌ها
create table if not exists exams (
  id uuid primary key default gen_random_uuid(),
  date date not null,
  title text,
  type text check (type in ('general','specialized')),
  subject text,
  total numeric default 100,
  created_at timestamptz default now()
);

-- نمرات آزمون هر دانش‌آموز
create table if not exists exam_scores (
  exam_id uuid references exams(id) on delete cascade,
  student_id uuid references students(id) on delete cascade,
  score numeric,
  primary key (exam_id, student_id)
);

-- اقدامات اصلاحی
create table if not exists actions (
  id uuid primary key default gen_random_uuid(),
  student_id uuid references students(id) on delete cascade,
  date date,
  problem text,
  action text,
  owner text,
  status text,
  result text,
  created_at timestamptz default now()
);

-- تنظیمات کلی (وزن‌ها، آستانه‌ها، پیام‌های کارنامه) - فقط ادمین می‌نویسد
create table if not exists cfg (
  id int primary key default 1,
  data jsonb not null default '{}'::jsonb,
  check (id = 1)
);
insert into cfg (id, data) values (1, '{}'::jsonb) on conflict (id) do nothing;

-- ----------------------------------------------------------------
-- توابع کمکی (security definer تا در RLS گیر نکنیم)
-- ----------------------------------------------------------------
create or replace function is_admin()
returns boolean language sql security definer stable as $$
  select exists(select 1 from profiles where id = auth.uid() and role = 'admin');
$$;

create or replace function my_group_ids()
returns setof uuid language sql security definer stable as $$
  select group_id from staff_groups where staff_id = auth.uid();
$$;

-- ----------------------------------------------------------------
-- فعال‌سازی RLS
-- ----------------------------------------------------------------
alter table profiles enable row level security;
alter table groups enable row level security;
alter table staff_groups enable row level security;
alter table students enable row level security;
alter table days enable row level security;
alter table exams enable row level security;
alter table exam_scores enable row level security;
alter table actions enable row level security;
alter table cfg enable row level security;

-- profiles
drop policy if exists "profiles self or admin read" on profiles;
create policy "profiles self or admin read" on profiles for select
  using (id = auth.uid() or is_admin());
drop policy if exists "profiles admin write" on profiles;
create policy "profiles admin write" on profiles for insert with check (is_admin());
drop policy if exists "profiles admin update" on profiles;
create policy "profiles admin update" on profiles for update using (is_admin());
drop policy if exists "profiles admin delete" on profiles;
create policy "profiles admin delete" on profiles for delete using (is_admin());

-- groups
drop policy if exists "groups read all authenticated" on groups;
create policy "groups read all authenticated" on groups for select using (auth.uid() is not null);
drop policy if exists "groups admin write" on groups;
create policy "groups admin write" on groups for insert with check (is_admin());
drop policy if exists "groups admin update" on groups;
create policy "groups admin update" on groups for update using (is_admin());
drop policy if exists "groups admin delete" on groups;
create policy "groups admin delete" on groups for delete using (is_admin());

-- staff_groups
drop policy if exists "staff_groups self or admin read" on staff_groups;
create policy "staff_groups self or admin read" on staff_groups for select
  using (staff_id = auth.uid() or is_admin());
drop policy if exists "staff_groups admin write" on staff_groups;
create policy "staff_groups admin write" on staff_groups for insert with check (is_admin());
drop policy if exists "staff_groups admin delete" on staff_groups;
create policy "staff_groups admin delete" on staff_groups for delete using (is_admin());

-- students
drop policy if exists "students read" on students;
create policy "students read" on students for select
  using (is_admin() or group_id in (select my_group_ids()));
drop policy if exists "students admin write" on students;
create policy "students admin write" on students for insert with check (is_admin());
drop policy if exists "students update" on students;
create policy "students update" on students for update
  using (is_admin() or group_id in (select my_group_ids()));
drop policy if exists "students admin delete" on students;
create policy "students admin delete" on students for delete using (is_admin());

-- days
drop policy if exists "days read" on days;
create policy "days read" on days for select
  using (is_admin() or student_id in (select id from students where group_id in (select my_group_ids())));
drop policy if exists "days write" on days;
create policy "days write" on days for insert with check (
  is_admin() or student_id in (select id from students where group_id in (select my_group_ids()))
);
drop policy if exists "days update" on days;
create policy "days update" on days for update using (
  is_admin() or student_id in (select id from students where group_id in (select my_group_ids()))
);
drop policy if exists "days delete" on days;
create policy "days delete" on days for delete using (
  is_admin() or student_id in (select id from students where group_id in (select my_group_ids()))
);

-- exams
drop policy if exists "exams read" on exams;
create policy "exams read" on exams for select using (auth.uid() is not null);
drop policy if exists "exams admin write" on exams;
create policy "exams admin write" on exams for insert with check (is_admin());
drop policy if exists "exams admin update" on exams;
create policy "exams admin update" on exams for update using (is_admin());
drop policy if exists "exams admin delete" on exams;
create policy "exams admin delete" on exams for delete using (is_admin());

-- exam_scores
drop policy if exists "exam_scores read" on exam_scores;
create policy "exam_scores read" on exam_scores for select using (
  is_admin() or student_id in (select id from students where group_id in (select my_group_ids()))
);
drop policy if exists "exam_scores write" on exam_scores;
create policy "exam_scores write" on exam_scores for insert with check (
  is_admin() or student_id in (select id from students where group_id in (select my_group_ids()))
);
drop policy if exists "exam_scores update" on exam_scores;
create policy "exam_scores update" on exam_scores for update using (
  is_admin() or student_id in (select id from students where group_id in (select my_group_ids()))
);
drop policy if exists "exam_scores delete" on exam_scores;
create policy "exam_scores delete" on exam_scores for delete using (
  is_admin() or student_id in (select id from students where group_id in (select my_group_ids()))
);

-- actions
drop policy if exists "actions read" on actions;
create policy "actions read" on actions for select using (
  is_admin() or student_id in (select id from students where group_id in (select my_group_ids()))
);
drop policy if exists "actions write" on actions;
create policy "actions write" on actions for insert with check (
  is_admin() or student_id in (select id from students where group_id in (select my_group_ids()))
);
drop policy if exists "actions update" on actions;
create policy "actions update" on actions for update using (
  is_admin() or student_id in (select id from students where group_id in (select my_group_ids()))
);
drop policy if exists "actions delete" on actions;
create policy "actions delete" on actions for delete using (
  is_admin() or student_id in (select id from students where group_id in (select my_group_ids()))
);

-- cfg
drop policy if exists "cfg read" on cfg;
create policy "cfg read" on cfg for select using (auth.uid() is not null);
drop policy if exists "cfg admin update" on cfg;
create policy "cfg admin update" on cfg for update using (is_admin());
