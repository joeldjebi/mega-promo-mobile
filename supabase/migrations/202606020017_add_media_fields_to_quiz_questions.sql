-- MegaPromo - Questions multimedia pour QL/JCQ et banques de questions
-- A executer dans Supabase SQL Editor apres 202606020004.
--
-- Objectif:
-- - permettre une question texte, image, ou texte + image;
-- - permettre des propositions texte, image, ou texte + image;
-- - garder la compatibilite avec les questions texte existantes;
-- - rendre les champs disponibles dans les RPC qui retournent public.questions.*;
-- - preparer le SA et les imports CSV a gerer les colonnes:
--   question_image_url, option_a_image_url, option_b_image_url,
--   option_c_image_url, option_d_image_url.

alter table public.questions
add column if not exists question_image_url text,
add column if not exists option_a_image_url text,
add column if not exists option_b_image_url text,
add column if not exists option_c_image_url text,
add column if not exists option_d_image_url text;

update public.questions
set
  question_image_url = nullif(trim(coalesce(question_image_url, '')), ''),
  option_a_image_url = nullif(trim(coalesce(option_a_image_url, '')), ''),
  option_b_image_url = nullif(trim(coalesce(option_b_image_url, '')), ''),
  option_c_image_url = nullif(trim(coalesce(option_c_image_url, '')), ''),
  option_d_image_url = nullif(trim(coalesce(option_d_image_url, '')), '');

alter table public.questions
drop constraint if exists questions_prompt_text_or_image_check;

alter table public.questions
add constraint questions_prompt_text_or_image_check
check (
  length(trim(coalesce(question_text, ''))) > 0
  or length(trim(coalesce(question_image_url, ''))) > 0
);

alter table public.questions
drop constraint if exists questions_option_a_text_or_image_check;

alter table public.questions
add constraint questions_option_a_text_or_image_check
check (
  length(trim(coalesce(option_a, ''))) > 0
  or length(trim(coalesce(option_a_image_url, ''))) > 0
);

alter table public.questions
drop constraint if exists questions_option_b_text_or_image_check;

alter table public.questions
add constraint questions_option_b_text_or_image_check
check (
  length(trim(coalesce(option_b, ''))) > 0
  or length(trim(coalesce(option_b_image_url, ''))) > 0
);

alter table public.questions
drop constraint if exists questions_option_c_text_or_image_check;

alter table public.questions
add constraint questions_option_c_text_or_image_check
check (
  length(trim(coalesce(option_c, ''))) > 0
  or length(trim(coalesce(option_c_image_url, ''))) > 0
);

alter table public.questions
drop constraint if exists questions_option_d_text_or_image_check;

alter table public.questions
add constraint questions_option_d_text_or_image_check
check (
  length(trim(coalesce(option_d, ''))) > 0
  or length(trim(coalesce(option_d_image_url, ''))) > 0
);

create index if not exists questions_with_prompt_image_idx
  on public.questions(question_image_url)
  where question_image_url is not null;

comment on column public.questions.question_image_url is
  'URL image facultative du prompt. La question peut etre texte, image, ou texte + image.';

comment on column public.questions.option_a_image_url is
  'URL image facultative de la proposition A. La proposition peut etre texte, image, ou texte + image.';

comment on column public.questions.option_b_image_url is
  'URL image facultative de la proposition B. La proposition peut etre texte, image, ou texte + image.';

comment on column public.questions.option_c_image_url is
  'URL image facultative de la proposition C. La proposition peut etre texte, image, ou texte + image.';

comment on column public.questions.option_d_image_url is
  'URL image facultative de la proposition D. La proposition peut etre texte, image, ou texte + image.';

notify pgrst, 'reload schema';
