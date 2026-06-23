-- MegaPromo - 400 questions Culture, Philosophie, Livre et auteur
-- A exécuter dans Supabase SQL Editor.
--
-- Objectif:
-- - créer ou mettre à jour la catégorie "Culture, Philosophie, Livre et auteur";
-- - créer ou mettre à jour la banque "Banque Philosophie, Livre et auteur";
-- - ajouter 200 questions texte sur des pensées philosophiques et leurs auteurs;
-- - ajouter 200 questions texte sur des livres africains et leurs auteurs;
-- - répartir exactement les bonnes réponses: 100 A, 100 B, 100 C, 100 D.

alter table public.questions
add column if not exists question_type text not null default 'quiz',
add column if not exists question_bank_id uuid,
add column if not exists category_id uuid,
add column if not exists question_scope text,
add column if not exists difficulty text,
add column if not exists is_active boolean not null default true,
add column if not exists question_image_url text,
add column if not exists option_a_image_url text,
add column if not exists option_b_image_url text,
add column if not exists option_c_image_url text,
add column if not exists option_d_image_url text;

-- Reprise propre: on vide d'abord les questions de cette banque pour éviter
-- de conserver d'anciennes questions ambiguës déjà chargées.
delete from public.questions
where question_bank_id = '20260623-0000-4000-b008-000000000008'::uuid
  and coalesce(question_scope, 'bank') = 'bank';

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
    'Culture, Philosophie, Livre et auteur',
    'Questions sur les pensées philosophiques, les philosophes, les livres africains et leurs auteurs.',
    'menu_book',
    '#7C3AED',
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
    '20260623-0000-4000-b008-000000000008'::uuid,
    'Banque Philosophie, Livre et auteur',
    'Questions texte sur les pensées philosophiques, leurs auteurs, les livres africains et leurs écrivains.',
    10,
    true,
    now(),
    now()
  )
  on conflict (name) do update set
    description = excluded.description,
    questions_per_quiz = 10,
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
philosophy_pairs as (
  select *
  from (
    values
      (1, 'Le cogito: « Je pense, donc je suis »', 'René Descartes'),
      (2, 'L''impératif catégorique comme principe moral universel', 'Emmanuel Kant'),
      (3, 'L''existence précède l''essence', 'Jean-Paul Sartre'),
      (4, 'Le mythe de Sisyphe comme image de l''absurde', 'Albert Camus'),
      (5, 'La volonté de puissance et la critique des valeurs établies', 'Friedrich Nietzsche'),
      (6, 'La théorie des Idées ou des Formes intelligibles', 'Platon'),
      (7, 'L''homme est un animal politique', 'Aristote'),
      (8, 'La maïeutique, art de faire accoucher les esprits', 'Socrate'),
      (9, 'Le plaisir sobre et l''ataraxie comme voie du bonheur', 'Épicure'),
      (10, 'Dieu ou la Nature comme substance unique', 'Baruch Spinoza'),
      (11, 'L''état de nature comme guerre de tous contre tous', 'Thomas Hobbes'),
      (12, 'La propriété liée au travail et au droit naturel', 'John Locke'),
      (13, 'Le contrat social et la volonté générale', 'Jean-Jacques Rousseau'),
      (14, 'L''empirisme et la critique de la causalité nécessaire', 'David Hume'),
      (15, 'La dialectique et le déploiement historique de l''Esprit', 'Georg Wilhelm Friedrich Hegel'),
      (16, 'Le matérialisme historique et la lutte des classes', 'Karl Marx'),
      (17, 'L''angoisse, le choix et le saut de la foi', 'Søren Kierkegaard'),
      (18, 'La question de l''Être et du Dasein', 'Martin Heidegger'),
      (19, 'La phénoménologie comme retour aux choses mêmes', 'Edmund Husserl'),
      (20, 'Les jeux de langage et les limites du langage', 'Ludwig Wittgenstein'),
      (21, 'Le voile d''ignorance dans la théorie de la justice', 'John Rawls'),
      (22, 'On ne naît pas femme, on le devient', 'Simone de Beauvoir'),
      (23, 'La banalité du mal et la réflexion sur le totalitarisme', 'Hannah Arendt'),
      (24, 'Le pouvoir, le savoir et la discipline des corps', 'Michel Foucault'),
      (25, 'La déconstruction des oppositions figées du langage', 'Jacques Derrida'),
      (26, 'La durée vécue et l''élan vital', 'Henri Bergson'),
      (27, 'Le pari sur Dieu et la misère de l''homme sans grâce', 'Blaise Pascal'),
      (28, 'Que sais-je ? comme devise du scepticisme humaniste', 'Michel de Montaigne'),
      (29, 'La séparation des pouvoirs pour limiter l''arbitraire', 'Montesquieu'),
      (30, 'La défense de la tolérance contre le fanatisme', 'Voltaire'),
      (31, 'La dialectique du maître et de l''esclave', 'G. W. F. Hegel'),
      (32, 'Le doute méthodique pour fonder une connaissance certaine', 'René Descartes'),
      (33, 'La critique de la raison pure et des conditions de la connaissance', 'Emmanuel Kant'),
      (34, 'L''aliénation du travail dans la société capitaliste', 'Karl Marx'),
      (35, 'Le surhomme comme dépassement de l''homme ancien', 'Friedrich Nietzsche'),
      (36, 'La négritude comme affirmation culturelle et humaniste', 'Léopold Sédar Senghor'),
      (37, 'Le consciencisme comme synthèse politique et culturelle africaine', 'Kwame Nkrumah'),
      (38, 'La critique de l''ethnophilosophie africaine', 'Paulin Hountondji'),
      (39, 'La décolonisation conceptuelle de la philosophie africaine', 'Kwasi Wiredu'),
      (40, 'La critique de la bibliothèque coloniale sur l''Afrique', 'Valentin-Yves Mudimbe'),
      (41, 'La postcolonie et la réflexion sur les pouvoirs contemporains', 'Achille Mbembe'),
      (42, 'La violence coloniale et la libération des peuples dominés', 'Frantz Fanon'),
      (43, 'Le Discours sur le colonialisme et la critique de l''Europe coloniale', 'Aimé Césaire'),
      (44, 'La pensée de l''ubuntu: « Je suis parce que nous sommes »', 'Mogobe Ramose'),
      (45, 'La philosophie bantoue et la notion de force vitale', 'Placide Tempels'),
      (46, 'La crise du Muntu et la critique des mythes identitaires', 'Fabien Eboussi Boulaga'),
      (47, 'L''antériorité des civilisations africaines dans l''histoire universelle', 'Cheikh Anta Diop'),
      (48, 'L''éthique de la discussion et l''agir communicationnel', 'Jürgen Habermas'),
      (49, 'Le principe responsabilité face aux risques de la technique', 'Hans Jonas'),
      (50, 'Le panoptique comme figure moderne de surveillance', 'Jeremy Bentham')
  ) as rows (idx, thought, author)
),
book_pairs as (
  select *
  from (
    values
      (1, 'Le Monde s''effondre', 'Chinua Achebe'),
      (2, 'Une si longue lettre', 'Mariama Bâ'),
      (3, 'L''Enfant noir', 'Camara Laye'),
      (4, 'Les Soleils des indépendances', 'Ahmadou Kourouma'),
      (5, 'Allah n''est pas obligé', 'Ahmadou Kourouma'),
      (6, 'Le Vieux Nègre et la médaille', 'Ferdinand Oyono'),
      (7, 'Une vie de boy', 'Ferdinand Oyono'),
      (8, 'Ville cruelle', 'Mongo Beti'),
      (9, 'Le Pauvre Christ de Bomba', 'Mongo Beti'),
      (10, 'La Grève des bàttu', 'Aminata Sow Fall'),
      (11, 'L''Aventure ambiguë', 'Cheikh Hamidou Kane'),
      (12, 'Le Devoir de violence', 'Yambo Ouologuem'),
      (13, 'La Vie et demie', 'Sony Labou Tansi'),
      (14, 'Verre cassé', 'Alain Mabanckou'),
      (15, 'Mémoires de porc-épic', 'Alain Mabanckou'),
      (16, 'Petit Piment', 'Alain Mabanckou'),
      (17, 'L''Impasse', 'Daniel Biyaoula'),
      (18, 'Murambi, le livre des ossements', 'Boubacar Boris Diop'),
      (19, 'Le Cavalier et son ombre', 'Boubacar Boris Diop'),
      (20, 'Les Bouts de bois de Dieu', 'Ousmane Sembène'),
      (21, 'Le Docker noir', 'Ousmane Sembène'),
      (22, 'Xala', 'Ousmane Sembène'),
      (23, 'Crépuscule des temps anciens', 'Nazi Boni'),
      (24, 'Le Baobab fou', 'Ken Bugul'),
      (25, 'Riwan ou le chemin de sable', 'Ken Bugul'),
      (26, 'Notre-Dame du Nil', 'Scholastique Mukasonga'),
      (27, 'Petit Pays', 'Gaël Faye'),
      (28, 'Mathématiques congolaises', 'In Koli Jean Bofane'),
      (29, 'Congo Inc.', 'In Koli Jean Bofane'),
      (30, 'Les Honneurs perdus', 'Calixthe Beyala'),
      (31, 'Femme nue, femme noire', 'Calixthe Beyala'),
      (32, 'C''est le soleil qui m''a brûlée', 'Calixthe Beyala'),
      (33, 'La Saison de l''ombre', 'Léonora Miano'),
      (34, 'Contours du jour qui vient', 'Léonora Miano'),
      (35, 'L''Intérieur de la nuit', 'Léonora Miano'),
      (36, 'La Carte d''identité', 'Jean-Marie Adiaffi'),
      (37, 'Les Naufragés de l''intelligence', 'Jean-Marie Adiaffi'),
      (38, 'Climbié', 'Bernard Dadié'),
      (39, 'Un Nègre à Paris', 'Bernard Dadié'),
      (40, 'Maïmouna', 'Abdoulaye Sadji'),
      (41, 'Nini, mulâtresse du Sénégal', 'Abdoulaye Sadji'),
      (42, 'Le Regard du roi', 'Camara Laye'),
      (43, 'L''Ivrogne dans la brousse', 'Amos Tutuola'),
      (44, 'Le Pleurer-rire', 'Henri Lopes'),
      (45, 'Tribaliques', 'Henri Lopes'),
      (46, 'Le Lys et le Flamboyant', 'Henri Lopes'),
      (47, 'Sozaboy', 'Ken Saro-Wiwa'),
      (48, 'Pétales de sang', 'Ngũgĩ wa Thiong''o'),
      (49, 'Un grain de blé', 'Ngũgĩ wa Thiong''o'),
      (50, 'Décoloniser l''esprit', 'Ngũgĩ wa Thiong''o')
  ) as rows (idx, book_title, author)
),
philosophy_question_templates as (
  select
    1000 + ((p.idx - 1) * 4) + variant.variant_index as order_index,
    case when p.idx <= 25 then 'intermediaire' else 'difficile' end as difficulty,
    case variant.variant_index
      when 1 then 'Quel auteur est associé à cette pensée: "' || p.thought || '" ?'
      when 2 then 'À quel philosophe attribue-t-on généralement cette idée: "' || p.thought || '" ?'
      when 3 then 'Quel penseur correspond le mieux à cette notion: "' || p.thought || '" ?'
      else 'Qui est principalement relié à cette formulation: "' || p.thought || '" ?'
    end as question_text,
    case variant.variant_index
      when 1 then p.author
      else (select author from philosophy_pairs where idx = ((p.idx + 10) % 50) + 1)
    end as option_a,
    case variant.variant_index
      when 2 then p.author
      else (select author from philosophy_pairs where idx = ((p.idx + 22) % 50) + 1)
    end as option_b,
    case variant.variant_index
      when 3 then p.author
      else (select author from philosophy_pairs where idx = ((p.idx + 36) % 50) + 1)
    end as option_c,
    case variant.variant_index
      when 4 then p.author
      else (select author from philosophy_pairs where idx = ((p.idx + 44) % 50) + 1)
    end as option_d,
    case variant.variant_index
      when 1 then 'A'
      when 2 then 'B'
      when 3 then 'C'
      else 'D'
    end as correct_answer
  from philosophy_pairs p
  cross join (
    values (1), (2), (3), (4)
  ) as variant(variant_index)
),
book_question_templates as (
  select
    2000 + ((p.idx - 1) * 4) + variant.variant_index as order_index,
    case when p.idx <= 25 then 'intermediaire' else 'difficile' end as difficulty,
    case variant.variant_index
      when 1 then 'Quel auteur a écrit le livre africain "' || p.book_title || '" ?'
      when 2 then 'Quel écrivain africain est l''auteur de "' || p.book_title || '" ?'
      when 3 then 'À qui doit-on le livre africain "' || p.book_title || '" ?'
      else 'Qui a signé l''œuvre africaine "' || p.book_title || '" ?'
    end as question_text,
    case variant.variant_index
      when 1 then p.author
      else (select author from book_pairs where idx = ((p.idx + 10) % 50) + 1)
    end as option_a,
    case variant.variant_index
      when 2 then p.author
      else (select author from book_pairs where idx = ((p.idx + 22) % 50) + 1)
    end as option_b,
    case variant.variant_index
      when 3 then p.author
      else (select author from book_pairs where idx = ((p.idx + 36) % 50) + 1)
    end as option_c,
    case variant.variant_index
      when 4 then p.author
      else (select author from book_pairs where idx = ((p.idx + 44) % 50) + 1)
    end as option_d,
    case variant.variant_index
      when 1 then 'A'
      when 2 then 'B'
      when 3 then 'C'
      else 'D'
    end as correct_answer
  from book_pairs p
  cross join (
    values (1), (2), (3), (4)
  ) as variant(variant_index)
),
question_templates as (
  select
    'philosophie' as theme,
    order_index,
    difficulty,
    question_text,
    option_a,
    option_b,
    option_c,
    option_d,
    correct_answer
  from philosophy_question_templates
  union all
  select
    'livres_africains' as theme,
    order_index,
    difficulty,
    question_text,
    option_a,
    option_b,
    option_c,
    option_d,
    correct_answer
  from book_question_templates
),
question_seed as (
  insert into public.questions (
    id,
    contest_id,
    question_bank_id,
    category_id,
    question_scope,
    question_type,
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
      substr(md5('culture-philosophie-livres-auteurs-20260623-question-' || question_templates.order_index), 1, 8)
      || '-' ||
      substr(md5('culture-philosophie-livres-auteurs-20260623-question-' || question_templates.order_index), 9, 4)
      || '-' ||
      substr(md5('culture-philosophie-livres-auteurs-20260623-question-' || question_templates.order_index), 13, 4)
      || '-' ||
      substr(md5('culture-philosophie-livres-auteurs-20260623-question-' || question_templates.order_index), 17, 4)
      || '-' ||
      substr(md5('culture-philosophie-livres-auteurs-20260623-question-' || question_templates.order_index), 21, 12)
    )::uuid,
    null,
    bank_seed.id,
    category_seed.id,
    'bank',
    'quiz',
    question_templates.question_text,
    null,
    question_templates.option_a,
    null,
    question_templates.option_b,
    null,
    question_templates.option_c,
    null,
    question_templates.option_d,
    null,
    question_templates.correct_answer,
    case question_templates.difficulty
      when 'difficile' then 15
      else 10
    end,
    case question_templates.difficulty
      when 'difficile' then 25
      else 20
    end,
    question_templates.order_index,
    question_templates.difficulty,
    true,
    now()
  from question_templates
  cross join bank_seed
  cross join category_seed
  on conflict (id) do update set
    contest_id = null,
    question_bank_id = excluded.question_bank_id,
    category_id = excluded.category_id,
    question_scope = 'bank',
    question_type = 'quiz',
    question_text = excluded.question_text,
    question_image_url = null,
    option_a = excluded.option_a,
    option_a_image_url = null,
    option_b = excluded.option_b,
    option_b_image_url = null,
    option_c = excluded.option_c,
    option_c_image_url = null,
    option_d = excluded.option_d,
    option_d_image_url = null,
    correct_answer = excluded.correct_answer,
    points = excluded.points,
    time_limit = excluded.time_limit,
    order_index = excluded.order_index,
    difficulty = excluded.difficulty,
    is_active = true
  returning id
)
select
  (select count(*) from category_seed) as categories_ready,
  (select count(*) from bank_seed) as banks_ready,
  (select count(*) from bank_category_seed) as bank_category_links_inserted,
  (select count(*) from question_seed) as questions_upserted,
  count(*) filter (where theme = 'philosophie') as philosophie_questions,
  count(*) filter (where theme = 'livres_africains') as livres_africains_questions,
  count(*) filter (where correct_answer = 'A') as correct_a,
  count(*) filter (where correct_answer = 'B') as correct_b,
  count(*) filter (where correct_answer = 'C') as correct_c,
  count(*) filter (where correct_answer = 'D') as correct_d
from question_templates;

notify pgrst, 'reload schema';
