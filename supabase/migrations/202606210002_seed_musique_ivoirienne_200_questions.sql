-- MegaPromo - 200 questions Musique ivoirienne
-- A exécuter dans Supabase SQL Editor.
--
-- Objectif:
-- - créer ou mettre à jour la catégorie "Musique";
-- - créer ou mettre à jour la banque "Banque Musique";
-- - ajouter 200 questions QCM texte sur la musique ivoirienne;
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
    'Musique',
    'Questions sur les genres, artistes, danses, chansons et patrimoines de la musique ivoirienne.',
    'music',
    '#EC4899',
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
    '20260621-0000-4000-b006-000000000006'::uuid,
    'Banque Musique',
    'Questions texte sur la musique ivoirienne: zouglou, coupé-décalé, reggae, zoblazo, ziglibithy, traditions, artistes et culture populaire.',
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
      (601, 'intermediaire', 'Quel genre musical ivoirien est né dans les milieux étudiants au début des années 1990 ?', 'Zouglou', 'Salsa', 'Flamenco', 'Country', 'A'),
      (602, 'intermediaire', 'Quel genre musical ivoirien est surtout associé aux concepts de danse et à l''ambiance des années 2000 ?', 'Makossa', 'Coupé-décalé', 'Blues', 'Tango', 'B'),
      (603, 'intermediaire', 'Quel artiste ivoirien est fortement associé au zoblazo ?', 'Alpha Blondy', 'DJ Arafat', 'Meiway', 'Tiken Jah Fakoly', 'C'),
      (604, 'intermediaire', 'Quel artiste ivoirien est considéré comme une grande figure du ziglibithy ?', 'A''Salfo', 'Josey', 'Bebi Philip', 'Ernesto Djédjé', 'D'),
      (605, 'intermediaire', 'Quel groupe ivoirien a popularisé la chanson "Premier Gaou" ?', 'Magic System', 'P-Square', 'Toofan', 'X-Maleya', 'A'),
      (606, 'intermediaire', 'Quel artiste ivoirien est une figure majeure du reggae africain ?', 'Meiway', 'Alpha Blondy', 'DJ Mix Premier', 'Kerozen', 'B'),
      (607, 'intermediaire', 'Quel chanteur ivoirien est connu pour son reggae engagé et ses textes politiques ?', 'Yodé', 'Pat Sako', 'Tiken Jah Fakoly', 'Serge Beynaud', 'C'),
      (608, 'intermediaire', 'Quel artiste est souvent surnommé le roi du coupé-décalé ?', 'Serges Kassy', 'Dobet Gnahoré', 'Ismaël Isaac', 'DJ Arafat', 'D'),
      (609, 'intermediaire', 'Quel mouvement musical ivoirien utilise souvent l''humour pour parler des réalités sociales ?', 'Zouglou', 'Jazz manouche', 'Opéra', 'Fado', 'A'),
      (610, 'intermediaire', 'Quel style ivoirien Meiway a-t-il contribué à faire connaître ?', 'Mapouka', 'Zoblazo', 'Gospel américain', 'Highlife ghanéen', 'B'),
      (611, 'intermediaire', 'Quel genre est lié à des artistes comme Douk Saga, DJ Arafat et Serge Beynaud ?', 'Ziglibithy', 'Reggae roots', 'Coupé-décalé', 'Musique classique', 'C'),
      (612, 'intermediaire', 'Quel genre musical ivoirien est associé à la danse mapouka ?', 'Zouglou', 'Zoblazo', 'Rock ivoire', 'Mapouka', 'D'),
      (613, 'intermediaire', 'Dans la musique ivoirienne, quel artiste est le leader vocal de Magic System ?', 'A''Salfo', 'Meiway', 'Debordo Leekunfa', 'Kiff No Beat', 'A'),
      (614, 'intermediaire', 'Quel festival musical est fortement associé à Magic System et à A''Salfo ?', 'MASA', 'FEMUA', 'FESPACO', 'Jazz à Vienne', 'B'),
      (615, 'intermediaire', 'Quel artiste ivoirien a marqué le coupé-décalé avec le surnom "Yôrôbô" ?', 'Kerozen', 'Didi B', 'DJ Arafat', 'Suspect 95', 'C'),
      (616, 'intermediaire', 'Quel mot désigne souvent les bars-restaurants populaires où la musique ivoirienne anime les soirées ?', 'Opéras', 'Studios', 'Conservatoires', 'Maquis', 'D'),
      (617, 'intermediaire', 'Quel langage urbain est souvent utilisé dans le rap ivoire et le coupé-décalé ?', 'Nouchi', 'Latin', 'Grec ancien', 'Esperanto', 'A'),
      (618, 'intermediaire', 'Quel courant musical ivoirien a souvent porté la critique sociale dans les années 1990 ?', 'Disco', 'Zouglou', 'Valse', 'Polka', 'B'),
      (619, 'intermediaire', 'Quelle ville est le principal foyer urbain de la scène musicale moderne ivoirienne ?', 'Man', 'Bouna', 'Abidjan', 'Odienné', 'C'),
      (620, 'intermediaire', 'Quel genre ivoirien est souvent lié aux "concepts" lancés par les DJ ?', 'Gospel', 'Zoblazo', 'Ziglibithy', 'Coupé-décalé', 'D'),
      (621, 'intermediaire', 'Quel artiste est associé au titre "Sweet Fanta Diallo" ?', 'Alpha Blondy', 'DJ Arafat', 'Meiway', 'Bebi Philip', 'A'),
      (622, 'intermediaire', 'Quel artiste ivoirien est associé au titre "Plus rien ne m''étonne" ?', 'A''Salfo', 'Tiken Jah Fakoly', 'Kerozen', 'Dobet Gnahoré', 'B'),
      (623, 'intermediaire', 'Quel groupe ivoirien est composé notamment d''A''Salfo, Manadja, Tino et Goudé ?', 'Kiff No Beat', 'Les Patrons', 'Magic System', 'Espoir 2000', 'C'),
      (624, 'intermediaire', 'Quel artiste ivoirien est associé au zoblazo et au titre "200% Zoblazo" ?', 'Tiken Jah Fakoly', 'Alpha Blondy', 'DJ Arafat', 'Meiway', 'D'),
      (625, 'intermediaire', 'Quel genre ivoirien est porté par des groupes comme Les Garagistes et Espoir 2000 ?', 'Zouglou', 'Techno', 'Samba', 'Raï', 'A'),
      (626, 'intermediaire', 'Quel duo zouglou est connu pour ses chansons humoristiques et sociales ?', 'Toofan', 'Yodé et Siro', 'P-Square', 'Daft Punk', 'B'),
      (627, 'intermediaire', 'Quel groupe ivoirien est associé à la chanson "Abidjan farot" ?', 'Magic System', 'Les Patrons', 'Espoir 2000', 'Les Salopards', 'C'),
      (628, 'intermediaire', 'Quel artiste du coupé-décalé était surnommé "Président de la Jet Set" ?', 'Bebi Philip', 'Debordo Leekunfa', 'Kédjévara', 'Douk Saga', 'D'),
      (629, 'intermediaire', 'Quel genre ivoirien est souvent présenté comme une musique de revendication joyeuse ?', 'Zouglou', 'Métal symphonique', 'Boléro', 'Bluegrass', 'A'),
      (630, 'intermediaire', 'Quel style traditionnel ivoirien est associé à Allah Thérèse ?', 'Coupé-décalé', 'Agbirô', 'Trap', 'Salsa', 'B'),
      (631, 'intermediaire', 'Quel instrument est fréquemment utilisé dans les musiques traditionnelles mandingues ?', 'Synthétiseur uniquement', 'Guitare électrique uniquement', 'Kora', 'Orgue d''église uniquement', 'C'),
      (632, 'intermediaire', 'Quel instrument de percussion est très présent dans les fêtes et danses africaines, y compris en Côte d''Ivoire ?', 'Clavecin', 'Harpe classique', 'Violon baroque', 'Djembé', 'D'),
      (633, 'intermediaire', 'Quel peuple du nord ivoirien est souvent associé à des traditions musicales et initiatiques comme le Poro ?', 'Sénoufo', 'Inuit', 'Basque', 'Maori', 'A'),
      (634, 'intermediaire', 'Quelle famille culturelle du centre ivoirien est souvent associée aux chants et rythmes baoulé ?', 'Touareg', 'Akan', 'Maya', 'Viking', 'B'),
      (635, 'intermediaire', 'Quel genre est le plus lié aux artistes Alpha Blondy et Tiken Jah Fakoly ?', 'Coupé-décalé', 'Zoblazo', 'Reggae', 'Mapouka', 'C'),
      (636, 'intermediaire', 'Quel artiste ivoirien est connu pour le style zoblazo et pour des chorégraphies populaires ?', 'A''Salfo', 'Didi B', 'Ismaël Isaac', 'Meiway', 'D'),
      (637, 'intermediaire', 'Quel artiste ivoirien est associé au reggae et au titre "Brigadier Sabari" ?', 'Alpha Blondy', 'Serge Beynaud', 'DJ Lewis', 'Claire Bahi', 'A'),
      (638, 'intermediaire', 'Quel artiste ivoirien est surnommé "le Daïshi" ?', 'A''Salfo', 'DJ Arafat', 'Meiway', 'Ernesto Djédjé', 'B'),
      (639, 'intermediaire', 'Quel genre musical ivoirien a popularisé les notions de "travaillement" et de "farot" ?', 'Zouglou', 'Gospel', 'Coupé-décalé', 'Zoblazo', 'C'),
      (640, 'intermediaire', 'Quel terme est souvent utilisé pour désigner une danse ou une tendance lancée dans le coupé-décalé ?', 'Symphonie', 'Partition', 'Sonate', 'Concept', 'D'),
      (641, 'intermediaire', 'Quel groupe zouglou a popularisé "Premier Gaou" avant de connaître un succès international ?', 'Magic System', 'Les Wailers', 'Kassav''', 'Coldplay', 'A'),
      (642, 'intermediaire', 'Quel artiste est associé au style tradi-moderne baoulé ?', 'DJ Arafat', 'Adeba Konan', 'Bob Marley', 'Fally Ipupa', 'B'),
      (643, 'intermediaire', 'Quel genre musical ivoirien est le plus directement lié à Ernesto Djédjé ?', 'Zouglou', 'Coupé-décalé', 'Ziglibithy', 'Rap ivoire', 'C'),
      (644, 'intermediaire', 'Quel espace culturel d''Abidjan accueille souvent de grands concerts ivoiriens ?', 'Tour Eiffel', 'Colisée', 'Madison Square Garden', 'Palais de la Culture', 'D'),
      (645, 'intermediaire', 'Quel artiste ivoirien est connu pour le titre "Sagacité" ?', 'Douk Saga', 'Meiway', 'Tiken Jah Fakoly', 'Josey', 'A'),
      (646, 'intermediaire', 'Quel artiste du coupé-décalé est aussi arrangeur et producteur connu sous le nom "Bebi Philip" ?', 'A''Salfo', 'Bebi Philip', 'Ismaël Isaac', 'Yodé', 'B'),
      (647, 'intermediaire', 'Quel chanteur ivoirien est souvent lié au reggae avec le surnom "Gangaba de Treichville" ?', 'Didi B', 'Kerozen', 'Ismaël Isaac', 'DJ Mix Premier', 'C'),
      (648, 'intermediaire', 'Quel artiste ivoirien est associé à la chanson "Okeninkpin" ?', 'Meiway', 'Alpha Blondy', 'A''Salfo', 'Dobet Gnahoré', 'D'),
      (649, 'intermediaire', 'Quel genre ivoirien a souvent mis en avant la vie quotidienne des jeunes à Abidjan ?', 'Zouglou', 'Flamenco', 'Bossa nova', 'Country', 'A'),
      (650, 'intermediaire', 'Quel courant musical ivoirien est lié aux DJs, aux boîtes de nuit et aux chorégraphies virales ?', 'Musique baroque', 'Coupé-décalé', 'Opéra lyrique', 'Fado', 'B'),
      (651, 'intermediaire', 'Quel artiste ivoirien est associé à la chanson "Côcô" dans le coupé-décalé ?', 'A''Salfo', 'Alpha Blondy', 'Serge Beynaud', 'Yodé', 'C'),
      (652, 'intermediaire', 'Quelle chanteuse ivoirienne est connue pour des titres de variété et d''afro-zouk comme "Diplôme" ?', 'Allah Thérèse', 'Tina Glamour', 'Chantal Taïba', 'Josey', 'D'),
      (653, 'intermediaire', 'Quel artiste ivoirien est connu comme membre du groupe Magic System ?', 'A''Salfo', 'DJ Kedjevara', 'Debordo Leekunfa', 'Didi B', 'A'),
      (654, 'intermediaire', 'Quel artiste ivoirien est associé à la génération rap ivoire avec le groupe Kiff No Beat ?', 'Meiway', 'Didi B', 'Alpha Blondy', 'Allah Thérèse', 'B'),
      (655, 'intermediaire', 'Quel groupe ivoirien a contribué à populariser le rap ivoire auprès du grand public ?', 'Espoir 2000', 'Les Patrons', 'Kiff No Beat', 'Magic System', 'C'),
      (656, 'intermediaire', 'Quel style musical mélange souvent rap, nouchi et réalités urbaines ivoiriennes ?', 'Agbirô', 'Ziglibithy', 'Valse', 'Rap ivoire', 'D'),
      (657, 'intermediaire', 'Quel artiste est fortement lié à la modernisation du reggae ivoirien ?', 'Alpha Blondy', 'DJ Lewis', 'Meiway', 'Serge Beynaud', 'A'),
      (658, 'intermediaire', 'Quelle musique ivoirienne est souvent chantée en français, en nouchi et parfois en langues locales ?', 'Country américaine', 'Zouglou', 'Fado portugais', 'Polka', 'B'),
      (659, 'intermediaire', 'Quel chanteur zouglou fait partie du duo Yodé et Siro ?', 'DJ Arafat', 'Meiway', 'Yodé', 'Tiken Jah Fakoly', 'C'),
      (660, 'intermediaire', 'Quel chanteur zouglou fait partie du duo Yodé et Siro ?', 'A''Salfo', 'Bebi Philip', 'Kerozen', 'Siro', 'D'),
      (661, 'intermediaire', 'Quel artiste ivoirien est connu pour des chansons de motivation comme "Le Temps" ?', 'Kerozen', 'Douk Saga', 'Ernesto Djédjé', 'Ismaël Isaac', 'A'),
      (662, 'intermediaire', 'Quel artiste du coupé-décalé est connu pour son style de danse et de show scénique ?', 'Alpha Blondy', 'Serge Beynaud', 'Meiway', 'Dobet Gnahoré', 'B'),
      (663, 'intermediaire', 'Quel genre ivoirien a souvent des refrains collectifs et des chœurs très participatifs ?', 'Trap américaine uniquement', 'Techno minimale', 'Zouglou', 'Salsa cubaine', 'C'),
      (664, 'intermediaire', 'Quel artiste ivoirien est connu pour le titre "Mon pays" en reggae ?', 'DJ Arafat', 'Josey', 'A''Salfo', 'Tiken Jah Fakoly', 'D'),
      (665, 'intermediaire', 'Quel artiste ivoirien est associé à "Jerusalem" et au reggae africain ?', 'Alpha Blondy', 'Bebi Philip', 'Debordo Leekunfa', 'Didi B', 'A'),
      (666, 'intermediaire', 'Quel terme désigne souvent les fans de DJ Arafat ?', 'Gaous', 'Chinois', 'Zouglous', 'Akans', 'B'),
      (667, 'intermediaire', 'Quel genre ivoirien a popularisé les danses comme "Bobaraba" et plusieurs concepts festifs ?', 'Reggae roots', 'Ziglibithy', 'Coupé-décalé', 'Agbirô', 'C'),
      (668, 'intermediaire', 'Quel artiste est lié au titre "Bobaraba" ?', 'Didi B', 'A''Salfo', 'Tiken Jah Fakoly', 'DJ Mix Premier', 'D'),
      (669, 'intermediaire', 'Quel genre est souvent joué dans les maquis pour faire danser le public ?', 'Coupé-décalé', 'Opéra italien', 'Chant grégorien', 'Musique de chambre', 'A'),
      (670, 'intermediaire', 'Quel style musical est né avant le coupé-décalé et a fortement marqué la parole sociale ivoirienne ?', 'K-pop', 'Zouglou', 'Rock progressif', 'Boléro', 'B'),
      (671, 'intermediaire', 'Quel artiste ivoirien est une référence féminine de la scène afro-pop et variété ?', 'Douk Saga', 'Ernesto Djédjé', 'Josey', 'DJ Lewis', 'C'),
      (672, 'intermediaire', 'Quel artiste ivoirien est connu pour sa voix dans le reggae et des chansons spirituelles ?', 'Serge Beynaud', 'Debordo Leekunfa', 'Kiff No Beat', 'Ismaël Isaac', 'D'),
      (673, 'intermediaire', 'Quel artiste ivoirien a créé ou popularisé fortement le ziglibithy moderne ?', 'Ernesto Djédjé', 'A''Salfo', 'DJ Arafat', 'Josey', 'A'),
      (674, 'intermediaire', 'Quel groupe zouglou est associé à des titres comme "Gloire à Dieu" et "Sida dans la cité" ?', 'Kiff No Beat', 'Les Garagistes', 'Coldplay', 'P-Square', 'B'),
      (675, 'intermediaire', 'Quel groupe zouglou est connu pour son humour et ses observations sociales ?', 'Daft Punk', 'Toofan', 'Espoir 2000', 'Metallica', 'C'),
      (676, 'intermediaire', 'Quel artiste ivoirien est associé au titre "Faut pas fâcher" ?', 'Alpha Blondy', 'Dobet Gnahoré', 'Bebi Philip', 'Kerozen', 'D'),
      (677, 'intermediaire', 'Quel genre musical ivoirien est souvent lié aux cérémonies, villages et traditions locales ?', 'Musique traditionnelle', 'Techno berlinoise', 'Disco américaine', 'Ska jamaïcain', 'A'),
      (678, 'intermediaire', 'Quel style associe des rythmes traditionnels ivoiriens à des instruments modernes ?', 'Hard rock', 'Tradi-moderne', 'Reggaeton', 'Fado', 'B'),
      (679, 'intermediaire', 'Quel instrument à lames sonores est utilisé dans plusieurs musiques mandingues et ouest-africaines ?', 'Violon', 'Trompette', 'Balafon', 'Saxophone uniquement', 'C'),
      (680, 'intermediaire', 'Quelle famille de rythmes est souvent portée par les tambours dans les fêtes traditionnelles ?', 'Cordes pincées seulement', 'Claviers classiques', 'Cuivres militaires', 'Percussions', 'D'),
      (681, 'intermediaire', 'Quel chanteur ivoirien est connu pour son style reggae et son engagement panafricain ?', 'Tiken Jah Fakoly', 'Meiway', 'Debordo Leekunfa', 'Kédjévara', 'A'),
      (682, 'intermediaire', 'Quel artiste ivoirien est célèbre pour le zoblazo et le surnom "Le professeur Awôlôwô" ?', 'DJ Arafat', 'Meiway', 'Didi B', 'Yodé', 'B'),
      (683, 'intermediaire', 'Quel genre musical ivoirien est souvent lié à des groupes comme Les Salopards et Les Patrons ?', 'Gospel', 'Coupé-décalé', 'Zouglou', 'Reggae', 'C'),
      (684, 'intermediaire', 'Quel artiste ivoirien est la mère de DJ Arafat et une chanteuse connue ?', 'Josey', 'Dobet Gnahoré', 'Chantal Taïba', 'Tina Glamour', 'D'),
      (685, 'intermediaire', 'Quel artiste ivoirien est connu pour le style coupé-décalé et le titre "Tchintchin" ?', 'Debordo Leekunfa', 'Alpha Blondy', 'Meiway', 'A''Salfo', 'A'),
      (686, 'intermediaire', 'Quel artiste ivoirien est associé au coupé-décalé et au titre "Apéritif Yamoukidi" ?', 'Yodé', 'DJ Arafat', 'Dobet Gnahoré', 'Ernesto Djédjé', 'B'),
      (687, 'intermediaire', 'Quel artiste ivoirien est connu dans le rap ivoire avec le collectif Kiff No Beat ?', 'Meiway', 'Ismaël Isaac', 'Elow''n', 'Alpha Blondy', 'C'),
      (688, 'intermediaire', 'Quel artiste ivoirien est connu dans le rap ivoire avec le collectif Kiff No Beat ?', 'Yodé', 'Siro', 'Allah Thérèse', 'Black K', 'D'),
      (689, 'intermediaire', 'Quel genre musical ivoirien fait souvent appel à des slogans et expressions populaires ?', 'Coupé-décalé', 'Musique classique', 'Chant lyrique', 'Bossa nova', 'A'),
      (690, 'intermediaire', 'Quel style ivoirien est très lié aux campus, aux quartiers et aux sujets de société ?', 'Salsa', 'Zouglou', 'Techno', 'Country', 'B'),
      (691, 'intermediaire', 'Quelle chanteuse ivoirienne est reconnue sur la scène world music internationale ?', 'Claire Bahi', 'Tina Glamour', 'Dobet Gnahoré', 'Josey uniquement', 'C'),
      (692, 'intermediaire', 'Quel artiste ivoirien est connu pour des chansons comme "Mousso" et une forte présence afro-pop ?', 'Yodé', 'Siro', 'DJ Lewis', 'Josey', 'D'),
      (693, 'intermediaire', 'Quel terme qualifie souvent une chanson qui devient rapidement une danse populaire ?', 'Concept', 'Sonate', 'Symphonie', 'Aria', 'A'),
      (694, 'intermediaire', 'Quel style musical ivoirien a fait connaître des pas de danse très codifiés dans les années 2000 ?', 'Blues', 'Coupé-décalé', 'Musette', 'Folk irlandais', 'B'),
      (695, 'intermediaire', 'Quel artiste du coupé-décalé est aussi appelé "Opah la nation" ?', 'A''Salfo', 'Meiway', 'Serge Beynaud', 'Alpha Blondy', 'C'),
      (696, 'intermediaire', 'Quel artiste du coupé-décalé est lié au nom "Yoro Gang" ?', 'Douk Saga', 'Bebi Philip', 'Kerozen', 'DJ Arafat', 'D'),
      (697, 'intermediaire', 'Quel groupe ivoirien a contribué à faire voyager le zouglou hors de Côte d''Ivoire ?', 'Magic System', 'The Beatles', 'P-Square', 'Kassav'' uniquement', 'A'),
      (698, 'intermediaire', 'Quel genre musical ivoirien est associé au duo Yodé et Siro ?', 'Reggaeton', 'Zouglou', 'Opéra', 'Afro-trap uniquement', 'B'),
      (699, 'intermediaire', 'Quel artiste ivoirien est connu pour le titre "Miss Lolo" ?', 'DJ Arafat', 'Tiken Jah Fakoly', 'Meiway', 'Kiff No Beat', 'C'),
      (700, 'intermediaire', 'Quel artiste ivoirien est connu pour le titre "Coupé Bibamba" ?', 'Kerozen', 'Didi B', 'Josey', 'Meiway', 'D'),
      (701, 'difficile', 'Quel genre ivoirien est souvent analysé comme une chronique chantée de la société ?', 'Zouglou', 'Trap américaine', 'Samba brésilienne', 'Chant grégorien', 'A'),
      (702, 'difficile', 'Quel courant musical ivoirien a émergé dans la diaspora ivoirienne avant de se diffuser à Abidjan ?', 'Gospel', 'Coupé-décalé', 'Jazz bebop', 'Highlife', 'B'),
      (703, 'difficile', 'Quel artiste est associé au style ziglibithy, mélangeant tradition bété et modernité ?', 'Alpha Blondy', 'A''Salfo', 'Ernesto Djédjé', 'DJ Arafat', 'C'),
      (704, 'difficile', 'Quel style de Meiway mélange rythmes traditionnels, cuivres, danse et modernité ?', 'Rap ivoire', 'Zouglou', 'Reggae', 'Zoblazo', 'D'),
      (705, 'difficile', 'Quel mot désigne souvent les chansons religieuses chrétiennes populaires en Côte d''Ivoire ?', 'Gospel', 'Zoblazo', 'Coupé-décalé', 'Ziglibithy', 'A'),
      (706, 'difficile', 'Quel artiste ivoirien est associé à la chanson "Amen" dans la musique de motivation ?', 'Meiway', 'Kerozen', 'DJ Arafat', 'Ernesto Djédjé', 'B'),
      (707, 'difficile', 'Quel groupe ivoirien est fortement associé au festival FEMUA ?', 'Kiff No Beat', 'Espoir 2000', 'Magic System', 'Les Patrons', 'C'),
      (708, 'difficile', 'Quel artiste ivoirien a souvent porté un discours panafricain dans ses chansons reggae ?', 'Serge Beynaud', 'Bebi Philip', 'Debordo Leekunfa', 'Tiken Jah Fakoly', 'D'),
      (709, 'difficile', 'Quelle langue urbaine donne une couleur locale à beaucoup de chansons populaires ivoiriennes ?', 'Nouchi', 'Allemand', 'Japonais', 'Russe', 'A'),
      (710, 'difficile', 'Quel genre ivoirien est né dans un contexte de fête, de danse et de démonstration sociale ?', 'Zouglou', 'Coupé-décalé', 'Agbirô', 'Ziglibithy', 'B'),
      (711, 'difficile', 'Quel artiste est associé à la chanson reggae "Multipartisme" ?', 'Meiway', 'Douk Saga', 'Alpha Blondy', 'Didi B', 'C'),
      (712, 'difficile', 'Quel artiste ivoirien est associé au titre "Mangercratie" ?', 'DJ Arafat', 'A''Salfo', 'Josey', 'Tiken Jah Fakoly', 'D'),
      (713, 'difficile', 'Quel groupe a contribué à faire du zouglou un produit d''exportation avec "Premier Gaou" ?', 'Magic System', 'Kiff No Beat', 'P-Square', 'Toofan', 'A'),
      (714, 'difficile', 'Quel style musical est rattaché à la grande chanteuse traditionnelle Allah Thérèse ?', 'Reggaeton', 'Agbirô', 'Rap ivoire', 'Disco', 'B'),
      (715, 'difficile', 'Quel artiste est souvent cité comme pionnier du zoblazo ?', 'A''Salfo', 'DJ Arafat', 'Meiway', 'Yodé', 'C'),
      (716, 'difficile', 'Quel artiste a fortement marqué le coupé-décalé avec une succession de surnoms et de concepts ?', 'Ernesto Djédjé', 'Alpha Blondy', 'Ismaël Isaac', 'DJ Arafat', 'D'),
      (717, 'difficile', 'Quel style musical est souvent rattaché aux danses de village modernisées pour la scène ?', 'Tradi-moderne', 'Techno', 'Valse', 'Fado', 'A'),
      (718, 'difficile', 'Quel artiste ivoirien est lié au style zoblazo et à la ville de Grand-Bassam ?', 'DJ Arafat', 'Meiway', 'Tiken Jah Fakoly', 'Didi B', 'B'),
      (719, 'difficile', 'Quel type de chant est central dans beaucoup de musiques traditionnelles ivoiriennes ?', 'Autotune uniquement', 'Silence instrumental', 'Chant responsorial', 'Rap allemand', 'C'),
      (720, 'difficile', 'Quel élément accompagne souvent les danses traditionnelles ivoiriennes ?', 'Clavecin seul', 'Sitar seul', 'Harpe celtique seule', 'Tambours', 'D'),
      (721, 'difficile', 'Quel artiste ivoirien a popularisé "Zoropoto" dans le coupé-décalé ?', 'DJ Arafat', 'Meiway', 'Alpha Blondy', 'Yodé', 'A'),
      (722, 'difficile', 'Quel artiste ivoirien est associé au titre "Kababléké" ?', 'A''Salfo', 'DJ Arafat', 'Josey', 'Dobet Gnahoré', 'B'),
      (723, 'difficile', 'Quel artiste du coupé-décalé est associé au titre "Tchintchin" ?', 'Tiken Jah Fakoly', 'A''Salfo', 'Debordo Leekunfa', 'Meiway', 'C'),
      (724, 'difficile', 'Quel artiste ivoirien est associé à "Ma rivale" dans la variété moderne ?', 'Siro', 'Yodé', 'DJ Lewis', 'Josey', 'D'),
      (725, 'difficile', 'Quel courant musical ivoirien se distingue souvent par des textes de campus et de quartier ?', 'Zouglou', 'House music', 'Boléro', 'Musette', 'A'),
      (726, 'difficile', 'Quel mouvement musical a popularisé la figure du DJ chanteur en Côte d''Ivoire ?', 'Reggae roots', 'Coupé-décalé', 'Ziglibithy', 'Folk', 'B'),
      (727, 'difficile', 'Quel artiste ivoirien est souvent associé à des chansons de motivation et d''espoir ?', 'DJ Arafat', 'Meiway', 'Kerozen', 'Tiken Jah Fakoly', 'C'),
      (728, 'difficile', 'Quel artiste ivoirien est associé au titre "Golgotha" comme album de zoblazo ?', 'Didi B', 'A''Salfo', 'DJ Lewis', 'Meiway', 'D'),
      (729, 'difficile', 'Quel groupe a marqué le zouglou avec des titres de critique sociale comme "Tableau blanc" ?', 'Yodé et Siro', 'P-Square', 'Daft Punk', 'Toofan', 'A'),
      (730, 'difficile', 'Quel artiste ivoirien est associé à la musique bété-dida et aux chants traditionnels religieux ?', 'Josey', 'Hortense Zatto', 'Bebi Philip', 'Didi B', 'B'),
      (731, 'difficile', 'Quel style peut être décrit comme un pont entre patrimoine local et arrangements modernes ?', 'Opéra italien', 'Country', 'Tradi-moderne', 'Disco', 'C'),
      (732, 'difficile', 'Quel artiste ivoirien est associé au surnom "Daïshikan" ?', 'A''Salfo', 'Kerozen', 'Ernesto Djédjé', 'DJ Arafat', 'D'),
      (733, 'difficile', 'Quel genre ivoirien utilise souvent des slogans comme "on est ensemble" dans une logique festive ?', 'Coupé-décalé', 'Musique classique', 'Tango', 'Bluegrass', 'A'),
      (734, 'difficile', 'Quel artiste ivoirien a popularisé un reggae chanté en français, anglais et langues africaines ?', 'Debordo Leekunfa', 'Alpha Blondy', 'Bebi Philip', 'Claire Bahi', 'B'),
      (735, 'difficile', 'Quel chanteur est connu comme membre du duo zouglou Yodé et Siro ?', 'Didi B', 'Meiway', 'Siro', 'DJ Mix Premier', 'C'),
      (736, 'difficile', 'Quel chanteur est connu comme membre du duo zouglou Yodé et Siro ?', 'Tiken Jah Fakoly', 'Serge Beynaud', 'A''Salfo', 'Yodé', 'D'),
      (737, 'difficile', 'Quel mouvement musical ivoirien a souvent raconté la galère, l''espoir et la débrouillardise ?', 'Zouglou', 'Valse', 'Chant baroque', 'Ska', 'A'),
      (738, 'difficile', 'Quelle artiste ivoirienne représente fortement la variété afro-pop contemporaine ?', 'Douk Saga', 'Josey', 'Ernesto Djédjé', 'Alpha Blondy', 'B'),
      (739, 'difficile', 'Quel artiste ivoirien est une figure du rap ivoire et membre de Kiff No Beat ?', 'Meiway', 'Tiken Jah Fakoly', 'Didi B', 'Allah Thérèse', 'C'),
      (740, 'difficile', 'Quel artiste ivoirien est une figure du rap ivoire et membre de Kiff No Beat ?', 'Alpha Blondy', 'Josey', 'A''Salfo', 'Joochar', 'D'),
      (741, 'difficile', 'Quel genre ivoirien est souvent accompagné de chorégraphies lancées par les artistes eux-mêmes ?', 'Coupé-décalé', 'Reggae roots', 'Chant lyrique', 'Jazz vocal', 'A'),
      (742, 'difficile', 'Quelle artiste ivoirienne est connue pour une voix puissante dans l''afro-pop ivoirienne ?', 'Ernesto Djédjé', 'Josey', 'Siro', 'Meiway', 'B'),
      (743, 'difficile', 'Quel style musical est associé à des pas comme "Grippe aviaire" ou "Kpangor" dans la culture populaire ?', 'Zouglou', 'Gospel', 'Coupé-décalé', 'Zoblazo', 'C'),
      (744, 'difficile', 'Quel artiste ivoirien est connu pour le titre "Kpangor" ?', 'Alpha Blondy', 'A''Salfo', 'Dobet Gnahoré', 'DJ Arafat', 'D'),
      (745, 'difficile', 'Quel genre musical ivoirien a souvent des textes racontant l''université, la rue et la politique ?', 'Zouglou', 'House', 'Fado', 'Samba', 'A'),
      (746, 'difficile', 'Quel artiste ivoirien est une figure féminine du coupé-décalé ?', 'Dobet Gnahoré', 'Claire Bahi', 'Allah Thérèse', 'Hortense Zatto', 'B'),
      (747, 'difficile', 'Quel artiste ivoirien a une carrière internationale dans les musiques du monde et a remporté un Grammy Award ?', 'Josey', 'Tina Glamour', 'Dobet Gnahoré', 'Claire Bahi', 'C'),
      (748, 'difficile', 'Quel genre est généralement associé à Dobet Gnahoré ?', 'Coupé-décalé pur', 'Zoblazo pur', 'Techno minimale', 'World music', 'D'),
      (749, 'difficile', 'Quel artiste ivoirien est associé au reggae et à la chanson "Journalistes en danger" ?', 'Alpha Blondy', 'Serge Beynaud', 'Bebi Philip', 'Kiff No Beat', 'A'),
      (750, 'difficile', 'Quel artiste ivoirien a popularisé un reggae engagé avec "Quitte le pouvoir" ?', 'Meiway', 'Tiken Jah Fakoly', 'DJ Lewis', 'Josey', 'B'),
      (751, 'difficile', 'Quelle scène est souvent considérée comme le cœur médiatique et musical moderne de la Côte d''Ivoire ?', 'Odienné', 'Touba', 'Abidjan', 'Tabou', 'C'),
      (752, 'difficile', 'Quel terme renvoie à l''art de donner de l''argent pour montrer sa réussite dans le coupé-décalé ?', 'Polyphonie', 'Improvisation', 'Solmisation', 'Travaillement', 'D'),
      (753, 'difficile', 'Quel artiste est une figure centrale de la "Jet Set" ivoirienne ?', 'Douk Saga', 'Ernesto Djédjé', 'Dobet Gnahoré', 'Hortense Zatto', 'A'),
      (754, 'difficile', 'Quel artiste est souvent associé à l''énergie scénique du coupé-décalé ?', 'Meiway', 'DJ Arafat', 'Alpha Blondy', 'Didi B', 'B'),
      (755, 'difficile', 'Quel artiste est souvent associé au titre "Tapis vélo" ?', 'Yodé', 'Josey', 'DJ Arafat', 'Tiken Jah Fakoly', 'C'),
      (756, 'difficile', 'Quel artiste ivoirien est associé au coupé-décalé moderne et à des chorégraphies populaires ?', 'A''Salfo', 'Kerozen', 'Siro', 'Serge Beynaud', 'D'),
      (757, 'difficile', 'Quel genre musical ivoirien se danse souvent avec des gestes démonstratifs et des codes de prestige ?', 'Coupé-décalé', 'Gospel choral', 'Musique militaire', 'Chant lyrique', 'A'),
      (758, 'difficile', 'Quel artiste ivoirien a popularisé des chansons zouglou avec le groupe Magic System ?', 'DJ Arafat', 'A''Salfo', 'Kerozen', 'Meiway', 'B'),
      (759, 'difficile', 'Quel style ivoirien est associé à la phrase "ça fait rire mais ça dit vrai" dans l''esprit populaire ?', 'Coupé-décalé', 'Trap', 'Zouglou', 'Zoblazo', 'C'),
      (760, 'difficile', 'Quel artiste ivoirien a contribué à faire rayonner le reggae africain depuis Abidjan ?', 'Bebi Philip', 'Debordo Leekunfa', 'Didi B', 'Alpha Blondy', 'D'),
      (761, 'difficile', 'Quel genre ivoirien a souvent une structure d''appel-réponse entre chanteur et chœurs ?', 'Musique traditionnelle', 'Rock progressif', 'Synthwave', 'Chant grégorien', 'A'),
      (762, 'difficile', 'Quel instrument africain est souvent fait de lames de bois accordées ?', 'Violon', 'Balafon', 'Trombone', 'Accordéon', 'B'),
      (763, 'difficile', 'Quel instrument à cordes est associé à la tradition mandingue ?', 'Saxophone', 'Batterie électronique', 'Kora', 'Piano droit', 'C'),
      (764, 'difficile', 'Quel élément est central dans les prestations de masques et danses de l''ouest ivoirien ?', 'Silence total', 'Lecture seule', 'Cinéma muet', 'Percussions', 'D'),
      (765, 'difficile', 'Quel artiste ivoirien est associé au titre "Zoblazo" dans plusieurs versions ?', 'Meiway', 'Tiken Jah Fakoly', 'DJ Arafat', 'Didi B', 'A'),
      (766, 'difficile', 'Quel artiste ivoirien est associé à la chanson "Brigadier Sabari" ?', 'Serge Beynaud', 'Alpha Blondy', 'Kerozen', 'Josey', 'B'),
      (767, 'difficile', 'Quel artiste ivoirien est associé au titre "Plus rien ne m''étonne" ?', 'Meiway', 'Didi B', 'Tiken Jah Fakoly', 'A''Salfo', 'C'),
      (768, 'difficile', 'Quel artiste ivoirien est associé à "Premier Gaou" comme chanteur principal de Magic System ?', 'DJ Arafat', 'Alpha Blondy', 'Yodé', 'A''Salfo', 'D'),
      (769, 'difficile', 'Quel genre musical ivoirien utilise souvent la satire pour commenter l''actualité ?', 'Zouglou', 'Salsa', 'Bluegrass', 'K-pop', 'A'),
      (770, 'difficile', 'Quel genre ivoirien a souvent mis en avant l''ambiance parisienne de la diaspora ivoirienne ?', 'Agbirô', 'Coupé-décalé', 'Ziglibithy', 'Reggae', 'B'),
      (771, 'difficile', 'Quel artiste ivoirien est associé à la chanson "Drogba" dans la culture coupé-décalé ?', 'Meiway', 'Josey', 'DJ Arafat', 'Alpha Blondy', 'C'),
      (772, 'difficile', 'Quel artiste ivoirien est souvent associé à des chansons populaires de motivation ?', 'A''Salfo', 'Siro', 'Didi B', 'Kerozen', 'D'),
      (773, 'difficile', 'Quel courant musical ivoirien est souvent relié à la jeunesse universitaire des années 1990 ?', 'Zouglou', 'Country', 'Fado', 'Punk britannique', 'A'),
      (774, 'difficile', 'Quel artiste ivoirien est connu pour l''album "Jah Glory" ?', 'Meiway', 'Alpha Blondy', 'Serge Beynaud', 'DJ Lewis', 'B'),
      (775, 'difficile', 'Quel artiste ivoirien est connu pour l''album "Francafrique" ?', 'DJ Arafat', 'Dobet Gnahoré', 'Tiken Jah Fakoly', 'Josey', 'C'),
      (776, 'difficile', 'Quel artiste ivoirien est associé à l''album "M20" ?', 'Didi B', 'A''Salfo', 'Debordo Leekunfa', 'Meiway', 'D'),
      (777, 'difficile', 'Quel style est très lié à la danse, aux tenues et au show dans la musique ivoirienne moderne ?', 'Coupé-décalé', 'Chant grégorien', 'Valse viennoise', 'Opéra', 'A'),
      (778, 'difficile', 'Quel style de musique ivoirienne est très utilisé pour sensibiliser tout en divertissant ?', 'Techno', 'Zouglou', 'Tango', 'Disco européenne', 'B'),
      (779, 'difficile', 'Quel artiste ivoirien est associé au titre "Logobitombo" ?', 'Meiway', 'A''Salfo', 'DJ Arafat', 'Tiken Jah Fakoly', 'C'),
      (780, 'difficile', 'Quelle artiste ivoirienne est associée à la variété contemporaine et à l''afro-pop ?', 'Siro', 'Meiway', 'Alpha Blondy', 'Josey', 'D'),
      (781, 'difficile', 'Quel groupe ivoirien est associé au zouglou et à un fort succès international ?', 'Magic System', 'P-Square', 'Toofan', 'X-Maleya', 'A'),
      (782, 'difficile', 'Quel artiste ivoirien est souvent associé au surnom "Le fils de Dieu" dans le coupé-décalé ?', 'Alpha Blondy', 'Bebi Philip', 'A''Salfo', 'Meiway', 'B'),
      (783, 'difficile', 'Quel artiste ivoirien est associé au titre "La go là" ?', 'Dobet Gnahoré', 'Meiway', 'Kiff No Beat', 'Allah Thérèse', 'C'),
      (784, 'difficile', 'Quel artiste ivoirien est reconnu pour un reggae engagé dépassant les frontières ivoiriennes ?', 'Yodé', 'Siro', 'Ernesto Djédjé', 'Tiken Jah Fakoly', 'D'),
      (785, 'difficile', 'Quel genre musical ivoirien est souvent lié aux fêtes de quartier et aux maquis ?', 'Coupé-décalé', 'Opéra', 'Musique de chambre', 'Flamenco', 'A'),
      (786, 'difficile', 'Quel genre musical ivoirien est souvent lié aux universités, aux cités et aux paroles sociales ?', 'Techno', 'Zouglou', 'Boléro', 'Country', 'B'),
      (787, 'difficile', 'Quel style musical ivoirien s''appuie fortement sur la figure du DJ et de l''animateur ?', 'Reggae', 'Agbirô', 'Coupé-décalé', 'Zoblazo', 'C'),
      (788, 'difficile', 'Quel genre musical ivoirien a été porté à l''international par Meiway ?', 'Zouglou', 'Coupé-décalé', 'Reggae', 'Zoblazo', 'D'),
      (789, 'difficile', 'Quel artiste ivoirien est associé à "Black Samouraï" dans le reggae ?', 'Alpha Blondy', 'DJ Arafat', 'Kerozen', 'Josey', 'A'),
      (790, 'difficile', 'Quelle artiste ivoirienne est associée à des chansons sentimentales et afro-pop ?', 'Meiway', 'Josey', 'Douk Saga', 'Ernesto Djédjé', 'B'),
      (791, 'difficile', 'Quel groupe ivoirien est associé au rap ivoire et à des carrières solos comme celle de Didi B ?', 'Magic System', 'Les Patrons', 'Kiff No Beat', 'Espoir 2000', 'C'),
      (792, 'difficile', 'Quel style musical est représenté par des artistes ivoiriens comme Didi B, Suspect 95 et Elow''n ?', 'Zoblazo', 'Reggae roots', 'Agbirô', 'Rap ivoire', 'D'),
      (793, 'difficile', 'Quel artiste ivoirien est connu dans le rap pour son humour et son personnage de "président du syndicat" ?', 'Suspect 95', 'Meiway', 'Allah Thérèse', 'Ismaël Isaac', 'A'),
      (794, 'difficile', 'Quel artiste ivoirien est associé à la tradition baoulé et à la musique agbirô ?', 'Tiken Jah Fakoly', 'Allah Thérèse', 'DJ Arafat', 'Kiff No Beat', 'B'),
      (795, 'difficile', 'Quel artiste ivoirien est connu comme chanteur de reggae et surnommé "le blondy" par son nom de scène ?', 'Didi B', 'Kerozen', 'Alpha Blondy', 'Bebi Philip', 'C'),
      (796, 'difficile', 'Quel genre ivoirien moderne est le plus associé à DJ Arafat, Serge Beynaud et Debordo Leekunfa ?', 'Zouglou', 'Reggae', 'Zoblazo', 'Coupé-décalé', 'D'),
      (797, 'difficile', 'Quel genre musical est souvent lié à la spiritualité chrétienne en Côte d''Ivoire ?', 'Gospel', 'Ziglibithy', 'Samba', 'House', 'A'),
      (798, 'difficile', 'Quel genre musical ivoirien met souvent en avant des messages sociaux dans une ambiance populaire ?', 'Jazz bebop', 'Zouglou', 'Musique classique', 'Disco', 'B'),
      (799, 'difficile', 'Quel artiste ivoirien est connu pour avoir donné une identité forte au zoblazo ?', 'DJ Arafat', 'A''Salfo', 'Meiway', 'Yodé', 'C'),
      (800, 'difficile', 'Quel genre ivoirien est le plus associé à la "Jet Set" et à Douk Saga ?', 'Reggae', 'Zouglou', 'Gospel', 'Coupé-décalé', 'D')
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
      substr(md5('musique-ivoirienne-20260621-question-' || question_templates.order_index), 1, 8)
      || '-' ||
      substr(md5('musique-ivoirienne-20260621-question-' || question_templates.order_index), 9, 4)
      || '-' ||
      substr(md5('musique-ivoirienne-20260621-question-' || question_templates.order_index), 13, 4)
      || '-' ||
      substr(md5('musique-ivoirienne-20260621-question-' || question_templates.order_index), 17, 4)
      || '-' ||
      substr(md5('musique-ivoirienne-20260621-question-' || question_templates.order_index), 21, 12)
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
