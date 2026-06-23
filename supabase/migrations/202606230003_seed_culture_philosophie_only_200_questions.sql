-- MegaPromo - 200 questions Philosophie uniquement
-- A exécuter dans Supabase SQL Editor après la création de la catégorie
-- "Culture, Philosophie, Livre et auteur".
--
-- Objectif:
-- - ajouter 200 questions uniques liées uniquement à la philosophie;
-- - rattacher les questions à la catégorie "Culture, Philosophie, Livre et auteur";
-- - utiliser la Banque Philosophie, Livre et auteur existante;
-- - répartir les bonnes réponses entre A, B, C et D: 50 chacune;
-- - permettre une reprise propre sur la plage order_index 3001 à 3200.

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
  and order_index between 3001 and 3200;

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
question_templates as (
  select *
  from (
    values
      (3001, 'intermediaire', 'Quel philosophe est associé au cogito: « Je pense, donc je suis » ?', 'René Descartes'),
      (3002, 'intermediaire', 'Quel philosophe est associé à l’impératif catégorique ?', 'Emmanuel Kant'),
      (3003, 'intermediaire', 'Quel philosophe défend l’idée que l’existence précède l’essence ?', 'Jean-Paul Sartre'),
      (3004, 'intermediaire', 'Quel philosophe a popularisé le mythe de Sisyphe comme image de l’absurde ?', 'Albert Camus'),
      (3005, 'intermediaire', 'Quel philosophe est associé à la théorie des Idées ?', 'Platon'),
      (3006, 'intermediaire', 'Quel philosophe définit l’être humain comme un animal politique ?', 'Aristote'),
      (3007, 'intermediaire', 'Quel philosophe est célèbre pour la maïeutique ?', 'Socrate'),
      (3008, 'intermediaire', 'Quel philosophe associe le bonheur à l’ataraxie et au plaisir sobre ?', 'Épicure'),
      (3009, 'intermediaire', 'Quel philosophe affirme que Dieu ou la Nature est une substance unique ?', 'Baruch Spinoza'),
      (3010, 'intermediaire', 'Quel philosophe décrit l’état de nature comme une guerre de tous contre tous ?', 'Thomas Hobbes'),
      (3011, 'intermediaire', 'Quel philosophe relie la propriété au travail dans sa théorie politique ?', 'John Locke'),
      (3012, 'intermediaire', 'Quel philosophe est associé au contrat social et à la volonté générale ?', 'Jean-Jacques Rousseau'),
      (3013, 'intermediaire', 'Quel philosophe critique la causalité nécessaire dans l’empirisme moderne ?', 'David Hume'),
      (3014, 'intermediaire', 'Quel philosophe est associé à la dialectique de l’Esprit ?', 'Georg Wilhelm Friedrich Hegel'),
      (3015, 'intermediaire', 'Quel philosophe est associé au matérialisme historique ?', 'Karl Marx'),
      (3016, 'intermediaire', 'Quel philosophe est associé à l’angoisse, au choix et au saut de la foi ?', 'Søren Kierkegaard'),
      (3017, 'intermediaire', 'Quel philosophe est associé au Dasein et à la question de l’Être ?', 'Martin Heidegger'),
      (3018, 'intermediaire', 'Quel philosophe fonde la phénoménologie comme retour aux choses mêmes ?', 'Edmund Husserl'),
      (3019, 'intermediaire', 'Quel philosophe parle des jeux de langage ?', 'Ludwig Wittgenstein'),
      (3020, 'intermediaire', 'Quel philosophe propose le voile d’ignorance dans la théorie de la justice ?', 'John Rawls'),
      (3021, 'intermediaire', 'Quelle philosophe écrit: « On ne naît pas femme, on le devient » ?', 'Simone de Beauvoir'),
      (3022, 'intermediaire', 'Quelle philosophe est associée à la notion de banalité du mal ?', 'Hannah Arendt'),
      (3023, 'intermediaire', 'Quel philosophe analyse les relations entre pouvoir, savoir et discipline ?', 'Michel Foucault'),
      (3024, 'intermediaire', 'Quel philosophe est associé à la déconstruction ?', 'Jacques Derrida'),
      (3025, 'intermediaire', 'Quel philosophe est associé à la durée vécue et à l’élan vital ?', 'Henri Bergson'),
      (3026, 'intermediaire', 'Quel philosophe est associé au pari sur Dieu ?', 'Blaise Pascal'),
      (3027, 'intermediaire', 'Quel philosophe humaniste est associé à la formule « Que sais-je ? » ?', 'Michel de Montaigne'),
      (3028, 'intermediaire', 'Quel penseur est associé à la séparation des pouvoirs ?', 'Montesquieu'),
      (3029, 'intermediaire', 'Quel philosophe des Lumières défend fortement la tolérance contre le fanatisme ?', 'Voltaire'),
      (3030, 'intermediaire', 'Quel philosophe est associé à la généalogie de la morale ?', 'Friedrich Nietzsche'),
      (3031, 'intermediaire', 'Quel philosophe est associé à la philosophie de l’absurde ?', 'Albert Camus'),
      (3032, 'intermediaire', 'Quel philosophe défend la liberté radicale et la responsabilité individuelle ?', 'Jean-Paul Sartre'),
      (3033, 'intermediaire', 'Quel philosophe est associé au doute méthodique ?', 'René Descartes'),
      (3034, 'intermediaire', 'Quel philosophe distingue phénomènes et noumènes ?', 'Emmanuel Kant'),
      (3035, 'intermediaire', 'Quel philosophe critique l’aliénation du travail dans le capitalisme ?', 'Karl Marx'),
      (3036, 'intermediaire', 'Quel philosophe est associé au surhomme ?', 'Friedrich Nietzsche'),
      (3037, 'intermediaire', 'Quel philosophe est associé à l’idéalisme absolu ?', 'Georg Wilhelm Friedrich Hegel'),
      (3038, 'intermediaire', 'Quel philosophe associe la vertu au juste milieu ?', 'Aristote'),
      (3039, 'intermediaire', 'Quel philosophe grec oppose le monde sensible au monde intelligible ?', 'Platon'),
      (3040, 'intermediaire', 'Quel philosophe romain stoïcien a écrit des Pensées pour lui-même ?', 'Marc Aurèle'),
      (3041, 'intermediaire', 'Quel philosophe stoïcien fut aussi précepteur de Néron ?', 'Sénèque'),
      (3042, 'intermediaire', 'Quel ancien esclave est devenu une grande figure du stoïcisme ?', 'Épictète'),
      (3043, 'intermediaire', 'Quel philosophe utilitariste formule le principe du plus grand bonheur ?', 'Jeremy Bentham'),
      (3044, 'intermediaire', 'Quel philosophe libéral défend la liberté individuelle dans De la liberté ?', 'John Stuart Mill'),
      (3045, 'intermediaire', 'Quel philosophe est associé au falsificationnisme scientifique ?', 'Karl Popper'),
      (3046, 'intermediaire', 'Quel philosophe analyse les révolutions scientifiques par les changements de paradigme ?', 'Thomas Kuhn'),
      (3047, 'intermediaire', 'Quel philosophe développe l’éthique de la discussion ?', 'Jürgen Habermas'),
      (3048, 'intermediaire', 'Quel philosophe propose le principe responsabilité face à la technique ?', 'Hans Jonas'),
      (3049, 'intermediaire', 'Quel philosophe est associé au panoptique ?', 'Jeremy Bentham'),
      (3050, 'intermediaire', 'Quel philosophe est associé à la critique de la raison instrumentale ?', 'Max Horkheimer'),
      (3051, 'difficile', 'Quel philosophe africain développe le consciencisme ?', 'Kwame Nkrumah'),
      (3052, 'difficile', 'Quel philosophe africain critique l’ethnophilosophie ?', 'Paulin Hountondji'),
      (3053, 'difficile', 'Quel philosophe africain défend la décolonisation conceptuelle ?', 'Kwasi Wiredu'),
      (3054, 'difficile', 'Quel penseur analyse la bibliothèque coloniale sur l’Afrique ?', 'Valentin-Yves Mudimbe'),
      (3055, 'difficile', 'Quel penseur africain est associé à la notion de postcolonie ?', 'Achille Mbembe'),
      (3056, 'difficile', 'Quel penseur analyse la violence coloniale dans une perspective de libération ?', 'Frantz Fanon'),
      (3057, 'difficile', 'Quel auteur du Discours sur le colonialisme critique radicalement l’Europe coloniale ?', 'Aimé Césaire'),
      (3058, 'difficile', 'Quel philosophe africain est associé à l’ubuntu comme pensée philosophique ?', 'Mogobe Ramose'),
      (3059, 'difficile', 'Quel auteur est associé à La philosophie bantoue ?', 'Placide Tempels'),
      (3060, 'difficile', 'Quel philosophe camerounais a écrit La crise du Muntu ?', 'Fabien Eboussi Boulaga'),
      (3061, 'difficile', 'Quel penseur défend l’antériorité des civilisations africaines dans l’histoire universelle ?', 'Cheikh Anta Diop'),
      (3062, 'difficile', 'Quel penseur sénégalais lie négritude, culture et humanisme ?', 'Léopold Sédar Senghor'),
      (3063, 'difficile', 'Quel philosophe béninois insiste sur la philosophie africaine comme discours critique ?', 'Paulin Hountondji'),
      (3064, 'difficile', 'Quel philosophe ghanéen propose de repenser les catégories philosophiques africaines ?', 'Kwasi Wiredu'),
      (3065, 'difficile', 'Quel penseur martiniquais a fortement inspiré les réflexions anticoloniales africaines ?', 'Frantz Fanon'),
      (3066, 'difficile', 'Quel philosophe est associé à l’archéologie du savoir ?', 'Michel Foucault'),
      (3067, 'difficile', 'Quel philosophe est associé à la différance ?', 'Jacques Derrida'),
      (3068, 'difficile', 'Quel philosophe développe la théorie de l’agir communicationnel ?', 'Jürgen Habermas'),
      (3069, 'difficile', 'Quel philosophe est associé à la critique de la société ouverte menacée par le totalitarisme ?', 'Karl Popper'),
      (3070, 'difficile', 'Quel philosophe est associé à la méthode généalogique appliquée à la morale ?', 'Friedrich Nietzsche'),
      (3071, 'difficile', 'Quel philosophe critique la raison pure pour examiner les conditions de la connaissance ?', 'Emmanuel Kant'),
      (3072, 'difficile', 'Quel philosophe fait de la substance une réalité unique infinie ?', 'Baruch Spinoza'),
      (3073, 'difficile', 'Quel philosophe associe la dialectique au dépassement des contradictions ?', 'Georg Wilhelm Friedrich Hegel'),
      (3074, 'difficile', 'Quel philosophe rattache la justice à l’équité ?', 'John Rawls'),
      (3075, 'difficile', 'Quel philosophe associe la liberté à l’absence d’entraves injustifiées dans la société libérale ?', 'John Stuart Mill'),
      (3076, 'difficile', 'Quel philosophe analyse la mauvaise foi dans l’existence humaine ?', 'Jean-Paul Sartre'),
      (3077, 'difficile', 'Quel philosophe associe le divertissement à la fuite devant la condition humaine ?', 'Blaise Pascal'),
      (3078, 'difficile', 'Quel philosophe associe le rire à une fonction sociale de correction ?', 'Henri Bergson'),
      (3079, 'difficile', 'Quel philosophe interroge l’habitude et la croyance dans la connaissance humaine ?', 'David Hume'),
      (3080, 'difficile', 'Quel philosophe met en avant l’expérience comme origine majeure des idées ?', 'John Locke'),
      (3081, 'difficile', 'Quel auteur a écrit La République ?', 'Platon'),
      (3082, 'difficile', 'Quel auteur a écrit Le Banquet ?', 'Platon'),
      (3083, 'difficile', 'Quel auteur a écrit Métaphysique ?', 'Aristote'),
      (3084, 'difficile', 'Quel auteur a écrit Éthique à Nicomaque ?', 'Aristote'),
      (3085, 'difficile', 'Quel auteur a écrit Méditations métaphysiques ?', 'René Descartes'),
      (3086, 'difficile', 'Quel auteur a écrit Discours de la méthode ?', 'René Descartes'),
      (3087, 'difficile', 'Quel auteur a écrit Critique de la raison pure ?', 'Emmanuel Kant'),
      (3088, 'difficile', 'Quel auteur a écrit Critique de la raison pratique ?', 'Emmanuel Kant'),
      (3089, 'difficile', 'Quel auteur a écrit L’Être et le Néant ?', 'Jean-Paul Sartre'),
      (3090, 'difficile', 'Quel auteur a écrit L’existentialisme est un humanisme ?', 'Jean-Paul Sartre'),
      (3091, 'difficile', 'Quel auteur a écrit Le Mythe de Sisyphe ?', 'Albert Camus'),
      (3092, 'difficile', 'Quel auteur a écrit L’Homme révolté ?', 'Albert Camus'),
      (3093, 'difficile', 'Quel auteur a écrit Ainsi parlait Zarathoustra ?', 'Friedrich Nietzsche'),
      (3094, 'difficile', 'Quel auteur a écrit Par-delà bien et mal ?', 'Friedrich Nietzsche'),
      (3095, 'difficile', 'Quel auteur a écrit Éthique ?', 'Baruch Spinoza'),
      (3096, 'difficile', 'Quel auteur a écrit Léviathan ?', 'Thomas Hobbes'),
      (3097, 'difficile', 'Quel auteur a écrit Du contrat social ?', 'Jean-Jacques Rousseau'),
      (3098, 'difficile', 'Quel auteur a écrit Essai sur l’entendement humain ?', 'John Locke'),
      (3099, 'difficile', 'Quel auteur a écrit Enquête sur l’entendement humain ?', 'David Hume'),
      (3100, 'difficile', 'Quel auteur a écrit Phénoménologie de l’esprit ?', 'Georg Wilhelm Friedrich Hegel'),
      (3101, 'difficile', 'Quel auteur a écrit Le Capital ?', 'Karl Marx'),
      (3102, 'difficile', 'Quel auteur a écrit Manifeste du parti communiste avec Friedrich Engels ?', 'Karl Marx'),
      (3103, 'difficile', 'Quel auteur a écrit Ou bien... ou bien ?', 'Søren Kierkegaard'),
      (3104, 'difficile', 'Quel auteur a écrit Crainte et tremblement ?', 'Søren Kierkegaard'),
      (3105, 'difficile', 'Quel auteur a écrit Être et Temps ?', 'Martin Heidegger'),
      (3106, 'difficile', 'Quel auteur a écrit Idées directrices pour une phénoménologie ?', 'Edmund Husserl'),
      (3107, 'difficile', 'Quel auteur a écrit Recherches logiques ?', 'Edmund Husserl'),
      (3108, 'difficile', 'Quel auteur a écrit Tractatus logico-philosophicus ?', 'Ludwig Wittgenstein'),
      (3109, 'difficile', 'Quel auteur a écrit Investigations philosophiques ?', 'Ludwig Wittgenstein'),
      (3110, 'difficile', 'Quel auteur a écrit Théorie de la justice ?', 'John Rawls'),
      (3111, 'difficile', 'Quel auteur a écrit Le Deuxième Sexe ?', 'Simone de Beauvoir'),
      (3112, 'difficile', 'Quel auteur a écrit La Condition de l’homme moderne ?', 'Hannah Arendt'),
      (3113, 'difficile', 'Quel auteur a écrit Les Origines du totalitarisme ?', 'Hannah Arendt'),
      (3114, 'difficile', 'Quel auteur a écrit Surveiller et punir ?', 'Michel Foucault'),
      (3115, 'difficile', 'Quel auteur a écrit Les Mots et les Choses ?', 'Michel Foucault'),
      (3116, 'difficile', 'Quel auteur a écrit De la grammatologie ?', 'Jacques Derrida'),
      (3117, 'difficile', 'Quel auteur a écrit Matière et mémoire ?', 'Henri Bergson'),
      (3118, 'difficile', 'Quel auteur a écrit L’Évolution créatrice ?', 'Henri Bergson'),
      (3119, 'difficile', 'Quel auteur a écrit Pensées ?', 'Blaise Pascal'),
      (3120, 'difficile', 'Quel auteur a écrit Essais ?', 'Michel de Montaigne'),
      (3121, 'difficile', 'Quel auteur a écrit De l’esprit des lois ?', 'Montesquieu'),
      (3122, 'difficile', 'Quel auteur a écrit Traité sur la tolérance ?', 'Voltaire'),
      (3123, 'difficile', 'Quel auteur a écrit Pensées pour moi-même ?', 'Marc Aurèle'),
      (3124, 'difficile', 'Quel auteur a écrit Lettres à Lucilius ?', 'Sénèque'),
      (3125, 'difficile', 'Quel auteur est associé au Manuel dans la tradition stoïcienne ?', 'Épictète'),
      (3126, 'difficile', 'Quel auteur a écrit Introduction aux principes de morale et de législation ?', 'Jeremy Bentham'),
      (3127, 'difficile', 'Quel auteur a écrit De la liberté ?', 'John Stuart Mill'),
      (3128, 'difficile', 'Quel auteur a écrit La Société ouverte et ses ennemis ?', 'Karl Popper'),
      (3129, 'difficile', 'Quel auteur a écrit La Structure des révolutions scientifiques ?', 'Thomas Kuhn'),
      (3130, 'difficile', 'Quel auteur a écrit Théorie de l’agir communicationnel ?', 'Jürgen Habermas'),
      (3131, 'difficile', 'Quel auteur a écrit Le Principe responsabilité ?', 'Hans Jonas'),
      (3132, 'difficile', 'Quel auteur a écrit Éclipse de la raison ?', 'Max Horkheimer'),
      (3133, 'difficile', 'Quel auteur a écrit Dialectique de la raison avec Theodor W. Adorno ?', 'Max Horkheimer'),
      (3134, 'difficile', 'Quel auteur a écrit Minima Moralia ?', 'Theodor W. Adorno'),
      (3135, 'difficile', 'Quel auteur a écrit Éros et civilisation ?', 'Herbert Marcuse'),
      (3136, 'difficile', 'Quel auteur a écrit Consciencism ?', 'Kwame Nkrumah'),
      (3137, 'difficile', 'Quel auteur a écrit Sur la philosophie africaine ?', 'Paulin Hountondji'),
      (3138, 'difficile', 'Quel auteur a écrit Cultural Universals and Particulars ?', 'Kwasi Wiredu'),
      (3139, 'difficile', 'Quel auteur a écrit L’Invention de l’Afrique ?', 'Valentin-Yves Mudimbe'),
      (3140, 'difficile', 'Quel auteur a écrit De la postcolonie ?', 'Achille Mbembe'),
      (3141, 'difficile', 'Quel auteur a écrit Peau noire, masques blancs ?', 'Frantz Fanon'),
      (3142, 'difficile', 'Quel auteur a écrit Les Damnés de la terre ?', 'Frantz Fanon'),
      (3143, 'difficile', 'Quel auteur a écrit Discours sur le colonialisme ?', 'Aimé Césaire'),
      (3144, 'difficile', 'Quel auteur a écrit African Philosophy through Ubuntu ?', 'Mogobe Ramose'),
      (3145, 'difficile', 'Quel auteur a écrit La philosophie bantoue ?', 'Placide Tempels'),
      (3146, 'difficile', 'Quel auteur a écrit La crise du Muntu ?', 'Fabien Eboussi Boulaga'),
      (3147, 'difficile', 'Quel auteur a écrit Nations nègres et culture ?', 'Cheikh Anta Diop'),
      (3148, 'difficile', 'Quel auteur a écrit Civilisation ou barbarie ?', 'Cheikh Anta Diop'),
      (3149, 'difficile', 'Quel auteur a écrit Liberté I: Négritude et humanisme ?', 'Léopold Sédar Senghor'),
      (3150, 'difficile', 'Quel auteur a écrit Critique of Black Reason ?', 'Achille Mbembe'),
      (3151, 'difficile', 'Quel auteur a écrit La Nausée, roman philosophique existentialiste ?', 'Jean-Paul Sartre'),
      (3152, 'difficile', 'Quel auteur a écrit Caligula, pièce souvent associée à la réflexion sur l’absurde ?', 'Albert Camus'),
      (3153, 'difficile', 'Quel auteur a écrit Généalogie de la morale ?', 'Friedrich Nietzsche'),
      (3154, 'difficile', 'Quel auteur a écrit Aurore ?', 'Friedrich Nietzsche'),
      (3155, 'difficile', 'Quel auteur a écrit Prolégomènes à toute métaphysique future ?', 'Emmanuel Kant'),
      (3156, 'difficile', 'Quel auteur a écrit Fondements de la métaphysique des mœurs ?', 'Emmanuel Kant'),
      (3157, 'difficile', 'Quel auteur a écrit Lettre sur la tolérance ?', 'John Locke'),
      (3158, 'difficile', 'Quel auteur a écrit Discours sur l’origine et les fondements de l’inégalité parmi les hommes ?', 'Jean-Jacques Rousseau'),
      (3159, 'difficile', 'Quel auteur a écrit La Monadologie ?', 'Gottfried Wilhelm Leibniz'),
      (3160, 'difficile', 'Quel auteur a écrit Nouveaux essais sur l’entendement humain ?', 'Gottfried Wilhelm Leibniz'),
      (3161, 'difficile', 'Quel auteur a écrit Monadologie et défend l’idée des monades ?', 'Gottfried Wilhelm Leibniz'),
      (3162, 'difficile', 'Quel auteur a écrit Somme théologique ?', 'Thomas d’Aquin'),
      (3163, 'difficile', 'Quel auteur a écrit Les Confessions dans la tradition philosophique chrétienne ?', 'Augustin d’Hippone'),
      (3164, 'difficile', 'Quel auteur a écrit La Cité de Dieu ?', 'Augustin d’Hippone'),
      (3165, 'difficile', 'Quel auteur a écrit Le Prince ?', 'Nicolas Machiavel'),
      (3166, 'difficile', 'Quel auteur a écrit Utopie ?', 'Thomas More'),
      (3167, 'difficile', 'Quel auteur a écrit Novum Organum ?', 'Francis Bacon'),
      (3168, 'difficile', 'Quel auteur a écrit La Science nouvelle ?', 'Giambattista Vico'),
      (3169, 'difficile', 'Quel auteur a écrit Le Monde comme volonté et comme représentation ?', 'Arthur Schopenhauer'),
      (3170, 'difficile', 'Quel auteur a écrit Aphorismes sur la sagesse dans la vie ?', 'Arthur Schopenhauer'),
      (3171, 'difficile', 'Quel auteur a écrit L’Unique et sa propriété ?', 'Max Stirner'),
      (3172, 'difficile', 'Quel auteur a écrit La Pensée sauvage ?', 'Claude Lévi-Strauss'),
      (3173, 'difficile', 'Quel auteur a écrit Tristes Tropiques ?', 'Claude Lévi-Strauss'),
      (3174, 'difficile', 'Quel auteur a écrit Le Principe espérance ?', 'Ernst Bloch'),
      (3175, 'difficile', 'Quel auteur a écrit Totalité et Infini ?', 'Emmanuel Levinas'),
      (3176, 'difficile', 'Quel auteur a écrit Autrement qu’être ou au-delà de l’essence ?', 'Emmanuel Levinas'),
      (3177, 'difficile', 'Quel auteur a écrit La Voix et le Phénomène ?', 'Jacques Derrida'),
      (3178, 'difficile', 'Quel auteur a écrit L’Archéologie du savoir ?', 'Michel Foucault'),
      (3179, 'difficile', 'Quel auteur a écrit La Société du spectacle ?', 'Guy Debord'),
      (3180, 'difficile', 'Quel auteur a écrit Différence et répétition ?', 'Gilles Deleuze'),
      (3181, 'difficile', 'Quel auteur a écrit Mille Plateaux avec Félix Guattari ?', 'Gilles Deleuze'),
      (3182, 'difficile', 'Quel auteur a écrit L’Anti-Œdipe avec Félix Guattari ?', 'Gilles Deleuze'),
      (3183, 'difficile', 'Quel auteur a écrit La Condition postmoderne ?', 'Jean-François Lyotard'),
      (3184, 'difficile', 'Quel auteur a écrit Simulacres et Simulation ?', 'Jean Baudrillard'),
      (3185, 'difficile', 'Quel auteur a écrit La Société de consommation ?', 'Jean Baudrillard'),
      (3186, 'difficile', 'Quel auteur a écrit Sphères ?', 'Peter Sloterdijk'),
      (3187, 'difficile', 'Quel auteur a écrit Critique de la raison cynique ?', 'Peter Sloterdijk'),
      (3188, 'difficile', 'Quel auteur a écrit Après la vertu ?', 'Alasdair MacIntyre'),
      (3189, 'difficile', 'Quel auteur a écrit Sources of the Self ?', 'Charles Taylor'),
      (3190, 'difficile', 'Quel auteur a écrit Multiculturalisme: différence et démocratie ?', 'Charles Taylor'),
      (3191, 'difficile', 'Quel auteur a écrit Anarchie, État et utopie ?', 'Robert Nozick'),
      (3192, 'difficile', 'Quel auteur a écrit Sphères de justice ?', 'Michael Walzer'),
      (3193, 'difficile', 'Quel auteur a écrit Éthique de la sollicitude ?', 'Carol Gilligan'),
      (3194, 'difficile', 'Quel auteur a écrit Une voix différente ?', 'Carol Gilligan'),
      (3195, 'difficile', 'Quel auteur a écrit La Vie de l’esprit ?', 'Hannah Arendt'),
      (3196, 'difficile', 'Quel auteur a écrit Condition de l’homme moderne ?', 'Hannah Arendt'),
      (3197, 'difficile', 'Quel auteur a écrit Justice et démocratie ?', 'John Rawls'),
      (3198, 'difficile', 'Quel auteur a écrit Libéralisme politique ?', 'John Rawls'),
      (3199, 'difficile', 'Quel auteur a écrit L’Éthique de la psychanalyse dans ses séminaires ?', 'Jacques Lacan'),
      (3200, 'difficile', 'Quel auteur est associé aux Écrits et à une relecture philosophique de Freud ?', 'Jacques Lacan')
  ) as rows (order_index, difficulty, question_text, correct_answer)
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
      ('Herbert Marcuse'),
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
      ('Sénèque'),
      ('Søren Kierkegaard'),
      ('Theodor W. Adorno'),
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
      substr(md5('culture-philosophie-only-20260623-question-' || question_options.order_index), 1, 8)
      || '-' ||
      substr(md5('culture-philosophie-only-20260623-question-' || question_options.order_index), 9, 4)
      || '-' ||
      substr(md5('culture-philosophie-only-20260623-question-' || question_options.order_index), 13, 4)
      || '-' ||
      substr(md5('culture-philosophie-only-20260623-question-' || question_options.order_index), 17, 4)
      || '-' ||
      substr(md5('culture-philosophie-only-20260623-question-' || question_options.order_index), 21, 12)
    )::uuid,
    null,
    bank_seed.id,
    category_seed.id,
    'bank',
    'quiz',
    question_options.question_text,
    null,
    case when question_options.correct_slot = 1 then question_options.correct_answer else question_options.distractor_options[1] end,
    null,
    case when question_options.correct_slot = 2 then question_options.correct_answer else question_options.distractor_options[case when question_options.correct_slot = 1 then 1 else 2 end] end,
    null,
    case when question_options.correct_slot = 3 then question_options.correct_answer else question_options.distractor_options[case when question_options.correct_slot in (1, 2) then 2 else 3 end] end,
    null,
    case when question_options.correct_slot = 4 then question_options.correct_answer else question_options.distractor_options[3] end,
    null,
    case question_options.correct_slot
      when 1 then 'A'
      when 2 then 'B'
      when 3 then 'C'
      else 'D'
    end,
    case question_options.difficulty
      when 'difficile' then 15
      else 10
    end,
    case question_options.difficulty
      when 'difficile' then 25
      else 20
    end,
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
  count(distinct question_text) as unique_question_texts
from question_options;

notify pgrst, 'reload schema';
