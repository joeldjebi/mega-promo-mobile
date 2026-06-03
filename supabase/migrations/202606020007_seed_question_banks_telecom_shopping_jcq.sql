-- MegaPromo - Banques Telecom, Shopping + JCQ entreprises ivoiriennes
-- A executer dans Supabase SQL Editor apres:
-- 202606020001, 202606020002, 202606020003 et 202606020004.
--
-- Objectif:
-- - creer 2 banques de questions: Telecom et Shopping;
-- - lier chaque banque a sa categorie JCQ;
-- - creer 10 questions par banque;
-- - creer 1 JCQ par banque/categorie, donc 2 JCQ visibles au total;
-- - quand le joueur demarre un JCQ, le serveur tire 3 questions aleatoires
--   depuis la banque liee a la categorie du JCQ.
--
-- Important:
-- - execute d'abord en DEV pour tester;
-- - execute en PROD uniquement si tu veux publier ces JCQ aux vrais joueurs.

insert into public.contest_types (key, name, description, is_active, order_index)
values
  ('quiz', 'Quiz', 'Concours avec questions, reponses et score.', true, 1)
on conflict (key) do update set
  name = excluded.name,
  description = excluded.description,
  is_active = true,
  order_index = excluded.order_index;

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
      'Telecom',
      'Quiz sur les operateurs, services mobiles, reseaux et usages telecom en Cote d''Ivoire.',
      'phone',
      '#0891B2',
      true,
      now()
    ),
    (
      'Shopping',
      'Quiz sur les enseignes, achats, paiement, livraison et reflexes consommateurs en Cote d''Ivoire.',
      'shopping-bag',
      '#F59E0B',
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
  where name in ('Telecom', 'Shopping')
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
      '20260602-0000-4000-b004-000000000004'::uuid,
      'Banque Telecom',
      'Questions mutualisees pour les JCQ de la categorie Telecom.',
      true,
      now(),
      now()
    ),
    (
      '20260602-0000-4000-b005-000000000005'::uuid,
      'Banque Shopping',
      'Questions mutualisees pour les JCQ de la categorie Shopping.',
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
      ('Banque Telecom', 'Telecom'),
      ('Banque Shopping', 'Shopping')
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
    '20260602-0000-4000-e000-000000000501'::uuid,
    'Credit JCQ Entreprises CI',
    'voucher',
    'Credit promotionnel offert aux gagnants des JCQ Telecom et Shopping.',
    'Credit 3 000 FCFA',
    3000,
    null,
    'JCQ-CI-3000',
    'Contacter le gagnant depuis le SA pour confirmer son identite et organiser la remise du credit.',
    'Quiz gratuit, sans achat requis. Credit promotionnel personnel, non remboursable.',
    40,
    0,
    true,
    '{"seed": true, "free_quiz": true, "no_purchase_required": true, "theme": "entreprises_ivoiriennes"}'::jsonb,
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
      ('telecom', 1, 'Quel service permet d''appeler et d''envoyer des messages depuis un telephone mobile ?', 'Le reseau mobile', 'Le ticket de caisse', 'La carte de fidelite', 'Le panier d''achat', 'A', 'facile'),
      ('telecom', 2, 'Quel element identifie generalement une ligne mobile chez un operateur ?', 'La carte SIM', 'Le code-barres produit', 'Le sac de livraison', 'Le ticket de caisse', 'A', 'facile'),
      ('telecom', 3, 'Quel service est souvent propose par les operateurs telecom en Cote d''Ivoire pour payer ou transferer de l''argent ?', 'Mobile money', 'Lavage auto', 'Impression photo', 'Service pressing', 'A', 'facile'),
      ('telecom', 4, 'Que mesure principalement la qualite d''un reseau mobile ?', 'La couverture et la stabilite du signal', 'La couleur du telephone', 'La taille du magasin', 'Le poids du chargeur', 'A', 'moyen'),
      ('telecom', 5, 'Quel usage consomme generalement des donnees internet mobile ?', 'Regarder une video en ligne', 'Eteindre son telephone', 'Lire un papier hors ligne', 'Brancher un chargeur sans internet', 'A', 'facile'),
      ('telecom', 6, 'Quel canal permet souvent de joindre le service client d''un operateur ?', 'Un numero court ou centre d''appel', 'Une pompe a essence', 'Un rayon textile', 'Un distributeur de pain', 'A', 'facile'),
      ('telecom', 7, 'Pourquoi comparer les forfaits mobiles avant d''acheter ?', 'Pour choisir l''offre adaptee a son besoin', 'Pour changer la couleur de la SIM', 'Pour supprimer le reseau', 'Pour eviter tout appel', 'A', 'moyen'),
      ('telecom', 8, 'Quel type d''entreprise fournit des forfaits voix, SMS et internet ?', 'Un operateur telecom', 'Une boulangerie', 'Un garage auto', 'Une librairie seulement', 'A', 'facile'),
      ('telecom', 9, 'Que signifie recharger son credit mobile ?', 'Ajouter du solde a sa ligne', 'Changer de telephone obligatoirement', 'Effacer son numero', 'Bloquer le reseau', 'A', 'facile'),
      ('telecom', 10, 'Quel bon reflexe adopter avant une operation mobile money ?', 'Verifier le beneficiaire et le montant', 'Partager son code secret', 'Ignorer les SMS de confirmation', 'Valider sans regarder', 'A', 'moyen'),

      ('shopping', 1, 'Quel document confirme generalement un achat en boutique ?', 'Le ticket de caisse', 'La carte SIM', 'Le code PIN mobile', 'Le signal reseau', 'A', 'facile'),
      ('shopping', 2, 'Quel service permet de recevoir un produit sans se deplacer en magasin ?', 'La livraison', 'Le mode avion', 'La messagerie vocale', 'La recharge mobile', 'A', 'facile'),
      ('shopping', 3, 'Quel bon reflexe adopter avant de payer en ligne ?', 'Verifier le site, le prix et le vendeur', 'Partager son mot de passe', 'Acheter sans lire', 'Ignorer les frais', 'A', 'moyen'),
      ('shopping', 4, 'Dans un supermarche, que compare souvent un client avant d''acheter ?', 'Le prix et la qualite', 'Le numero de telephone du reseau', 'Le nom de la carte SIM', 'La force du signal', 'A', 'facile'),
      ('shopping', 5, 'Quel mode de paiement est courant dans les commerces modernes ?', 'Paiement mobile ou carte bancaire', 'Code secret partage en public', 'Photo de profil', 'Mode avion', 'A', 'facile'),
      ('shopping', 6, 'Pourquoi garder une preuve d''achat ?', 'Pour faciliter un retour ou une reclamation', 'Pour augmenter le reseau', 'Pour changer son numero', 'Pour supprimer la livraison', 'A', 'moyen'),
      ('shopping', 7, 'Quel type d''entreprise vend des produits aux consommateurs finaux ?', 'Une enseigne de distribution', 'Un satellite', 'Une antenne reseau', 'Un moteur uniquement', 'A', 'facile'),
      ('shopping', 8, 'Que signifie une promotion dans un magasin ?', 'Une offre avec avantage ou reduction', 'Une panne reseau', 'Une carte SIM inactive', 'Un paiement refuse automatiquement', 'A', 'facile'),
      ('shopping', 9, 'Quel risque existe si un prix est trop beau pour etre vrai en ligne ?', 'Une arnaque ou une mauvaise surprise', 'Une meilleure connexion', 'Un reseau plus fort', 'Une livraison instantanee garantie', 'A', 'moyen'),
      ('shopping', 10, 'Quel reflexe aide a choisir une boutique fiable ?', 'Consulter les avis et les informations du vendeur', 'Ignorer toutes les informations', 'Envoyer son code secret', 'Payer sans verifier', 'A', 'moyen')
  ) as rows(bank_key, order_index, question_text, option_a, option_b, option_c, option_d, correct_answer, difficulty)
),
bank_mapping as (
  select *
  from (
    values
      ('telecom', 'Telecom', '20260602-0000-4000-b004-000000000004'::uuid),
      ('shopping', 'Shopping', '20260602-0000-4000-b005-000000000005'::uuid)
  ) as rows(bank_key, category_name, question_bank_id)
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
      substr(md5('bank-question-ci-' || question_rows.bank_key || '-' || question_rows.order_index), 1, 8)
      || '-' ||
      substr(md5('bank-question-ci-' || question_rows.bank_key || '-' || question_rows.order_index), 9, 4)
      || '-' ||
      substr(md5('bank-question-ci-' || question_rows.bank_key || '-' || question_rows.order_index), 13, 4)
      || '-' ||
      substr(md5('bank-question-ci-' || question_rows.bank_key || '-' || question_rows.order_index), 17, 4)
      || '-' ||
      substr(md5('bank-question-ci-' || question_rows.bank_key || '-' || question_rows.order_index), 21, 12)
    )::uuid,
    null,
    bank_mapping.question_bank_id,
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
  join bank_mapping on bank_mapping.bank_key = question_rows.bank_key
  join category_rows categories on categories.name = bank_mapping.category_name
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
      ('telecom', 'JCQ Telecom CI', 'Quiz concours gratuit sur les services telecom et usages mobiles des entreprises presentes en Cote d''Ivoire.', 'https://images.unsplash.com/photo-1516321497487-e288fb19713f?auto=format&fit=crop&w=1200&q=80'),
      ('shopping', 'JCQ Shopping CI', 'Quiz concours gratuit sur les enseignes, achats, paiement et livraison en Cote d''Ivoire.', 'https://images.unsplash.com/photo-1472851294608-062f824d29cc?auto=format&fit=crop&w=1200&q=80')
  ) as rows(bank_key, title, description, image_url)
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
      substr(md5('jcq-ci-contest-' || contest_rows.bank_key), 1, 8)
      || '-' ||
      substr(md5('jcq-ci-contest-' || contest_rows.bank_key), 9, 4)
      || '-' ||
      substr(md5('jcq-ci-contest-' || contest_rows.bank_key), 13, 4)
      || '-' ||
      substr(md5('jcq-ci-contest-' || contest_rows.bank_key), 17, 4)
      || '-' ||
      substr(md5('jcq-ci-contest-' || contest_rows.bank_key), 21, 12)
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
        bank_mapping.question_bank_id::text,
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
  join bank_mapping on bank_mapping.bank_key = contest_rows.bank_key
  join category_rows categories on categories.name = bank_mapping.category_name
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
