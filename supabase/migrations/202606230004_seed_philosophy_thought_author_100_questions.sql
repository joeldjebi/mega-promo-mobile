-- MegaPromo - 100 questions Pensées philosophiques et auteurs
-- A exécuter dans Supabase SQL Editor.
--
-- Objectif:
-- - ajouter 100 questions uniques de philosophie;
-- - question = une pensée, une notion ou une formule philosophique;
-- - réponse = l'auteur ou le penseur associé;
-- - rattacher les questions à la Banque Philosophie, Livre et auteur;
-- - répartir les bonnes réponses: 25 A, 25 B, 25 C, 25 D;
-- - permettre une reprise propre sur la plage order_index 4001 à 4100.

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

delete from public.questions
where question_bank_id = '20260623-0000-4000-b008-000000000008'::uuid
  and coalesce(question_scope, 'bank') = 'bank'
  and order_index between 4001 and 4100;

with category_seed as (
  insert into public.categories (name, description, icon, color, is_active, created_at)
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
  insert into public.question_banks (id, name, description, questions_per_quiz, is_active, created_at, updated_at)
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
  insert into public.question_bank_categories (question_bank_id, category_id)
  select bank_seed.id, category_seed.id
  from bank_seed
  cross join category_seed
  on conflict (question_bank_id, category_id) do nothing
  returning question_bank_id, category_id
),
question_templates as (
  select *
  from (
    values
      (4001, 'intermediaire', 'Le cogito: « Je pense, donc je suis »', 'René Descartes'),
      (4002, 'intermediaire', 'L’impératif catégorique comme loi morale universelle', 'Emmanuel Kant'),
      (4003, 'intermediaire', 'L’existence précède l’essence', 'Jean-Paul Sartre'),
      (4004, 'intermediaire', 'Le mythe de Sisyphe comme figure de l’absurde', 'Albert Camus'),
      (4005, 'intermediaire', 'La théorie des Idées ou des Formes intelligibles', 'Platon'),
      (4006, 'intermediaire', 'L’être humain comme animal politique', 'Aristote'),
      (4007, 'intermediaire', 'La maïeutique comme art d’accoucher les esprits', 'Socrate'),
      (4008, 'intermediaire', 'L’ataraxie et le plaisir sobre comme voie du bonheur', 'Épicure'),
      (4009, 'intermediaire', 'Dieu ou la Nature comme substance unique', 'Baruch Spinoza'),
      (4010, 'intermediaire', 'L’état de nature comme guerre de tous contre tous', 'Thomas Hobbes'),
      (4011, 'intermediaire', 'La propriété fondée sur le travail', 'John Locke'),
      (4012, 'intermediaire', 'La volonté générale dans le contrat social', 'Jean-Jacques Rousseau'),
      (4013, 'intermediaire', 'La critique empiriste de la causalité nécessaire', 'David Hume'),
      (4014, 'intermediaire', 'La dialectique comme mouvement de l’Esprit', 'Georg Wilhelm Friedrich Hegel'),
      (4015, 'intermediaire', 'Le matérialisme historique et la lutte des classes', 'Karl Marx'),
      (4016, 'intermediaire', 'L’angoisse et le saut de la foi', 'Søren Kierkegaard'),
      (4017, 'intermediaire', 'Le Dasein et la question de l’Être', 'Martin Heidegger'),
      (4018, 'intermediaire', 'Le retour aux choses mêmes en phénoménologie', 'Edmund Husserl'),
      (4019, 'intermediaire', 'Les jeux de langage', 'Ludwig Wittgenstein'),
      (4020, 'intermediaire', 'Le voile d’ignorance dans la théorie de la justice', 'John Rawls'),
      (4021, 'intermediaire', '« On ne naît pas femme, on le devient »', 'Simone de Beauvoir'),
      (4022, 'intermediaire', 'La banalité du mal', 'Hannah Arendt'),
      (4023, 'intermediaire', 'Le pouvoir-savoir et la discipline des corps', 'Michel Foucault'),
      (4024, 'intermediaire', 'La déconstruction des oppositions figées', 'Jacques Derrida'),
      (4025, 'intermediaire', 'La durée vécue et l’élan vital', 'Henri Bergson'),
      (4026, 'intermediaire', 'Le pari sur Dieu', 'Blaise Pascal'),
      (4027, 'intermediaire', '« Que sais-je ? » comme devise sceptique', 'Michel de Montaigne'),
      (4028, 'intermediaire', 'La séparation des pouvoirs', 'Montesquieu'),
      (4029, 'intermediaire', 'La tolérance contre le fanatisme', 'Voltaire'),
      (4030, 'intermediaire', 'La volonté de puissance', 'Friedrich Nietzsche'),
      (4031, 'intermediaire', 'Le surhomme comme dépassement de l’homme ancien', 'Friedrich Nietzsche'),
      (4032, 'intermediaire', 'Le juste milieu comme principe de vertu', 'Aristote'),
      (4033, 'intermediaire', 'Le monde sensible opposé au monde intelligible', 'Platon'),
      (4034, 'intermediaire', 'Le doute méthodique', 'René Descartes'),
      (4035, 'intermediaire', 'La distinction entre phénomènes et noumènes', 'Emmanuel Kant'),
      (4036, 'intermediaire', 'La mauvaise foi dans l’existence humaine', 'Jean-Paul Sartre'),
      (4037, 'intermediaire', 'Le divertissement comme fuite devant la condition humaine', 'Blaise Pascal'),
      (4038, 'intermediaire', 'Le rire comme correction sociale', 'Henri Bergson'),
      (4039, 'intermediaire', 'L’habitude comme fondement de nombreuses croyances', 'David Hume'),
      (4040, 'intermediaire', 'La tabula rasa et l’origine empirique des idées', 'John Locke'),
      (4041, 'intermediaire', 'Le principe du plus grand bonheur', 'Jeremy Bentham'),
      (4042, 'intermediaire', 'La défense libérale de la liberté individuelle', 'John Stuart Mill'),
      (4043, 'intermediaire', 'Le falsificationnisme scientifique', 'Karl Popper'),
      (4044, 'intermediaire', 'Les paradigmes dans les révolutions scientifiques', 'Thomas Kuhn'),
      (4045, 'intermediaire', 'L’éthique de la discussion', 'Jürgen Habermas'),
      (4046, 'intermediaire', 'Le principe responsabilité face à la technique', 'Hans Jonas'),
      (4047, 'intermediaire', 'Le panoptique comme modèle de surveillance', 'Jeremy Bentham'),
      (4048, 'intermediaire', 'La critique de la raison instrumentale', 'Max Horkheimer'),
      (4049, 'intermediaire', 'Le stoïcisme des Pensées pour soi-même', 'Marc Aurèle'),
      (4050, 'intermediaire', 'Le Manuel comme texte majeur du stoïcisme', 'Épictète'),
      (4051, 'difficile', 'Le consciencisme comme synthèse politique et culturelle africaine', 'Kwame Nkrumah'),
      (4052, 'difficile', 'La critique de l’ethnophilosophie africaine', 'Paulin Hountondji'),
      (4053, 'difficile', 'La décolonisation conceptuelle en philosophie africaine', 'Kwasi Wiredu'),
      (4054, 'difficile', 'La bibliothèque coloniale comme construction du savoir sur l’Afrique', 'Valentin-Yves Mudimbe'),
      (4055, 'difficile', 'La postcolonie comme analyse des pouvoirs contemporains', 'Achille Mbembe'),
      (4056, 'difficile', 'La violence coloniale et la libération des peuples dominés', 'Frantz Fanon'),
      (4057, 'difficile', 'La critique radicale du colonialisme européen', 'Aimé Césaire'),
      (4058, 'difficile', 'L’ubuntu: « Je suis parce que nous sommes »', 'Mogobe Ramose'),
      (4059, 'difficile', 'La philosophie bantoue et la notion de force vitale', 'Placide Tempels'),
      (4060, 'difficile', 'La crise du Muntu comme critique des mythes identitaires', 'Fabien Eboussi Boulaga'),
      (4061, 'difficile', 'L’antériorité des civilisations africaines dans l’histoire universelle', 'Cheikh Anta Diop'),
      (4062, 'difficile', 'La négritude comme humanisme culturel', 'Léopold Sédar Senghor'),
      (4063, 'difficile', 'L’agir communicationnel', 'Jürgen Habermas'),
      (4064, 'difficile', 'La différance', 'Jacques Derrida'),
      (4065, 'difficile', 'L’archéologie du savoir', 'Michel Foucault'),
      (4066, 'difficile', 'La société ouverte contre le totalitarisme', 'Karl Popper'),
      (4067, 'difficile', 'La généalogie de la morale', 'Friedrich Nietzsche'),
      (4068, 'difficile', 'La substance infinie unique', 'Baruch Spinoza'),
      (4069, 'difficile', 'La justice comme équité', 'John Rawls'),
      (4070, 'difficile', 'La monadologie et l’idée de monades', 'Gottfried Wilhelm Leibniz'),
      (4071, 'difficile', 'La cité terrestre et la Cité de Dieu', 'Augustin d’Hippone'),
      (4072, 'difficile', 'La loi naturelle dans la pensée médiévale chrétienne', 'Thomas d’Aquin'),
      (4073, 'difficile', 'La politique pensée à partir de l’efficacité du pouvoir', 'Nicolas Machiavel'),
      (4074, 'difficile', 'L’utopie comme critique sociale et politique', 'Thomas More'),
      (4075, 'difficile', 'La méthode inductive dans la science moderne', 'Francis Bacon'),
      (4076, 'difficile', 'La science nouvelle de l’histoire humaine', 'Giambattista Vico'),
      (4077, 'difficile', 'Le monde comme volonté et représentation', 'Arthur Schopenhauer'),
      (4078, 'difficile', 'L’individualisme radical de l’Unique', 'Max Stirner'),
      (4079, 'difficile', 'La pensée sauvage et les structures de l’esprit humain', 'Claude Lévi-Strauss'),
      (4080, 'difficile', 'Le principe espérance', 'Ernst Bloch'),
      (4081, 'difficile', 'L’éthique du visage et de l’altérité', 'Emmanuel Levinas'),
      (4082, 'difficile', 'La société du spectacle', 'Guy Debord'),
      (4083, 'difficile', 'La différence et la répétition', 'Gilles Deleuze'),
      (4084, 'difficile', 'La condition postmoderne', 'Jean-François Lyotard'),
      (4085, 'difficile', 'Les simulacres et la simulation', 'Jean Baudrillard'),
      (4086, 'difficile', 'La critique de la raison cynique', 'Peter Sloterdijk'),
      (4087, 'difficile', 'La vertu comme tradition pratique', 'Alasdair MacIntyre'),
      (4088, 'difficile', 'Les sources modernes de l’identité', 'Charles Taylor'),
      (4089, 'difficile', 'L’État minimal dans l’utopie libertarienne', 'Robert Nozick'),
      (4090, 'difficile', 'Les sphères de justice', 'Michael Walzer'),
      (4091, 'difficile', 'L’éthique du care et la voix différente', 'Carol Gilligan'),
      (4092, 'difficile', 'L’éthique de la psychanalyse dans les séminaires', 'Jacques Lacan'),
      (4093, 'difficile', 'La critique de la raison pure', 'Emmanuel Kant'),
      (4094, 'difficile', 'La phénoménologie de l’esprit', 'Georg Wilhelm Friedrich Hegel'),
      (4095, 'difficile', 'La critique de l’aliénation dans le travail salarié', 'Karl Marx'),
      (4096, 'difficile', 'La foi comme rapport subjectif à l’absolu', 'Søren Kierkegaard'),
      (4097, 'difficile', 'La question de la technique comme dévoilement', 'Martin Heidegger'),
      (4098, 'difficile', 'L’intentionnalité de la conscience', 'Edmund Husserl'),
      (4099, 'difficile', 'La philosophie comme clarification logique du langage', 'Ludwig Wittgenstein'),
      (4100, 'difficile', 'La critique de la consommation et des signes', 'Jean Baudrillard')
  ) as rows (order_index, difficulty, thought_text, correct_answer)
),
distractor_authors as (
  select *
  from (
    values
      ('Achille Mbembe'),
      ('Aimé Césaire'),
      ('Alasdair MacIntyre'),
      ('Albert Camus'),
      ('Aristote'),
      ('Arthur Schopenhauer'),
      ('Augustin d’Hippone'),
      ('Baruch Spinoza'),
      ('Blaise Pascal'),
      ('Carol Gilligan'),
      ('Charles Taylor'),
      ('Cheikh Anta Diop'),
      ('Claude Lévi-Strauss'),
      ('David Hume'),
      ('Edmund Husserl'),
      ('Emmanuel Kant'),
      ('Emmanuel Levinas'),
      ('Ernst Bloch'),
      ('Fabien Eboussi Boulaga'),
      ('Francis Bacon'),
      ('Frantz Fanon'),
      ('Friedrich Nietzsche'),
      ('Georg Wilhelm Friedrich Hegel'),
      ('Giambattista Vico'),
      ('Gilles Deleuze'),
      ('Gottfried Wilhelm Leibniz'),
      ('Guy Debord'),
      ('Hannah Arendt'),
      ('Hans Jonas'),
      ('Henri Bergson'),
      ('Jacques Derrida'),
      ('Jacques Lacan'),
      ('Jean Baudrillard'),
      ('Jean-François Lyotard'),
      ('Jean-Jacques Rousseau'),
      ('Jean-Paul Sartre'),
      ('Jeremy Bentham'),
      ('John Locke'),
      ('John Rawls'),
      ('John Stuart Mill'),
      ('Jürgen Habermas'),
      ('Karl Marx'),
      ('Karl Popper'),
      ('Kwame Nkrumah'),
      ('Kwasi Wiredu'),
      ('Ludwig Wittgenstein'),
      ('Léopold Sédar Senghor'),
      ('Marc Aurèle'),
      ('Martin Heidegger'),
      ('Max Horkheimer'),
      ('Max Stirner'),
      ('Michael Walzer'),
      ('Michel Foucault'),
      ('Michel de Montaigne'),
      ('Mogobe Ramose'),
      ('Montesquieu'),
      ('Nicolas Machiavel'),
      ('Paulin Hountondji'),
      ('Peter Sloterdijk'),
      ('Placide Tempels'),
      ('Platon'),
      ('René Descartes'),
      ('Robert Nozick'),
      ('Simone de Beauvoir'),
      ('Socrate'),
      ('Søren Kierkegaard'),
      ('Thomas Hobbes'),
      ('Thomas Kuhn'),
      ('Thomas More'),
      ('Thomas d’Aquin'),
      ('Valentin-Yves Mudimbe'),
      ('Voltaire'),
      ('Épictète'),
      ('Épicure')
  ) as rows (author)
),
numbered_questions as (
  select
    question_templates.*,
    row_number() over (order by question_templates.order_index) as rn
  from question_templates
),
question_options as (
  select
    numbered_questions.*,
    ((numbered_questions.rn - 1) % 4) + 1 as correct_slot,
    distractors.authors as distractor_options
  from numbered_questions
  cross join lateral (
    select array_agg(author order by author) as authors
    from (
      select distractor_authors.author
      from distractor_authors
      where distractor_authors.author <> numbered_questions.correct_answer
      order by md5(numbered_questions.order_index::text || '-' || distractor_authors.author)
      limit 3
    ) picked
  ) distractors
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
      substr(md5('culture-philosophy-thought-author-20260623-question-' || question_options.order_index), 1, 8)
      || '-' || substr(md5('culture-philosophy-thought-author-20260623-question-' || question_options.order_index), 9, 4)
      || '-' || substr(md5('culture-philosophy-thought-author-20260623-question-' || question_options.order_index), 13, 4)
      || '-' || substr(md5('culture-philosophy-thought-author-20260623-question-' || question_options.order_index), 17, 4)
      || '-' || substr(md5('culture-philosophy-thought-author-20260623-question-' || question_options.order_index), 21, 12)
    )::uuid,
    null,
    bank_seed.id,
    category_seed.id,
    'bank',
    'quiz',
    'À quel auteur ou penseur associe-t-on cette pensée: "' || question_options.thought_text || '" ?',
    null,
    case when question_options.correct_slot = 1 then question_options.correct_answer else question_options.distractor_options[1] end,
    null,
    case when question_options.correct_slot = 2 then question_options.correct_answer else question_options.distractor_options[case when question_options.correct_slot = 1 then 1 else 2 end] end,
    null,
    case when question_options.correct_slot = 3 then question_options.correct_answer else question_options.distractor_options[case when question_options.correct_slot in (1, 2) then 2 else 3 end] end,
    null,
    case when question_options.correct_slot = 4 then question_options.correct_answer else question_options.distractor_options[3] end,
    null,
    case question_options.correct_slot when 1 then 'A' when 2 then 'B' when 3 then 'C' else 'D' end,
    case question_options.difficulty when 'difficile' then 15 else 10 end,
    case question_options.difficulty when 'difficile' then 25 else 20 end,
    question_options.order_index,
    question_options.difficulty,
    true,
    now()
  from question_options
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
  count(*) filter (where correct_slot = 1) as correct_a,
  count(*) filter (where correct_slot = 2) as correct_b,
  count(*) filter (where correct_slot = 3) as correct_c,
  count(*) filter (where correct_slot = 4) as correct_d,
  count(distinct thought_text) as unique_thoughts
from question_options;

notify pgrst, 'reload schema';
