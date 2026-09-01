-- Verificação reproduzível da Fase 1.
-- Execute após aplicar as quatro migrations da Fase 1.
-- Cada teste usa dados temporários com o prefixo phase1_verify_ e os remove ao final.
-- Resultado esperado: todos os blocos "deve passar" concluem sem exceção;
-- todos os blocos "deve falhar" capturam a exceção esperada.

begin;

create temporary table phase1_verification_context (
  host_id uuid not null,
  driver_id uuid not null,
  stranger_id uuid not null,
  garage_id uuid not null,
  driver_vehicle_id uuid not null,
  stranger_vehicle_id uuid not null,
  confirmed_reservation_id uuid not null,
  pending_reservation_id uuid not null,
  expired_reservation_id uuid not null
) on commit drop;

-- Dados temporários isolados. Os usuários são inseridos primeiro em auth.users
-- para atender à FK de public.profiles. Os IDs simulam usuários autenticados via
-- set_config('request.jwt.claim.sub', ...).
insert into auth.users (
  id,
  instance_id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at
)
values
  (
    '00000000-0000-0000-0000-000000000101',
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    'phase1_verify_host@example.test',
    crypt('phase1_verify_host_password', gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"full_name":"phase1_verify_host"}'::jsonb,
    now(),
    now()
  ),
  (
    '00000000-0000-0000-0000-000000000102',
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    'phase1_verify_driver@example.test',
    crypt('phase1_verify_driver_password', gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"full_name":"phase1_verify_driver"}'::jsonb,
    now(),
    now()
  ),
  (
    '00000000-0000-0000-0000-000000000103',
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    'phase1_verify_stranger@example.test',
    crypt('phase1_verify_stranger_password', gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"full_name":"phase1_verify_stranger"}'::jsonb,
    now(),
    now()
  );

insert into public.profiles (id, full_name, created_at, updated_at)
values
  ('00000000-0000-0000-0000-000000000101', 'phase1_verify_host', now(), now()),
  ('00000000-0000-0000-0000-000000000102', 'phase1_verify_driver', now(), now()),
  ('00000000-0000-0000-0000-000000000103', 'phase1_verify_stranger', now(), now());

insert into public.garages (
  id, host_id, title, description, status, address_label, capacity, timezone, created_at, updated_at
)
values (
  '00000000-0000-0000-0000-000000000201',
  '00000000-0000-0000-0000-000000000101',
  'phase1_verify_garage',
  'Garagem temporária para verificação da Fase 1',
  'active',
  'Bairro de teste',
  1,
  'America/Sao_Paulo',
  now(),
  now()
);

insert into public.garage_private_details (
  garage_id, private_address, private_access_instructions, exact_latitude, exact_longitude, created_at, updated_at
)
values (
  '00000000-0000-0000-0000-000000000201',
  'Rua temporária, 100',
  'Use o portão lateral.',
  -23.550520,
  -46.633308,
  now(),
  now()
);

insert into public.vehicles (id, owner_id, plate, model, vehicle_type, created_at, updated_at)
values
  ('00000000-0000-0000-0000-000000000301', '00000000-0000-0000-0000-000000000102', 'P1V102', 'Carro do motorista', 'car', now(), now()),
  ('00000000-0000-0000-0000-000000000302', '00000000-0000-0000-0000-000000000103', 'P1V103', 'Carro do terceiro', 'car', now(), now());

insert into public.garage_pricing (garage_id, mode, amount_cents, minimum_units, created_at, updated_at)
values
  ('00000000-0000-0000-0000-000000000201', 'hour', 1000, 1, now(), now()),
  ('00000000-0000-0000-0000-000000000201', 'daily', 5000, 1, now(), now());

-- Segunda-feira, 10:00–18:00 no fuso America/Sao_Paulo.
insert into public.garage_availability (garage_id, kind, day_of_week, start_time, end_time, created_at, updated_at)
values (
  '00000000-0000-0000-0000-000000000201',
  'recurring',
  1,
  '10:00',
  '18:00',
  now(),
  now()
);

insert into phase1_verification_context (
  host_id, driver_id, stranger_id, garage_id, driver_vehicle_id, stranger_vehicle_id,
  confirmed_reservation_id, pending_reservation_id, expired_reservation_id
)
values (
  '00000000-0000-0000-0000-000000000101',
  '00000000-0000-0000-0000-000000000102',
  '00000000-0000-0000-0000-000000000103',
  '00000000-0000-0000-0000-000000000201',
  '00000000-0000-0000-0000-000000000301',
  '00000000-0000-0000-0000-000000000302',
  '00000000-0000-0000-0000-000000000401',
  '00000000-0000-0000-0000-000000000402',
  '00000000-0000-0000-0000-000000000403'
);

