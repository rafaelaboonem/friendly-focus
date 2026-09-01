alter table public.garages
  drop constraint if exists garages_latitude_range,
  drop constraint if exists garages_longitude_range,
  drop column if exists latitude,
  drop column if exists longitude,
  add column if not exists timezone text;

alter table public.garages
  add constraint garages_timezone_valid
  check (timezone is null or timezone in (select name from pg_timezone_names));

alter table public.garage_private_details
  add column if not exists exact_latitude numeric(9, 6),
  add column if not exists exact_longitude numeric(9, 6),
  add constraint garage_private_details_exact_latitude_range
    check (exact_latitude is null or exact_latitude between -90 and 90),
  add constraint garage_private_details_exact_longitude_range
    check (exact_longitude is null or exact_longitude between -180 and 180);

drop index if exists public.garages_status_location_idx;

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
  v_garage_timezone text;
  v_units integer;
  v_garage_amount_cents integer;
  v_reservation public.reservations%rowtype;
  v_start_local timestamp;
  v_end_local timestamp;
  v_start_day smallint;
  v_end_day smallint;
  v_start_time time;
  v_end_time time;
begin
  if v_driver_id is null then
    raise exception 'Autenticação obrigatória';
  end if;

  if p_ends_at <= p_starts_at or p_starts_at < now() then
    raise exception 'O período da reserva é inválido ou já começou';
  end if;

  if p_pricing_mode not in ('hour', 'daily') then
    raise exception 'Esta modalidade de preço ainda não está disponível para reservas';
  end if;

  if not exists (
    select 1
    from public.vehicles
    where id = p_vehicle_id
      and owner_id = v_driver_id
  ) then
    raise exception 'O veículo não pertence ao motorista autenticado';
  end if;

  select timezone
  into v_garage_timezone
  from public.garages
  where id = p_garage_id
    and status = 'active'
    and capacity = 1
  for share;

  if not found or v_garage_timezone is null
    or not exists (select 1 from pg_timezone_names where name = v_garage_timezone) then
    raise exception 'Garagem indisponível para reservas';
  end if;

  v_start_local := p_starts_at at time zone v_garage_timezone;
  v_end_local := p_ends_at at time zone v_garage_timezone;
  v_start_day := extract(dow from v_start_local)::smallint;
  v_end_day := extract(dow from (v_end_local - interval '1 microsecond'))::smallint;
  v_start_time := v_start_local::time;
  v_end_time := (v_end_local - interval '1 microsecond')::time;

  if not exists (
    select 1
    from public.garage_availability
    where garage_id = p_garage_id
      and kind = 'recurring'
  ) then
    raise exception 'A garagem ainda não possui disponibilidade configurada';
  end if;

  -- Reservas que atravessam dias locais ainda não são suportadas no MVP.
  if v_start_day <> v_end_day or not exists (
    select 1
    from public.garage_availability
    where garage_id = p_garage_id
      and kind = 'recurring'
      and day_of_week = v_start_day
      and start_time <= v_start_time
      and end_time >= v_end_time
  ) then
    raise exception 'O período selecionado está fora da disponibilidade local da garagem';
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

  update public.reservations
  set status = 'expired',
      payment_expires_at = null
  where garage_id = p_garage_id
    and status = 'pending_payment'
    and payment_expires_at <= now()
    and tstzrange(starts_at, ends_at, '[)') && tstzrange(p_starts_at, p_ends_at, '[)');

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
  else
    v_units := greatest(1, ceil(extract(epoch from (p_ends_at - p_starts_at)) / 86400.0)::integer);
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
    and status = 'pending_payment'
  returning * into v_reservation;

  if not found then
    raise exception 'Apenas reservas aguardando pagamento podem ser canceladas';
  end if;

  return v_reservation;
end;
$$;
revoke all on function public.cancel_reservation(uuid) from public;
grant execute on function public.cancel_reservation(uuid) to authenticated;
