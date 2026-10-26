-- به‌روزرسانی ۴: کاربران عادی (زیرگروه‌ها) هم بتوانند آزمون ثبت و ویرایش کنند.
-- قبلاً فقط مدیر اجازه‌ی نوشتن در جدول exams داشت و ذخیره‌ی آزمون برای بقیه خطا می‌داد.
-- نمرات (exam_scores) همچنان فقط برای دانش‌آموزان زیرگروه خود کاربر قابل ثبت است. حذف آزمون فقط با مدیر.
-- اجرا: Supabase > SQL Editor > Run
drop policy if exists "exams staff insert" on exams;
create policy "exams staff insert" on exams for insert with check (auth.uid() is not null);
drop policy if exists "exams staff update" on exams;
create policy "exams staff update" on exams for update using (auth.uid() is not null) with check (auth.uid() is not null);
