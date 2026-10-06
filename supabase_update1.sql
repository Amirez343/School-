-- بروزرسانی کوچک: افزودن ستون ایمیل به profiles (برای نمایش در پنل مدیریت)
alter table profiles add column if not exists email text;
update profiles set email = (select email from auth.users where auth.users.id = profiles.id) where email is null;
