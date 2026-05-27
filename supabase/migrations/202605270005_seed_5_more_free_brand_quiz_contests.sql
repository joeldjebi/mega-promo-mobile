-- MegaPromo - 5 quiz promotionnels gratuits supplementaires
-- A executer dans Supabase SQL Editor apres:
-- 1) 20260525_create_manual_reward_fields.sql
-- 2) 202605270004_seed_7_free_brand_quiz_contests.sql
-- Script idempotent: cree/met a jour 5 quiz gratuits qui prennent fin
-- 5 jours apres execution, avec 3 questions chacun.

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
  values (
    'Quiz promo gratuits',
    'Quiz gratuits proposes par des entreprises partenaires pour faire connaitre leurs activites, produits et services.',
    'campaign',
    '#2563EB',
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
  values
    (
      '20260527-0000-4000-e000-000000000201'::uuid,
      'Bon trajet SOTRA',
      'voucher',
      'Bon de transport offert par SOTRA au laureat du quiz promo gratuit.',
      'Bon transport 3 000 FCFA',
      3000,
      null,
      'SOTRA-BON',
      'Envoyer le bon numerique au laureat apres validation du resultat.',
      'Quiz gratuit, sans achat requis. Bon non remboursable, utilisable selon les conditions SOTRA.',
      30,
      0,
      true,
      '{"seed": true, "apple_review": true, "free_quiz": true, "sponsor": "SOTRA"}'::jsonb,
      now(),
      now()
    ),
    (
      '20260527-0000-4000-e000-000000000202'::uuid,
      'Bon reduction Air Cote d''Ivoire',
      'discount_code',
      'Bon promotionnel offert par Air Cote d''Ivoire au laureat du quiz promo gratuit.',
      'Bon reduction voyage 10 000 FCFA',
      10000,
      null,
      'AIRCIV-PROMO',
      'Envoyer le bon numerique au laureat apres validation du resultat.',
      'Quiz gratuit, sans achat requis. Bon non remboursable, utilisable selon les conditions Air Cote d''Ivoire.',
      10,
      0,
      true,
      '{"seed": true, "apple_review": true, "free_quiz": true, "sponsor": "Air Cote d Ivoire"}'::jsonb,
      now(),
      now()
    ),
    (
      '20260527-0000-4000-e000-000000000203'::uuid,
      'Bon boisson Solibra',
      'voucher',
      'Bon de reduction offert par Solibra pour decouvrir ses produits et campagnes de marque.',
      'Bon reduction Solibra 5 000 FCFA',
      5000,
      null,
      'SOLIBRA-BON',
      'Envoyer le bon numerique au laureat apres validation du resultat.',
      'Quiz gratuit, sans achat requis. Bon non remboursable, utilisable selon les conditions Solibra.',
      20,
      0,
      true,
      '{"seed": true, "apple_review": true, "free_quiz": true, "sponsor": "Solibra"}'::jsonb,
      now(),
      now()
    ),
    (
      '20260527-0000-4000-e000-000000000204'::uuid,
      'Bon carburant TotalEnergies CI',
      'voucher',
      'Bon de service offert par TotalEnergies Cote d''Ivoire au laureat du quiz promo gratuit.',
      'Bon carburant 10 000 FCFA',
      10000,
      null,
      'TOTAL-CI-BON',
      'Envoyer le bon numerique au laureat apres validation du resultat.',
      'Quiz gratuit, sans achat requis. Bon non remboursable, utilisable selon les conditions TotalEnergies CI.',
      15,
      0,
      true,
      '{"seed": true, "apple_review": true, "free_quiz": true, "sponsor": "TotalEnergies Cote d Ivoire"}'::jsonb,
      now(),
      now()
    ),
    (
      '20260527-0000-4000-e000-000000000205'::uuid,
      'Bon cosmetique Gandour',
      'physical_item',
      'Produit cosmetique offert par Nouvelle Parfumerie Gandour au laureat du quiz promo gratuit.',
      'Pack cosmetique Gandour',
      8000,
      null,
      'GANDOUR-PACK',
      'Contacter le laureat pour organiser la remise du pack produit offert.',
      'Quiz gratuit, sans achat requis. Pack personnel, non remboursable et remis selon les conditions Gandour.',
      12,
      0,
      true,
      '{"seed": true, "apple_review": true, "free_quiz": true, "sponsor": "Nouvelle Parfumerie Gandour"}'::jsonb,
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
contest_rows as (
  select *
  from (
    values
      (
        '20260527-0000-4000-d000-000000000201'::uuid,
        'Quiz gratuit SOTRA - Mobilite urbaine',
        'SOTRA propose ce quiz promotionnel gratuit pour presenter ses services de transport urbain, ses lignes et son role dans la mobilite quotidienne en Cote d''Ivoire. La participation est gratuite, sans achat requis, et la recompense est offerte par SOTRA aux meilleurs scores.',
        'https://images.unsplash.com/photo-1544620347-c4fd4a3d5957?auto=format&fit=crop&w=1200&q=80',
        'https://www.google.com/s2/favicons?domain=sotra.ci&sz=128',
        'SOTRA',
        '20260527-0000-4000-e000-000000000201'::uuid,
        true
      ),
      (
        '20260527-0000-4000-d000-000000000202'::uuid,
        'Quiz gratuit Air Cote d''Ivoire - Voyage local',
        'Air Cote d''Ivoire propose ce quiz promotionnel gratuit pour faire connaitre ses destinations, son service client et son experience de voyage. Aucun achat n''est requis: les joueurs repondent a des questions sur l''activite de la compagnie, puis les meilleurs scores peuvent recevoir une recompense offerte par Air Cote d''Ivoire.',
        'https://images.unsplash.com/photo-1436491865332-7a61a109cc05?auto=format&fit=crop&w=1200&q=80',
        'https://www.google.com/s2/favicons?domain=aircotedivoire.com&sz=128',
        'Air Cote d''Ivoire',
        '20260527-0000-4000-e000-000000000202'::uuid,
        true
      ),
      (
        '20260527-0000-4000-d000-000000000203'::uuid,
        'Quiz gratuit Solibra - Marques et boissons',
        'Solibra propose ce quiz promotionnel gratuit pour presenter ses marques, ses produits et ses actions de proximite. La participation est gratuite, sans achat requis, et la recompense est offerte par Solibra pour valoriser ses produits aupres des joueurs.',
        'https://images.unsplash.com/photo-1544145945-f90425340c7e?auto=format&fit=crop&w=1200&q=80',
        'https://www.google.com/s2/favicons?domain=solibra.ci&sz=128',
        'Solibra',
        '20260527-0000-4000-e000-000000000203'::uuid,
        false
      ),
      (
        '20260527-0000-4000-d000-000000000204'::uuid,
        'Quiz gratuit TotalEnergies CI - Services station',
        'TotalEnergies Cote d''Ivoire propose ce quiz promotionnel gratuit pour presenter ses stations-service, ses produits energie et ses services utiles aux conducteurs. Aucun achat n''est requis: la recompense est offerte par TotalEnergies CI aux meilleurs scores.',
        'https://images.unsplash.com/photo-1545558014-8692077e9b5c?auto=format&fit=crop&w=1200&q=80',
        'https://www.google.com/s2/favicons?domain=totalenergies.ci&sz=128',
        'TotalEnergies Cote d''Ivoire',
        '20260527-0000-4000-e000-000000000204'::uuid,
        true
      ),
      (
        '20260527-0000-4000-d000-000000000205'::uuid,
        'Quiz gratuit Gandour - Produits cosmetiques',
        'Nouvelle Parfumerie Gandour propose ce quiz promotionnel gratuit pour faire connaitre ses produits cosmetiques, soins et marques du quotidien. La participation est gratuite, sans achat requis, et la recompense est offerte par Gandour aux meilleurs scores.',
        'https://images.unsplash.com/photo-1596462502278-27bfdc403348?auto=format&fit=crop&w=1200&q=80',
        'https://www.google.com/s2/favicons?domain=gandour.com&sz=128',
        'Nouvelle Parfumerie Gandour',
        '20260527-0000-4000-e000-000000000205'::uuid,
        false
      )
  ) as rows (
    contest_id,
    title,
    description,
    image_url,
    brand_logo_url,
    brand_name,
    reward_catalog_id,
    is_boosted
  )
),
contest_seed as (
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
    live_starts_at,
    live_status,
    views_count,
    shares_count,
    created_at
  )
  select
    contest_rows.contest_id,
    null,
    contest_rows.title,
    contest_rows.description,
    contest_rows.image_url,
    contest_rows.brand_logo_url,
    contest_rows.brand_name,
    'quiz',
    category_seed.name,
    category_seed.id,
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
        'free_quiz', true,
        'no_purchase_required', true,
        'reward_provider', contest_rows.brand_name,
        'apple_review_context',
        'Quiz promotionnel gratuit: la recompense est offerte par l entreprise partenaire.'
      ),
    2,
    null,
    now(),
    now() + interval '5 days',
    contest_rows.is_boosted,
    array['free']::text[],
    false,
    null,
    'scheduled',
    0,
    0,
    now()
  from contest_rows
  join category_seed on true
  join reward_seed on reward_seed.id = contest_rows.reward_catalog_id
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
    live_starts_at = null,
    live_status = 'scheduled'
  returning id
),
questions_seed as (
  insert into public.questions (
    id,
    contest_id,
    question_text,
    option_a,
    option_b,
    option_c,
    option_d,
    correct_answer,
    points,
    time_limit,
    order_index,
    created_at
  )
  select
    question_rows.id,
    question_rows.contest_id,
    question_rows.question_text,
    question_rows.option_a,
    question_rows.option_b,
    question_rows.option_c,
    question_rows.option_d,
    question_rows.correct_answer,
    question_rows.points,
    question_rows.time_limit,
    question_rows.order_index,
    question_rows.created_at
  from (
    values
    (
      '20260527-0000-4000-f000-000000000801'::uuid,
      '20260527-0000-4000-d000-000000000201'::uuid,
      'Quel service SOTRA met-il en avant dans ce quiz gratuit ?',
      'Transport urbain',
      'Cinema',
      'Vente en ligne',
      'Produits cosmetiques',
      'A',
      10,
      25,
      1,
      now()
    ),
    (
      '20260527-0000-4000-f000-000000000802'::uuid,
      '20260527-0000-4000-d000-000000000201'::uuid,
      'A quoi sert principalement le reseau SOTRA ?',
      'Faciliter les deplacements en ville',
      'Commander des repas',
      'Regarder des films',
      'Acheter des parfums',
      'A',
      10,
      25,
      2,
      now()
    ),
    (
      '20260527-0000-4000-f000-000000000803'::uuid,
      '20260527-0000-4000-d000-000000000201'::uuid,
      'Qui offre la recompense du quiz SOTRA ?',
      'SOTRA',
      'Une librairie',
      'Une salle de sport',
      'Un magasin de vetements',
      'A',
      10,
      25,
      3,
      now()
    ),
    (
      '20260527-0000-4000-f000-000000000811'::uuid,
      '20260527-0000-4000-d000-000000000202'::uuid,
      'Air Cote d''Ivoire est associee a quel service ?',
      'Transport aerien',
      'Transport urbain par bus',
      'Cosmetiques',
      'Distribution alimentaire',
      'A',
      10,
      25,
      1,
      now()
    ),
    (
      '20260527-0000-4000-f000-000000000812'::uuid,
      '20260527-0000-4000-d000-000000000202'::uuid,
      'Que presente ce quiz Air Cote d''Ivoire ?',
      'Destinations et experience de voyage',
      'Produits de beaute',
      'Tickets cinema',
      'Stations-service uniquement',
      'A',
      10,
      25,
      2,
      now()
    ),
    (
      '20260527-0000-4000-f000-000000000813'::uuid,
      '20260527-0000-4000-d000-000000000202'::uuid,
      'La participation a ce quiz Air Cote d''Ivoire est indiquee comme quoi ?',
      'Gratuite, sans achat requis',
      'Reservee aux employes',
      'Reservee aux agences externes',
      'Reservee aux boutiques',
      'A',
      10,
      25,
      3,
      now()
    ),
    (
      '20260527-0000-4000-f000-000000000821'::uuid,
      '20260527-0000-4000-d000-000000000203'::uuid,
      'Solibra est associee a quel type de produits ?',
      'Boissons et marques de consommation',
      'Avions',
      'Bus urbains',
      'Forfaits TV',
      'A',
      10,
      25,
      1,
      now()
    ),
    (
      '20260527-0000-4000-f000-000000000822'::uuid,
      '20260527-0000-4000-d000-000000000203'::uuid,
      'Quel est l''objectif du quiz Solibra ?',
      'Faire connaitre ses marques et produits',
      'Changer un mot de passe',
      'Vendre un ordinateur',
      'Presenter une compagnie aerienne',
      'A',
      10,
      25,
      2,
      now()
    ),
    (
      '20260527-0000-4000-f000-000000000823'::uuid,
      '20260527-0000-4000-d000-000000000203'::uuid,
      'Quelle recompense Solibra offre-t-elle ?',
      'Un bon de reduction',
      'Un billet avion',
      'Une carte de transport',
      'Un forfait TV',
      'A',
      10,
      25,
      3,
      now()
    ),
    (
      '20260527-0000-4000-f000-000000000831'::uuid,
      '20260527-0000-4000-d000-000000000204'::uuid,
      'TotalEnergies CI est connue pour quels services ?',
      'Stations-service et produits energie',
      'Salles de cinema',
      'Transport aerien',
      'Cosmetiques',
      'A',
      10,
      25,
      1,
      now()
    ),
    (
      '20260527-0000-4000-f000-000000000832'::uuid,
      '20260527-0000-4000-d000-000000000204'::uuid,
      'Quel public ce quiz TotalEnergies CI informe-t-il notamment ?',
      'Conducteurs et clients des stations',
      'Spectateurs de cinema uniquement',
      'Voyageurs aeriens uniquement',
      'Lecteurs de journaux',
      'A',
      10,
      25,
      2,
      now()
    ),
    (
      '20260527-0000-4000-f000-000000000833'::uuid,
      '20260527-0000-4000-d000-000000000204'::uuid,
      'Qui fournit la recompense TotalEnergies CI ?',
      'TotalEnergies Cote d''Ivoire',
      'Une boutique de jouets',
      'Une agence photo',
      'Une ecole de danse',
      'A',
      10,
      25,
      3,
      now()
    ),
    (
      '20260527-0000-4000-f000-000000000841'::uuid,
      '20260527-0000-4000-d000-000000000205'::uuid,
      'Gandour presente principalement quel univers dans ce quiz ?',
      'Cosmetiques et soins du quotidien',
      'Transport urbain',
      'Boissons gazeuses',
      'Compagnie aerienne',
      'A',
      10,
      25,
      1,
      now()
    ),
    (
      '20260527-0000-4000-f000-000000000842'::uuid,
      '20260527-0000-4000-d000-000000000205'::uuid,
      'Quelle recompense Gandour offre-t-elle ?',
      'Un pack cosmetique',
      'Un ticket cinema',
      'Un bon carburant',
      'Un bon transport',
      'A',
      10,
      25,
      2,
      now()
    ),
    (
      '20260527-0000-4000-f000-000000000843'::uuid,
      '20260527-0000-4000-d000-000000000205'::uuid,
      'Pourquoi ce quiz Gandour est-il propose ?',
      'Faire connaitre ses produits et marques',
      'Presenter des lignes de bus',
      'Presenter des destinations aeriennes',
      'Presenter des offres carburant',
      'A',
      10,
      25,
      3,
      now()
    )
  ) as question_rows (
    id,
    contest_id,
    question_text,
    option_a,
    option_b,
    option_c,
    option_d,
    correct_answer,
    points,
    time_limit,
    order_index,
    created_at
  )
  join contest_seed on contest_seed.id = question_rows.contest_id
  on conflict (id) do update set
    question_text = excluded.question_text,
    option_a = excluded.option_a,
    option_b = excluded.option_b,
    option_c = excluded.option_c,
    option_d = excluded.option_d,
    correct_answer = excluded.correct_answer,
    points = excluded.points,
    time_limit = excluded.time_limit,
    order_index = excluded.order_index
  returning id
)
select
  contests.id,
  contests.title,
  contests.brand_name,
  contests.type,
  contests.starts_at,
  contests.ends_at,
  contests.prize_description,
  contests.reward_catalog_id,
  count(questions.id) as questions_count
from public.contests
left join public.questions on questions.contest_id = contests.id
where contests.id in (
  '20260527-0000-4000-d000-000000000201'::uuid,
  '20260527-0000-4000-d000-000000000202'::uuid,
  '20260527-0000-4000-d000-000000000203'::uuid,
  '20260527-0000-4000-d000-000000000204'::uuid,
  '20260527-0000-4000-d000-000000000205'::uuid
)
group by contests.id
order by contests.brand_name;
