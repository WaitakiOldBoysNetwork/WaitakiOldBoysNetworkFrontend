-- =============================================================================
-- Migration 05: Secure User Account Deletion Function
-- =============================================================================
-- Description:
--   Allows authenticated users to permanently delete their own account and all
--   associated data (profile, posts, comments, likes, connections, and auth user).
--
-- Security:
--   - Uses SECURITY DEFINER to execute with elevated rights.
--   - Strict auth.uid() check ensures a user can ONLY delete their own account.
-- =============================================================================

create or replace function public.delete_user_account()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
begin
  -- Identify the authenticated calling user
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  -- 1. Delete comments made by user
  delete from public.post_comments where user_id = v_user_id;

  -- 2. Delete likes made by user
  delete from public.post_likes where user_id = v_user_id;

  -- 3. Delete posts authored by user (and cascade any associated comments/likes)
  delete from public.posts where author_id = v_user_id;

  -- 4. Delete all connection requests sent or received by user
  delete from public.connections where requester_id = v_user_id or recipient_id = v_user_id;

  -- 5. Delete profile record
  delete from public.profiles where id = v_user_id or user_id = v_user_id;

  -- 6. Delete user record from auth.users (cascades any remaining auth data)
  delete from auth.users where id = v_user_id;
end;
$$;

-- Grant execution permission to authenticated users
grant execute on function public.delete_user_account() to authenticated;
