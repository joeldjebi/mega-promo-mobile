-- MegaPromo - Relier les questions aux vraies banques lisibles
-- A executer si le SA affiche encore:
-- "Banque introuvable (20260602...)" apres les seeds/reparations.
--
-- Pourquoi:
-- - des questions peuvent pointer vers des anciens IDs de banques;
-- - les banques peuvent exister avec les bons noms mais avec d'autres IDs;
-- - le SA affiche alors les questions, mais ne trouve pas la banque par ID.
--
-- Objectif:
-- - garantir les 3 banques par nom;
-- - utiliser les IDs reels de ces banques;
-- - relier les questions Automobile/Technologie/Musique aux IDs reels;
-- - recréer les liens banque/categorie;
-- - ne pas supprimer de question;
-- - ne pas supprimer de JCQ.
--
-- Important:
-- - execute cette requete dans le meme Supabase que celui utilise par le web SA;
-- - DEV d'abord, PROD uniquement apres validation.

grant select on public.question_banks to authenticated, anon;
grant insert, update, delete on public.question_banks to authenticated;
grant select on public.question_bank_categories to authenticated, anon;
grant insert, update, delete on public.question_bank_categories to authenticated;

alter table public.question_banks disable row level security;
alter table public.question_bank_categories disable row level security;

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
expected_banks as (
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
  ) as rows(expected_bank_id, bank_name, category_name, bank_description)
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
    expected_banks.expected_bank_id,
    expected_banks.bank_name,
    expected_banks.bank_description,
    true,
    now(),
    now()
  from expected_banks
  on conflict (name) do update set
    description = excluded.description,
    is_active = true,
    updated_at = now()
  returning id, name
),
actual_banks as (
  select
    banks.id as actual_bank_id,
    expected_banks.expected_bank_id,
    expected_banks.bank_name,
    expected_banks.category_name,
    category_rows.id as category_id
  from expected_banks
  join public.question_banks banks on banks.name = expected_banks.bank_name
  join category_rows on category_rows.name = expected_banks.category_name
),
bank_category_cleanup as (
  delete from public.question_bank_categories links
  using actual_banks
  where links.category_id = actual_banks.category_id
    and links.question_bank_id <> actual_banks.actual_bank_id
  returning links.question_bank_id, links.category_id
),
bank_category_seed as (
  insert into public.question_bank_categories (
    question_bank_id,
    category_id
  )
  select
    actual_banks.actual_bank_id,
    actual_banks.category_id
  from actual_banks
  on conflict (question_bank_id, category_id) do nothing
  returning question_bank_id, category_id
),
question_relink as (
  update public.questions questions
  set
    question_bank_id = actual_banks.actual_bank_id,
    category_id = actual_banks.category_id,
    question_scope = 'bank',
    is_active = coalesce(questions.is_active, true)
  from actual_banks
  where questions.contest_id is null
    and (
      questions.category_id = actual_banks.category_id
      or questions.question_bank_id = actual_banks.expected_bank_id
      or questions.question_bank_id = actual_banks.actual_bank_id
    )
    and questions.question_bank_id is distinct from actual_banks.actual_bank_id
  returning questions.id
),
remaining_missing as (
  select count(*)::int as missing_count
  from public.questions questions
  left join public.question_banks banks
    on banks.id = questions.question_bank_id
  where questions.question_bank_id is not null
    and banks.id is null
)
select
  (select count(*) from bank_seed) as banks_ready,
  (select count(*) from bank_category_cleanup) as old_category_links_removed,
  (select count(*) from bank_category_seed) as bank_category_links_inserted,
  (select count(*) from question_relink) as questions_relinked,
  (select missing_count from remaining_missing) as remaining_questions_with_missing_bank;

notify pgrst, 'reload schema';