-- Reserva confirmada de apoio para validar RLS de dados privados.
insert into public.reservations (
  id, garage_id, driver_id, vehicle_id, pricing_mode, starts_at, ends_at, status,
  garage_amount_cents, platform_fee_cents, total_amount_cents, payment_expires_at, created_at, updated_at
)
values (
  '00000000-0000-0000-0000-000000000401',
  '00000000-0000-0000-0000-000000000201',
  '00000000-0000-0000-0000-000000000102',
  '00000000-0000-0000-0000-000000000301',
  'hour',
  now() + interval '14 days',
  now() + interval '14 days 1 hour',
  'confirmed',
  1000,
  0,
  1000,
  null,
  now(),
  now()
);

-- 1. TIMEZONE IANA VÁLIDO — deve passar.
do $$
begin
  insert into public.garages (id, host_id, title, status, address_label, capacity, timezone)
  values (
    '00000000-0000-0000-0000-000000000211',
    '00000000-0000-0000-0000-000000000101',
    'phase1_verify_valid_timezone',
    'active',
    'Teste',
    1,
    'America/Sao_Paulo'
  );
  delete from public.garages where id = '00000000-0000-0000-0000-000000000211';
end;
$$;

-- 2. TIMEZONE INVÁLIDO — deve falhar.
do $$
begin
  begin
    insert into public.garages (id, host_id, title, status, address_label, capacity, timezone)
    values (
      '00000000-0000-0000-0000-000000000212',
      '00000000-0000-0000-0000-000000000101',
      'phase1_verify_invalid_timezone',
      'active',
      'Teste',
      1,
      'Invalid/Timezone'
    );
    raise exception 'Teste 2 falhou: timezone inválido foi aceito';
  exception when others then
    if position('Timezone IANA inválido' in sqlerrm) = 0 then
      raise;
    end if;
  end;
end;
$$;

-- 3. GARAGEM ATIVA SEM TIMEZONE — deve falhar.
do $$
begin
  begin
    insert into public.garages (id, host_id, title, status, address_label, capacity, timezone)
    values (
      '00000000-0000-0000-0000-000000000213',
      '00000000-0000-0000-0000-000000000101',
      'phase1_verify_missing_timezone',
      'active',
      'Teste',
      1,
      null
    );
    raise exception 'Teste 3 falhou: garagem ativa sem timezone foi aceita';
  exception when others then
    if position('Garagem ativa precisa de timezone IANA' in sqlerrm) = 0 then
      raise;
    end if;
  end;
end;
$$;

-- 4–7. RLS DE garage_private_details.
-- A simulação usa o papel authenticated e o claim JWT do usuário comum.
set local role authenticated;

-- 5. ANFITRIÃO ACESSANDO SEUS DADOS PRIVADOS — deve passar.
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000101', true);
do $$
begin
  if not exists (select 1 from public.garage_private_details where garage_id = '00000000-0000-0000-0000-000000000201') then
    raise exception 'Teste 5 falhou: anfitrião não acessou seus dados privados';
  end if;
end;
$$;

-- 6. USUÁRIO SEM RESERVA TENTANDO ACESSAR DADOS PRIVADOS — deve retornar zero linhas.
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000103', true);
do $$
begin
  if exists (select 1 from public.garage_private_details where garage_id = '00000000-0000-0000-0000-000000000201') then
    raise exception 'Teste 6 falhou: usuário sem reserva acessou dados privados';
  end if;
end;
$$;

-- 7. MOTORISTA COM RESERVA CONFIRMADA ACESSANDO DADOS PRIVADOS — deve passar.
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000102', true);
do $$
begin
  if not exists (select 1 from public.garage_private_details where garage_id = '00000000-0000-0000-0000-000000000201') then
    raise exception 'Teste 7 falhou: motorista confirmado não acessou dados privados';
  end if;
end;
$$;

reset role;

-- 8. VEÍCULO PERTENCENTE AO MOTORISTA — reserva via RPC deve passar.
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000102', true);
set local role authenticated;
do $$
declare
  v_reservation public.reservations;
begin
  v_reservation := public.create_reservation(
    '00000000-0000-0000-0000-000000000201',
    '00000000-0000-0000-0000-000000000301',
    'hour',
    timestamptz '2030-01-07 13:00:00+00',
    timestamptz '2030-01-07 14:00:00+00'
  );
  if v_reservation.status <> 'pending_payment' then
    raise exception 'Teste 8 falhou: reserva válida não ficou pendente de pagamento';
  end if;
