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
6. Open the app, sign in, then Account > Open admin panel to add users and set the user limit.

Notes
- Add all later users from the admin panel (not the Supabase dashboard).
- The user limit counts normal users only; admins are not counted.
- If `SB` stays `null`, the app works as before (no login).
- The service worker cache is now `chapel-v3`, so installed copies update on next online open.
