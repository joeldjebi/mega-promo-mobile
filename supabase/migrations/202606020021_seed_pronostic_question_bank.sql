-- MegaPromo - Banque de questions Pronostics
-- A executer dans Supabase SQL Editor apres:
-- 202606020004_create_question_banks_and_category_draw.sql
-- 202606020017_add_media_fields_to_quiz_questions.sql
-- 202606020020_add_pronostic_question_type.sql
--
-- Objectif:
-- - creer la categorie de banque "Pronostics";
-- - creer une banque officielle "Banque Pronostics";
-- - ajouter 30 questions de type pronostic:
--   * 10 questions ou le prompt est une image;
--   * 10 questions ou les propositions sont des images;
--   * 10 questions normales texte;
-- - ne pas creer de JCQ ni QL;
-- - ne pas toucher aux questions de Quiz Live deja ouverts.

alter table public.questions
add column if not exists question_image_url text,
add column if not exists option_a_image_url text,
add column if not exists option_b_image_url text,
add column if not exists option_c_image_url text,
add column if not exists option_d_image_url text,
add column if not exists question_type text not null default 'quiz',
add column if not exists prediction_type text,
add column if not exists prediction_payload jsonb not null default '{}'::jsonb,
add column if not exists result_payload jsonb not null default '{}'::jsonb,
add column if not exists resolution_status text not null default 'not_required';

