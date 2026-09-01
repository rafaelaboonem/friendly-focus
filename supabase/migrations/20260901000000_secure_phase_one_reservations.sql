alter table public.garages
  drop constraint if exists garages_private_address_not_blank,
  drop constraint if exists garages_capacity_positive,
  drop column if exists private_address,
  drop column if exists private_access_instructions;

alter table public.garages
  alter column capacity set default 1;

update public.garages
set capacity = 1
where capacity <> 1;

alter table public.garages
  add constraint garages_capacity_one check (capacity = 1);

create table if not exists public.garage_private_details (
  garage_id uuid primary key references public.garages(id) on delete cascade,
  private_address text not null,
  private_access_instructions text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint garage_private_details_address_not_blank check (length(trim(private_address)) > 0)
);
grant select, insert, update, delete on public.garage_private_details to authenticated;
grant all on public.garage_private_details to service_role;
alter table public.garage_private_details enable row level security;
drop policy if exists "Hosts and confirmed drivers can view private garage details" on public.garage_private_details;
create policy "Hosts and confirmed drivers can view private garage details"
on public.garage_private_details for select to authenticated using (
  exists (
    select 1
    from public.garages
    where garages.id = garage_private_details.garage_id
      and garages.host_id = auth.uid()
  )
  or exists (
    select 1
    from public.reservations
    where reservations.garage_id = garage_private_details.garage_id
      and reservations.driver_id = auth.uid()
      and reservations.status in ('confirmed', 'active', 'completed')
  )
);
drop policy if exists "Hosts can manage private garage details" on public.garage_private_details;
create policy "Hosts can manage private garage details"
on public.garage_private_details for all to authenticated using (
  exists (
    select 1
    from public.garages
    where garages.id = garage_private_details.garage_id
      and garages.host_id = auth.uid()
  )
) with check (
  exists (
    select 1
    from public.garages
    where garages.id = garage_private_details.garage_id
      and garages.host_id = auth.uid()
  )
);

alter table public.reservations
  add column if not exists payment_expires_at timestamptz;

update public.reservations
set payment_expires_at = created_at + interval '15 minutes'
where status = 'pending_payment'
  and payment_expires_at is null;

alter table public.reservations
  add constraint reservations_pending_payment_expiry_valid
  check (
    (status = 'pending_payment' and payment_expires_at is not null)
    or (status <> 'pending_payment' and payment_expires_at is null)
  );

revoke insert, update, delete on public.reservations from authenticated;
drop policy if exists "Drivers can create their own reservations" on public.reservations;
drop policy if exists "Drivers can cancel their own reservations" on public.reservations;

alter table public.instant_availability enable row level security;
drop policy if exists "Users can view active instant availability" on public.instant_availability;
create policy "Users can view active instant availability"
on public.instant_availability for select to authenticated using (
  exists (
    select 1
    from public.garages
    where garages.id = instant_availability.garage_id
      and garages.status = 'active'
  )
);

create or replace function public.create_reservation(
  p_garage_id uuid,
  p_vehicle_id uuid,
  p_pricing_mode public.pricing_mode,
  p_starts_at timestamptz,
  p_ends_at timestamptz
)
returns public.reservations
language plpgsql
security definer
set search_path = public
as $$
declare
  v_driver_id uuid := auth.uid();
  v_price public.garage_pricing%rowtype;
  v_units integer;
  v_garage_amount_cents integer;
  v_reservation public.reservations%rowtype;