end;
$$;
reset role;

-- 9. TENTATIVA DE USAR VEÍCULO DE OUTRO USUÁRIO — deve falhar.
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000102', true);
set local role authenticated;
do $$
begin
  begin
    perform public.create_reservation(
      '00000000-0000-0000-0000-000000000201',
      '00000000-0000-0000-0000-000000000302',
      'hour',
      timestamptz '2030-01-07 14:00:00+00',
      timestamptz '2030-01-07 15:00:00+00'
    );
    raise exception 'Teste 9 falhou: veículo de outro usuário foi aceito';
  exception when others then
    if position('O veículo não pertence ao motorista autenticado' in sqlerrm) = 0 then
      raise;
    end if;
  end;
end;
$$;
reset role;

-- 10. RESERVA VÁLIDA — deve passar.
-- A reserva criada no teste 8 confirma a cadeia RPC, preço e disponibilidade.

-- 11. RESERVA FORA DA DISPONIBILIDADE RECORRENTE — deve falhar.
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000102', true);
set local role authenticated;
do $$
begin
  begin
    perform public.create_reservation(
      '00000000-0000-0000-0000-000000000201',
      '00000000-0000-0000-0000-000000000301',
      'hour',
      timestamptz '2030-01-07 21:00:00+00',
      timestamptz '2030-01-07 22:00:00+00'
    );
    raise exception 'Teste 11 falhou: período fora da disponibilidade foi aceito';
  exception when others then
    if position('O período selecionado está fora da disponibilidade da garagem' in sqlerrm) = 0 then
      raise;
    end if;
  end;
end;
$$;
reset role;

-- 12. PERÍODO BLOQUEADO — deve falhar.
insert into public.garage_availability (garage_id, kind, starts_at, ends_at, created_at, updated_at)
values (
  '00000000-0000-0000-0000-000000000201',
  'blocked',
  timestamptz '2030-01-07 15:00:00+00',
  timestamptz '2030-01-07 16:00:00+00',
  now(),
  now()
);
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000102', true);
set local role authenticated;
do $$
begin
  begin
    perform public.create_reservation(
      '00000000-0000-0000-0000-000000000201',
      '00000000-0000-0000-0000-000000000301',
      'hour',
      timestamptz '2030-01-07 15:00:00+00',
      timestamptz '2030-01-07 16:00:00+00'
    );
    raise exception 'Teste 12 falhou: período bloqueado foi aceito';
  exception when others then
    if position('A garagem está bloqueada para o período selecionado' in sqlerrm) = 0 then
      raise;
    end if;
  end;
end;
$$;
reset role;

-- 13. RESERVA ATRAVESSANDO DIA LOCAL — deve falhar.
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000102', true);
set local role authenticated;
do $$
begin
  begin
    perform public.create_reservation(
      '00000000-0000-0000-0000-000000000201',
      '00000000-0000-0000-0000-000000000301',
      'hour',
      timestamptz '2030-01-08 02:30:00+00',
      timestamptz '2030-01-08 03:30:00+00'
    );
    raise exception 'Teste 13 falhou: reserva atravessando dia local foi aceita';
  exception when others then
    if position('Reservas que atravessam dias locais ainda não são suportadas' in sqlerrm) = 0 then
      raise;
    end if;
  end;
end;
$$;
reset role;

-- 14. DOUBLE BOOKING — deve falhar.
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000102', true);
set local role authenticated;
do $$
begin
  begin
    perform public.create_reservation(
      '00000000-0000-0000-0000-000000000201',
      '00000000-0000-0000-0000-000000000301',
      'hour',
      timestamptz '2030-01-07 13:30:00+00',
      timestamptz '2030-01-07 14:30:00+00'
    );
    raise exception 'Teste 14 falhou: double booking foi aceito';
  exception when exclusion_violation then
    null;
  when others then
    if position('conflito' in lower(sqlerrm)) = 0 and position('overlap' in lower(sqlerrm)) = 0 then
      raise;
    end if;
  end;
end;
$$;
reset role;

-- 15. EXPIRAÇÃO DE pending_payment — deve passar.
insert into public.reservations (
  id, garage_id, driver_id, vehicle_id, pricing_mode, starts_at, ends_at, status,
  garage_amount_cents, platform_fee_cents, total_amount_cents, payment_expires_at, created_at, updated_at
)
values (
  '00000000-0000-0000-0000-000000000403',
  '00000000-0000-0000-0000-000000000201',
  '00000000-0000-0000-0000-000000000102',
  '00000000-0000-0000-0000-000000000301',
  'hour',
  now() + interval '30 days',
  now() + interval '30 days 1 hour',
  'pending_payment',
  1000,
  0,
  1000,
  now() - interval '1 minute',
  now(),
  now()
);
do $$
begin
  perform public.expire_pending_payment_reservations();
  if not exists (
    select 1 from public.reservations
    where id = '00000000-0000-0000-0000-000000000403'
      and status = 'expired'
      and payment_expires_at is null
  ) then
    raise exception 'Teste 15 falhou: pending_payment expirado não foi atualizado';
  end if;
