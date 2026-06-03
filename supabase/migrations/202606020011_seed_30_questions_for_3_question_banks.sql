-- MegaPromo - 30 questions pour 3 banques JCQ
-- A executer dans Supabase SQL Editor apres:
-- 202606020010_seed_3_question_bank_categories_only.sql.
--
-- Objectif:
-- - ajouter 10 questions dans Banque Automobile;
-- - ajouter 10 questions dans Banque Technologie;
-- - ajouter 10 questions dans Banque Musique;
-- - ne pas creer de JCQ;
-- - garder les questions modifiables depuis le SA.
--
-- Important:
-- - execute d'abord en DEV;
-- - execute ensuite en PROD uniquement apres validation.

with category_rows as (
  select id, name
  from public.categories
  where name in ('Automobile', 'Technologie', 'Musique')
),
bank_mapping as (
  select *
  from (
    values
      (
        'automobile',
        'Automobile',
        '20260602-0000-4000-b001-000000000001'::uuid
      ),
      (
        'technologie',
        'Technologie',
        '20260602-0000-4000-b002-000000000002'::uuid
      ),
      (
        'musique',
        'Musique',
        '20260602-0000-4000-b003-000000000003'::uuid
      )
  ) as rows(bank_key, category_name, question_bank_id)
),
question_rows as (
  select *
  from (
    values
      (
        'automobile',
        1,
        'Quel element permet principalement de ralentir une voiture ?',
        'Les freins',
        'Le klaxon',
        'Les phares',
        'La radio',
        'A',
        'facile'
      ),
      (
        'automobile',
        2,
        'Que signifie generalement ABS dans une voiture ?',
        'Systeme antiblocage des roues',
        'Aide batterie sport',
        'Air balance system',
        'Auto boost simple',
        'A',
        'moyen'
      ),
      (
        'automobile',
        3,
        'Quel document est indispensable pour conduire legalement ?',
        'Le permis de conduire',
        'Une carte de fidelite',
        'Un ticket de lavage',
        'Une facture de carburant',
        'A',
        'facile'
      ),
      (
        'automobile',
        4,
        'Quel voyant signale souvent un probleme de moteur ?',
        'Check engine',
        'Bluetooth',
        'Mode nuit',
        'Volume audio',
        'A',
        'moyen'
      ),
      (
        'automobile',
        5,
        'Quelle pression concerne directement les pneus ?',
        'La pression d air',
        'La pression fiscale',
        'La pression sonore',
        'La pression d ecran',
        'A',
        'facile'
      ),
      (
        'automobile',
        6,
        'Quel organe transmet la puissance aux roues ?',
        'La transmission',
        'Le pare-soleil',
        'Le retroviseur',
        'Le siege arriere',
        'A',
        'moyen'
      ),
      (
        'automobile',
        7,
        'Que faut-il verifier avant un long trajet ?',
        'Niveau d huile et pneus',
        'Fond d ecran du telephone',
        'Nom Bluetooth',
        'Couleur des tapis',
        'A',
        'facile'
      ),
      (
        'automobile',
        8,
        'Quel carburant est couramment utilise par les moteurs diesel ?',
        'Gazole',
        'Kerosene aviation',
        'Eau minerale',
        'Huile alimentaire',
        'A',
        'facile'
      ),
      (
        'automobile',
        9,
        'Que designe la cylindree d un moteur ?',
        'Le volume des cylindres',
        'La taille du coffre',
        'La couleur du volant',
        'La largeur du pare-brise',
        'A',
        'moyen'
      ),
      (
        'automobile',
        10,
        'Quel equipement aide a rester dans sa voie sur certains vehicules ?',
        'Aide au maintien de voie',
        'Chargeur mural',
        'Radio AM',
        'Boite a gants',
        'A',
        'moyen'
      ),

      (
        'technologie',
        1,
        'Que signifie IA dans le domaine numerique ?',
        'Intelligence artificielle',
        'Interface analogique',
        'Image automatique',
        'Internet ancien',
        'A',
        'facile'
      ),
      (
        'technologie',
        2,
        'Quel appareil sert principalement a se connecter a internet en mobilite ?',
        'Smartphone',
        'Micro-onde',
        'Fer a repasser',
        'Boussole papier',
        'A',
        'facile'
      ),
      (
        'technologie',
        3,
        'Que protege un mot de passe robuste ?',
        'Un compte utilisateur',
        'Une bouteille d eau',
        'Une chaise',
        'Un cable HDMI uniquement',
        'A',
        'facile'
      ),
      (
        'technologie',
        4,
        'Quel service permet de stocker des fichiers en ligne ?',
        'Cloud',
        'Clavier',
        'Batterie',
        'Projecteur',
        'A',
        'facile'
      ),
      (
        'technologie',
        5,
        'Que signifie generalement 5G ?',
        'Cinquieme generation mobile',
        'Cinq gigaoctets fixes',
        'Graphisme 5 couleurs',
        'Gestion 5 fichiers',
        'A',
        'moyen'
      ),
      (
        'technologie',
        6,
        'Quel composant execute les calculs principaux d un ordinateur ?',
        'Processeur',
        'Ecran',
        'Souris',
        'Haut-parleur',
        'A',
        'facile'
      ),
      (
        'technologie',
        7,
        'Quel format est souvent utilise pour les pages web ?',
        'HTML',
        'MP3',
        'PNG uniquement',
        'GPS',
        'A',
        'facile'
      ),
      (
        'technologie',
        8,
        'Que permet une mise a jour de securite ?',
        'Corriger des failles',
        'Changer la couleur du mur',
        'Augmenter le carburant',
        'Remplacer une carte SIM physique',
        'A',
        'moyen'
      ),
      (
        'technologie',
        9,
        'Quel reseau local sans fil est tres courant ?',
        'Wi-Fi',
        'Diesel',
        'Vinyle',
        'Climatiseur',
        'A',
        'facile'
      ),
      (
        'technologie',
        10,
        'Quel terme designe une application installee sur telephone ?',
        'Application mobile',
        'Circuit imprimante',
        'Cable optique seul',
        'Carte routiere papier',
        'A',
        'facile'
      ),

      (
        'musique',
        1,
        'Quel element donne souvent le rythme dans une chanson ?',
        'La batterie',
        'Le retroviseur',
        'Le clavier numerique',
        'Le passeport',
        'A',
        'facile'
      ),
      (
        'musique',
        2,
        'Comment appelle-t-on une suite de chansons publiees ensemble ?',
        'Album',
        'Moteur',
        'Forfait',
        'Clavier',
        'A',
        'facile'
      ),
      (
        'musique',
        3,
        'Quel artiste chante generalement avec sa voix ?',
        'Le vocaliste',
        'Le mecanicien',
        'Le programmeur',
        'Le pilote automatique',
        'A',
        'facile'
      ),
      (
        'musique',
        4,
        'Quel instrument possede des touches noires et blanches ?',
        'Piano',
        'Tambourin',
        'Microphone',
        'Casque audio',
        'A',
        'facile'
      ),
      (
        'musique',
        5,
        'Que mesure le tempo d une musique ?',
        'La vitesse du rythme',
        'La taille de la scene',
        'Le prix du ticket',
        'La couleur de la pochette',
        'A',
        'moyen'
      ),
      (
        'musique',
        6,
        'Comment appelle-t-on les paroles d une chanson ?',
        'Lyrics',
        'Moteur',
        'Pixel',
        'Carte SIM',
        'A',
        'facile'
      ),
      (
        'musique',
        7,
        'Quel style musical est tres populaire en Cote d Ivoire ?',
        'Coupe-decale',
        'Country alpin',
        'Opera spatial',
        'Jazz polaire',
        'A',
        'facile'
      ),
      (
        'musique',
        8,
        'Quel outil amplifie la voix sur scene ?',
        'Microphone',
        'Cle a molette',
        'Routeur Wi-Fi',
        'Extincteur',
        'A',
        'facile'
      ),
      (
        'musique',
        9,
        'Que fait un DJ pendant une prestation musicale ?',
        'Il mixe des sons',
        'Il repare un moteur',
        'Il construit un pont',
        'Il imprime des cartes',
        'A',
        'facile'
      ),
      (
        'musique',
        10,
        'Comment appelle-t-on une performance musicale devant un public ?',
        'Concert',
        'Vidange',
        'Connexion',
        'Archive',
        'A',
        'facile'
      )
  ) as rows(
    bank_key,
    order_index,
    question_text,
    option_a,
    option_b,
    option_c,
    option_d,
    correct_answer,
    difficulty
  )
),
question_seed as (
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
      substr(md5('bank-question-v2-' || question_rows.bank_key || '-' || question_rows.order_index), 1, 8)
      || '-' ||
      substr(md5('bank-question-v2-' || question_rows.bank_key || '-' || question_rows.order_index), 9, 4)
      || '-' ||
      substr(md5('bank-question-v2-' || question_rows.bank_key || '-' || question_rows.order_index), 13, 4)
      || '-' ||
      substr(md5('bank-question-v2-' || question_rows.bank_key || '-' || question_rows.order_index), 17, 4)
      || '-' ||
      substr(md5('bank-question-v2-' || question_rows.bank_key || '-' || question_rows.order_index), 21, 12)
    )::uuid,
    null,
    bank_mapping.question_bank_id,
    category_rows.id,
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
  join category_rows on category_rows.name = bank_mapping.category_name
  on conflict (id) do update set
    contest_id = null,
    question_bank_id = excluded.question_bank_id,
    category_id = excluded.category_id,
    question_scope = 'bank',
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
)
select
  (select count(*) from question_seed) as questions_upserted,
  (
    select count(*)
    from public.questions
    where question_bank_id in (
      '20260602-0000-4000-b001-000000000001'::uuid,
      '20260602-0000-4000-b002-000000000002'::uuid,
      '20260602-0000-4000-b003-000000000003'::uuid
    )
  ) as bank_questions_total;

notify pgrst, 'reload schema';
