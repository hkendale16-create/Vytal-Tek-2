-- Lock down Auth trigger helper — not callable via Data API
revoke execute on function public.handle_new_user() from anon, authenticated, public;
grant execute on function public.handle_new_user() to postgres, service_role, supabase_auth_admin;