alter table public.questions
alter column question_type set default 'quiz',
alter column prediction_payload set default '{}'::jsonb,
alter column result_payload set default '{}'::jsonb,
alter column resolution_status set default 'not_required';

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
    'Pronostics',
    'Questions de prediction sportive pour les JCQ et Quiz Live.',
    'sports',
    '#16A34A',
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
bank_seed as (
  insert into public.question_banks (
    id,
    name,
    description,
    questions_per_quiz,
    is_active,
    created_at,
    updated_at
  )
  values (
    '20260602-0000-4000-b004-000000000004'::uuid,
    'Banque Pronostics',
    'Questions de pronostics sport et football pour les JCQ/QL.',
    5,
    true,
    now(),
    now()
  )
  on conflict (name) do update set
    name = excluded.name,
    description = excluded.description,
    questions_per_quiz = excluded.questions_per_quiz,
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
    bank_seed.id,
    category_seed.id
  from bank_seed
  cross join category_seed
  on conflict (question_bank_id, category_id) do nothing
  returning question_bank_id, category_id
),
question_rows as (
  select *
  from (
    values
      (
        101,
        'image_prompt',
        'match_winner',
        'Sur cette affiche de match, quel est ton pronostic ?',
        'Victoire Cote d Ivoire',
        'Match nul',
        'Victoire adversaire',
        'Plus de 2,5 buts',
        'A',
        'https://images.unsplash.com/photo-1574629810360-7efbbe195018?auto=format&fit=crop&w=1200&q=80',
        null,
        null,
        null,
        null,
        '{"match_label": "Cote d Ivoire vs Senegal", "home_team": "Cote d Ivoire", "away_team": "Senegal", "market": "match_winner"}'::jsonb
      ),
      (
        102,
        'image_prompt',
        'exact_score',
        'Observe l image du stade: quel score final anticipes-tu ?',
        '2-1',
        '1-1',
        '1-0',
        '0-2',
        'A',
        'https://images.unsplash.com/photo-1518091043644-c1d4457512c6?auto=format&fit=crop&w=1200&q=80',
        null,
        null,
        null,
        null,
        '{"match_label": "Cote d Ivoire vs Nigeria", "home_team": "Cote d Ivoire", "away_team": "Nigeria", "market": "exact_score"}'::jsonb
      ),
      (
        103,
        'image_prompt',
        'over_under',
        'D apres cette ambiance de match, que pronostiques-tu ?',
        'Plus de 2,5 buts',
        'Moins de 2,5 buts',
        'Aucun but',
        'Plus de 4,5 buts',
        'A',
        'https://images.unsplash.com/photo-1508098682722-e99c43a406b2?auto=format&fit=crop&w=1200&q=80',
        null,
        null,
        null,
        null,
        '{"match_label": "Ghana vs Cote d Ivoire", "home_team": "Ghana", "away_team": "Cote d Ivoire", "market": "over_under", "line": 2.5}'::jsonb
      ),
      (
        104,
        'image_prompt',
        'scorer',
        'Cette image evoque une phase offensive: qui marquera ?',
        'Attaquant ivoirien',
        'Milieu ivoirien',
        'Defenseur adverse',
        'Aucun buteur',
        'A',
        'https://images.unsplash.com/photo-1522778119026-d647f0596c20?auto=format&fit=crop&w=1200&q=80',
        null,
        null,
        null,
        null,
        '{"match_label": "Cote d Ivoire vs Mali", "home_team": "Cote d Ivoire", "away_team": "Mali", "market": "scorer"}'::jsonb
      ),
      (
        105,
        'image_prompt',
        'first_goal',
        'Sur cette action, quel scenario vois-tu arriver ?',
        'Cote d Ivoire marque en premier',
        'Adversaire marque en premier',
        'Pas de but',
        'But apres la 75e minute',
        'A',
        'https://images.unsplash.com/photo-1431324155629-1a6deb1dec8d?auto=format&fit=crop&w=1200&q=80',
        null,
        null,
        null,
        null,
        '{"match_label": "Cote d Ivoire vs Cameroun", "home_team": "Cote d Ivoire", "away_team": "Cameroun", "market": "first_goal"}'::jsonb
      ),
      (
        106,
        'image_prompt',
        'double_chance',
        'Quel choix securise le mieux ce match affiche ?',
        'Cote d Ivoire ou nul',
        'Adversaire ou nul',
        'Cote d Ivoire ou adversaire',
        'Score exact 0-0',
        'A',
        'https://images.unsplash.com/photo-1526232761682-d26e03ac148e?auto=format&fit=crop&w=1200&q=80',
        null,
        null,
        null,
        null,
        '{"match_label": "Cote d Ivoire vs Maroc", "home_team": "Cote d Ivoire", "away_team": "Maroc", "market": "double_chance"}'::jsonb
      ),
      (
        107,
        'image_prompt',
        'corners',
        'Cette image montre un corner: quel total anticipes-tu ?',
        'Plus de 8 corners',
        'Moins de 8 corners',
        'Aucun corner',
        'Exactement 3 corners',
        'A',
        'https://images.unsplash.com/photo-1551958219-acbc608c6377?auto=format&fit=crop&w=1200&q=80',
        null,
        null,
        null,
        null,
        '{"match_label": "Cote d Ivoire vs Afrique du Sud", "home_team": "Cote d Ivoire", "away_team": "Afrique du Sud", "market": "corners", "line": 8}'::jsonb
      ),
      (
        108,
        'image_prompt',
        'cards',
        'Sur ce duel intense, quel pronostic cartons choisis-tu ?',
        'Plus de 3 cartons',
        'Moins de 3 cartons',
        'Aucun carton',
        'Carton rouge obligatoire',
        'A',
        'https://images.unsplash.com/photo-1517747614396-d21a78b850e8?auto=format&fit=crop&w=1200&q=80',
        null,
        null,
        null,
        null,
        '{"match_label": "Senegal vs Cote d Ivoire", "home_team": "Senegal", "away_team": "Cote d Ivoire", "market": "cards", "line": 3}'::jsonb
      ),
      (
        109,
        'image_prompt',
        'halftime_result',
        'A la pause, quel resultat imagines-tu ?',
        'Cote d Ivoire devant',
        'Egalite',
        'Adversaire devant',
        'Score vierge',
        'A',
        'https://images.unsplash.com/photo-1579952363873-27f3bade9f55?auto=format&fit=crop&w=1200&q=80',
        null,
        null,
        null,
        null,
        '{"match_label": "Cote d Ivoire vs Burkina Faso", "home_team": "Cote d Ivoire", "away_team": "Burkina Faso", "market": "halftime_result"}'::jsonb
      ),
      (
        110,
        'image_prompt',
        'clean_sheet',
        'Cette defense tiendra-t-elle sans encaisser ?',
        'Oui, clean sheet',
        'Non, au moins un but encaisse',
        'Match annule',
        'Penalty seulement',
        'A',
        'https://images.unsplash.com/photo-1486286701208-1d58e9338013?auto=format&fit=crop&w=1200&q=80',
        null,
        null,
        null,
        null,
        '{"match_label": "Cote d Ivoire vs Tunisie", "home_team": "Cote d Ivoire", "away_team": "Tunisie", "market": "clean_sheet"}'::jsonb
      ),

      (
        201,
        'image_answers',
        'match_winner',
        'Quelle selection vois-tu gagner le match ?',
        '',
        '',
        '',
        '',
        'A',
        null,
        'https://flagcdn.com/w640/ci.png',
        'https://flagcdn.com/w640/sn.png',
        'https://flagcdn.com/w640/ng.png',
        'https://flagcdn.com/w640/gh.png',
        '{"match_label": "Cote d Ivoire vs Senegal", "home_team": "Cote d Ivoire", "away_team": "Senegal", "market": "match_winner", "image_answers": true}'::jsonb
      ),
      (
        202,
        'image_answers',
        'match_winner',
        'Quelle equipe terminera en tete du groupe ?',
        '',
        '',
        '',
        '',
        'A',
        null,
        'https://flagcdn.com/w640/ci.png',
        'https://flagcdn.com/w640/ma.png',
        'https://flagcdn.com/w640/cm.png',
        'https://flagcdn.com/w640/za.png',
        '{"match_label": "Groupe Afrique", "home_team": "Cote d Ivoire", "away_team": "Maroc", "market": "group_winner", "image_answers": true}'::jsonb
      ),
      (
        203,
        'image_answers',
        'first_goal',
        'Quelle equipe marquera en premier ?',
        '',
        '',
        '',
        '',
        'A',
        null,
        'https://flagcdn.com/w640/ci.png',
        'https://flagcdn.com/w640/ml.png',
        'https://flagcdn.com/w640/bf.png',
        'https://flagcdn.com/w640/tn.png',
        '{"match_label": "Cote d Ivoire vs Mali", "home_team": "Cote d Ivoire", "away_team": "Mali", "market": "first_goal", "image_answers": true}'::jsonb
      ),
      (
        204,
        'image_answers',
        'double_chance',
        'Choisis le drapeau du pronostic double chance Cote d Ivoire ou nul.',
        '',
        '',
        '',
        '',
        'A',
        null,
        'https://flagcdn.com/w640/ci.png',
        'https://flagcdn.com/w640/sn.png',
        'https://flagcdn.com/w640/ma.png',
        'https://flagcdn.com/w640/ng.png',
        '{"match_label": "Cote d Ivoire vs Maroc", "home_team": "Cote d Ivoire", "away_team": "Maroc", "market": "double_chance", "image_answers": true}'::jsonb
      ),
      (
        205,
        'image_answers',
        'match_winner',
        'Quelle equipe gagnera si le match va aux penalties ?',
        '',
        '',
        '',
        '',
        'A',
        null,
        'https://flagcdn.com/w640/ci.png',
        'https://flagcdn.com/w640/eg.png',
        'https://flagcdn.com/w640/dz.png',
        'https://flagcdn.com/w640/cm.png',
        '{"match_label": "Cote d Ivoire vs Egypte", "home_team": "Cote d Ivoire", "away_team": "Egypte", "market": "penalty_winner", "image_answers": true}'::jsonb
      ),
      (
        206,
        'image_answers',
        'scorer_team',
        'Quel pays aura le premier buteur ?',
        '',
        '',
        '',
        '',
        'A',
        null,
        'https://flagcdn.com/w640/ci.png',
        'https://flagcdn.com/w640/gh.png',
        'https://flagcdn.com/w640/sn.png',
        'https://flagcdn.com/w640/za.png',
        '{"match_label": "Cote d Ivoire vs Ghana", "home_team": "Cote d Ivoire", "away_team": "Ghana", "market": "scorer_team", "image_answers": true}'::jsonb
      ),
      (
        207,
        'image_answers',
        'clean_sheet',
        'Quelle selection peut garder sa cage inviolee ?',
        '',
        '',
        '',
        '',
        'A',
        null,
        'https://flagcdn.com/w640/ci.png',
        'https://flagcdn.com/w640/tn.png',
        'https://flagcdn.com/w640/ml.png',
        'https://flagcdn.com/w640/bf.png',
        '{"match_label": "Cote d Ivoire vs Tunisie", "home_team": "Cote d Ivoire", "away_team": "Tunisie", "market": "clean_sheet", "image_answers": true}'::jsonb
      ),
      (
        208,
        'image_answers',
        'qualifier',
        'Quelle equipe se qualifiera ?',
        '',
        '',
        '',
        '',
        'A',
        null,
        'https://flagcdn.com/w640/ci.png',
        'https://flagcdn.com/w640/cm.png',
        'https://flagcdn.com/w640/ng.png',
        'https://flagcdn.com/w640/sn.png',
        '{"match_label": "Quart de finale", "home_team": "Cote d Ivoire", "away_team": "Cameroun", "market": "qualifier", "image_answers": true}'::jsonb
      ),
      (
        209,
        'image_answers',
        'match_winner',
        'Quel drapeau correspond a ton favori ?',
        '',
        '',
        '',
        '',
        'A',
        null,
        'https://flagcdn.com/w640/ci.png',
        'https://flagcdn.com/w640/ma.png',
        'https://flagcdn.com/w640/eg.png',
        'https://flagcdn.com/w640/dz.png',
        '{"match_label": "Favori du tournoi", "home_team": "Cote d Ivoire", "away_team": "Maroc", "market": "tournament_favorite", "image_answers": true}'::jsonb
      ),
      (
        210,
        'image_answers',
        'halftime_result',
        'Quelle equipe sera devant a la mi-temps ?',
        '',
        '',
        '',
        '',
        'A',
        null,
        'https://flagcdn.com/w640/ci.png',
        'https://flagcdn.com/w640/ng.png',
        'https://flagcdn.com/w640/sn.png',
        'https://flagcdn.com/w640/gh.png',
        '{"match_label": "Cote d Ivoire vs Nigeria", "home_team": "Cote d Ivoire", "away_team": "Nigeria", "market": "halftime_result", "image_answers": true}'::jsonb
      ),

      (
        301,
        'text_only',
        'match_winner',
        'Qui remportera Cote d Ivoire vs Senegal ?',
        'Cote d Ivoire',
        'Match nul',
        'Senegal',
        'Victoire aux tirs au but',
        'A',
        null,
        null,
        null,
        null,
        null,
        '{"match_label": "Cote d Ivoire vs Senegal", "home_team": "Cote d Ivoire", "away_team": "Senegal", "market": "match_winner"}'::jsonb
      ),
      (
        302,
        'text_only',
        'exact_score',
        'Quel score exact vois-tu pour Cote d Ivoire vs Nigeria ?',
        '2-1',
        '1-1',
        '0-0',
        '1-2',
        'A',
        null,
        null,
        null,
        null,
        null,
        '{"match_label": "Cote d Ivoire vs Nigeria", "home_team": "Cote d Ivoire", "away_team": "Nigeria", "market": "exact_score"}'::jsonb
      ),
      (
        303,
        'text_only',
        'over_under',
        'Total buts: quel pronostic choisis-tu ?',
        'Plus de 2,5 buts',
        'Moins de 2,5 buts',
        'Exactement 2 buts',
        'Aucun but',
        'A',
        null,
        null,
        null,
        null,
        null,
        '{"match_label": "Ghana vs Cote d Ivoire", "home_team": "Ghana", "away_team": "Cote d Ivoire", "market": "over_under", "line": 2.5}'::jsonb
      ),
      (
        304,
        'text_only',
        'first_goal',
        'Qui marquera en premier ?',
        'Cote d Ivoire',
        'Adversaire',
        'Pas de but',
        'But contre son camp',
        'A',
        null,
        null,
        null,
        null,
        null,
        '{"match_label": "Cote d Ivoire vs Mali", "home_team": "Cote d Ivoire", "away_team": "Mali", "market": "first_goal"}'::jsonb
      ),
      (
        305,
        'text_only',
        'scorer',
        'Quel profil marquera pendant le match ?',
        'Attaquant',
        'Milieu',
        'Defenseur',
        'Aucun buteur',
        'A',
        null,
        null,
        null,
        null,
        null,
        '{"match_label": "Cote d Ivoire vs Cameroun", "home_team": "Cote d Ivoire", "away_team": "Cameroun", "market": "scorer"}'::jsonb
      ),
      (
        306,
        'text_only',
        'double_chance',
        'Quelle double chance choisis-tu ?',
        'Cote d Ivoire ou nul',
        'Adversaire ou nul',
        'Cote d Ivoire ou adversaire',
        'Nul uniquement',
        'A',
        null,
        null,
        null,
        null,
        null,
        '{"match_label": "Cote d Ivoire vs Maroc", "home_team": "Cote d Ivoire", "away_team": "Maroc", "market": "double_chance"}'::jsonb
      ),
      (
        307,
        'text_only',
        'corners',
        'Combien de corners dans le match ?',
        'Plus de 8',
        'Moins de 8',
        'Exactement 8',
        'Aucun',
        'A',
        null,
        null,
        null,
        null,
        null,
        '{"match_label": "Cote d Ivoire vs Afrique du Sud", "home_team": "Cote d Ivoire", "away_team": "Afrique du Sud", "market": "corners", "line": 8}'::jsonb
      ),
      (
        308,
        'text_only',
        'cards',
        'Quel total de cartons anticipes-tu ?',
        'Plus de 3',
        'Moins de 3',
        'Aucun carton',
        'Un carton rouge',
        'A',
        null,
        null,
        null,
        null,
        null,
        '{"match_label": "Senegal vs Cote d Ivoire", "home_team": "Senegal", "away_team": "Cote d Ivoire", "market": "cards", "line": 3}'::jsonb
      ),
      (
        309,
        'text_only',
        'halftime_result',
        'Quel sera le resultat a la mi-temps ?',
        'Cote d Ivoire devant',
        'Egalite',
        'Adversaire devant',
        '0-0 uniquement',
        'A',
        null,
        null,
        null,
        null,
        null,
        '{"match_label": "Cote d Ivoire vs Burkina Faso", "home_team": "Cote d Ivoire", "away_team": "Burkina Faso", "market": "halftime_result"}'::jsonb
      ),
      (
        310,
        'text_only',
        'clean_sheet',
        'La Cote d Ivoire gardera-t-elle sa cage inviolee ?',
        'Oui',
        'Non',
        'Seulement en premiere mi-temps',
        'Seulement apres penalty',
        'A',
        null,
        null,
        null,
        null,
        null,
        '{"match_label": "Cote d Ivoire vs Tunisie", "home_team": "Cote d Ivoire", "away_team": "Tunisie", "market": "clean_sheet"}'::jsonb
      )
  ) as rows(
    order_index,
    media_mode,
    prediction_type,
    question_text,
    option_a,
    option_b,
    option_c,
    option_d,
    correct_answer,
    question_image_url,
    option_a_image_url,
    option_b_image_url,
    option_c_image_url,
    option_d_image_url,
    prediction_payload
  )
),
question_seed as (
  insert into public.questions (
    id,
    contest_id,
    question_bank_id,
    category_id,
    question_scope,
    question_type,
    prediction_type,
    prediction_payload,
    result_payload,
    resolution_status,
    question_text,
    question_image_url,
    option_a,
    option_a_image_url,
    option_b,
    option_b_image_url,
    option_c,
    option_c_image_url,
    option_d,
    option_d_image_url,
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
      substr(md5('pronostic-bank-question-' || question_rows.order_index), 1, 8)
      || '-' ||
      substr(md5('pronostic-bank-question-' || question_rows.order_index), 9, 4)
      || '-' ||
      substr(md5('pronostic-bank-question-' || question_rows.order_index), 13, 4)
      || '-' ||
      substr(md5('pronostic-bank-question-' || question_rows.order_index), 17, 4)
      || '-' ||
      substr(md5('pronostic-bank-question-' || question_rows.order_index), 21, 12)
    )::uuid,
    null,
    bank_seed.id,
    category_seed.id,
    'bank',
    'pronostic',
    question_rows.prediction_type,
    question_rows.prediction_payload,
    '{}'::jsonb,
    'pending',
    question_rows.question_text,
    question_rows.question_image_url,
    question_rows.option_a,
    question_rows.option_a_image_url,
    question_rows.option_b,
    question_rows.option_b_image_url,
    question_rows.option_c,
    question_rows.option_c_image_url,
    question_rows.option_d,
    question_rows.option_d_image_url,
    question_rows.correct_answer,
    0,
    20,
    question_rows.order_index,
    question_rows.media_mode,
    true,
    now()
  from question_rows
  cross join bank_seed
  cross join category_seed
  on conflict (id) do update set
    contest_id = null,
    question_bank_id = excluded.question_bank_id,
    category_id = excluded.category_id,
    question_scope = 'bank',
    question_type = 'pronostic',
    prediction_type = excluded.prediction_type,
    prediction_payload = excluded.prediction_payload,
    result_payload = '{}'::jsonb,
    resolution_status = 'pending',
    question_text = excluded.question_text,
    question_image_url = excluded.question_image_url,
    option_a = excluded.option_a,
    option_a_image_url = excluded.option_a_image_url,
    option_b = excluded.option_b,
    option_b_image_url = excluded.option_b_image_url,
    option_c = excluded.option_c,
    option_c_image_url = excluded.option_c_image_url,
    option_d = excluded.option_d,
    option_d_image_url = excluded.option_d_image_url,
    correct_answer = excluded.correct_answer,
    points = excluded.points,
    time_limit = excluded.time_limit,
    order_index = excluded.order_index,
    difficulty = excluded.difficulty,
    is_active = true
  returning id, difficulty
)
select
  (select count(*) from category_seed) as pronostic_category_ready,
  (select count(*) from bank_seed) as pronostic_bank_ready,
  (select count(*) from bank_category_seed) as bank_category_links_inserted,
  (select count(*) from question_seed) as pronostic_questions_upserted,
  (
    select count(*)
    from question_seed
    where difficulty = 'image_prompt'
  ) as image_question_count,
  (
    select count(*)
    from question_seed
    where difficulty = 'image_answers'
  ) as image_answer_count,
  (
    select count(*)
    from question_seed
    where difficulty = 'text_only'
  ) as normal_question_count;

notify pgrst, 'reload schema';
