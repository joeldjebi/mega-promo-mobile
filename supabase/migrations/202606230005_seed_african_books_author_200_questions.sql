-- MegaPromo - 200 questions Livres africains et auteurs
-- A exécuter dans Supabase SQL Editor.
--
-- Objectif:
-- - ajouter 200 questions uniques sur des livres africains;
-- - question = un livre africain;
-- - réponse = l'auteur ou l'autrice;
-- - rattacher les questions à la Banque Philosophie, Livre et auteur;
-- - répartir les bonnes réponses: 50 A, 50 B, 50 C, 50 D;
-- - permettre une reprise propre sur la plage order_index 5001 à 5200.

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
  and order_index between 5001 and 5200;

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
      (5001, 'intermediaire', 'Quel auteur a écrit le livre africain "Le Monde s’effondre" ?', 'Chinua Achebe'),
      (5002, 'intermediaire', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "Le Monde s’effondre" ?', 'Chinua Achebe'),
      (5003, 'intermediaire', 'Quel auteur a écrit le livre africain "Le Malaise" ?', 'Chinua Achebe'),
      (5004, 'intermediaire', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "Le Malaise" ?', 'Chinua Achebe'),
      (5005, 'intermediaire', 'Quel auteur a écrit le livre africain "La Flèche de Dieu" ?', 'Chinua Achebe'),
      (5006, 'intermediaire', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "La Flèche de Dieu" ?', 'Chinua Achebe'),
      (5007, 'intermediaire', 'Quel auteur a écrit le livre africain "Le Démagogue" ?', 'Chinua Achebe'),
      (5008, 'intermediaire', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "Le Démagogue" ?', 'Chinua Achebe'),
      (5009, 'intermediaire', 'Quel auteur a écrit le livre africain "Les Termitières de la savane" ?', 'Chinua Achebe'),
      (5010, 'intermediaire', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "Les Termitières de la savane" ?', 'Chinua Achebe'),
      (5011, 'intermediaire', 'Quel auteur a écrit le livre africain "Une si longue lettre" ?', 'Mariama Bâ'),
      (5012, 'intermediaire', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "Une si longue lettre" ?', 'Mariama Bâ'),
      (5013, 'intermediaire', 'Quel auteur a écrit le livre africain "Un chant écarlate" ?', 'Mariama Bâ'),
      (5014, 'intermediaire', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "Un chant écarlate" ?', 'Mariama Bâ'),
      (5015, 'intermediaire', 'Quel auteur a écrit le livre africain "L’Enfant noir" ?', 'Camara Laye'),
      (5016, 'intermediaire', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "L’Enfant noir" ?', 'Camara Laye'),
      (5017, 'intermediaire', 'Quel auteur a écrit le livre africain "Le Regard du roi" ?', 'Camara Laye'),
      (5018, 'intermediaire', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "Le Regard du roi" ?', 'Camara Laye'),
      (5019, 'intermediaire', 'Quel auteur a écrit le livre africain "Les Soleils des indépendances" ?', 'Ahmadou Kourouma'),
      (5020, 'intermediaire', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "Les Soleils des indépendances" ?', 'Ahmadou Kourouma'),
      (5021, 'intermediaire', 'Quel auteur a écrit le livre africain "Monnè, outrages et défis" ?', 'Ahmadou Kourouma'),
      (5022, 'intermediaire', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "Monnè, outrages et défis" ?', 'Ahmadou Kourouma'),
      (5023, 'intermediaire', 'Quel auteur a écrit le livre africain "En attendant le vote des bêtes sauvages" ?', 'Ahmadou Kourouma'),
      (5024, 'intermediaire', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "En attendant le vote des bêtes sauvages" ?', 'Ahmadou Kourouma'),
      (5025, 'intermediaire', 'Quel auteur a écrit le livre africain "Allah n’est pas obligé" ?', 'Ahmadou Kourouma'),
      (5026, 'intermediaire', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "Allah n’est pas obligé" ?', 'Ahmadou Kourouma'),
      (5027, 'intermediaire', 'Quel auteur a écrit le livre africain "Quand on refuse on dit non" ?', 'Ahmadou Kourouma'),
      (5028, 'intermediaire', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "Quand on refuse on dit non" ?', 'Ahmadou Kourouma'),
      (5029, 'intermediaire', 'Quel auteur a écrit le livre africain "Le Vieux Nègre et la médaille" ?', 'Ferdinand Oyono'),
      (5030, 'intermediaire', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "Le Vieux Nègre et la médaille" ?', 'Ferdinand Oyono'),
      (5031, 'intermediaire', 'Quel auteur a écrit le livre africain "Une vie de boy" ?', 'Ferdinand Oyono'),
      (5032, 'intermediaire', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "Une vie de boy" ?', 'Ferdinand Oyono'),
      (5033, 'intermediaire', 'Quel auteur a écrit le livre africain "Chemin d’Europe" ?', 'Ferdinand Oyono'),
      (5034, 'intermediaire', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "Chemin d’Europe" ?', 'Ferdinand Oyono'),
      (5035, 'intermediaire', 'Quel auteur a écrit le livre africain "Ville cruelle" ?', 'Mongo Beti'),
      (5036, 'intermediaire', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "Ville cruelle" ?', 'Mongo Beti'),
      (5037, 'intermediaire', 'Quel auteur a écrit le livre africain "Le Pauvre Christ de Bomba" ?', 'Mongo Beti'),
      (5038, 'intermediaire', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "Le Pauvre Christ de Bomba" ?', 'Mongo Beti'),
      (5039, 'intermediaire', 'Quel auteur a écrit le livre africain "Mission terminée" ?', 'Mongo Beti'),
      (5040, 'intermediaire', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "Mission terminée" ?', 'Mongo Beti'),
      (5041, 'intermediaire', 'Quel auteur a écrit le livre africain "Remember Ruben" ?', 'Mongo Beti'),
      (5042, 'intermediaire', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "Remember Ruben" ?', 'Mongo Beti'),
      (5043, 'intermediaire', 'Quel auteur a écrit le livre africain "La Grève des bàttu" ?', 'Aminata Sow Fall'),
      (5044, 'intermediaire', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "La Grève des bàttu" ?', 'Aminata Sow Fall'),
      (5045, 'intermediaire', 'Quel auteur a écrit le livre africain "L’Appel des arènes" ?', 'Aminata Sow Fall'),
      (5046, 'intermediaire', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "L’Appel des arènes" ?', 'Aminata Sow Fall'),
      (5047, 'intermediaire', 'Quel auteur a écrit le livre africain "L’Aventure ambiguë" ?', 'Cheikh Hamidou Kane'),
      (5048, 'intermediaire', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "L’Aventure ambiguë" ?', 'Cheikh Hamidou Kane'),
      (5049, 'intermediaire', 'Quel auteur a écrit le livre africain "Les Gardiens du temple" ?', 'Cheikh Hamidou Kane'),
      (5050, 'intermediaire', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "Les Gardiens du temple" ?', 'Cheikh Hamidou Kane'),
      (5051, 'intermediaire', 'Quel auteur a écrit le livre africain "Le Devoir de violence" ?', 'Yambo Ouologuem'),
      (5052, 'intermediaire', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "Le Devoir de violence" ?', 'Yambo Ouologuem'),
      (5053, 'intermediaire', 'Quel auteur a écrit le livre africain "La Vie et demie" ?', 'Sony Labou Tansi'),
      (5054, 'intermediaire', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "La Vie et demie" ?', 'Sony Labou Tansi'),
      (5055, 'intermediaire', 'Quel auteur a écrit le livre africain "L’État honteux" ?', 'Sony Labou Tansi'),
      (5056, 'intermediaire', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "L’État honteux" ?', 'Sony Labou Tansi'),
      (5057, 'intermediaire', 'Quel auteur a écrit le livre africain "Verre cassé" ?', 'Alain Mabanckou'),
      (5058, 'intermediaire', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "Verre cassé" ?', 'Alain Mabanckou'),
      (5059, 'intermediaire', 'Quel auteur a écrit le livre africain "Mémoires de porc-épic" ?', 'Alain Mabanckou'),
      (5060, 'intermediaire', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "Mémoires de porc-épic" ?', 'Alain Mabanckou'),
      (5061, 'intermediaire', 'Quel auteur a écrit le livre africain "Petit Piment" ?', 'Alain Mabanckou'),
      (5062, 'intermediaire', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "Petit Piment" ?', 'Alain Mabanckou'),
      (5063, 'intermediaire', 'Quel auteur a écrit le livre africain "Bleu-Blanc-Rouge" ?', 'Alain Mabanckou'),
      (5064, 'intermediaire', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "Bleu-Blanc-Rouge" ?', 'Alain Mabanckou'),
      (5065, 'intermediaire', 'Quel auteur a écrit le livre africain "Demain j’aurai vingt ans" ?', 'Alain Mabanckou'),
      (5066, 'intermediaire', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "Demain j’aurai vingt ans" ?', 'Alain Mabanckou'),
      (5067, 'intermediaire', 'Quel auteur a écrit le livre africain "Murambi, le livre des ossements" ?', 'Boubacar Boris Diop'),
      (5068, 'intermediaire', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "Murambi, le livre des ossements" ?', 'Boubacar Boris Diop'),
      (5069, 'intermediaire', 'Quel auteur a écrit le livre africain "Le Cavalier et son ombre" ?', 'Boubacar Boris Diop'),
      (5070, 'intermediaire', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "Le Cavalier et son ombre" ?', 'Boubacar Boris Diop'),
      (5071, 'intermediaire', 'Quel auteur a écrit le livre africain "Kaveena" ?', 'Boubacar Boris Diop'),
      (5072, 'intermediaire', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "Kaveena" ?', 'Boubacar Boris Diop'),
      (5073, 'intermediaire', 'Quel auteur a écrit le livre africain "Les Bouts de bois de Dieu" ?', 'Ousmane Sembène'),
      (5074, 'intermediaire', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "Les Bouts de bois de Dieu" ?', 'Ousmane Sembène'),
      (5075, 'intermediaire', 'Quel auteur a écrit le livre africain "Le Docker noir" ?', 'Ousmane Sembène'),
      (5076, 'intermediaire', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "Le Docker noir" ?', 'Ousmane Sembène'),
      (5077, 'intermediaire', 'Quel auteur a écrit le livre africain "Xala" ?', 'Ousmane Sembène'),
      (5078, 'intermediaire', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "Xala" ?', 'Ousmane Sembène'),
      (5079, 'intermediaire', 'Quel auteur a écrit le livre africain "Ô pays, mon beau peuple !" ?', 'Ousmane Sembène'),
      (5080, 'intermediaire', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "Ô pays, mon beau peuple !" ?', 'Ousmane Sembène'),
      (5081, 'intermediaire', 'Quel auteur a écrit le livre africain "Le Baobab fou" ?', 'Ken Bugul'),
      (5082, 'intermediaire', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "Le Baobab fou" ?', 'Ken Bugul'),
      (5083, 'intermediaire', 'Quel auteur a écrit le livre africain "Riwan ou le chemin de sable" ?', 'Ken Bugul'),
      (5084, 'intermediaire', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "Riwan ou le chemin de sable" ?', 'Ken Bugul'),
      (5085, 'intermediaire', 'Quel auteur a écrit le livre africain "Rue Félix-Faure" ?', 'Ken Bugul'),
      (5086, 'intermediaire', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "Rue Félix-Faure" ?', 'Ken Bugul'),
      (5087, 'intermediaire', 'Quel auteur a écrit le livre africain "Notre-Dame du Nil" ?', 'Scholastique Mukasonga'),
      (5088, 'intermediaire', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "Notre-Dame du Nil" ?', 'Scholastique Mukasonga'),
      (5089, 'intermediaire', 'Quel auteur a écrit le livre africain "La Femme aux pieds nus" ?', 'Scholastique Mukasonga'),
      (5090, 'intermediaire', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "La Femme aux pieds nus" ?', 'Scholastique Mukasonga'),
      (5091, 'intermediaire', 'Quel auteur a écrit le livre africain "Inyenzi ou les Cafards" ?', 'Scholastique Mukasonga'),
      (5092, 'intermediaire', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "Inyenzi ou les Cafards" ?', 'Scholastique Mukasonga'),
      (5093, 'intermediaire', 'Quel auteur a écrit le livre africain "Petit Pays" ?', 'Gaël Faye'),
      (5094, 'intermediaire', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "Petit Pays" ?', 'Gaël Faye'),
      (5095, 'intermediaire', 'Quel auteur a écrit le livre africain "Mathématiques congolaises" ?', 'In Koli Jean Bofane'),
      (5096, 'intermediaire', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "Mathématiques congolaises" ?', 'In Koli Jean Bofane'),
      (5097, 'intermediaire', 'Quel auteur a écrit le livre africain "Congo Inc." ?', 'In Koli Jean Bofane'),
      (5098, 'intermediaire', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "Congo Inc." ?', 'In Koli Jean Bofane'),
      (5099, 'intermediaire', 'Quel auteur a écrit le livre africain "Les Honneurs perdus" ?', 'Calixthe Beyala'),
      (5100, 'intermediaire', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "Les Honneurs perdus" ?', 'Calixthe Beyala'),
      (5101, 'difficile', 'Quel auteur a écrit le livre africain "Femme nue, femme noire" ?', 'Calixthe Beyala'),
      (5102, 'difficile', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "Femme nue, femme noire" ?', 'Calixthe Beyala'),
      (5103, 'difficile', 'Quel auteur a écrit le livre africain "C’est le soleil qui m’a brûlée" ?', 'Calixthe Beyala'),
      (5104, 'difficile', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "C’est le soleil qui m’a brûlée" ?', 'Calixthe Beyala'),
      (5105, 'difficile', 'Quel auteur a écrit le livre africain "La Saison de l’ombre" ?', 'Léonora Miano'),
      (5106, 'difficile', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "La Saison de l’ombre" ?', 'Léonora Miano'),
      (5107, 'difficile', 'Quel auteur a écrit le livre africain "Contours du jour qui vient" ?', 'Léonora Miano'),
      (5108, 'difficile', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "Contours du jour qui vient" ?', 'Léonora Miano'),
      (5109, 'difficile', 'Quel auteur a écrit le livre africain "L’Intérieur de la nuit" ?', 'Léonora Miano'),
      (5110, 'difficile', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "L’Intérieur de la nuit" ?', 'Léonora Miano'),
      (5111, 'difficile', 'Quel auteur a écrit le livre africain "Crépuscule des temps anciens" ?', 'Nazi Boni'),
      (5112, 'difficile', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "Crépuscule des temps anciens" ?', 'Nazi Boni'),
      (5113, 'difficile', 'Quel auteur a écrit le livre africain "La Carte d’identité" ?', 'Jean-Marie Adiaffi'),
      (5114, 'difficile', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "La Carte d’identité" ?', 'Jean-Marie Adiaffi'),
      (5115, 'difficile', 'Quel auteur a écrit le livre africain "Les Naufragés de l’intelligence" ?', 'Jean-Marie Adiaffi'),
      (5116, 'difficile', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "Les Naufragés de l’intelligence" ?', 'Jean-Marie Adiaffi'),
      (5117, 'difficile', 'Quel auteur a écrit le livre africain "Climbié" ?', 'Bernard Dadié'),
      (5118, 'difficile', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "Climbié" ?', 'Bernard Dadié'),
      (5119, 'difficile', 'Quel auteur a écrit le livre africain "Un Nègre à Paris" ?', 'Bernard Dadié'),
      (5120, 'difficile', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "Un Nègre à Paris" ?', 'Bernard Dadié'),
      (5121, 'difficile', 'Quel auteur a écrit le livre africain "Patron de New York" ?', 'Bernard Dadié'),
      (5122, 'difficile', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "Patron de New York" ?', 'Bernard Dadié'),
      (5123, 'difficile', 'Quel auteur a écrit le livre africain "Maïmouna" ?', 'Abdoulaye Sadji'),
      (5124, 'difficile', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "Maïmouna" ?', 'Abdoulaye Sadji'),
      (5125, 'difficile', 'Quel auteur a écrit le livre africain "Nini, mulâtresse du Sénégal" ?', 'Abdoulaye Sadji'),
      (5126, 'difficile', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "Nini, mulâtresse du Sénégal" ?', 'Abdoulaye Sadji'),
      (5127, 'difficile', 'Quel auteur a écrit le livre africain "L’Ivrogne dans la brousse" ?', 'Amos Tutuola'),
      (5128, 'difficile', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "L’Ivrogne dans la brousse" ?', 'Amos Tutuola'),
      (5129, 'difficile', 'Quel auteur a écrit le livre africain "Ma vie dans la brousse des fantômes" ?', 'Amos Tutuola'),
      (5130, 'difficile', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "Ma vie dans la brousse des fantômes" ?', 'Amos Tutuola'),
      (5131, 'difficile', 'Quel auteur a écrit le livre africain "Le Pleurer-rire" ?', 'Henri Lopes'),
      (5132, 'difficile', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "Le Pleurer-rire" ?', 'Henri Lopes'),
      (5133, 'difficile', 'Quel auteur a écrit le livre africain "Tribaliques" ?', 'Henri Lopes'),
      (5134, 'difficile', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "Tribaliques" ?', 'Henri Lopes'),
      (5135, 'difficile', 'Quel auteur a écrit le livre africain "Le Lys et le Flamboyant" ?', 'Henri Lopes'),
      (5136, 'difficile', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "Le Lys et le Flamboyant" ?', 'Henri Lopes'),
      (5137, 'difficile', 'Quel auteur a écrit le livre africain "Sozaboy" ?', 'Ken Saro-Wiwa'),
      (5138, 'difficile', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "Sozaboy" ?', 'Ken Saro-Wiwa'),
      (5139, 'difficile', 'Quel auteur a écrit le livre africain "Pétales de sang" ?', 'Ngũgĩ wa Thiong’o'),
      (5140, 'difficile', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "Pétales de sang" ?', 'Ngũgĩ wa Thiong’o'),
      (5141, 'difficile', 'Quel auteur a écrit le livre africain "Un grain de blé" ?', 'Ngũgĩ wa Thiong’o'),
      (5142, 'difficile', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "Un grain de blé" ?', 'Ngũgĩ wa Thiong’o'),
      (5143, 'difficile', 'Quel auteur a écrit le livre africain "Décoloniser l’esprit" ?', 'Ngũgĩ wa Thiong’o'),
      (5144, 'difficile', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "Décoloniser l’esprit" ?', 'Ngũgĩ wa Thiong’o'),
      (5145, 'difficile', 'Quel auteur a écrit le livre africain "Devil on the Cross" ?', 'Ngũgĩ wa Thiong’o'),
      (5146, 'difficile', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "Devil on the Cross" ?', 'Ngũgĩ wa Thiong’o'),
      (5147, 'difficile', 'Quel auteur a écrit le livre africain "Weep Not, Child" ?', 'Ngũgĩ wa Thiong’o'),
      (5148, 'difficile', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "Weep Not, Child" ?', 'Ngũgĩ wa Thiong’o'),
      (5149, 'difficile', 'Quel auteur a écrit le livre africain "The River Between" ?', 'Ngũgĩ wa Thiong’o'),
      (5150, 'difficile', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "The River Between" ?', 'Ngũgĩ wa Thiong’o'),
      (5151, 'difficile', 'Quel auteur a écrit le livre africain "Wizard of the Crow" ?', 'Ngũgĩ wa Thiong’o'),
      (5152, 'difficile', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "Wizard of the Crow" ?', 'Ngũgĩ wa Thiong’o'),
      (5153, 'difficile', 'Quel auteur a écrit le livre africain "Nervous Conditions" ?', 'Tsitsi Dangarembga'),
      (5154, 'difficile', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "Nervous Conditions" ?', 'Tsitsi Dangarembga'),
      (5155, 'difficile', 'Quel auteur a écrit le livre africain "The Book of Not" ?', 'Tsitsi Dangarembga'),
      (5156, 'difficile', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "The Book of Not" ?', 'Tsitsi Dangarembga'),
      (5157, 'difficile', 'Quel auteur a écrit le livre africain "This Mournable Body" ?', 'Tsitsi Dangarembga'),
      (5158, 'difficile', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "This Mournable Body" ?', 'Tsitsi Dangarembga'),
      (5159, 'difficile', 'Quel auteur a écrit le livre africain "The House of Hunger" ?', 'Dambudzo Marechera'),
      (5160, 'difficile', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "The House of Hunger" ?', 'Dambudzo Marechera'),
      (5161, 'difficile', 'Quel auteur a écrit le livre africain "July’s People" ?', 'Nadine Gordimer'),
      (5162, 'difficile', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "July’s People" ?', 'Nadine Gordimer'),
      (5163, 'difficile', 'Quel auteur a écrit le livre africain "Burger’s Daughter" ?', 'Nadine Gordimer'),
      (5164, 'difficile', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "Burger’s Daughter" ?', 'Nadine Gordimer'),
      (5165, 'difficile', 'Quel auteur a écrit le livre africain "The Conservationist" ?', 'Nadine Gordimer'),
      (5166, 'difficile', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "The Conservationist" ?', 'Nadine Gordimer'),
      (5167, 'difficile', 'Quel auteur a écrit le livre africain "Disgrâce" ?', 'J. M. Coetzee'),
      (5168, 'difficile', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "Disgrâce" ?', 'J. M. Coetzee'),
      (5169, 'difficile', 'Quel auteur a écrit le livre africain "Vie et temps de Michael K" ?', 'J. M. Coetzee'),
      (5170, 'difficile', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "Vie et temps de Michael K" ?', 'J. M. Coetzee'),
      (5171, 'difficile', 'Quel auteur a écrit le livre africain "En attendant les barbares" ?', 'J. M. Coetzee'),
      (5172, 'difficile', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "En attendant les barbares" ?', 'J. M. Coetzee'),
      (5173, 'difficile', 'Quel auteur a écrit le livre africain "La Route de la faim" ?', 'Ben Okri'),
      (5174, 'difficile', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "La Route de la faim" ?', 'Ben Okri'),
      (5175, 'difficile', 'Quel auteur a écrit le livre africain "Songs of Enchantment" ?', 'Ben Okri'),
      (5176, 'difficile', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "Songs of Enchantment" ?', 'Ben Okri'),
      (5177, 'difficile', 'Quel auteur a écrit le livre africain "L’Hibiscus pourpre" ?', 'Chimamanda Ngozi Adichie'),
      (5178, 'difficile', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "L’Hibiscus pourpre" ?', 'Chimamanda Ngozi Adichie'),
      (5179, 'difficile', 'Quel auteur a écrit le livre africain "L’Autre Moitié du soleil" ?', 'Chimamanda Ngozi Adichie'),
      (5180, 'difficile', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "L’Autre Moitié du soleil" ?', 'Chimamanda Ngozi Adichie'),
      (5181, 'difficile', 'Quel auteur a écrit le livre africain "Americanah" ?', 'Chimamanda Ngozi Adichie'),
      (5182, 'difficile', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "Americanah" ?', 'Chimamanda Ngozi Adichie'),
      (5183, 'difficile', 'Quel auteur a écrit le livre africain "Autour de ton cou" ?', 'Chimamanda Ngozi Adichie'),
      (5184, 'difficile', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "Autour de ton cou" ?', 'Chimamanda Ngozi Adichie'),
      (5185, 'difficile', 'Quel auteur a écrit le livre africain "Il nous faut de nouveaux noms" ?', 'NoViolet Bulawayo'),
      (5186, 'difficile', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "Il nous faut de nouveaux noms" ?', 'NoViolet Bulawayo'),
      (5187, 'difficile', 'Quel auteur a écrit le livre africain "The Hairdresser of Harare" ?', 'Tendai Huchu'),
      (5188, 'difficile', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "The Hairdresser of Harare" ?', 'Tendai Huchu'),
      (5189, 'difficile', 'Quel auteur a écrit le livre africain "Maps" ?', 'Nuruddin Farah'),
      (5190, 'difficile', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "Maps" ?', 'Nuruddin Farah'),
      (5191, 'difficile', 'Quel auteur a écrit le livre africain "From a Crooked Rib" ?', 'Nuruddin Farah'),
      (5192, 'difficile', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "From a Crooked Rib" ?', 'Nuruddin Farah'),
      (5193, 'difficile', 'Quel auteur a écrit le livre africain "Links" ?', 'Nuruddin Farah'),
      (5194, 'difficile', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "Links" ?', 'Nuruddin Farah'),
      (5195, 'difficile', 'Quel auteur a écrit le livre africain "Saison de la migration vers le nord" ?', 'Tayeb Salih'),
      (5196, 'difficile', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "Saison de la migration vers le nord" ?', 'Tayeb Salih'),
      (5197, 'difficile', 'Quel auteur a écrit le livre africain "Le Mariage de Zein" ?', 'Tayeb Salih'),
      (5198, 'difficile', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "Le Mariage de Zein" ?', 'Tayeb Salih'),
      (5199, 'difficile', 'Quel auteur a écrit le livre africain "Ferdaous, une voix en enfer" ?', 'Nawal El Saadawi'),
      (5200, 'difficile', 'À quel écrivain ou écrivaine doit-on l’œuvre africaine "Ferdaous, une voix en enfer" ?', 'Nawal El Saadawi')
  ) as rows (order_index, difficulty, question_text, correct_answer)
),
distractor_authors as (
  select *
  from (
    values
      ('Abdoulaye Sadji'),
      ('Ahmadou Kourouma'),
      ('Alain Mabanckou'),
      ('Aminata Sow Fall'),
      ('Amos Tutuola'),
      ('Ben Okri'),
      ('Bernard Dadié'),
      ('Boubacar Boris Diop'),
      ('Calixthe Beyala'),
      ('Camara Laye'),
      ('Cheikh Hamidou Kane'),
      ('Chimamanda Ngozi Adichie'),
      ('Chinua Achebe'),
      ('Dambudzo Marechera'),
      ('Ferdinand Oyono'),
      ('Gaël Faye'),
      ('Henri Lopes'),
      ('In Koli Jean Bofane'),
      ('J. M. Coetzee'),
      ('Jean-Marie Adiaffi'),
      ('Ken Bugul'),
      ('Ken Saro-Wiwa'),
      ('Léonora Miano'),
      ('Mariama Bâ'),
      ('Mongo Beti'),
      ('Nadine Gordimer'),
      ('Nawal El Saadawi'),
      ('Nazi Boni'),
      ('Ngũgĩ wa Thiong’o'),
      ('NoViolet Bulawayo'),
      ('Nuruddin Farah'),
      ('Ousmane Sembène'),
      ('Scholastique Mukasonga'),
      ('Sony Labou Tansi'),
      ('Tayeb Salih'),
      ('Tendai Huchu'),
      ('Tsitsi Dangarembga'),
      ('Yambo Ouologuem')
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
      substr(md5('culture-african-books-author-20260623-question-' || question_options.order_index), 1, 8)
      || '-' || substr(md5('culture-african-books-author-20260623-question-' || question_options.order_index), 9, 4)
      || '-' || substr(md5('culture-african-books-author-20260623-question-' || question_options.order_index), 13, 4)
      || '-' || substr(md5('culture-african-books-author-20260623-question-' || question_options.order_index), 17, 4)
      || '-' || substr(md5('culture-african-books-author-20260623-question-' || question_options.order_index), 21, 12)
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
  count(distinct question_text) as unique_question_texts
from question_options;

notify pgrst, 'reload schema';
