-- MegaPromo - 100 questions Côte d'Ivoire histoire, culture et société
-- A exécuter dans Supabase SQL Editor après:
-- 202606080004_seed_cote_ivoire_actuelle_question_bank.sql.
--
-- Objectif:
-- - enrichir la catégorie "Côte d'Ivoire Actuelle";
-- - ajouter 100 questions QCM texte sur l'indépendance, les régions,
--   les personnalités publiques, la culture, les peuples, les plats,
--   la musique et la population;
-- - varier la position de la bonne réponse entre A, B, C et D.

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
    'Côte d''Ivoire Actuelle',
    'Questions sur la Côte d''Ivoire: histoire, régions, culture, peuples, gastronomie, musique et société.',
    'flag',
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
    '20260608-0000-4000-b005-000000000005'::uuid,
    'Banque Côte d''Ivoire Actuelle',
    'Questions texte et média sur la Côte d''Ivoire actuelle, son histoire, ses régions, ses cultures et sa société.',
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
      (401, 'intermediaire', 'À quelle date la Côte d''Ivoire a-t-elle proclamé son indépendance ?', '7 août 1960', '1er janvier 1960', '15 novembre 1958', '6 mars 1957', 'A'),
      (402, 'intermediaire', 'Qui est le premier président de la République de Côte d''Ivoire ?', 'Laurent Gbagbo', 'Félix Houphouët-Boigny', 'Alassane Ouattara', 'Henri Konan Bédié', 'B'),
      (403, 'intermediaire', 'Quelle ville est la capitale politique officielle de la Côte d''Ivoire ?', 'Abidjan', 'Bouaké', 'Yamoussoukro', 'Korhogo', 'C'),
      (404, 'intermediaire', 'Quelle ville est souvent considérée comme la capitale économique ivoirienne ?', 'San Pedro', 'Bouaké', 'Daloa', 'Abidjan', 'D'),
      (405, 'intermediaire', 'Quel pays partage une frontière à l''est avec la Côte d''Ivoire ?', 'Ghana', 'Sénégal', 'Cameroun', 'Niger', 'A'),
      (406, 'intermediaire', 'Quel pays partage une frontière au nord avec la Côte d''Ivoire ?', 'Bénin', 'Burkina Faso', 'Gabon', 'Tchad', 'B'),
      (407, 'intermediaire', 'Quel pays partage une frontière à l''ouest avec la Côte d''Ivoire ?', 'Nigeria', 'Togo', 'Libéria', 'Cap-Vert', 'C'),
      (408, 'intermediaire', 'Quelle monnaie est utilisée en Côte d''Ivoire ?', 'Cedi', 'Naira', 'Dalasi', 'Franc CFA BCEAO', 'D'),
      (409, 'intermediaire', 'Quelle langue est la langue officielle de la Côte d''Ivoire ?', 'Français', 'Anglais', 'Espagnol', 'Portugais', 'A'),
      (410, 'intermediaire', 'Quel produit agricole a longtemps fait de la Côte d''Ivoire un acteur majeur mondial ?', 'Thé', 'Cacao', 'Olive', 'Blé', 'B'),
      (411, 'intermediaire', 'Quel port est un grand centre d''exportation dans le sud-ouest ivoirien ?', 'Odienné', 'Man', 'San Pedro', 'Bouna', 'C'),
      (412, 'intermediaire', 'Quel quartier d''Abidjan est connu comme centre administratif et d''affaires ?', 'Yopougon', 'Abobo', 'Koumassi', 'Plateau', 'D'),
      (413, 'intermediaire', 'Quelle commune d''Abidjan est connue pour sa forte population et sa vie culturelle ?', 'Yopougon', 'Sassandra', 'Tengréla', 'Bongouanou', 'A'),
      (414, 'intermediaire', 'Quelle commune d''Abidjan abrite l''aéroport international Félix-Houphouët-Boigny ?', 'Cocody', 'Port-Bouët', 'Adjamé', 'Attécoubé', 'B'),
      (415, 'intermediaire', 'Quelle ville ivoirienne est associée à la basilique Notre-Dame de la Paix ?', 'Grand-Bassam', 'Abidjan', 'Yamoussoukro', 'Daloa', 'C'),
      (416, 'intermediaire', 'Quel site ivoirien est inscrit au patrimoine mondial de l''UNESCO pour son histoire coloniale ?', 'Assinie', 'Jacqueville', 'Tiébissou', 'Grand-Bassam', 'D'),
      (417, 'intermediaire', 'Quel fleuve traverse une grande partie de la Côte d''Ivoire et donne son nom à une région ?', 'Bandama', 'Nil', 'Congo', 'Sénégal', 'A'),
      (418, 'intermediaire', 'Quelle lagune est fortement associée à la ville d''Abidjan ?', 'Lagune Nokoué', 'Lagune Ébrié', 'Lagune de Tunis', 'Lagune Aby uniquement', 'B'),
      (419, 'intermediaire', 'Quelle ville est souvent présentée comme la deuxième grande ville ivoirienne par son importance historique ?', 'Tabou', 'Aboisso', 'Bouaké', 'Touba', 'C'),
      (420, 'intermediaire', 'Quelle ville de l''ouest ivoirien est connue pour ses montagnes et ses paysages ?', 'Bingerville', 'Dabou', 'Adzopé', 'Man', 'D'),
      (421, 'intermediaire', 'Quel peuple est particulièrement associé à la région de Korhogo et au nord ivoirien ?', 'Sénoufo', 'Basque', 'Maasaï', 'Zoulou', 'A'),
      (422, 'intermediaire', 'Quel peuple est fortement associé au centre de la Côte d''Ivoire ?', 'Peul uniquement', 'Baoulé', 'Wolof', 'Bamiléké', 'B'),
      (423, 'intermediaire', 'Quel groupe culturel est associé à l''ouest de la Côte d''Ivoire, notamment autour de Man ?', 'Akan uniquement', 'Touareg', 'Dan / Yacouba', 'Mossi', 'C'),
      (424, 'intermediaire', 'Quel peuple lagunaire est historiquement associé à Abidjan et à la lagune Ébrié ?', 'Soninké', 'Haoussa', 'Kikongo', 'Ébrié', 'D'),
      (425, 'intermediaire', 'Quel groupe culturel est associé à la région d''Abengourou et au royaume de l''Indénié ?', 'Agni', 'Dogon', 'Bambara', 'Bété uniquement', 'A'),
      (426, 'intermediaire', 'Quel peuple est souvent associé à la région de Gagnoa et au centre-ouest ?', 'Kroumen uniquement', 'Bété', 'Somba', 'Mina', 'B'),
      (427, 'intermediaire', 'Quel peuple est associé au sud-ouest ivoirien et aux zones côtières autour de Tabou ?', 'Baoulé', 'Ébrié', 'Kroumen', 'Sénoufo', 'C'),
      (428, 'intermediaire', 'Quel terme désigne souvent les grands groupes culturels Akan, Krou, Mandé et Gour en Côte d''Ivoire ?', 'Partis politiques', 'Clubs sportifs', 'Monnaies locales', 'Familles ethnolinguistiques', 'D'),
      (429, 'intermediaire', 'Quel plat à base de semoule de manioc est très populaire en Côte d''Ivoire ?', 'Attiéké', 'Pizza', 'Tacos', 'Paella', 'A'),
      (430, 'intermediaire', 'Quel plat ivoirien est préparé avec de la banane plantain frite ?', 'Garba', 'Alloco', 'Kédjénou', 'Placali', 'B'),
      (431, 'intermediaire', 'Quel plat populaire associe souvent attiéké, thon frit et condiments ?', 'Foutou sauce graine', 'Riz gras', 'Garba', 'Sauce claire', 'C'),
      (432, 'intermediaire', 'Quel plat est traditionnellement préparé à l''étouffée avec du poulet ou de la pintade ?', 'Alloco', 'Attiéké poisson', 'Riz cantonais', 'Kédjénou', 'D'),
      (433, 'intermediaire', 'Quel accompagnement est souvent fait à base de banane plantain ou d''igname pilée ?', 'Foutou', 'Couscous', 'Sushi', 'Pain pita', 'A'),
      (434, 'intermediaire', 'Quelle sauce ivoirienne est souvent préparée à base de graines de palmier ?', 'Sauce tomate italienne', 'Sauce graine', 'Sauce soja', 'Sauce béchamel', 'B'),
      (435, 'intermediaire', 'Quel aliment fermenté à base de manioc accompagne souvent des sauces en Côte d''Ivoire ?', 'Riz parfumé', 'Mil soufflé', 'Placali', 'Pain complet', 'C'),
      (436, 'intermediaire', 'Quel nom est souvent donné aux restaurants populaires ivoiriens où l''on mange et échange ?', 'Bistros alpins', 'Cantines polaires', 'Tavernes vikings', 'Maquis', 'D'),
      (437, 'intermediaire', 'Quel style musical est né en Côte d''Ivoire dans les années 2000 et a marqué les pistes de danse ?', 'Coupé-décalé', 'Flamenco', 'Bluegrass', 'Fado', 'A'),
      (438, 'intermediaire', 'Quel genre musical ivoirien est associé à des textes de société et à des groupes comme Magic System ?', 'Reggae jamaïcain', 'Zouglou', 'Country', 'K-pop', 'B'),
      (439, 'intermediaire', 'Quel artiste ivoirien est souvent cité comme une figure majeure du reggae africain ?', 'DJ Arafat', 'Alpha Blondy', 'Tiken Jah Fakoly', 'Meiway', 'C'),
      (440, 'intermediaire', 'Quel artiste est considéré comme une grande figure du coupé-décalé ivoirien ?', 'Fally Ipupa', 'Salif Keïta', 'Youssou N''Dour', 'DJ Arafat', 'D'),
      (441, 'intermediaire', 'Quel artiste ivoirien est associé au style zoblazo ?', 'Meiway', 'Bob Marley', 'Koffi Olomidé', 'Akon', 'A'),
      (442, 'intermediaire', 'Quel groupe ivoirien a popularisé le titre "Premier Gaou" à l''international ?', 'Toofan', 'Magic System', 'P-Square', 'X-Maleya', 'B'),
      (443, 'intermediaire', 'Quel chanteur ivoirien engagé est connu pour des titres reggae et des messages politiques ?', 'A''Salfo', 'Kerozen', 'Tiken Jah Fakoly', 'Didi B', 'C'),
      (444, 'intermediaire', 'Quel terme désigne souvent l''ambiance musicale et festive des quartiers d''Abidjan ?', 'Opéra baroque', 'Silence monastique', 'Concert classique uniquement', 'Ambiance maquis', 'D'),
      (445, 'intermediaire', 'Quelle fête nationale ivoirienne est célébrée le 7 août ?', 'Fête de l''Indépendance', 'Fête du Travail uniquement', 'Noël', 'Pâques', 'A'),
      (446, 'intermediaire', 'Quel emblème animal est associé à l''équipe nationale de football ivoirienne ?', 'Les Lions', 'Les Éléphants', 'Les Aigles', 'Les Panthères', 'B'),
      (447, 'intermediaire', 'Quelle compétition la Côte d''Ivoire a organisée et remportée lors de l''édition 2023 ?', 'Coupe du monde', 'Euro', 'CAN', 'Copa América', 'C'),
      (448, 'intermediaire', 'Quel stade d''Abidjan a accueilli la finale de la CAN 2023 ?', 'Stade de la Paix', 'Stade Laurent Pokou', 'Stade Amadou Gon Coulibaly', 'Stade Alassane Ouattara d''Ébimpé', 'D'),
      (449, 'intermediaire', 'Quel joueur ivoirien est une figure historique de Chelsea et des Éléphants ?', 'Didier Drogba', 'Sadio Mané', 'Samuel Eto''o', 'Michael Essien', 'A'),
      (450, 'intermediaire', 'Quel ancien milieu ivoirien a joué au FC Barcelone et à Manchester City ?', 'Jay-Jay Okocha', 'Yaya Touré', 'Asamoah Gyan', 'Nwankwo Kanu', 'B'),
      (451, 'intermediaire', 'Quelle ville du nord a accueilli des matchs de la CAN 2023 ?', 'Aboisso', 'Gagnoa', 'Korhogo', 'Adiaké', 'C'),
      (452, 'intermediaire', 'Quelle ville portuaire a accueilli des matchs de la CAN 2023 au sud-ouest ?', 'Bouna', 'Dimbokro', 'Agboville', 'San Pedro', 'D'),
      (453, 'difficile', 'Quel ancien président ivoirien a succédé à Félix Houphouët-Boigny en 1993 ?', 'Henri Konan Bédié', 'Robert Guéï', 'Laurent Gbagbo', 'Alassane Ouattara', 'A'),
      (454, 'difficile', 'Quel président ivoirien a dirigé le pays après le coup d''État de 1999 ?', 'Félix Houphouët-Boigny', 'Robert Guéï', 'Henri Konan Bédié', 'Amadou Gon Coulibaly', 'B'),
      (455, 'difficile', 'Quel président ivoirien a été élu en 2000 ?', 'Alassane Ouattara', 'Félix Houphouët-Boigny', 'Laurent Gbagbo', 'Tiemoko Meyliet Koné', 'C'),
      (456, 'difficile', 'Quel président ivoirien est arrivé au pouvoir après la crise postélectorale de 2010-2011 ?', 'Henri Konan Bédié', 'Robert Guéï', 'Félix Houphouët-Boigny', 'Alassane Ouattara', 'D'),
      (457, 'difficile', 'Quel nom portait la colonie avant l''indépendance dans l''administration française ?', 'Côte d''Ivoire', 'Haute-Volta', 'Dahomey', 'Soudan français', 'A'),
      (458, 'difficile', 'Dans quelle fédération coloniale la Côte d''Ivoire était-elle intégrée ?', 'Afrique équatoriale française', 'Afrique-Occidentale française', 'Union indochinoise', 'Fédération des Antilles', 'B'),
      (459, 'difficile', 'Quel parti historique est associé à Félix Houphouët-Boigny avant et après l''indépendance ?', 'FPI', 'RDR', 'PDCI-RDA', 'UDPCI', 'C'),
      (460, 'difficile', 'Quel terme désigne la longue période de stabilité et de croissance économique après l''indépendance ?', 'Révolution culturelle', 'Printemps ivoirien', 'Transition minière', 'Miracle ivoirien', 'D'),
      (461, 'difficile', 'Quel secteur a fortement soutenu le "miracle ivoirien" des premières décennies ?', 'Agriculture d''exportation', 'Industrie spatiale', 'Pêche arctique', 'Cinéma hollywoodien', 'A'),
      (462, 'difficile', 'Quel produit, avec le cacao, a longtemps été central dans les exportations agricoles ivoiriennes ?', 'Riz basmati', 'Café', 'Thé vert', 'Safran', 'B'),
      (463, 'difficile', 'Quel organisme régional de monnaie est lié au franc CFA utilisé en Côte d''Ivoire ?', 'CAF', 'ONU', 'BCEAO', 'OPEP', 'C'),
      (464, 'difficile', 'Quelle organisation économique ouest-africaine regroupe notamment des pays utilisant le franc CFA BCEAO ?', 'ASEAN', 'Mercosur', 'Union européenne', 'UEMOA', 'D'),
      (465, 'difficile', 'Quelle institution financière africaine a son siège à Abidjan ?', 'Banque africaine de développement', 'Banque mondiale', 'Banque centrale européenne', 'Banque du Japon', 'A'),
      (466, 'difficile', 'Quelle bourse régionale est basée à Abidjan ?', 'Bourse de Paris', 'BRVM', 'NYSE', 'NASDAQ', 'B'),
      (467, 'difficile', 'Quel parc national ivoirien est classé au patrimoine mondial de l''UNESCO pour sa biodiversité forestière ?', 'Parc du Banco uniquement', 'Parc Kruger', 'Parc national de Taï', 'Serengeti', 'C'),
      (468, 'difficile', 'Quel grand parc national ivoirien est situé au nord-est du pays ?', 'Parc national de la Pendjari', 'Parc national de Mole', 'Parc national du W', 'Parc national de la Comoé', 'D'),
      (469, 'difficile', 'Quelle ville est associée au royaume de l''Indénié ?', 'Abengourou', 'San Pedro', 'Daloa', 'Korhogo', 'A'),
      (470, 'difficile', 'Quel titre traditionnel est souvent associé au royaume baoulé de Sakassou ?', 'Sultan', 'Reine-mère', 'Doge', 'Tsar', 'B'),
      (471, 'difficile', 'Quelle reine est une figure fondatrice importante dans l''histoire baoulé ?', 'Aline Sitoé Diatta', 'Ranavalona III', 'Abla Pokou', 'Yaa Asantewaa uniquement', 'C'),
      (472, 'difficile', 'Quel peuple est associé au Poro, société initiatique importante du nord ivoirien ?', 'Ébrié', 'Baoulé', 'Kroumen', 'Sénoufo', 'D'),
      (473, 'difficile', 'Quelle région administrative a pour chef-lieu Korhogo ?', 'Poro', 'Gbêkê', 'Cavally', 'La Mé', 'A'),
      (474, 'difficile', 'Quelle région administrative a pour chef-lieu Bouaké ?', 'Tonkpi', 'Gbêkê', 'Bélier', 'Gôh', 'B'),
      (475, 'difficile', 'Quelle région administrative a pour chef-lieu Man ?', 'Nawa', 'Indénié-Djuablin', 'Tonkpi', 'Iffou', 'C'),
      (476, 'difficile', 'Quelle région administrative a pour chef-lieu San Pedro ?', 'Poro', 'Gontougo', 'Bafing', 'San-Pédro', 'D'),
      (477, 'difficile', 'Quelle région administrative a pour chef-lieu Daloa ?', 'Haut-Sassandra', 'Agnéby-Tiassa', 'Béré', 'Folon', 'A'),
      (478, 'difficile', 'Quelle région administrative a pour chef-lieu Abengourou ?', 'Bagoué', 'Indénié-Djuablin', 'Hambol', 'Moronou', 'B'),
      (479, 'difficile', 'Quelle région administrative a pour chef-lieu Bondoukou ?', 'Lôh-Djiboua', 'N''Zi', 'Gontougo', 'Cavally', 'C'),
      (480, 'difficile', 'Quelle région administrative a pour chef-lieu Divo ?', 'Sud-Comoé', 'Bounkani', 'Worodougou', 'Lôh-Djiboua', 'D'),
      (481, 'difficile', 'Quelle région administrative a pour chef-lieu Aboisso ?', 'Sud-Comoé', 'Marahoué', 'Bélier', 'Tchologo', 'A'),
      (482, 'difficile', 'Quelle région administrative a pour chef-lieu Gagnoa ?', 'Iffou', 'Gôh', 'Bafing', 'Folon', 'B'),
      (483, 'difficile', 'Quelle région administrative a pour chef-lieu Séguéla ?', 'Poro', 'Agnéby-Tiassa', 'Worodougou', 'Nawa', 'C'),
      (484, 'difficile', 'Quelle région administrative a pour chef-lieu Odienné ?', 'Moronou', 'La Mé', 'Gbôklè', 'Kabadougou', 'D'),
      (485, 'difficile', 'Quelle région administrative a pour chef-lieu Boundiali ?', 'Bagoué', 'Gontougo', 'Cavally', 'Haut-Sassandra', 'A'),
      (486, 'difficile', 'Quelle région administrative a pour chef-lieu Bouna ?', 'Nawa', 'Bounkani', 'Tonkpi', 'Mé', 'B'),
      (487, 'difficile', 'Quelle région administrative a pour chef-lieu Ferkessédougou ?', 'Gôh', 'Bélier', 'Tchologo', 'Sud-Comoé', 'C'),
      (488, 'difficile', 'Quelle région administrative a pour chef-lieu Touba ?', 'Poro', 'Gbêkê', 'Hambol', 'Bafing', 'D'),
      (489, 'difficile', 'Quelle région administrative a pour chef-lieu Dimbokro ?', 'N''Zi', 'Cavally', 'Béré', 'Folon', 'A'),
      (490, 'difficile', 'Quelle région administrative a pour chef-lieu Bongouanou ?', 'Tchologo', 'Moronou', 'San-Pédro', 'Gôh', 'B'),
      (491, 'difficile', 'Quelle région administrative a pour chef-lieu Adzopé ?', 'Kabadougou', 'Gontougo', 'La Mé', 'Iffou', 'C'),
      (492, 'difficile', 'Selon le RGPH 2021, quel ordre de grandeur correspond à la population de la Côte d''Ivoire ?', 'Moins de 5 millions', 'Environ 10 millions', 'Environ 18 millions', 'Près de 29 millions', 'D'),
      (493, 'difficile', 'Quel phénomène explique en partie la forte croissance urbaine d''Abidjan ?', 'Concentration des emplois et services', 'Climat polaire', 'Absence de ports', 'Interdiction de vivre ailleurs', 'A'),
      (494, 'difficile', 'Quel secteur urbain d''Abidjan est connu pour ses gares routières et son intense activité commerciale ?', 'Assinie', 'Adjamé', 'Korhogo', 'Daloa', 'B'),
      (495, 'difficile', 'Quelle commune d''Abidjan est souvent associée à des institutions, universités et résidences diplomatiques ?', 'Abobo', 'Treichville', 'Cocody', 'Yopougon', 'C'),
      (496, 'difficile', 'Quelle commune d''Abidjan est historiquement liée au port et à l''activité industrielle ?', 'Bingerville', 'Anyama', 'Songon', 'Treichville', 'D'),
      (497, 'difficile', 'Quel type d''habitat traditionnel est souvent associé aux villages du nord selon les zones culturelles ?', 'Cases rondes ou rectangulaires en matériaux locaux', 'Igloos', 'Chalets alpins', 'Yourtes mongoles uniquement', 'A'),
      (498, 'difficile', 'Quel masque est particulièrement associé à certaines traditions de l''ouest ivoirien ?', 'Masque vénitien', 'Masque Dan', 'Masque kabuki', 'Masque balinais', 'B'),
      (499, 'difficile', 'Quel art textile est important dans plusieurs traditions ivoiriennes, notamment chez les Akan ?', 'Calligraphie arabe uniquement', 'Origami', 'Tissage', 'Mosaïque romaine', 'C'),
      (500, 'difficile', 'Quel choix rend une question sur la Côte d''Ivoire plus fiable dans une banque de quiz ?', 'Utiliser des rumeurs virales', 'Changer les réponses selon l''humeur', 'Éviter les sources publiques', 'S''appuyer sur des faits historiques et culturels stables', 'D')
  ) as rows (
    order_index,
    difficulty,
    question_text,
    option_a,
    option_b,
    option_c,
    option_d,
    correct_answer
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
      substr(md5('cote-ivoire-histoire-culture-20260619-question-' || question_templates.order_index), 1, 8)
      || '-' ||
      substr(md5('cote-ivoire-histoire-culture-20260619-question-' || question_templates.order_index), 9, 4)
      || '-' ||
      substr(md5('cote-ivoire-histoire-culture-20260619-question-' || question_templates.order_index), 13, 4)
      || '-' ||
      substr(md5('cote-ivoire-histoire-culture-20260619-question-' || question_templates.order_index), 17, 4)
      || '-' ||
      substr(md5('cote-ivoire-histoire-culture-20260619-question-' || question_templates.order_index), 21, 12)
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
  count(*) filter (where correct_answer = 'A') as correct_a,
  count(*) filter (where correct_answer = 'B') as correct_b,
  count(*) filter (where correct_answer = 'C') as correct_c,
  count(*) filter (where correct_answer = 'D') as correct_d
from question_templates;

notify pgrst, 'reload schema';
