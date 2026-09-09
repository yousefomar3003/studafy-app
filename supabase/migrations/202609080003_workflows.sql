create table public.meeting_deliveries (
  meeting_id uuid not null references public.meetings(id) on delete cascade,
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  state text not null check (state in ('queued', 'sent', 'failed', 'cancelled')),
  delivered_at timestamptz,
  error text,
  primary key (meeting_id, recipient_id)
);

create table public.account_deletion_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  state text not null default 'grace_period'
    check (state in ('grace_period', 'cancelled', 'executing', 'completed')),
  requested_at timestamptz not null default now(),
  execute_after timestamptz not null default now() + interval '14 days',
  completed_at timestamptz,
  unique (user_id, state)
);

alter table public.meeting_deliveries enable row level security;
alter table public.account_deletion_requests enable row level security;

create policy "meeting deliveries own or teacher" on public.meeting_deliveries for select
using (recipient_id=auth.uid() or exists (
  select 1 from public.meetings m
  where m.id=meeting_id and public.is_class_teacher(m.classroom_id)
));
create policy "deletion requests own" on public.account_deletion_requests for select
using (user_id=auth.uid());

create index meeting_deliveries_recipient_idx
on public.meeting_deliveries(recipient_id, state);
create index account_deletion_due_idx
on public.account_deletion_requests(execute_after)
where state='grace_period';