end;
$$;

-- 16–18. ALTERAÇÕES DIRETAS EM reservations POR MOTORISTA — devem falhar.
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000102', true);
set local role authenticated;
do $$
begin
  begin
    insert into public.reservations (
      garage_id, driver_id, vehicle_id, pricing_mode, starts_at, ends_at, status,
      garage_amount_cents, platform_fee_cents, total_amount_cents, payment_expires_at
    ) values (
      '00000000-0000-0000-0000-000000000201',
      '00000000-0000-0000-0000-000000000102',
      '00000000-0000-0000-0000-000000000301',
      'hour', now() + interval '40 days', now() + interval '40 days 1 hour', 'pending_payment',
      1, 0, 1, now() + interval '15 minutes'
    );
    raise exception 'Teste 16 falhou: INSERT direto em reservations foi aceito';
  exception when insufficient_privilege then
    null;
  end;

  begin
    update public.reservations
    set status = 'cancelled_by_driver'
    where id = '00000000-0000-0000-0000-000000000401';
    raise exception 'Teste 17 falhou: UPDATE direto em reservations foi aceito';
  exception when insufficient_privilege then
    null;
  end;

  begin
    delete from public.reservations
    where id = '00000000-0000-0000-0000-000000000401';
    raise exception 'Teste 18 falhou: DELETE direto em reservations foi aceito';
  exception when insufficient_privilege then
    null;
  end;
end;
$$;
reset role;

-- 19. CANCELAMENTO DE pending_payment — deve passar.
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000102', true);
set local role authenticated;
do $$
declare
  v_reservation public.reservations;
begin
  v_reservation := public.create_reservation(
    '00000000-0000-0000-0000-000000000201',
    '00000000-0000-0000-0000-000000000301',
    'hour',
    timestamptz '2030-01-07 16:00:00+00',
    timestamptz '2030-01-07 17:00:00+00'
  );
  v_reservation := public.cancel_reservation(v_reservation.id);
  if v_reservation.status <> 'cancelled_by_driver' or v_reservation.payment_expires_at is not null then
    raise exception 'Teste 19 falhou: pending_payment não foi cancelada corretamente';
  end if;
end;
$$;
reset role;

-- 20. MOTORISTA TENTANDO CANCELAR confirmed — deve falhar.
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000102', true);
set local role authenticated;
do $$
begin
  begin
    perform public.cancel_reservation('00000000-0000-0000-0000-000000000401');
    raise exception 'Teste 20 falhou: motorista cancelou reserva confirmed';
  exception when others then
    if position('Reserva não pode ser cancelada' in sqlerrm) = 0 then
      raise;
    end if;
  end;
end;
$$;
reset role;

-- 21. TRANSIÇÃO VÁLIDA DE STATUS PELO BACKEND — deve passar.
do $$
declare
  v_reservation public.reservations;
begin
  v_reservation := public.transition_reservation_status(
    '00000000-0000-0000-0000-000000000401',
    'active'
  );
  if v_reservation.status <> 'active' then
    raise exception 'Teste 21 falhou: transição backend válida não foi aplicada';
  end if;
end;
$$;

-- 22. TRANSIÇÃO INVÁLIDA DE STATUS — deve falhar.
do $$
begin
  begin
    perform public.transition_reservation_status(
      '00000000-0000-0000-0000-000000000401',
      'confirmed'
    );
    raise exception 'Teste 22 falhou: transição inválida foi aceita';
  exception when others then
    if position('Transição de status não permitida' in sqlerrm) = 0 then
      raise;
    end if;
  end;
end;
$$;

-- Limpeza explícita dos dados temporários. A transação também garante rollback em falhas.
delete from public.garages where id = '00000000-0000-0000-0000-000000000201';
delete from public.profiles where id in (
  '00000000-0000-0000-0000-000000000101',
  '00000000-0000-0000-0000-000000000102',
  '00000000-0000-0000-0000-000000000103'
);
delete from auth.users where id in (
  '00000000-0000-0000-0000-000000000101',
  '00000000-0000-0000-0000-000000000102',
  '00000000-0000-0000-0000-000000000103'
);

commit;
