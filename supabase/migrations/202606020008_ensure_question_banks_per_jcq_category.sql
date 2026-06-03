-- MegaPromo - Consolider les banques de questions par categorie JCQ
-- A executer dans Supabase SQL Editor apres 202606020004.
--
-- Objectif:
-- - garantir une banque officielle pour chaque categorie JCQ:
--   Automobile, Musique, Shopping, Technologie, Telecom;
-- - lier chaque banque a sa categorie;
-- - rattacher les questions de banque existantes a la banque de leur categorie;
-- - garder les questions modifiables depuis le SA.
--
-- Important:
-- - execute d'abord en DEV pour valider l'affichage SA;
-- - execute ensuite en PROD si les banques/questions doivent etre disponibles
--   pour les vrais joueurs.

with category_seed as (
  insert into public.categories (
    name,
    description,
    icon,
    color,
    is_active,
    created_at
  )
  values
    (
      'Automobile',
      'Quiz sur les voitures, la route, les marques et la mobilite.',
      'car',
      '#2563EB',
      true,
      now()
    ),
    (
      'Musique',
      'Quiz sur les artistes, les styles, les scenes et la culture musicale.',
      'music',
      '#DB2777',
      true,
      now()
    ),
    (
      'Shopping',
      'Quiz sur les enseignes, achats, paiement, livraison et reflexes consommateurs.',
      'shopping-bag',
      '#F59E0B',
      true,
      now()
    ),
    (
      'Technologie',
      'Quiz sur le numerique, les applications, internet et les innovations.',
      'cpu',
      '#6A5BE2',
      true,
      now()
    ),
    (
      'Telecom',
      'Quiz sur les operateurs, services mobiles, reseaux et usages telecom.',
      'phone',
      '#0891B2',
      true,
      now()
    )
  on conflict (name) do update set
    description = excluded.description,
    icon = excluded.icon,
    color = excluded.color,
    is_active = true
  returning id, name
),
category_rows as (
  select id, name from category_seed
  union
  select id, name
  from public.categories
  where name in (
    'Automobile',
    'Musique',
    'Shopping',
    'Technologie',
    'Telecom'
  )
),
bank_mapping as (
  select *
  from (
    values
      (
        '20260602-0000-4000-b001-000000000001'::uuid,
        'Banque Automobile',
        'Automobile',
        'Questions mutualisees pour les JCQ de la categorie Automobile.'
      ),
      (
        '20260602-0000-4000-b003-000000000003'::uuid,
        'Banque Musique',
        'Musique',
        'Questions mutualisees pour les JCQ de la categorie Musique.'
      ),
      (
        '20260602-0000-4000-b005-000000000005'::uuid,
        'Banque Shopping',
        'Shopping',
        'Questions mutualisees pour les JCQ de la categorie Shopping.'
      ),
      (
        '20260602-0000-4000-b002-000000000002'::uuid,
        'Banque Technologie',
        'Technologie',
        'Questions mutualisees pour les JCQ de la categorie Technologie.'
      ),
      (
        '20260602-0000-4000-b004-000000000004'::uuid,
        'Banque Telecom',
        'Telecom',
        'Questions mutualisees pour les JCQ de la categorie Telecom.'
      )
  ) as rows(bank_id, bank_name, category_name, bank_description)
),
bank_seed as (
  insert into public.question_banks (
    id,
    name,
    description,
    is_active,
    created_at,
    updated_at
  )
  select
    bank_mapping.bank_id,
    bank_mapping.bank_name,
    bank_mapping.bank_description,
    true,
    now(),
    now()
  from bank_mapping
  on conflict (id) do update set
    name = excluded.name,
    description = excluded.description,
    is_active = true,
    updated_at = now()
  returning id, name
),
bank_category_seed as (
  insert into public.question_bank_categories (
    question_bank_id,
    category_id
  )
  select
    bank_mapping.bank_id,
    category_rows.id
  from bank_mapping
  join category_rows on category_rows.name = bank_mapping.category_name
  on conflict (question_bank_id, category_id) do nothing
  returning question_bank_id, category_id
),
question_repair as (
  update public.questions
  set
    question_bank_id = bank_mapping.bank_id,
    question_scope = 'bank',
    is_active = coalesce(public.questions.is_active, true)
  from bank_mapping
  join category_rows on category_rows.name = bank_mapping.category_name
  where public.questions.category_id = category_rows.id
    and public.questions.contest_id is null
    and (
      public.questions.question_bank_id is null
      or public.questions.question_bank_id <> bank_mapping.bank_id
    )
  returning public.questions.id
)
select
  (select count(*) from bank_seed) as banks_upserted,
  (select count(*) from bank_category_seed) as bank_category_links_inserted,
  (select count(*) from question_repair) as questions_relinked,
  (
    select count(*)
    from public.questions
    where question_bank_id is not null
      and contest_id is null
  ) as bank_questions_total;