begin
  if v_driver_id is null then
    raise exception 'Autenticação obrigatória';
  end if;

  if p_ends_at <= p_starts_at then
    raise exception 'O período da reserva é inválido';
  end if;

  if not exists (
    select 1
    from public.vehicles
    where id = p_vehicle_id
      and owner_id = v_driver_id
  ) then
    raise exception 'O veículo não pertence ao motorista autenticado';
  end if;

  if not exists (
    select 1
    from public.garages
    where id = p_garage_id
      and status = 'active'
      and capacity = 1
  ) then
    raise exception 'Garagem indisponível para reservas';
  end if;

  if exists (
    select 1
    from public.garage_availability
    where garage_id = p_garage_id
      and kind = 'blocked'
      and tstzrange(starts_at, ends_at, '[)') && tstzrange(p_starts_at, p_ends_at, '[)')
  ) then
    raise exception 'A garagem está bloqueada para o período selecionado';
  end if;

  select *
  into v_price
  from public.garage_pricing
  where garage_id = p_garage_id
    and mode = p_pricing_mode
  for share;

  if not found then
    raise exception 'Preço indisponível para o período selecionado';
  end if;

  if p_pricing_mode = 'hour' then
    v_units := greatest(1, ceil(extract(epoch from (p_ends_at - p_starts_at)) / 3600.0)::integer);
  elsif p_pricing_mode in ('daily', 'period') then
    v_units := greatest(1, ceil(extract(epoch from (p_ends_at - p_starts_at)) / 86400.0)::integer);
  else
    v_units := greatest(1, ceil(extract(epoch from (p_ends_at - p_starts_at)) / (30 * 86400.0))::integer);
  end if;

  if v_units < v_price.minimum_units
    or (v_price.maximum_units is not null and v_units > v_price.maximum_units) then
    raise exception 'O período não atende às regras de preço da garagem';
  end if;

  v_garage_amount_cents := v_price.amount_cents * v_units;

  insert into public.reservations (
    garage_id,
    driver_id,
    vehicle_id,
    pricing_mode,
    starts_at,
    ends_at,
    status,
    garage_amount_cents,
    platform_fee_cents,
    total_amount_cents,
    payment_expires_at
  ) values (
    p_garage_id,
    v_driver_id,
    p_vehicle_id,
    p_pricing_mode,
    p_starts_at,
    p_ends_at,
    'pending_payment',
    v_garage_amount_cents,
    0,
    v_garage_amount_cents,
    now() + interval '15 minutes'
  )
  returning * into v_reservation;

  return v_reservation;
end;
$$;
revoke all on function public.create_reservation(uuid, uuid, public.pricing_mode, timestamptz, timestamptz) from public;
grant execute on function public.create_reservation(uuid, uuid, public.pricing_mode, timestamptz, timestamptz) to authenticated;

create or replace function public.cancel_reservation(p_reservation_id uuid)
returns public.reservations
language plpgsql
security definer
set search_path = public
as $$
declare
  v_reservation public.reservations%rowtype;
begin
  update public.reservations
  set status = 'cancelled_by_driver',
      payment_expires_at = null
  where id = p_reservation_id
    and driver_id = auth.uid()
    and status in ('pending_payment', 'confirmed')
  returning * into v_reservation;

  if not found then
    raise exception 'Reserva não pode ser cancelada';
  end if;

  return v_reservation;
end;
$$;
revoke all on function public.cancel_reservation(uuid) from public;
grant execute on function public.cancel_reservation(uuid) to authenticated;

create or replace function public.expire_pending_payment_reservations()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count integer;
begin
  update public.reservations
  set status = 'expired',
      payment_expires_at = null
  where status = 'pending_payment'
    and payment_expires_at <= now();

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;
revoke all on function public.expire_pending_payment_reservations() from public;
grant execute on function public.expire_pending_payment_reservations() to service_role;

create or replace function public.transition_reservation_status(
  p_reservation_id uuid,
  p_status public.reservation_status
)
returns public.reservations
language plpgsql
security definer
set search_path = public
as $$
declare
  v_reservation public.reservations%rowtype;
begin
  if current_user <> 'service_role' then
    raise exception 'Operação restrita ao backend';
  end if;

  if p_status not in ('confirmed', 'active', 'completed', 'cancelled_by_host', 'payment_failed', 'expired', 'refunded', 'disputed') then
    raise exception 'Status de reserva não permitido';
  end if;

  update public.reservations
  set status = p_status,
      payment_expires_at = case when p_status = 'pending_payment' then payment_expires_at else null end
  where id = p_reservation_id
  returning * into v_reservation;

  if not found then
    raise exception 'Reserva não encontrada';
  end if;

  return v_reservation;
end;
$$;
revoke all on function public.transition_reservation_status(uuid, public.reservation_status) from public;
grant execute on function public.transition_reservation_status(uuid, public.reservation_status) to service_role;

create index if not exists garage_private_details_garage_id_idx on public.garage_private_details(garage_id);
create index if not exists reservations_pending_payment_expires_at_idx on public.reservations(payment_expires_at) where status = 'pending_payment';

drop trigger if exists garage_private_details_set_updated_at on public.garage_private_details;
create trigger garage_private_details_set_updated_at
before update on public.garage_private_details
for each row execute procedure public.set_updated_at();
