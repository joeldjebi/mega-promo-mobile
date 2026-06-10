-- MegaPromo - Banque Côte d'Ivoire Actuelle
-- A executer dans Supabase SQL Editor apres les migrations question_banks.
--
-- Objectif:
-- - creer la categorie "Côte d'Ivoire Actuelle";
-- - creer une banque de questions liee a cette categorie;
-- - ajouter 100 questions QCM texte de niveau intermediaire et difficile.
--
-- Notes:
-- - questions concues pour un lancement en juin 2026;
-- - sujets neutres: institutions, economie, sport, geographie, culture,
--   infrastructures et vie publique;
-- - eviter les formulations partisanes ou les faits trop volatils.

alter table public.questions
add column if not exists question_type text not null default 'quiz',
add column if not exists question_bank_id uuid,
add column if not exists category_id uuid,
add column if not exists question_scope text,
add column if not exists difficulty text,
add column if not exists is_active boolean not null default true;

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
    'Questions sur la Cote d''Ivoire contemporaine: institutions, economie, sport, culture et infrastructures.',
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
    '100 questions intermediaires et difficiles sur la Cote d''Ivoire actuelle pour les JCQ et QL.',
    10,
    true,
    now(),
    now()
  )
  on conflict (name) do update set
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
question_templates as (
  select *
  from (
    values
      (1, 'intermediaire', 'Quelle ville est la capitale politique de la Cote d''Ivoire ?', 'Yamoussoukro', 'Abidjan', 'Bouake', 'San Pedro', 'A'),
      (2, 'intermediaire', 'Quelle ville est generalement consideree comme la capitale economique du pays ?', 'Abidjan', 'Yamoussoukro', 'Korhogo', 'Man', 'A'),
      (3, 'intermediaire', 'Quel est le nom officiel de la monnaie utilisee en Cote d''Ivoire ?', 'Franc CFA BCEAO', 'Naira', 'Cedi', 'Dirham', 'A'),
      (4, 'intermediaire', 'Dans quelle organisation monetaire la Cote d''Ivoire utilise-t-elle le franc CFA ?', 'UEMOA', 'CEMAC', 'SADC', 'COMESA', 'A'),
      (5, 'intermediaire', 'Quel produit agricole reste l''un des plus strategiques pour l''economie ivoirienne ?', 'Cacao', 'Riz basmati', 'The vert', 'Coton egyptien', 'A'),
      (6, 'intermediaire', 'Quelle institution encadre la filiere cafe-cacao en Cote d''Ivoire ?', 'Conseil Cafe-Cacao', 'Banque Africaine de Developpement', 'CAF', 'BRVM', 'A'),
      (7, 'intermediaire', 'Quel port est un hub majeur du commerce maritime ivoirien ?', 'Port autonome d''Abidjan', 'Port de Dakar', 'Port de Tema', 'Port de Douala', 'A'),
      (8, 'intermediaire', 'Quelle autre ville portuaire ivoirienne est connue pour l''exportation agricole et miniere ?', 'San Pedro', 'Odienne', 'Ferkessedougou', 'Daloa', 'A'),
      (9, 'intermediaire', 'Quelle institution financiere regionale a son siege a Abidjan ?', 'Banque Africaine de Developpement', 'Banque Centrale Europeenne', 'FMI', 'Banque du Canada', 'A'),
      (10, 'intermediaire', 'Quelle bourse regionale est installee a Abidjan ?', 'BRVM', 'NYSE', 'NASDAQ', 'Bourse de Casablanca', 'A'),
      (11, 'intermediaire', 'Quel pays la Cote d''Ivoire a-t-elle battu en finale de la CAN 2023 ?', 'Nigeria', 'Senegal', 'Maroc', 'Cameroun', 'A'),
      (12, 'intermediaire', 'Dans quel stade s''est jouee la finale de la CAN 2023 en Cote d''Ivoire ?', 'Stade Alassane Ouattara d''Ebimpe', 'Stade de la Paix de Bouake', 'Stade Laurent Pokou', 'Stade Charles Konan Banny', 'A'),
      (13, 'intermediaire', 'Combien de titres de CAN la Cote d''Ivoire comptait-elle apres son sacre de 2023 ?', 'Trois', 'Un', 'Deux', 'Cinq', 'A'),
      (14, 'intermediaire', 'Quelle ville a accueilli des matchs de la CAN 2023 avec le Stade de la Paix ?', 'Bouake', 'Gagnoa', 'Aboisso', 'Bondoukou', 'A'),
      (15, 'intermediaire', 'Quelle ville du nord ivoirien a accueilli des matchs de la CAN 2023 ?', 'Korhogo', 'Tabou', 'Adzope', 'Tengrela', 'A'),
      (16, 'intermediaire', 'Quelle ville balneaire et portuaire a accueilli des matchs de la CAN 2023 ?', 'San Pedro', 'Toumodi', 'Agboville', 'Dimbokro', 'A'),
      (17, 'intermediaire', 'Quel surnom des footballeurs ivoiriens est le plus connu ?', 'Les Elephants', 'Les Lions Indomptables', 'Les Aigles', 'Les Fennecs', 'A'),
      (18, 'intermediaire', 'Quel attaquant ivoirien a marque en finale de la CAN 2023 contre le Nigeria ?', 'Sebastien Haller', 'Didier Drogba', 'Yaya Toure', 'Wilfried Zaha', 'A'),
      (19, 'intermediaire', 'Quelle competition mondiale de football se joue en 2026 ?', 'Coupe du Monde FIFA', 'CAN', 'Euro', 'Copa America', 'A'),
      (20, 'intermediaire', 'Quel pays doit accueillir la CAN suivante apres la CAN 2023 ivoirienne ?', 'Maroc', 'Egypte', 'Ghana', 'Tunisie', 'A'),
      (21, 'intermediaire', 'Quel president dirige la Cote d''Ivoire en juin 2026 ?', 'Alassane Ouattara', 'Henri Konan Bedie', 'Laurent Gbagbo', 'Felix Houphouet-Boigny', 'A'),
      (22, 'intermediaire', 'Qui est Premier ministre de Cote d''Ivoire dans le gouvernement annonce en janvier 2026 ?', 'Robert Beugre Mambe', 'Patrick Achi', 'Guillaume Soro', 'Amadou Gon Coulibaly', 'A'),
      (23, 'intermediaire', 'Qui occupe la fonction de vice-president de la Republique en 2026 ?', 'Tiemoko Meyliet Kone', 'Robert Beugre Mambe', 'Yacine Idriss Diallo', 'Jean-Louis Billon', 'A'),
      (24, 'intermediaire', 'Quelle institution est la chambre basse du Parlement ivoirien ?', 'Assemblee nationale', 'Senat', 'Conseil constitutionnel', 'Cour des comptes', 'A'),
      (25, 'intermediaire', 'Quelle institution complete le Parlement ivoirien avec l''Assemblee nationale ?', 'Senat', 'CEI', 'BCEAO', 'BRVM', 'A'),
      (26, 'intermediaire', 'Quel organe organise les elections en Cote d''Ivoire ?', 'Commission Electorale Independante', 'Conseil Cafe-Cacao', 'BRVM', 'FIF', 'A'),
      (27, 'intermediaire', 'Quelle ville est associee a la basilique Notre-Dame de la Paix ?', 'Yamoussoukro', 'Abidjan', 'Grand-Bassam', 'Man', 'A'),
      (28, 'intermediaire', 'Quel site ivoirien est inscrit au patrimoine mondial de l''UNESCO pour son architecture coloniale ?', 'Ville historique de Grand-Bassam', 'Plateau d''Abidjan', 'Bouake Centre', 'Port de San Pedro', 'A'),
      (29, 'intermediaire', 'Quel parc national ivoirien est connu pour sa foret tropicale et sa biodiversite ?', 'Parc national de Tai', 'Parc Kruger', 'Serengeti', 'Parc W', 'A'),
      (30, 'intermediaire', 'Quel grand parc national se trouve au nord-est de la Cote d''Ivoire ?', 'Parc national de la Comoe', 'Parc national de Banco', 'Parc de la Pendjari', 'Parc de Mole', 'A'),
      (31, 'intermediaire', 'Quelle lagune est fortement associee a Abidjan ?', 'Lagune Ebrie', 'Lagune de Venise', 'Lac Victoria', 'Lac Tchad', 'A'),
      (32, 'intermediaire', 'Quel quartier d''Abidjan est connu comme centre administratif et d''affaires ?', 'Plateau', 'Treichville', 'Yopougon', 'Abobo', 'A'),
      (33, 'intermediaire', 'Quel quartier d''Abidjan est souvent presente comme l''une des communes les plus peuplees ?', 'Yopougon', 'Plateau', 'Cocody', 'Marcory', 'A'),
      (34, 'intermediaire', 'Quelle commune d''Abidjan abrite de nombreuses institutions et residences diplomatiques ?', 'Cocody', 'Port-Bouet', 'Koumassi', 'Anyama', 'A'),
      (35, 'intermediaire', 'Quel pont abidjanais porte le nom d''un ancien president ivoirien ?', 'Pont Henri Konan Bedie', 'Pont Nelson Mandela', 'Pont Kwame Nkrumah', 'Pont Lumumba', 'A'),
      (36, 'intermediaire', 'Quel type de projet de transport est associe a la modernisation d''Abidjan ?', 'Metro d''Abidjan', 'Train a grande vitesse Abidjan-Paris', 'Tramway sous-marin', 'Telepherique national', 'A'),
      (37, 'intermediaire', 'Quel aeroport international dessert principalement Abidjan ?', 'Aeroport Felix Houphouet-Boigny', 'Aeroport Blaise Diagne', 'Aeroport Hassan II', 'Aeroport Nnamdi Azikiwe', 'A'),
      (38, 'intermediaire', 'Quelle compagnie aerienne nationale est associee a la Cote d''Ivoire ?', 'Air Cote d''Ivoire', 'Air Senegal', 'Ethiopian Airlines', 'Royal Air Maroc', 'A'),
      (39, 'intermediaire', 'Quelle langue est la langue officielle de la Cote d''Ivoire ?', 'Francais', 'Anglais', 'Portugais', 'Arabe', 'A'),
      (40, 'intermediaire', 'Quel style musical populaire est fortement associe a la Cote d''Ivoire ?', 'Coupe-decale', 'Reggae jamaicain uniquement', 'K-pop', 'Flamenco', 'A'),
      (41, 'intermediaire', 'Quel genre musical ivoirien est lie a des groupes comme Magic System ?', 'Zouglou', 'Salsa', 'Country', 'Fado', 'A'),
      (42, 'intermediaire', 'Quel plat ivoirien est souvent servi avec poisson ou poulet et banane plantain ?', 'Alloco', 'Sushi', 'Couscous royal', 'Pad thai', 'A'),
      (43, 'intermediaire', 'Quel plat a base de semoule de manioc est tres populaire en Cote d''Ivoire ?', 'Attieke', 'Injera', 'Poutine', 'Polenta', 'A'),
      (44, 'intermediaire', 'Quel fleuve ivoirien donne son nom a une region et traverse le pays ?', 'Bandama', 'Nil', 'Congo', 'Niger', 'A'),
      (45, 'intermediaire', 'Quelle ville du centre est la deuxieme grande ville du pays par importance historique et economique ?', 'Bouake', 'Tabou', 'Bouna', 'Sikensi', 'A'),
      (46, 'intermediaire', 'Quelle ville de l''ouest est connue pour ses montagnes et son relief ?', 'Man', 'Bingerville', 'Anyama', 'Dabou', 'A'),
      (47, 'intermediaire', 'Quelle activite agricole est aussi importante dans le nord ivoirien ?', 'Coton et anacarde', 'The et riz basmati', 'Olives et lavande', 'Erable et ble', 'A'),
      (48, 'intermediaire', 'Quel produit est souvent associe au nord et a l''export agricole ivoirienne ?', 'Noix de cajou', 'Saumon', 'Diamant brut uniquement', 'Houblon', 'A'),
      (49, 'intermediaire', 'Quel organisme regional gere la politique monetaire du franc CFA BCEAO ?', 'BCEAO', 'FIFA', 'OPEP', 'OTAN', 'A'),
      (50, 'intermediaire', 'Quelle ville ivoirienne est connue pour le quartier du Plateau et le port autonome ?', 'Abidjan', 'Odienne', 'Bondoukou', 'Touba', 'A'),
      (51, 'difficile', 'Quel enjeu explique l''importance de la tracabilite dans le cacao ivoirien ?', 'Prouver l''origine durable des fèves', 'Changer la monnaie nationale', 'Remplacer le port d''Abidjan', 'Supprimer les cooperatives', 'A'),
      (52, 'difficile', 'Quel organisme est charge de reguler et stabiliser la filiere cafe-cacao ?', 'Conseil Cafe-Cacao', 'CEI', 'FIF', 'Cour supreme', 'A'),
      (53, 'difficile', 'Quelle part des exportations ivoiriennes est souvent fortement liee au cacao selon les analyses economiques recentes ?', 'Une part majeure, autour d''un tiers', 'Presque zero', 'Uniquement 2 %', 'La totalite des exportations', 'A'),
      (54, 'difficile', 'Quelle vulnerabilite economique est souvent citee pour la Cote d''Ivoire malgre sa croissance ?', 'Dependance au cacao', 'Absence totale de port', 'Absence de monnaie', 'Isolement maritime', 'A'),
      (55, 'difficile', 'Quel objectif poursuit la transformation locale du cacao ?', 'Augmenter la valeur ajoutee sur place', 'Interdire les exportations', 'Fermer les usines', 'Supprimer les planteurs', 'A'),
      (56, 'difficile', 'Quel role joue le port de San Pedro dans l''economie ivoirienne ?', 'Plateforme d''exportation agricole et miniere', 'Capitale politique', 'Siege de la BCEAO', 'Ville sans activite portuaire', 'A'),
      (57, 'difficile', 'Pourquoi Abidjan est-elle centrale pour la finance regionale ?', 'Elle abrite la BRVM et la BAD', 'Elle est la capitale de l''UEMOA', 'Elle heberge la Banque centrale europeenne', 'Elle fixe seule le prix mondial du petrole', 'A'),
      (58, 'difficile', 'Quelle organisation regroupe des pays ouest-africains utilisant le franc CFA BCEAO ?', 'UEMOA', 'Union europeenne', 'Mercosur', 'ASEAN', 'A'),
      (59, 'difficile', 'Quel secteur combine tourisme, memoire historique et patrimoine mondial a Grand-Bassam ?', 'Patrimoine culturel', 'Industrie aerospatiale', 'Extraction petroliere offshore', 'Technologie nucleaire', 'A'),
      (60, 'difficile', 'Quel parc ivoirien est classe UNESCO et represente une grande zone de foret humide ouest-africaine ?', 'Tai', 'Banco uniquement', 'Kruger', 'Etosha', 'A'),
      (61, 'difficile', 'Quel parc national ivoirien figure parmi les grandes aires protegees d''Afrique de l''Ouest ?', 'Comoe', 'Serengeti', 'Virunga seulement', 'Masai Mara', 'A'),
      (62, 'difficile', 'Quel defi environnemental touche directement le secteur cacao ivoirien ?', 'Deforestation et vieillissement des plantations', 'Fonte des glaciers', 'Cyclones polaires', 'Desertification totale d''Abidjan', 'A'),
      (63, 'difficile', 'Quelle logique explique les cartes/producteurs et QR codes dans la filiere cacao ?', 'Mieux tracer les parcelles et les lots', 'Vendre des billets de CAN', 'Remplacer les titres de transport', 'Creer une monnaie locale', 'A'),
      (64, 'difficile', 'Quelle ville ivoirienne est associee au stade Charles Konan Banny de la CAN 2023 ?', 'Yamoussoukro', 'Korhogo', 'San Pedro', 'Abidjan', 'A'),
      (65, 'difficile', 'Quel stade de Korhogo a accueilli des matchs de la CAN 2023 ?', 'Stade Amadou Gon Coulibaly', 'Stade Laurent Pokou', 'Stade Felix Houphouet-Boigny', 'Stade Robert Champroux', 'A'),
      (66, 'difficile', 'Quel stade de San Pedro a accueilli des matchs de la CAN 2023 ?', 'Stade Laurent Pokou', 'Stade de la Paix', 'Stade Amadou Gon Coulibaly', 'Stade Charles Konan Banny', 'A'),
      (67, 'difficile', 'Quel selectionneur a conduit les Elephants au titre de la CAN 2023 apres un changement en cours de competition ?', 'Emerse Fae', 'Herve Renard', 'Jean-Louis Gasset', 'Didier Deschamps', 'A'),
      (68, 'difficile', 'Quel score a donne la victoire ivoirienne face au Nigeria en finale de la CAN 2023 ?', '2-1', '1-0', '3-0', '0-0 puis tirs au but', 'A'),
      (69, 'difficile', 'Quel joueur ivoirien a egalise en finale de la CAN 2023 avant le but de Haller ?', 'Franck Kessie', 'Simon Adingra', 'Max Gradel', 'Serge Aurier', 'A'),
      (70, 'difficile', 'Quel joueur ivoirien a ete elu meilleur jeune joueur de la CAN 2023 ?', 'Simon Adingra', 'Sebastien Haller', 'Jean-Michael Seri', 'Odilon Kossounou', 'A'),
      (71, 'difficile', 'Quel pays a transmis le drapeau de la CAN au Maroc apres l''edition ivoirienne ?', 'Cote d''Ivoire', 'Nigeria', 'Senegal', 'Egypte', 'A'),
      (72, 'difficile', 'Quel enjeu de soft power la CAN 2023 a-t-elle represente pour la Cote d''Ivoire ?', 'Vitrine d''infrastructures et d''image nationale', 'Remplacement du Parlement', 'Creation d''une nouvelle monnaie', 'Annulation des exportations', 'A'),
      (73, 'difficile', 'Quelle institution ivoirienne valide les resultats definitifs des elections presidentielles ?', 'Conseil constitutionnel', 'BRVM', 'BCEAO', 'Conseil Cafe-Cacao', 'A'),
      (74, 'difficile', 'Dans le systeme institutionnel ivoirien, qui nomme le Premier ministre ?', 'President de la Republique', 'BRVM', 'CAF', 'BCEAO', 'A'),
      (75, 'difficile', 'Quelle revision constitutionnelle a renforce l''existence d''un Senat en Cote d''Ivoire ?', 'Constitution de 2016', 'Accord de Bretton Woods', 'Traite de Rome', 'Traite de Versailles', 'A'),
      (76, 'difficile', 'Quelle ville abrite officiellement la capitale politique mais pas le principal centre economique ?', 'Yamoussoukro', 'Abidjan', 'San Pedro', 'Bouake', 'A'),
      (77, 'difficile', 'Quel facteur explique le poids demographique d''Abidjan dans le pays ?', 'Concentration des emplois, services et infrastructures', 'Absence de port', 'Interdiction de s''installer ailleurs', 'Climat polaire', 'A'),
      (78, 'difficile', 'Pourquoi le Metro d''Abidjan est-il considere comme strategique ?', 'Reduire la congestion et structurer la mobilite urbaine', 'Remplacer les elections', 'Transporter uniquement du cacao', 'Fermer les ponts', 'A'),
      (79, 'difficile', 'Quel axe urbain d''Abidjan concentre de nombreux flux entre communes populaires et centre-ville ?', 'Nord-sud et est-ouest metropolitain', 'Transsaharien uniquement', 'Atlantique-Europe', 'Bouake-Man uniquement', 'A'),
      (80, 'difficile', 'Quel role joue l''aeroport Felix Houphouet-Boigny pour le pays ?', 'Porte internationale principale', 'Port cacaoyer', 'Siege du Parlement', 'Frontiere terrestre nord', 'A'),
      (81, 'difficile', 'Quel lien existe entre mobile money et vie quotidienne ivoirienne ?', 'Paiements et transferts rapides', 'Remplacement complet des banques centrales', 'Fin des reseaux mobiles', 'Transport maritime', 'A'),
      (82, 'difficile', 'Quel service public numerique est important pour moderniser l''administration ?', 'Demarches et identite en ligne', 'Vote obligatoire sur reseaux sociaux', 'Suppression de toutes les mairies', 'Passeport uniquement papier a vie', 'A'),
      (83, 'difficile', 'Quelle ville ivoirienne est un grand pole universitaire et administratif proche d''Abidjan historique ?', 'Bingerville', 'Tabou', 'Bouna', 'Toulepleu', 'A'),
      (84, 'difficile', 'Quel element rend la lagune Ebrie importante pour Abidjan ?', 'Elle structure la geographie urbaine et les transports', 'Elle se trouve au Sahara', 'Elle remplace le port de San Pedro', 'Elle est une montagne', 'A'),
      (85, 'difficile', 'Quelle commune d''Abidjan est associee a l''aeroport international ?', 'Port-Bouet', 'Plateau', 'Cocody', 'Yopougon', 'A'),
      (86, 'difficile', 'Quelle ville ivoirienne est connue pour etre proche du Ghana et pour son patrimoine frontalier/commercial ?', 'Aboisso', 'Man', 'Odienne', 'Seguela', 'A'),
      (87, 'difficile', 'Quel groupe de produits illustre la diversification agricole ivoirienne ?', 'Anacarde, hevea, palmier a huile', 'Neige, charbon polaire, saumon', 'Ble arctique, houblon, erable', 'Uranium lunaire, the vert, lavande', 'A'),
      (88, 'difficile', 'Quel secteur industriel est lie a la raffinerie et aux produits petroliers a Abidjan ?', 'Energie et hydrocarbures', 'Mode uniquement', 'Cinema uniquement', 'Peche artisanale seulement', 'A'),
      (89, 'difficile', 'Pourquoi la zone industrielle de Yopougon est-elle importante ?', 'Elle concentre des activites manufacturieres', 'Elle abrite la capitale politique', 'Elle est un parc national', 'Elle est une ile inhabitee', 'A'),
      (90, 'difficile', 'Quel enjeu accompagne l''urbanisation rapide d''Abidjan ?', 'Logement, transport et services urbains', 'Disparition totale du commerce', 'Fin des communes', 'Absence de population', 'A'),
      (91, 'difficile', 'Quel role jouent les communes d''Abobo et Yopougon dans l''agglomeration abidjanaise ?', 'Forts bassins de population et de mobilite', 'Zones desertes sans habitants', 'Capitales de pays voisins', 'Ports miniers uniquement', 'A'),
      (92, 'difficile', 'Quel evenement a renforce la visibilite internationale de la Cote d''Ivoire en 2024 ?', 'Organisation et victoire a la CAN 2023', 'Jeux olympiques d''hiver', 'Coupe du monde de cricket', 'Euro de football', 'A'),
      (93, 'difficile', 'Quel joueur ivoirien est souvent cite parmi les figures historiques des Elephants malgre sa retraite ?', 'Didier Drogba', 'Samuel Eto''o', 'Sadio Mane', 'Mohamed Salah', 'A'),
      (94, 'difficile', 'Quel ancien milieu ivoirien est associe a Manchester City et au FC Barcelone ?', 'Yaya Toure', 'Michael Essien', 'Jay-Jay Okocha', 'Nwankwo Kanu', 'A'),
      (95, 'difficile', 'Quelle industrie culturelle ivoirienne a gagne une audience regionale avec les danses urbaines ?', 'Coupe-decale', 'Opera italien', 'Tango argentin', 'Country americaine', 'A'),
      (96, 'difficile', 'Quel terme designe souvent l''ambiance populaire d''Abidjan dans la musique et la nuit ?', 'Ambiance maquis', 'Silence polaire', 'Carnaval de Rio uniquement', 'Feria espagnole', 'A'),
      (97, 'difficile', 'Pourquoi l''attieke est-il important dans le quotidien ivoirien ?', 'C''est un aliment populaire a base de manioc', 'C''est une monnaie', 'C''est un pont', 'C''est un stade', 'A'),
      (98, 'difficile', 'Quel duo de notions resume un defi majeur pour le pays en 2026 ?', 'Croissance et inclusion sociale', 'Isolement et absence de commerce', 'Hiver et neige', 'Disparition des villes', 'A'),
      (99, 'difficile', 'Quel indicateur social reste surveille malgre la croissance economique ?', 'Pauvrete et cout de la vie', 'Nombre de glaciers', 'Taux de neige', 'Nombre de volcans actifs a Abidjan', 'A'),
      (100, 'difficile', 'Quel choix rend une question d''actualite plus durable dans une banque MegaPromo ?', 'Se baser sur des faits publics stables', 'Se baser sur des rumeurs', 'Utiliser des insultes politiques', 'Changer la bonne reponse au hasard', 'A')
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
      substr(md5('cote-ivoire-actuelle-20260608-question-' || question_templates.order_index), 1, 8)
      || '-' ||
      substr(md5('cote-ivoire-actuelle-20260608-question-' || question_templates.order_index), 9, 4)
      || '-' ||
      substr(md5('cote-ivoire-actuelle-20260608-question-' || question_templates.order_index), 13, 4)
      || '-' ||
      substr(md5('cote-ivoire-actuelle-20260608-question-' || question_templates.order_index), 17, 4)
      || '-' ||
      substr(md5('cote-ivoire-actuelle-20260608-question-' || question_templates.order_index), 21, 12)
    )::uuid,
    null,
    bank_seed.id,
    category_seed.id,
    'bank',
    'quiz',
    question_templates.question_text,
    question_templates.option_a,
    question_templates.option_b,
    question_templates.option_c,
    question_templates.option_d,
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
  (select count(*) from category_seed) as categories_ready,
  (select count(*) from bank_seed) as banks_ready,
  (select count(*) from bank_category_seed) as bank_category_links_inserted,
  (select count(*) from question_seed) as questions_upserted;

notify pgrst, 'reload schema';
