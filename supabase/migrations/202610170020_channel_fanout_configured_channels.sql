-- Email and push fan out only to channels the worker can send (DL-070).
--
-- Production turns NOTIFICATION_CHANNELS_ENABLED on before the Resend and
-- Firebase keys exist, so that push and email start the moment their keys
-- are imported. The fan-out, though, created `pending` email and push rows
-- for every notification whatever was configured, and `channel_claim` has no
-- age limit. A channel without a sender would therefore pile up rows that
-- nothing reads, then send every one of them, days or weeks late, once its
-- key arrived.
--
-- `private.channel_fanout(p_limit, p_channels)` fans out only to the given
-- channels. The worker passes the channels it has a sender for, and does not
-- fan out at all when it has none. A channel configured later picks up only
-- the in-app notifications of the last 24 hours, as before, so nobody gets a
-- backlog. Everything else is unchanged: the same preferences, the same
-- exclusion of the inactive-account warning from email (202610150091), the
-- same idempotency. The one-argument form stays, fanning out to both
-- channels, for callers that predate this.

create or replace function private.channel_fanout(p_limit integer, p_channels text[])
returns integer language plpgsql security definer set search_path = '' as $$
declare
  n integer;
begin
  if p_channels is null or cardinality(p_channels) = 0 then
    return 0;
  end if;
  if exists (select 1 from unnest(p_channels) c where c is null or c not in ('email', 'push')) then
    raise exception using errcode = '22023', message = 'Unknown channel';
  end if;
  with candidates as (
    select d.school_id, d.outbox_id, d.recipient_id, ch.channel
    from public.notification_deliveries d
    join public.notification_outbox o on o.id = d.outbox_id
    join public.profiles p on p.id = d.recipient_id and p.status = 'active'
    cross join (values ('email'), ('push')) as ch(channel)
    where d.channel = 'in_app' and d.state = 'sent'
      and d.delivered_at >= now() - interval '24 hours'
      and ch.channel = any(p_channels)
      and not (ch.channel = 'email' and o.template_key = 'account.inactive_deletion_warning')
      and private.channel_allowed(d.recipient_id, d.school_id, ch.channel,
        private.notification_category(o.template_key))
      and not exists (
        select 1 from public.notification_deliveries x
        where x.outbox_id = d.outbox_id and x.recipient_id = d.recipient_id
          and x.channel = ch.channel)
    limit greatest(least(p_limit, 1000), 1)
  )
  insert into public.notification_deliveries(school_id, outbox_id, recipient_id, channel, attempt, state)
  select school_id, outbox_id, recipient_id, channel, 1, 'pending' from candidates
  on conflict (outbox_id, recipient_id, channel, attempt) do nothing;
  get diagnostics n = row_count;
  return n;
end;
$$;

create or replace function private.channel_fanout(p_limit integer default 200)
returns integer language sql security definer set search_path = '' as $$
  select private.channel_fanout(p_limit, array['email', 'push']);
$$;

do $grants$
declare fn text;
begin
  foreach fn in array array[
    'private.channel_fanout(integer, text[])',
    'private.channel_fanout(integer)'
  ] loop
    execute format('alter function %s owner to postgres', fn);
    execute format('revoke all on function %s from public, anon, authenticated, service_role, studafy_api_runtime, studafy_worker_runtime', fn);
  end loop;
end
$grants$;

grant execute on function private.channel_fanout(integer, text[]),
  private.channel_fanout(integer)
to studafy_worker_runtime;
