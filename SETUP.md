# Turn on accounts (one-time setup)

1. **Supabase project**: create a free project at supabase.com.
2. **Run the SQL**: Supabase > SQL Editor > paste all of `setup.sql` > Run.
3. **Email setting**: Authentication > Providers > Email > turn **Confirm email OFF**.
   (Leave "Allow new users to sign up" ON. The SQL blocks anyone the admin has not approved.)
4. **Create the first admin**: Authentication > Users > Add user.
   Email = `yourname@example.com`, set a password, tick auto-confirm.
   The first account ever created becomes the admin. Your login username is the part before `@`.
5. **Connect the app**: Project Settings > API. In `index.html` find the line
   `const SB=null;` and replace it with:
   `const SB={url:"https://YOUR-PROJECT.supabase.co",key:"YOUR-ANON-PUBLIC-KEY"};`
6. **Run `patch.sql`** the same way (SQL Editor > paste > Run). It makes the database set each chat message's sender name itself.
7. **Run `patch2.sql`** too (roles and profile pictures).
8. **Run `patch3.sql`** too (group chat members and photos).
9. **Run `patch4.sql`** too (multiple roles, Founder, shared task progress, Mass language and notes).
10. **Run `patch5.sql`** too (founder status and push notification tables).
11. **Push notifications:** Supabase > Edge Functions > Deploy a new function > Via Editor. Name it `push`, paste all of `push.ts`, then Deploy. In the app, open Settings and tap Turn on notifications on each device.
12. Open the app, sign in, then Account > Open admin panel to add users and set the user limit.

Notes
- Add all later users from the admin panel (not the Supabase dashboard).
- The user limit counts normal users only; admins are not counted.
- If `SB` stays `null`, the app works as before (no login).
- Optional: run `patch6.sql` so Users Status (priest and founder) can show the time each task was ticked.
- The service worker cache is now `chapel-v11`, so installed copies update on next online open.


## Optional: automatic 5:30 PM check for priest and founder
1. Supabase > Edge Functions > Secrets: add `CRON_SECRET` with any long random text.
2. Supabase > Integrations: turn on `pg_cron` and `pg_net`.
3. SQL Editor (replace the three values in capitals):
```sql
select cron.schedule('chapel-daily-check', '30 9 * * *', $$
  select net.http_post(
    url := 'https://YOUR-PROJECT.supabase.co/functions/v1/push',
    headers := '{"Content-Type":"application/json","x-cron-secret":"YOUR_CRON_SECRET","Authorization":"Bearer YOUR_ANON_KEY"}'::jsonb,
    body := '{"action":"check"}'::jsonb);
$$);
```
(09:30 UTC is 5:30 PM in the Philippines.)


## Sunday Mass language reminders (priest and founder)
1. OneSignal dashboard > Settings > Keys & IDs: copy the **REST API Key** (the app uses the same App ID as in `index.html`).
2. Supabase > Database > Extensions: turn on `pg_cron` and `pg_net`.
3. Supabase > SQL Editor: paste all of `patch_lang_reminder.sql` and Run.
4. In a new query, save your key (replace the text) and Run:
   `insert into public.app_secrets (name, value) values ('onesignal_api_key', 'PASTE_YOUR_REST_API_KEY') on conflict (name) do update set value = excluded.value;`
5. Test it: run `select public.lang_reminder('test', 0);` The priest and founder phones (with notifications turned on in Settings) get a test message.
   To see OneSignal's answer: `select status_code, content::text from net._http_response order by created desc limit 1;`
6. Times are Philippine time (Asia/Manila). Saturday (the day before Sunday): 8:00 AM, 12:00 PM, 7:00 PM. On Sunday itself: 4:00 AM and 5:00 AM. Saturday's Mass is always English, so nothing is sent for it. Nothing is sent once the language is set.


## Monday to Friday Mass: priests
Run `patch_weekday_priests.sql` once in the Supabase SQL Editor. It adds the three priests (Priest 1, 2 and 3), the priest for each weekday, and lets the priest and founder tick Chapel tasks.
