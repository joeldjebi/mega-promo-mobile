-- MegaPromo - Banques Automobile, Technologie, Musique + JCQ associes
-- A executer dans Supabase SQL Editor apres:
-- 202606020001, 202606020002, 202606020003 et 202606020004.
--
-- Objectif:
-- - creer 3 banques de questions;
-- - lier chaque banque a sa categorie JCQ;
-- - creer 10 questions par banque;
-- - creer 1 JCQ par banque/categorie, donc 3 JCQ visibles au total;
-- - quand le joueur demarre un JCQ, le serveur tire 3 questions aleatoires
--   depuis la banque liee a la categorie du JCQ.

insert into public.contest_types (key, name, description, is_active, order_index)
values
  ('quiz', 'Quiz', 'Concours avec questions, reponses et score.', true, 1)
on conflict (key) do update set
  name = excluded.name,
  description = excluded.description,
  is_active = true,
  order_index = excluded.order_index;

-- Si une ancienne version de ce seed avait cree 3 JCQ par categorie, on rend
-- les doublons invisibles sans toucher aux participations eventuelles.
update public.contests
set status = 'inactive'
where title in (
  'JCQ Automobile #2',
  'JCQ Automobile #3',
  'JCQ Technologie #2',
  'JCQ Technologie #3',
  'JCQ Musique #2',
  'JCQ Musique #3'
)
and coalesce(reward_metadata ->> 'question_count', '') = '3';

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
bank_seed as (
  insert into public.question_banks (
    id,
    name,
    description,
    is_active,
    created_at,
    updated_at
  )
  values
    (
      '20260602-0000-4000-b001-000000000001'::uuid,
      'Banque Automobile',
      'Questions mutualisees pour les JCQ de la categorie Automobile.',
      true,
      now(),
      now()
    ),
    (
      '20260602-0000-4000-b002-000000000002'::uuid,
      'Banque Technologie',
      'Questions mutualisees pour les JCQ de la categorie Technologie.',
      true,
      now(),
      now()
    ),
    (
      '20260602-0000-4000-b003-000000000003'::uuid,
      'Banque Musique',
      'Questions mutualisees pour les JCQ de la categorie Musique.',
      true,
      now(),
      now()
    )
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
    banks.id,
    categories.id
  from (
    values
      ('Banque Automobile', 'Automobile'),
      ('Banque Technologie', 'Technologie'),
      ('Banque Musique', 'Musique')
  ) as mapping(bank_name, category_name)
  join public.question_banks banks on banks.name = mapping.bank_name
  join category_rows categories on categories.name = mapping.category_name
  on conflict (question_bank_id, category_id) do nothing
  returning question_bank_id, category_id
),
reward_seed as (
  insert into public.reward_catalog (
    id,
    name,
    reward_type,
    description,
    value_label,
    estimated_value,
    partner_id,
    default_code,
    default_delivery_instructions,
    terms,
    stock_quantity,
    used_quantity,
    is_active,
    metadata,
    created_at,
    updated_at
  )
  values (
    '20260602-0000-4000-e000-000000000301'::uuid,
    'Credit JCQ MegaPromo',
    'voucher',
    'Credit promotionnel offert aux gagnants des JCQ Automobile, Technologie et Musique.',
    'Credit 3 000 FCFA',
    3000,
    null,
    'JCQ-BANK-3000',
    'Contacter le gagnant depuis le SA pour confirmer son identite et organiser la remise du credit.',
    'Quiz gratuit, sans achat requis. Credit promotionnel personnel, non remboursable.',
    60,
    0,
    true,
    '{"seed": true, "free_quiz": true, "no_purchase_required": true}'::jsonb,
    now(),
    now()
  )
  on conflict (id) do update set
    name = excluded.name,
    reward_type = excluded.reward_type,
    description = excluded.description,
    value_label = excluded.value_label,
    estimated_value = excluded.estimated_value,
    default_code = excluded.default_code,
    default_delivery_instructions = excluded.default_delivery_instructions,
    terms = excluded.terms,
    stock_quantity = excluded.stock_quantity,
    is_active = true,
    metadata = excluded.metadata,
    updated_at = now()
  returning *
),
question_rows as (
  select *
  from (
    values
      ('automobile', 1, 'Quel element permet principalement de ralentir une voiture ?', 'Les freins', 'Le klaxon', 'Les phares', 'La radio', 'A', 'facile'),
      ('automobile', 2, 'Que signifie generalement ABS dans une voiture ?', 'Systeme antiblocage des roues', 'Aide batterie sport', 'Air balance system', 'Auto boost simple', 'A', 'moyen'),
      ('automobile', 3, 'Quel document est indispensable pour conduire legalement ?', 'Le permis de conduire', 'Une carte de fidelite', 'Un ticket de lavage', 'Une facture de carburant', 'A', 'facile'),
      ('automobile', 4, 'Quel voyant signale souvent un probleme de moteur ?', 'Check engine', 'Bluetooth', 'Mode nuit', 'Volume audio', 'A', 'moyen'),
      ('automobile', 5, 'Quelle pression concerne directement les pneus ?', 'La pression d air', 'La pression fiscale', 'La pression sonore', 'La pression d ecran', 'A', 'facile'),
      ('automobile', 6, 'Quel organe transmet la puissance aux roues ?', 'La transmission', 'Le pare-soleil', 'Le retroviseur', 'Le siege arriere', 'A', 'moyen'),
      ('automobile', 7, 'Que faut-il verifier avant un long trajet ?', 'Niveau d huile et pneus', 'Fond d ecran du telephone', 'Nom Bluetooth', 'Couleur des tapis', 'A', 'facile'),
      ('automobile', 8, 'Quel carburant est couramment utilise par les moteurs diesel ?', 'Gazole', 'Kerosene aviation', 'Eau minerale', 'Huile alimentaire', 'A', 'facile'),
      ('automobile', 9, 'Que designe la cylindree d un moteur ?', 'Le volume des cylindres', 'La taille du coffre', 'La couleur du volant', 'La largeur du pare-brise', 'A', 'moyen'),
      ('automobile', 10, 'Quel equipement aide a rester dans sa voie sur certains vehicules ?', 'Aide au maintien de voie', 'Chargeur mural', 'Radio AM', 'Boite a gants', 'A', 'moyen'),

      ('technologie', 1, 'Que signifie IA dans le domaine numerique ?', 'Intelligence artificielle', 'Interface analogique', 'Image automatique', 'Internet ancien', 'A', 'facile'),
      ('technologie', 2, 'Quel appareil sert principalement a se connecter a internet en mobilite ?', 'Smartphone', 'Micro-onde', 'Fer a repasser', 'Boussole papier', 'A', 'facile'),
      ('technologie', 3, 'Que protege un mot de passe robuste ?', 'Un compte utilisateur', 'Une bouteille d eau', 'Une chaise', 'Un cable HDMI uniquement', 'A', 'facile'),
      ('technologie', 4, 'Quel service permet de stocker des fichiers en ligne ?', 'Cloud', 'Clavier', 'Batterie', 'Projecteur', 'A', 'facile'),
      ('technologie', 5, 'Que signifie generalement 5G ?', 'Cinquieme generation mobile', 'Cinq gigaoctets fixes', 'Graphisme 5 couleurs', 'Gestion 5 fichiers', 'A', 'moyen'),
      ('technologie', 6, 'Quel composant execute les calculs principaux d un ordinateur ?', 'Processeur', 'Ecran', 'Souris', 'Haut-parleur', 'A', 'facile'),
      ('technologie', 7, 'Quel format est souvent utilise pour les pages web ?', 'HTML', 'MP3', 'PNG uniquement', 'GPS', 'A', 'facile'),
      ('technologie', 8, 'Que permet une mise a jour de securite ?', 'Corriger des failles', 'Changer la couleur du mur', 'Augmenter le carburant', 'Remplacer une carte SIM physique', 'A', 'moyen'),
      ('technologie', 9, 'Quel reseau local sans fil est tres courant ?', 'Wi-Fi', 'Diesel', 'Vinyle', 'Climatiseur', 'A', 'facile'),
      ('technologie', 10, 'Quel terme designe une application installee sur telephone ?', 'Application mobile', 'Circuit imprimante', 'Cable optique seul', 'Carte routiere papier', 'A', 'facile'),

      ('musique', 1, 'Quel element donne souvent le rythme dans une chanson ?', 'La batterie', 'Le retroviseur', 'Le clavier numerique', 'Le passeport', 'A', 'facile'),
      ('musique', 2, 'Comment appelle-t-on une suite de chansons publiees ensemble ?', 'Album', 'Moteur', 'Forfait', 'Clavier', 'A', 'facile'),
      ('musique', 3, 'Quel artiste chante generalement avec sa voix ?', 'Le vocaliste', 'Le mecanicien', 'Le programmeur', 'Le pilote automatique', 'A', 'facile'),
      ('musique', 4, 'Quel instrument possede des touches noires et blanches ?', 'Piano', 'Tambourin', 'Microphone', 'Casque audio', 'A', 'facile'),
      ('musique', 5, 'Que mesure le tempo d une musique ?', 'La vitesse du rythme', 'La taille de la scene', 'Le prix du ticket', 'La couleur de la pochette', 'A', 'moyen'),
      ('musique', 6, 'Comment appelle-t-on les paroles d une chanson ?', 'Lyrics', 'Moteur', 'Pixel', 'Carte SIM', 'A', 'facile'),
      ('musique', 7, 'Quel style musical est tres populaire en Cote d Ivoire ?', 'Coupe-decale', 'Country alpin', 'Opera spatial', 'Jazz polaire', 'A', 'facile'),
      ('musique', 8, 'Quel outil amplifie la voix sur scene ?', 'Microphone', 'Cle a molette', 'Routeur Wi-Fi', 'Extincteur', 'A', 'facile'),
      ('musique', 9, 'Que fait un DJ pendant une prestation musicale ?', 'Il mixe des sons', 'Il repare un moteur', 'Il construit un pont', 'Il imprime des cartes', 'A', 'facile'),
      ('musique', 10, 'Comment appelle-t-on une performance musicale devant un public ?', 'Concert', 'Vidange', 'Connexion', 'Archive', 'A', 'facile')
  ) as rows(bank_key, order_index, question_text, option_a, option_b, option_c, option_d, correct_answer, difficulty)
),
question_insert as (
  insert into public.questions (
    id,
    contest_id,
    question_bank_id,
    category_id,
    question_scope,
    question_text,
    option_a,
    option_b,
    option_c,
    option_d,
    correct_answer,
    points,
    time_limit,
    order_index,
    difficulty,
    is_active,
    created_at
  )
  select
    (
      substr(md5('bank-question-' || question_rows.bank_key || '-' || question_rows.order_index), 1, 8)
      || '-' ||
      substr(md5('bank-question-' || question_rows.bank_key || '-' || question_rows.order_index), 9, 4)
      || '-' ||
      substr(md5('bank-question-' || question_rows.bank_key || '-' || question_rows.order_index), 13, 4)
      || '-' ||
      substr(md5('bank-question-' || question_rows.bank_key || '-' || question_rows.order_index), 17, 4)
      || '-' ||
      substr(md5('bank-question-' || question_rows.bank_key || '-' || question_rows.order_index), 21, 12)
    )::uuid,
    null,
    case question_rows.bank_key
      when 'automobile' then '20260602-0000-4000-b001-000000000001'::uuid
      when 'technologie' then '20260602-0000-4000-b002-000000000002'::uuid
      else '20260602-0000-4000-b003-000000000003'::uuid
    end,
    categories.id,
    'bank',
    question_rows.question_text,
    question_rows.option_a,
    question_rows.option_b,
    question_rows.option_c,
    question_rows.option_d,
    question_rows.correct_answer,
    10,
    20,
    question_rows.order_index,
    question_rows.difficulty,
    true,
    now()
  from question_rows
  join category_rows categories
    on lower(categories.name) = question_rows.bank_key
      or (
        question_rows.bank_key = 'technologie'
        and categories.name = 'Technologie'
      )
      or (
        question_rows.bank_key = 'musique'
        and categories.name = 'Musique'
      )
  on conflict (id) do update set
    question_bank_id = excluded.question_bank_id,
    category_id = excluded.category_id,
    question_scope = excluded.question_scope,
    question_text = excluded.question_text,
    option_a = excluded.option_a,
    option_b = excluded.option_b,
    option_c = excluded.option_c,
    option_d = excluded.option_d,
    correct_answer = excluded.correct_answer,
    points = excluded.points,
    time_limit = excluded.time_limit,
    order_index = excluded.order_index,
    difficulty = excluded.difficulty,
    is_active = true
  returning id
),
contest_rows as (
  select *
  from (
    values
      ('automobile', 1, 'JCQ Automobile', 'Quiz concours gratuit sur les bases de l automobile. Au demarrage, 3 questions sont tirees aleatoirement depuis la banque Automobile.', 'https://images.unsplash.com/photo-1492144534655-ae79c964c9d7?auto=format&fit=crop&w=1200&q=80'),
      ('technologie', 1, 'JCQ Technologie', 'Quiz concours gratuit sur le numerique et les usages tech. Au demarrage, 3 questions sont tirees aleatoirement depuis la banque Technologie.', 'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?auto=format&fit=crop&w=1200&q=80'),
      ('musique', 1, 'JCQ Musique', 'Quiz concours gratuit sur les bases de la musique. Au demarrage, 3 questions sont tirees aleatoirement depuis la banque Musique.', 'https://images.unsplash.com/photo-1511379938547-c1f69419868d?auto=format&fit=crop&w=1200&q=80')
  ) as rows(bank_key, contest_index, title, description, image_url)
),
contest_insert as (
  insert into public.contests (
    id,
    partner_id,
    title,
    description,
    image_url,
    brand_logo_url,
    brand_name,
    type,
    category,
    category_id,
    status,
    prize_description,
    prize_value,
    reward_type,
    reward_catalog_id,
    reward_delivery_mode,
    reward_delivery_instructions,
    reward_terms,
    reward_metadata,
    winners_count,
    max_participants,
    starts_at,
    ends_at,
    is_boosted,
    allowed_player_plan_keys,
    is_live,
    live_status,
    views_count,
    shares_count,
    created_at
  )
  select
    (
      substr(md5('jcq-bank-contest-' || contest_rows.bank_key || '-' || contest_rows.contest_index), 1, 8)
      || '-' ||
      substr(md5('jcq-bank-contest-' || contest_rows.bank_key || '-' || contest_rows.contest_index), 9, 4)
      || '-' ||
      substr(md5('jcq-bank-contest-' || contest_rows.bank_key || '-' || contest_rows.contest_index), 13, 4)
      || '-' ||
      substr(md5('jcq-bank-contest-' || contest_rows.bank_key || '-' || contest_rows.contest_index), 17, 4)
      || '-' ||
      substr(md5('jcq-bank-contest-' || contest_rows.bank_key || '-' || contest_rows.contest_index), 21, 12)
    )::uuid,
    null,
    contest_rows.title,
    contest_rows.description,
    contest_rows.image_url,
    'https://www.google.com/s2/favicons?domain=megapromo.app&sz=128',
    'MegaPromo',
    'quiz',
    categories.name,
    categories.id,
    'active',
    reward_seed.value_label,
    reward_seed.estimated_value,
    reward_seed.reward_type,
    reward_seed.id,
    'manual',
    reward_seed.default_delivery_instructions,
    reward_seed.terms,
    coalesce(reward_seed.metadata, '{}'::jsonb)
      || jsonb_build_object(
        'question_count',
        3,
        'question_bank_id',
        case contest_rows.bank_key
          when 'automobile' then '20260602-0000-4000-b001-000000000001'
          when 'technologie' then '20260602-0000-4000-b002-000000000002'
          else '20260602-0000-4000-b003-000000000003'
        end,
        'question_bank_category',
        categories.name,
        'free_quiz',
        true,
        'no_purchase_required',
        true
      ),
    1,
    null,
    now(),
    now() + interval '14 days',
    true,
    array['free']::text[],
    false,
    'scheduled',
    0,
    0,
    now()
  from contest_rows
  join category_rows categories
    on (
      contest_rows.bank_key = 'automobile'
      and categories.name = 'Automobile'
    )
    or (
      contest_rows.bank_key = 'technologie'
      and categories.name = 'Technologie'
    )
    or (
      contest_rows.bank_key = 'musique'
      and categories.name = 'Musique'
    )
  cross join reward_seed
  on conflict (id) do update set
    title = excluded.title,
    description = excluded.description,
    image_url = excluded.image_url,
    brand_logo_url = excluded.brand_logo_url,
    brand_name = excluded.brand_name,
    type = excluded.type,
    category = excluded.category,
    category_id = excluded.category_id,
    status = excluded.status,
    prize_description = excluded.prize_description,
    prize_value = excluded.prize_value,
    reward_type = excluded.reward_type,
    reward_catalog_id = excluded.reward_catalog_id,
    reward_delivery_mode = excluded.reward_delivery_mode,
    reward_delivery_instructions = excluded.reward_delivery_instructions,
    reward_terms = excluded.reward_terms,
    reward_metadata = excluded.reward_metadata,
    winners_count = excluded.winners_count,
    max_participants = excluded.max_participants,
    starts_at = excluded.starts_at,
    ends_at = excluded.ends_at,
    is_boosted = excluded.is_boosted,
    allowed_player_plan_keys = excluded.allowed_player_plan_keys,
    is_live = false,
    live_status = 'scheduled'
  returning id
)
select
  (select count(*) from bank_seed) as banks_upserted,
  (select count(*) from bank_category_seed) as bank_category_links_inserted,
  (select count(*) from question_insert) as questions_upserted,
  (select count(*) from contest_insert) as contests_upserted;
