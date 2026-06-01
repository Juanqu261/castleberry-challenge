DROP EXTENSION IF EXISTS pgcrypto CASCADE;
CREATE EXTENSION pgcrypto SCHEMA public;

UPDATE auth.users
SET encrypted_password = public.crypt('DemoPlay2026!', public.gen_salt('bf')),
    updated_at = now()
WHERE email = 'david.romero@castleberrymedia.co';