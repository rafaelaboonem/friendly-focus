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

  if not exists (
    select 1
    from public.garages
    where id = p_garage_id
      and status = 'active'
      and capacity = 1
  ) then
    raise exception 'Garagem indisponível para reservas';
  end if;

  v_start_day := extract(dow from p_starts_at at time zone 'UTC')::smallint;
  v_end_day := extract(dow from (p_ends_at - interval '1 microsecond') at time zone 'UTC')::smallint;
  v_start_time := (p_starts_at at time zone 'UTC')::time;
  v_end_time := ((p_ends_at - interval '1 microsecond') at time zone 'UTC')::time;

  if not exists (
    select 1
    from public.garage_availability
    where garage_id = p_garage_id
      and kind = 'recurring'
  ) then
    raise exception 'A garagem ainda não possui disponibilidade configurada';
  end if;

  if v_start_day <> v_end_day or not exists (
    select 1
    from public.garage_availability
    where garage_id = p_garage_id
      and kind = 'recurring'
      and day_of_week = v_start_day
      and start_time <= v_start_time
      and end_time >= v_end_time
  ) then
    raise exception 'O período selecionado está fora da disponibilidade da garagem';
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
  select *
  into v_reservation
  from public.reservations
  where id = p_reservation_id
  for update;

  if not found then
    raise exception 'Reserva não encontrada';
  end if;

  if not (
    (v_reservation.status = 'pending_payment' and p_status in ('confirmed', 'payment_failed', 'expired', 'cancelled_by_host'))
    or (v_reservation.status = 'confirmed' and p_status in ('active', 'cancelled_by_host', 'disputed', 'refunded'))
    or (v_reservation.status = 'active' and p_status in ('completed', 'disputed'))
  ) then
    raise exception 'Transição de status não permitida';
  end if;

  update public.reservations
  set status = p_status,
      payment_expires_at = null
  where id = p_reservation_id
  returning * into v_reservation;

  return v_reservation;
end;
$$;
revoke all on function public.transition_reservation_status(uuid, public.reservation_status) from public;
grant execute on function public.transition_reservation_status(uuid, public.reservation_status) to service_role;
