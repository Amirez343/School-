-- بروزرسانی ۳: افزودن نوع آزمون «تراز آزمون گزینه ۲» (taraz)
-- در Supabase -> SQL Editor اجرا کنید (Run as role: postgres)
alter table exams drop constraint if exists exams_type_check;
alter table exams add constraint exams_type_check check (type in ('general','specialized','taraz'));
