-- بروزرسانی: افزودن نام‌کاربری برای ورود مسئولین (بجای ایمیل)
alter table profiles add column if not exists username text;
create unique index if not exists profiles_username_uidx on profiles(username) where username is not null;
