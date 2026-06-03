-- MegaPromo - 3 banques de questions initiales, sans questions
-- A executer dans Supabase SQL Editor apres:
-- 202606020004_create_question_banks_and_category_draw.sql
-- et apres le reset 202606020009 si tu repars de zero.
--
-- Objectif:
-- - creer 3 categories JCQ: Automobile, Technologie, Musique;
-- - creer 1 banque de questions officielle pour chaque categorie;
-- - lier chaque banque a sa categorie;
-- - ne pas creer de questions;
-- - ne pas creer de JCQ.
--
-- Important:
-- - execute d'abord en DEV;
-- - execute ensuite en PROD uniquement apres validation.

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
      'Technologie',
      'Quiz sur le numerique, les applications, internet et les innovations.',
      'cpu',
      '#6A5BE2',
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
  where name in ('Automobile', 'Technologie', 'Musique')
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
        '20260602-0000-4000-b002-000000000002'::uuid,
        'Banque Technologie',
        'Technologie',
        'Questions mutualisees pour les JCQ de la categorie Technologie.'
      ),
      (
        '20260602-0000-4000-b003-000000000003'::uuid,
        'Banque Musique',
        'Musique',
        'Questions mutualisees pour les JCQ de la categorie Musique.'
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
)
select
  (select count(*) from category_rows) as categories_ready,
  (select count(*) from bank_seed) as banks_ready,
  (select count(*) from bank_category_seed) as bank_category_links_inserted;

notify pgrst, 'reload schema';
