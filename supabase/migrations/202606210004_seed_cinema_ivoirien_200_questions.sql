-- MegaPromo - 200 questions Cinéma Ivoirien
-- A exécuter dans Supabase SQL Editor.
--
-- Objectif:
-- - créer ou mettre à jour la catégorie "Cinéma Ivoirien";
-- - créer ou mettre à jour la banque "Banque Cinéma Ivoirien";
-- - ajouter 200 questions QCM texte sur le cinéma ivoirien;
-- - répartir équitablement les bonnes réponses: 50 A, 50 B, 50 C, 50 D.

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
    'Cinéma Ivoirien',
    'Questions sur les films, réalisateurs, acteurs, séries, institutions et repères du cinéma ivoirien.',
    'movie',
    '#8B5CF6',
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
    '20260621-0000-4000-b007-000000000007'::uuid,
    'Banque Cinéma Ivoirien',
    'Questions texte sur le cinéma ivoirien: films, réalisateurs, acteurs, séries populaires, festivals, institutions, métiers et culture audiovisuelle.',
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
      (801, 'intermediaire', 'Quel film est souvent cité comme le premier film ivoirien réalisé par un Ivoirien ?', 'Sur la Dune de la Solitude', 'Titanic', 'Black Panther', 'La Haine', 'A'),
      (802, 'intermediaire', 'Qui a réalisé "Sur la Dune de la Solitude" en 1964 ?', 'Henri Duparc', 'Timité Bassori', 'Philippe Lacôte', 'Roger Gnoan M''Bala', 'B'),
      (803, 'intermediaire', 'Quel réalisateur ivoirien est associé au film "Run" ?', 'Henri Duparc', 'Désiré Écaré', 'Philippe Lacôte', 'Sidiki Bakaba', 'C'),
      (804, 'intermediaire', 'Quel réalisateur ivoirien est associé au film "Au nom du Christ" ?', 'Philippe Lacôte', 'Henri Duparc', 'Désiré Écaré', 'Roger Gnoan M''Bala', 'D'),
      (805, 'intermediaire', 'Quel film ivoirien a été réalisé par Désiré Écaré en 1985 ?', 'Visages de femmes', 'Run', 'Rue Princesse', 'Bal poussière', 'A'),
      (806, 'intermediaire', 'Quel réalisateur ivoirien est associé au film "Bal poussière" ?', 'Philippe Lacôte', 'Henri Duparc', 'A''Salfo', 'Michel Gohou', 'B'),
      (807, 'intermediaire', 'Quel film de Philippe Lacôte a été présenté dans la section Un certain regard à Cannes en 2014 ?', 'Bal poussière', 'Adanggaman', 'Run', 'Ma famille', 'C'),
      (808, 'intermediaire', 'Quel film de Philippe Lacôte est connu en français sous le titre "La Nuit des rois" ?', 'Rue Princesse', 'Ablakon', 'Visages de femmes', 'Night of the Kings', 'D'),
      (809, 'intermediaire', 'Quelle institution ivoirienne a longtemps joué un rôle important dans l''audiovisuel public ?', 'RTI', 'NASA', 'FIFA', 'UNESCO uniquement', 'A'),
      (810, 'intermediaire', 'Quelle ville est le principal centre de production audiovisuelle en Côte d''Ivoire ?', 'Korhogo', 'Abidjan', 'Man', 'Bouna', 'B'),
      (811, 'intermediaire', 'Quel réalisateur ivoirien est associé au film "Adanggaman" ?', 'Philippe Lacôte', 'Timité Bassori', 'Roger Gnoan M''Bala', 'Désiré Écaré', 'C'),
      (812, 'intermediaire', 'Quel film ivoirien est associé à Henri Duparc et à l''univers de la rue à Abidjan ?', 'Run', 'La Nuit des rois', 'Amanie', 'Rue Princesse', 'D'),
      (813, 'intermediaire', 'Quel acteur ivoirien est très connu pour ses rôles comiques au cinéma et à la télévision ?', 'Michel Gohou', 'Brad Pitt', 'Omar Sy uniquement', 'Jackie Chan', 'A'),
      (814, 'intermediaire', 'Quelle actrice ivoirienne est connue pour son rôle de Clémentine dans des productions populaires ?', 'Dobet Gnahoré', 'Clémentine Papouet', 'Josey', 'Tina Glamour', 'B'),
      (815, 'intermediaire', 'Quelle série ivoirienne créée par Akissi Delta a marqué le public ivoirien ?', 'Game of Thrones', 'Plus belle la vie', 'Ma famille', 'Friends', 'C'),
      (816, 'intermediaire', 'Quel métier dirige les acteurs et les choix artistiques d''un film ?', 'Monteur son', 'Cascadeur', 'Figurant', 'Réalisateur', 'D'),
      (817, 'intermediaire', 'Dans un film, comment appelle-t-on le texte qui organise les scènes et les dialogues ?', 'Scénario', 'Budget', 'Affiche', 'Générique seulement', 'A'),
      (818, 'intermediaire', 'Quel festival panafricain du cinéma est une référence majeure pour les films africains ?', 'Festival de Cannes uniquement', 'FESPACO', 'Eurovision', 'Coupe d''Afrique', 'B'),
      (819, 'intermediaire', 'Dans quel pays se tient le FESPACO ?', 'Côte d''Ivoire', 'Sénégal', 'Burkina Faso', 'Ghana', 'C'),
      (820, 'intermediaire', 'Quel prix prestigieux du FESPACO a été remporté par "Au nom du Christ" ?', 'Oscar du meilleur film', 'Palme d''or', 'Lion d''or', 'Étalon de Yennenga', 'D'),
      (821, 'intermediaire', 'Quel film ivoirien parle d''un personnage qui fuit après un acte politique violent ?', 'Run', 'Bal poussière', 'Ablakon', 'Rue Princesse', 'A'),
      (822, 'intermediaire', 'Quel film ivoirien de Philippe Lacôte se déroule en partie dans un univers carcéral ?', 'Bal poussière', 'La Nuit des rois', 'L''Herbe sauvage', 'Visages de femmes', 'B'),
      (823, 'intermediaire', 'Quel réalisateur ivoirien est né à Grand-Bassam et a réalisé "Au nom du Christ" ?', 'Timité Bassori', 'Henri Duparc', 'Roger Gnoan M''Bala', 'Philippe Lacôte', 'C'),
      (824, 'intermediaire', 'Quel film ivoirien de Henri Duparc est sorti en 1977 ?', 'Run', 'Adanggaman', 'La Nuit des rois', 'L''Herbe sauvage', 'D'),
      (825, 'intermediaire', 'Quel réalisateur ivoirien est associé à "Visages de femmes" ?', 'Désiré Écaré', 'Philippe Lacôte', 'Michel Gohou', 'Souleymane Koly', 'A'),
      (826, 'intermediaire', 'Quel thème revient souvent dans le cinéma ivoirien social ?', 'Science-fiction spatiale uniquement', 'Famille et société', 'Mythologie nordique', 'Western américain', 'B'),
      (827, 'intermediaire', 'Quel support a beaucoup aidé les séries ivoiriennes à toucher le public local ?', 'Radio sans images', 'Cartes postales', 'Télévision', 'Télégraphe', 'C'),
      (828, 'intermediaire', 'Quel terme désigne le choix des acteurs pour un film ?', 'Montage', 'Doublage', 'Mixage', 'Casting', 'D'),
      (829, 'intermediaire', 'Quel film d''Henri Duparc est une comédie très connue du cinéma ivoirien ?', 'Bal poussière', 'Run', 'Adanggaman', 'Koundoum', 'A'),
      (830, 'intermediaire', 'Quel acteur ivoirien est souvent associé à la comédie populaire ?', 'Isaach de Bankolé uniquement', 'Michel Gohou', 'Philippe Lacôte', 'Timité Bassori', 'B'),
      (831, 'intermediaire', 'Quel film de Roger Gnoan M''Bala traite de l''esclavage et de la violence historique ?', 'Rue Princesse', 'Bal poussière', 'Adanggaman', 'Ma famille', 'C'),
      (832, 'intermediaire', 'Quel film ivoirien de Philippe Lacôte a été sélectionné pour représenter la Côte d''Ivoire aux Oscars ?', 'L''Herbe sauvage', 'Bal poussière', 'Ma famille', 'Run', 'D'),
      (833, 'intermediaire', 'Quel élément est essentiel pour financer la production d''un film ?', 'Budget', 'Hasard', 'Rumeur', 'Silence', 'A'),
      (834, 'intermediaire', 'Comment appelle-t-on l''étape où l''on assemble les images tournées ?', 'Casting', 'Montage', 'Repérage', 'Maquillage', 'B'),
      (835, 'intermediaire', 'Quelle langue est très utilisée dans de nombreux films ivoiriens ?', 'Russe', 'Japonais', 'Français', 'Islandais', 'C'),
      (836, 'intermediaire', 'Quel type d''humour est fréquent dans les productions populaires ivoiriennes ?', 'Humour social', 'Humour muet uniquement', 'Humour mathématique', 'Humour sans acteurs', 'D'),
      (837, 'intermediaire', 'Quel quartier ou commune d''Abidjan est souvent utilisé comme décor urbain dans les fictions ?', 'Cocody', 'Paris', 'New York', 'Tokyo', 'A'),
      (838, 'intermediaire', 'Quelle actrice ivoirienne a créé la série "Ma famille" ?', 'Clémentine Papouet', 'Akissi Delta', 'Dobet Gnahoré', 'Josey', 'B'),
      (839, 'intermediaire', 'Quel acteur ivoirien est souvent associé au personnage comique de Gohou ?', 'Sidiki Bakaba', 'Henri Duparc', 'Michel Gohou', 'Désiré Écaré', 'C'),
      (840, 'intermediaire', 'Quel type d''œuvre est "Ma famille" ?', 'Long métrage historique', 'Film muet', 'Documentaire animalier', 'Série télévisée', 'D'),
      (841, 'intermediaire', 'Quel réalisateur ivoirien est associé à une œuvre satirique et sociale comme "Le Chapeau" ?', 'Roger Gnoan M''Bala', 'Philippe Lacôte', 'Meiway', 'A''Salfo', 'A'),
      (842, 'intermediaire', 'Quel film de Désiré Écaré a été restauré et redécouvert par de nouveaux publics ?', 'Run', 'Visages de femmes', 'Koundoum', 'Adanggaman', 'B'),
      (843, 'intermediaire', 'Quel domaine désigne l''ensemble des sons, dialogues et musiques d''un film ?', 'Décor', 'Costume', 'Bande sonore', 'Affiche', 'C'),
      (844, 'intermediaire', 'Quel métier s''occupe de l''image et de la lumière sur un tournage ?', 'Scénariste', 'Producteur', 'Compositeur', 'Directeur de la photographie', 'D'),
      (845, 'intermediaire', 'Quel type de film raconte des faits réels ou des témoignages ?', 'Documentaire', 'Comédie musicale seulement', 'Jeu vidéo', 'Spot météo', 'A'),
      (846, 'intermediaire', 'Quel genre cinématographique fait souvent rire le public ?', 'Drame judiciaire uniquement', 'Comédie', 'Film institutionnel', 'Journal télévisé', 'B'),
      (847, 'intermediaire', 'Quel genre cinématographique met l''accent sur les émotions et les conflits ?', 'Publicité', 'Clip musical', 'Drame', 'Tutoriel', 'C'),
      (848, 'intermediaire', 'Quel élément apparaît généralement à la fin d''un film pour citer l''équipe ?', 'Synopsis', 'Storyboard', 'Silence', 'Générique', 'D'),
      (849, 'intermediaire', 'Quel terme désigne le lieu où l''on projette un film devant un public ?', 'Salle de cinéma', 'Banque', 'Stade', 'Marché', 'A'),
      (850, 'intermediaire', 'Quel métier cherche les financements et organise la fabrication d''un film ?', 'Acteur', 'Producteur', 'Spectateur', 'Critique', 'B'),
      (851, 'intermediaire', 'Quel type d''œuvre est généralement plus court qu''un long métrage ?', 'Roman', 'Série complète', 'Court métrage', 'Album musical', 'C'),
      (852, 'intermediaire', 'Quel terme désigne l''endroit où se déroule une scène ?', 'Budget', 'Casting', 'Distribution', 'Décor', 'D'),
      (853, 'intermediaire', 'Quel réalisateur ivoirien est associé à "Ablakon" ?', 'Roger Gnoan M''Bala', 'Henri Duparc', 'Désiré Écaré', 'Philippe Lacôte', 'A'),
      (854, 'intermediaire', 'Quel film de Roger Gnoan M''Bala a obtenu une reconnaissance forte au FESPACO ?', 'Run', 'Au nom du Christ', 'Rue Princesse', 'Ma famille', 'B'),
      (855, 'intermediaire', 'Quel film de Philippe Lacôte a reçu une forte visibilité internationale en 2020 ?', 'Bal poussière', 'L''Herbe sauvage', 'La Nuit des rois', 'Sur la Dune de la Solitude', 'C'),
      (856, 'intermediaire', 'Quel acteur ivoirien international apparaît dans "Run" ?', 'Michel Gohou', 'A''Salfo', 'DJ Arafat', 'Isaach de Bankolé', 'D'),
      (857, 'intermediaire', 'Quel thème est central dans de nombreuses comédies ivoiriennes populaires ?', 'Vie familiale', 'Navigation spatiale', 'Ski alpin', 'Mythologie grecque', 'A'),
      (858, 'intermediaire', 'Quel média a contribué à rendre célèbres plusieurs acteurs ivoiriens ?', 'Télévision', 'Imprimerie uniquement', 'Radio sans image', 'Télégramme', 'B'),
      (859, 'intermediaire', 'Quel terme désigne les personnes qui jouent les rôles dans un film ?', 'Réalisateurs uniquement', 'Producteurs uniquement', 'Acteurs', 'Monteurs uniquement', 'C'),
      (860, 'intermediaire', 'Quel terme désigne une personne qui écrit l''histoire et les dialogues d''un film ?', 'Projectionniste', 'Maquilleur', 'Costumier', 'Scénariste', 'D'),
      (861, 'intermediaire', 'Quel film ivoirien est associé à la question des femmes et de leur place sociale ?', 'Visages de femmes', 'Black Panther', 'Le Parrain', 'Avatar', 'A'),
      (862, 'intermediaire', 'Quel réalisateur ivoirien est connu pour un cinéma mêlant critique sociale et récit populaire ?', 'Timité Bassori', 'Roger Gnoan M''Bala', 'Steven Spielberg', 'Christopher Nolan', 'B'),
      (863, 'intermediaire', 'Quel film ivoirien est lié à l''univers de la nuit et d''Abidjan ?', 'Amanie', 'Koundoum', 'Rue Princesse', 'Ablakon', 'C'),
      (864, 'intermediaire', 'Quel mot désigne une suite d''épisodes télévisés ?', 'Court métrage', 'Bande-annonce', 'Affiche', 'Série', 'D'),
      (865, 'intermediaire', 'Quel élément annonce un film avant sa sortie ?', 'Bande-annonce', 'Facture', 'Permis de conduire', 'Ticket de bus', 'A'),
      (866, 'intermediaire', 'Quel festival international français accueille parfois des films africains dans ses sélections ?', 'Fête de la musique', 'Festival de Cannes', 'Salon de l''auto', 'Tour de France', 'B'),
      (867, 'intermediaire', 'Quel film de Philippe Lacôte a été sélectionné à Cannes en 2014 ?', 'Visages de femmes', 'Bal poussière', 'Run', 'Ma famille', 'C'),
      (868, 'intermediaire', 'Quel film de Philippe Lacôte a été sélectionné comme entrée ivoirienne aux Oscars pour 2021 ?', 'Ablakon', 'Rue Princesse', 'Bal poussière', 'La Nuit des rois', 'D'),
      (869, 'intermediaire', 'Quel élément peut distinguer le cinéma ivoirien populaire ?', 'Usage de l''humour social', 'Absence totale de dialogues', 'Uniquement des robots', 'Uniquement des paysages polaires', 'A'),
      (870, 'intermediaire', 'Quel acteur ivoirien est souvent associé à la série "Ma famille" ?', 'Tom Cruise', 'Michel Gohou', 'Leonardo DiCaprio', 'Brad Pitt', 'B'),
      (871, 'intermediaire', 'Quelle actrice ivoirienne est connue dans "Ma famille" sous le nom de Delta ?', 'Clémentine Papouet', 'Josey', 'Akissi Delta', 'Tina Glamour', 'C'),
      (872, 'intermediaire', 'Quel élément est indispensable pour tourner une scène ?', 'Un billet d''avion uniquement', 'Une coupe sportive', 'Un bulletin météo uniquement', 'Une caméra', 'D'),
      (873, 'intermediaire', 'Quel type de personnage revient souvent dans les comédies familiales ivoiriennes ?', 'Parent ou voisin', 'Astronaute lunaire', 'Chevalier médiéval européen', 'Pirate nordique', 'A'),
      (874, 'intermediaire', 'Quel secteur regroupe cinéma, télévision et séries ?', 'Agriculture', 'Audiovisuel', 'Transport maritime', 'Banque centrale', 'B'),
      (875, 'intermediaire', 'Quel terme désigne une personne qui regarde un film ?', 'Scénariste', 'Réalisateur', 'Spectateur', 'Régisseur', 'C'),
      (876, 'intermediaire', 'Quel métier coordonne souvent les aspects pratiques d''un tournage ?', 'Compositeur', 'Acteur principal', 'Critique cinéma', 'Régisseur', 'D'),
      (877, 'intermediaire', 'Quel réalisateur ivoirien a aussi été acteur et homme de théâtre ?', 'Sidiki Bakaba', 'Philippe Lacôte', 'Akissi Delta', 'Dobet Gnahoré', 'A'),
      (878, 'intermediaire', 'Quel film ivoirien a pour réalisateur Henri Duparc ?', 'Run', 'Bal poussière', 'Adanggaman', 'Amanie', 'B'),
      (879, 'intermediaire', 'Quel film ivoirien a pour réalisateur Roger Gnoan M''Bala ?', 'Visages de femmes', 'Rue Princesse', 'Au nom du Christ', 'Run', 'C'),
      (880, 'intermediaire', 'Quel film ivoirien a pour réalisateur Philippe Lacôte ?', 'Bal poussière', 'L''Herbe sauvage', 'Adanggaman', 'La Nuit des rois', 'D'),
      (881, 'intermediaire', 'Quel nom désigne le résumé court d''un film ?', 'Synopsis', 'Générique', 'Costume', 'Projecteur', 'A'),
      (882, 'intermediaire', 'Quel métier peut créer les vêtements des personnages ?', 'Monteur', 'Costumier', 'Producteur exécutif uniquement', 'Projectionniste', 'B'),
      (883, 'intermediaire', 'Quel métier peut transformer l''apparence d''un acteur pour un rôle ?', 'Scénariste', 'Régisseur', 'Maquilleur', 'Distributeur', 'C'),
      (884, 'intermediaire', 'Quel élément aide à éclairer une scène tournée de nuit ?', 'Micro-cravate uniquement', 'Chaise de production', 'Clap', 'Projecteur', 'D'),
      (885, 'intermediaire', 'Quel accessoire marque le début d''une prise au tournage ?', 'Clap', 'Livre de maths', 'Ballon', 'Passeport', 'A'),
      (886, 'intermediaire', 'Quel métier vend ou met un film à disposition des salles et plateformes ?', 'Acteur', 'Distributeur', 'Cascadeur', 'Maquilleur', 'B'),
      (887, 'intermediaire', 'Quel terme désigne la sortie officielle d''un film devant le public ?', 'Storyboard', 'Casting', 'Première', 'Répétition', 'C'),
      (888, 'intermediaire', 'Quel support permet aujourd''hui de diffuser des films et séries en ligne ?', 'Caméra argentique seulement', 'Journal papier seulement', 'Radio AM seulement', 'Plateforme de streaming', 'D'),
      (889, 'intermediaire', 'Quel film ivoirien ancien a été réalisé en noir et blanc selon les repères historiques ?', 'Sur la Dune de la Solitude', 'Avatar', 'Titanic', 'Jurassic Park', 'A'),
      (890, 'intermediaire', 'Quel organisme ivoirien est mentionné dans l''histoire de la Société Ivoirienne du Cinéma ?', 'ONU', 'RTI', 'FIFA', 'NASA', 'B'),
      (891, 'intermediaire', 'Quel type de critique le cinéma ivoirien peut-il porter ?', 'Critique sociale', 'Critique culinaire uniquement', 'Critique astronomique uniquement', 'Critique météorologique uniquement', 'C'),
      (892, 'intermediaire', 'Quel terme désigne l''ensemble des acteurs d''un film ?', 'Montage', 'Découpage', 'Repérage', 'Distribution', 'D'),
      (893, 'intermediaire', 'Quel réalisateur ivoirien a réalisé "L''Herbe sauvage" ?', 'Henri Duparc', 'Philippe Lacôte', 'Timité Bassori', 'Désiré Écaré', 'A'),
      (894, 'intermediaire', 'Quel réalisateur ivoirien a réalisé "Visages de femmes" ?', 'Roger Gnoan M''Bala', 'Désiré Écaré', 'Michel Gohou', 'Henri Duparc', 'B'),
      (895, 'intermediaire', 'Quel réalisateur ivoirien a réalisé "Run" ?', 'Henri Duparc', 'Akissi Delta', 'Philippe Lacôte', 'Sidiki Bakaba', 'C'),
      (896, 'intermediaire', 'Quel réalisateur ivoirien a réalisé "Au nom du Christ" ?', 'Timité Bassori', 'Désiré Écaré', 'Philippe Lacôte', 'Roger Gnoan M''Bala', 'D'),
      (897, 'difficile', 'Quelle structure a été créée en 1962 dans l''histoire du cinéma ivoirien ?', 'Société Ivoirienne du Cinéma', 'Netflix Côte d''Ivoire', 'Canal Olympia uniquement', 'Académie des Oscars', 'A'),
      (898, 'difficile', 'Quelle année est associée à la création de la télévision ivoirienne selon les repères historiques ?', '1950', '1963', '1980', '2000', 'B'),
      (899, 'difficile', 'Quelle durée approximative est souvent donnée pour "Sur la Dune de la Solitude" ?', '5 minutes', '90 minutes', '32 minutes', '3 heures', 'C'),
      (900, 'difficile', 'Dans "Sur la Dune de la Solitude", quel lieu est lié à la rencontre des personnages ?', 'Désert du Sahara', 'Montagne enneigée', 'Stade de football', 'Bord de lagune', 'D'),
      (901, 'difficile', 'Quel film de Roger Gnoan M''Bala a remporté l''Étalon de Yennenga au FESPACO ?', 'Au nom du Christ', 'Run', 'Rue Princesse', 'L''Herbe sauvage', 'A'),
      (902, 'difficile', 'Quel film ivoirien a reçu le prix FIPRESCI à Cannes en 1985 ?', 'Bal poussière', 'Visages de femmes', 'La Nuit des rois', 'Ablakon', 'B'),
      (903, 'difficile', 'Quel film de Philippe Lacôte a remporté l''Amplify Voices Award au Festival de Toronto en 2020 ?', 'Rue Princesse', 'Bal poussière', 'La Nuit des rois', 'Amanie', 'C'),
      (904, 'difficile', 'Quel réalisateur ivoirien a dirigé "Killer Heat" en 2024 après ses films ivoiriens reconnus ?', 'Henri Duparc', 'Timité Bassori', 'Désiré Écaré', 'Philippe Lacôte', 'D'),
      (905, 'difficile', 'Quel film de Roger Gnoan M''Bala date de 1984 ?', 'Ablakon', 'Run', 'Ma famille', 'Rue Princesse', 'A'),
      (906, 'difficile', 'Quel film de Roger Gnoan M''Bala date de 1988 ?', 'Bal poussière', 'Bouka', 'Visages de femmes', 'La Nuit des rois', 'B'),
      (907, 'difficile', 'Quel court métrage de Roger Gnoan M''Bala est cité dans sa filmographie des années 1970 ?', 'Run', 'Rue Princesse', 'Amanie', 'Ma famille', 'C'),
      (908, 'difficile', 'Quel documentaire de Roger Gnoan M''Bala est lié à une danse traditionnelle ?', 'Ablakon', 'Visages de femmes', 'Run', 'Koundoum', 'D'),
      (909, 'difficile', 'Quel réalisateur ivoirien est associé à un cinéma de satire sociale avec "Le Chapeau" ?', 'Roger Gnoan M''Bala', 'Philippe Lacôte', 'Akissi Delta', 'Sidiki Bakaba', 'A'),
      (910, 'difficile', 'Quel film d''Henri Duparc aborde le thème du "deuxième bureau" ?', 'Run', 'L''Herbe sauvage', 'Adanggaman', 'Amanie', 'B'),
      (911, 'difficile', 'Quel film d''Henri Duparc est souvent présenté comme une comédie populaire ivoirienne ?', 'La Nuit des rois', 'Visages de femmes', 'Bal poussière', 'Run', 'C'),
      (912, 'difficile', 'Quel film d''Henri Duparc se déroule dans l''univers de la prostitution et de la nuit abidjanaise ?', 'Koundoum', 'Ablakon', 'Bouka', 'Rue Princesse', 'D'),
      (913, 'difficile', 'Quel film de Désiré Écaré met fortement en scène des femmes ivoiriennes ?', 'Visages de femmes', 'Run', 'Adanggaman', 'Rue Princesse', 'A'),
      (914, 'difficile', 'Quelle langue locale est citée parmi les langues de "Visages de femmes" ?', 'Coréen', 'Baoulé', 'Russe', 'Allemand', 'B'),
      (915, 'difficile', 'Quelle autre langue locale est citée parmi les langues de "Visages de femmes" ?', 'Japonais', 'Islandais', 'Bété', 'Italien', 'C'),
      (916, 'difficile', 'Quelle langue ouest-africaine est citée parmi les langues de "Visages de femmes" ?', 'Suédois', 'Néerlandais', 'Norvégien', 'Jula', 'D'),
      (917, 'difficile', 'Quel acteur ivoirien apparaît dans "Visages de femmes" ?', 'Sidiki Bakaba', 'DJ Arafat', 'A''Salfo', 'Meiway', 'A'),
      (918, 'difficile', 'Quel réalisateur ivoirien a aussi joué un rôle important dans le théâtre ?', 'Philippe Lacôte', 'Sidiki Bakaba', 'Timité Bassori', 'Henri Duparc', 'B'),
      (919, 'difficile', 'Quel réalisateur ivoirien est lié au documentaire et au cinéma politique contemporain ?', 'Michel Gohou', 'Clémentine Papouet', 'Philippe Lacôte', 'Désiré Écaré uniquement', 'C'),
      (920, 'difficile', 'Quel film de Philippe Lacôte a pour titre anglais "Night of the Kings" ?', 'Run', 'Bal poussière', 'Ablakon', 'La Nuit des rois', 'D'),
      (921, 'difficile', 'Quel film ivoirien est lié à la MACA dans son imaginaire narratif ?', 'La Nuit des rois', 'Visages de femmes', 'L''Herbe sauvage', 'Sur la Dune de la Solitude', 'A'),
      (922, 'difficile', 'Dans "La Nuit des rois", quel rôle la parole et le récit jouent-ils fortement ?', 'Décor seulement', 'Moteur narratif', 'Publicité', 'Silence total', 'B'),
      (923, 'difficile', 'Quel film de Philippe Lacôte a pour personnage central un homme nommé Run ?', 'Ablakon', 'Bal poussière', 'Run', 'Rue Princesse', 'C'),
      (924, 'difficile', 'Quel thème historique est central dans "Adanggaman" ?', 'Cuisine urbaine', 'Football moderne', 'Mode abidjanaise', 'Esclavage et pouvoir', 'D'),
      (925, 'difficile', 'Quel réalisateur ivoirien a travaillé pour la RTI avant de créer plusieurs films ?', 'Roger Gnoan M''Bala', 'Steven Spielberg', 'Quentin Tarantino', 'Christopher Nolan', 'A'),
      (926, 'difficile', 'Quel cinéaste ivoirien est décédé en 2023 ?', 'Henri Duparc', 'Roger Gnoan M''Bala', 'Timité Bassori uniquement', 'Philippe Lacôte', 'B'),
      (927, 'difficile', 'Quel cinéaste ivoirien est décédé en 2006 ?', 'Philippe Lacôte', 'Akissi Delta', 'Henri Duparc', 'Michel Gohou', 'C'),
      (928, 'difficile', 'Quel cinéaste ivoirien est décédé en 2009 ?', 'Sidiki Bakaba', 'Roger Gnoan M''Bala', 'Philippe Lacôte', 'Désiré Écaré', 'D'),
      (929, 'difficile', 'Quel genre est très présent dans l''œuvre populaire de Henri Duparc ?', 'Comédie sociale', 'Science-fiction spatiale', 'Horreur polaire', 'Western muet', 'A'),
      (930, 'difficile', 'Quel enjeu traverse souvent le cinéma ivoirien d''auteur ?', 'Cuisine moléculaire', 'Société et identité', 'Astronomie', 'Alpinisme', 'B'),
      (931, 'difficile', 'Quel élément est important pour conserver les films anciens ivoiriens ?', 'Oubli volontaire', 'Destruction des copies', 'Restauration', 'Absence d''archives', 'C'),
      (932, 'difficile', 'Quel terme désigne la conservation organisée des films et documents audiovisuels ?', 'Casting', 'Catering', 'Doublage', 'Archivage', 'D'),
      (933, 'difficile', 'Quel acteur ivoirien est aussi connu à l''international et apparaît dans "Run" ?', 'Isaach de Bankolé', 'Michel Gohou', 'Kerozen', 'Didi B', 'A'),
      (934, 'difficile', 'Quel type de production a permis à Akissi Delta de toucher un très large public ?', 'Court métrage muet', 'Série télévisée', 'Film d''animation japonais', 'Western américain', 'B'),
      (935, 'difficile', 'Quel personnage féminin populaire est lié au nom de Clémentine Papouet ?', 'Une astronaute', 'Une reine nordique', 'Clémentine', 'Une détective américaine', 'C'),
      (936, 'difficile', 'Quel aspect donne souvent sa force aux séries populaires ivoiriennes ?', 'Vie quotidienne reconnaissable', 'Absence de personnages', 'Langue inventée uniquement', 'Décor polaire', 'D'),
      (937, 'difficile', 'Quel métier construit parfois une continuité visuelle entre les plans ?', 'Chef opérateur', 'Banquier', 'Footballeur', 'Pharmacien', 'A'),
      (938, 'difficile', 'Quel métier peut améliorer les dialogues, sons et ambiances après le tournage ?', 'Cascadeur', 'Ingénieur du son', 'Costumier uniquement', 'Figurant', 'B'),
      (939, 'difficile', 'Quelle étape consiste à chercher les lieux avant le tournage ?', 'Montage', 'Mixage', 'Repérage', 'Projection', 'C'),
      (940, 'difficile', 'Quelle étape permet de présenter un film aux journalistes et au public ?', 'Écriture privée', 'Tournage secret', 'Archivage seul', 'Projection', 'D'),
      (941, 'difficile', 'Quel type de film peut mettre en valeur une personnalité ou un événement réel ?', 'Documentaire', 'Comédie burlesque uniquement', 'Film de super-héros américain', 'Dessin animé japonais uniquement', 'A'),
      (942, 'difficile', 'Quel terme désigne un film de fiction d''une durée importante ?', 'Court métrage', 'Long métrage', 'Clip', 'Spot radio', 'B'),
      (943, 'difficile', 'Quel terme désigne une œuvre audiovisuelle de plusieurs épisodes ?', 'Affiche', 'Bande-annonce', 'Série', 'Clap', 'C'),
      (944, 'difficile', 'Quel métier assure souvent la continuité des accessoires et raccords ?', 'Compositeur', 'Régisseur général uniquement', 'Projectionniste', 'Scripte', 'D'),
      (945, 'difficile', 'Quel élément aide à identifier immédiatement un film auprès du public ?', 'Affiche', 'Facture', 'Passeport', 'Bulletin scolaire', 'A'),
      (946, 'difficile', 'Quel terme désigne la musique composée ou choisie pour un film ?', 'Découpage', 'Bande originale', 'Catering', 'Perchman', 'B'),
      (947, 'difficile', 'Quel métier tient souvent le micro au plus près des acteurs sans entrer dans le champ ?', 'Monteur image', 'Producteur', 'Perchman', 'Étalonneur seulement', 'C'),
      (948, 'difficile', 'Quel métier ajuste les couleurs et l''aspect final de l''image ?', 'Acteur', 'Maquilleur', 'Régisseur', 'Étalonneur', 'D'),
      (949, 'difficile', 'Quel film ivoirien donne une grande place au récit oral dans un espace fermé ?', 'La Nuit des rois', 'L''Herbe sauvage', 'Rue Princesse', 'Bal poussière', 'A'),
      (950, 'difficile', 'Quel film ivoirien est une œuvre de Désiré Écaré ?', 'Run', 'Visages de femmes', 'Ablakon', 'La Nuit des rois', 'B'),
      (951, 'difficile', 'Quel film ivoirien est une œuvre de Roger Gnoan M''Bala ?', 'Run', 'Bal poussière', 'Adanggaman', 'L''Herbe sauvage', 'C'),
      (952, 'difficile', 'Quel film ivoirien est une œuvre de Henri Duparc ?', 'Run', 'Visages de femmes', 'Amanie', 'Rue Princesse', 'D'),
      (953, 'difficile', 'Quel film ivoirien est une œuvre de Philippe Lacôte ?', 'Run', 'Bal poussière', 'L''Herbe sauvage', 'Amanie', 'A'),
      (954, 'difficile', 'Quel cinéaste ivoirien est associé à "Sur la Dune de la Solitude" ?', 'Roger Gnoan M''Bala', 'Timité Bassori', 'Henri Duparc', 'Désiré Écaré', 'B'),
      (955, 'difficile', 'Quel cinéaste ivoirien est associé à "Bal poussière" ?', 'Désiré Écaré', 'Philippe Lacôte', 'Henri Duparc', 'Akissi Delta', 'C'),
      (956, 'difficile', 'Quel cinéaste ivoirien est associé à "Au nom du Christ" ?', 'Philippe Lacôte', 'Timité Bassori', 'Henri Duparc', 'Roger Gnoan M''Bala', 'D'),
      (957, 'difficile', 'Quel sujet le cinéma ivoirien populaire aborde souvent avec humour ?', 'Relations familiales', 'Physique quantique seulement', 'Navigation interstellaire', 'Ski de fond', 'A'),
      (958, 'difficile', 'Quel aspect peut distinguer une bonne comédie sociale ivoirienne ?', 'Décors sans personnages', 'Observation du quotidien', 'Absence de dialogue', 'Uniquement des effets spéciaux', 'B'),
      (959, 'difficile', 'Quel secteur bénéficie de la formation des acteurs, techniciens et scénaristes ?', 'Pêche artisanale uniquement', 'Mines uniquement', 'Audiovisuel', 'Agriculture uniquement', 'C'),
      (960, 'difficile', 'Quel élément peut aider un film ivoirien à voyager hors du pays ?', 'Festival international', 'Ticket de bus', 'Marché de légumes', 'Permis de conduire', 'D'),
      (961, 'difficile', 'Quel festival a donné une visibilité internationale à plusieurs films africains ?', 'FESPACO', 'Tour de France', 'Coupe Davis', 'Salon agricole uniquement', 'A'),
      (962, 'difficile', 'Quel festival français est associé à la Semaine de la critique et à Un certain regard ?', 'Festival d''Angoulême uniquement', 'Festival de Cannes', 'Fête du livre', 'Salon du chocolat', 'B'),
      (963, 'difficile', 'Quel prix de Cannes est associé à "Visages de femmes" selon les repères historiques ?', 'Ballon d''or', 'Oscar du son', 'Prix FIPRESCI', 'César du montage', 'C'),
      (964, 'difficile', 'Quel film ivoirien a été interdit un temps en Côte d''Ivoire avant d''être redécouvert ?', 'Run', 'La Nuit des rois', 'Bal poussière', 'Visages de femmes', 'D'),
      (965, 'difficile', 'Quel film de Roger Gnoan M''Bala est lié à une critique religieuse et sociale ?', 'Au nom du Christ', 'Run', 'Rue Princesse', 'Ma famille', 'A'),
      (966, 'difficile', 'Quel film de Philippe Lacôte est un drame lié à l''histoire politique ivoirienne récente ?', 'Bal poussière', 'Run', 'L''Herbe sauvage', 'Amanie', 'B'),
      (967, 'difficile', 'Quel film de Philippe Lacôte met en scène un prisonnier conteur ?', 'Bal poussière', 'Ablakon', 'La Nuit des rois', 'Visages de femmes', 'C'),
      (968, 'difficile', 'Quel film d''Henri Duparc est associé au quartier et à la vie nocturne abidjanaise ?', 'Amanie', 'Bouka', 'Adanggaman', 'Rue Princesse', 'D'),
      (969, 'difficile', 'Quel film d''Henri Duparc traite de polygamie et de société avec humour ?', 'Bal poussière', 'Run', 'Adanggaman', 'Ablakon', 'A'),
      (970, 'difficile', 'Quel film de Désiré Écaré a mis longtemps à être finalisé entre tournage et sortie ?', 'Run', 'Visages de femmes', 'La Nuit des rois', 'Ma famille', 'B'),
      (971, 'difficile', 'Quel cinéaste ivoirien a une œuvre souvent liée aux femmes, au village et aux tensions sociales ?', 'Philippe Lacôte', 'Henri Duparc', 'Désiré Écaré', 'Timité Bassori', 'C'),
      (972, 'difficile', 'Quel cinéaste ivoirien a une œuvre contemporaine reconnue dans de grands festivals internationaux ?', 'A''Salfo', 'Michel Gohou', 'Clémentine Papouet', 'Philippe Lacôte', 'D'),
      (973, 'difficile', 'Quel élément rend une question de cinéma plus fiable dans une banque de quiz ?', 'Fait vérifiable', 'Rumeur de quartier', 'Opinion anonyme', 'Blague privée', 'A'),
      (974, 'difficile', 'Quel type d''information faut-il éviter dans une question durable ?', 'Date stable', 'Rumeur non vérifiée', 'Titre officiel', 'Nom de réalisateur', 'B'),
      (975, 'difficile', 'Quel élément peut être vérifié dans une fiche de film ?', 'Couleur préférée du spectateur', 'Humeur du public', 'Réalisateur', 'Chance du jour', 'C'),
      (976, 'difficile', 'Quel élément peut changer selon les plateformes et doit être traité avec prudence ?', 'Titre original', 'Réalisateur', 'Année de sortie historique', 'Disponibilité en ligne', 'D'),
      (977, 'difficile', 'Quel métier travaille souvent avec le réalisateur pour préparer les plans ?', 'Directeur de la photographie', 'Caissier de cinéma', 'Spectateur', 'Critique sportif', 'A'),
      (978, 'difficile', 'Quel métier peut composer la musique d''un film ?', 'Monteur image', 'Compositeur', 'Scripte', 'Cascadeur', 'B'),
      (979, 'difficile', 'Quel métier peut organiser le calendrier et la logistique du tournage ?', 'Acteur figurant uniquement', 'Spectateur', 'Assistant réalisateur', 'Projectionniste uniquement', 'C'),
      (980, 'difficile', 'Quel métier gère souvent les objets utilisés par les acteurs ?', 'Étalonneur', 'Distributeur', 'Critique', 'Accessoiriste', 'D'),
      (981, 'difficile', 'Quel support court sert souvent à promouvoir un film ?', 'Bande-annonce', 'Reçu de paiement', 'Liste de courses', 'Permis de conduire', 'A'),
      (982, 'difficile', 'Quel document visuel peut présenter les personnages et l''ambiance d''un film ?', 'Facture', 'Affiche', 'Contrat bancaire', 'Ticket de taxi', 'B'),
      (983, 'difficile', 'Quel événement peut réunir équipe du film, public et presse ?', 'Fermeture administrative', 'Réunion sportive', 'Avant-première', 'Examen scolaire', 'C'),
      (984, 'difficile', 'Quel terme désigne la personne qui critique ou analyse les films ?', 'Régisseur', 'Costumier', 'Perchman', 'Critique cinéma', 'D'),
      (985, 'difficile', 'Quel genre audiovisuel ivoirien a beaucoup profité de la télévision ?', 'Série', 'Opéra sans image', 'Roman papier', 'Podcast muet', 'A'),
      (986, 'difficile', 'Quelle actrice-réalisatrice ivoirienne est associée à "Ma famille" ?', 'Josey', 'Akissi Delta', 'Dobet Gnahoré', 'Tina Glamour', 'B'),
      (987, 'difficile', 'Quel acteur comique ivoirien est associé à la télévision et au cinéma populaire ?', 'Timité Bassori', 'Philippe Lacôte', 'Michel Gohou', 'Henri Duparc', 'C'),
      (988, 'difficile', 'Quelle actrice ivoirienne est souvent associée à des rôles maternels et populaires ?', 'Dobet Gnahoré', 'Josey', 'Tina Glamour', 'Clémentine Papouet', 'D'),
      (989, 'difficile', 'Quel nom désigne l''industrie et l''art de créer des films ?', 'Cinéma', 'Tennis', 'Commerce maritime', 'Agronomie', 'A'),
      (990, 'difficile', 'Quel mot désigne une suite d''images donnant une impression de mouvement ?', 'Roman', 'Film', 'Statue', 'Peinture fixe uniquement', 'B'),
      (991, 'difficile', 'Quel élément permet au public de comprendre les paroles dans une autre langue ?', 'Costume', 'Éclairage', 'Sous-titres', 'Clap', 'C'),
      (992, 'difficile', 'Quel procédé remplace les voix originales par des voix dans une autre langue ?', 'Montage', 'Repérage', 'Casting', 'Doublage', 'D'),
      (993, 'difficile', 'Quel format peut convenir à une histoire courte tournée avec peu de moyens ?', 'Court métrage', 'Trilogie de dix heures', 'Journal sportif', 'Catalogue bancaire', 'A'),
      (994, 'difficile', 'Quel format convient à une histoire longue destinée aux salles ?', 'Clip de 30 secondes', 'Long métrage', 'Affiche', 'Jingle radio', 'B'),
      (995, 'difficile', 'Quel support peut diffuser un épisode de série ivoirienne aujourd''hui ?', 'Ticket papier uniquement', 'Carte routière', 'Plateforme vidéo', 'Clap de tournage', 'C'),
      (996, 'difficile', 'Quel élément rend une scène crédible dans une fiction sociale ?', 'Décor cohérent', 'Objet sans rapport', 'Acteur absent', 'Dialogue supprimé', 'D'),
      (997, 'difficile', 'Quel objectif peut avoir un film social ivoirien ?', 'Faire réfléchir le public', 'Supprimer toute émotion', 'Remplacer les écoles', 'Interdire la culture', 'A'),
      (998, 'difficile', 'Quel public le cinéma ivoirien populaire cherche souvent à toucher ?', 'Public local et africain', 'Uniquement astronautes', 'Uniquement robots', 'Uniquement alpinistes', 'B'),
      (999, 'difficile', 'Quel élément est utile pour choisir les questions d''un JCQ sur le cinéma ivoirien ?', 'Rumeurs virales', 'Opinions non sourcées', 'Repères historiques stables', 'Secrets privés', 'C'),
      (1000, 'difficile', 'Quel choix respecte mieux une banque de questions sérieuse ?', 'Inventer des faits', 'Changer les réponses au hasard', 'Copier des rumeurs', 'S''appuyer sur des faits vérifiables', 'D')
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
      substr(md5('cinema-ivoirien-20260621-question-' || question_templates.order_index), 1, 8)
      || '-' ||
      substr(md5('cinema-ivoirien-20260621-question-' || question_templates.order_index), 9, 4)
      || '-' ||
      substr(md5('cinema-ivoirien-20260621-question-' || question_templates.order_index), 13, 4)
      || '-' ||
      substr(md5('cinema-ivoirien-20260621-question-' || question_templates.order_index), 17, 4)
      || '-' ||
      substr(md5('cinema-ivoirien-20260621-question-' || question_templates.order_index), 21, 12)
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
