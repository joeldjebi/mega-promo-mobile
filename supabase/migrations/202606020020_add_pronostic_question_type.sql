-- MegaPromo - Type de question Pronostics
-- A executer dans Supabase SQL Editor apres 202606020017.
--
-- Objectif:
-- - conserver le comportement QCM actuel par defaut;
-- - ajouter un type de question "pronostic" pour les QL/JCQ sport;
-- - stocker une configuration souple de pronostic sans impacter les questions
--   existantes;
-- - laisser la resolution des pronostics se faire plus tard par un workflow
--   dedie.

alter table public.questions
add column if not exists question_type text not null default 'quiz',
add column if not exists prediction_type text,
add column if not exists prediction_payload jsonb not null default '{}'::jsonb,
add column if not exists result_payload jsonb not null default '{}'::jsonb,
add column if not exists resolution_status text not null default 'not_required';

-- Ne pas mettre a jour les questions rattachees a un Quiz Live:
-- un trigger protege les QL deja ouverts contre toute modification tardive.
-- Les colonnes ajoutees ci-dessus ont des DEFAULT, donc les anciennes
-- questions restent automatiquement des QCM classiques.
update public.questions questions
set
  question_type = coalesce(nullif(trim(questions.question_type), ''), 'quiz'),
  prediction_payload = coalesce(questions.prediction_payload, '{}'::jsonb),
  result_payload = coalesce(questions.result_payload, '{}'::jsonb),
  resolution_status = case
    when coalesce(nullif(trim(questions.question_type), ''), 'quiz') = 'pronostic'
      then coalesce(nullif(trim(questions.resolution_status), ''), 'pending')
    else 'not_required'
  end
where not exists (
    select 1
    from public.contests contests
    where contests.id = questions.contest_id
      and coalesce(contests.is_live, false) = true
  )
  and (
    questions.question_type is null
    or trim(questions.question_type) = ''
    or questions.prediction_payload is null
    or questions.result_payload is null
    or questions.resolution_status is null
    or trim(questions.resolution_status) = ''
    or (
      coalesce(nullif(trim(questions.question_type), ''), 'quiz') = 'quiz'
      and questions.resolution_status <> 'not_required'
    )
    or (
      coalesce(nullif(trim(questions.question_type), ''), 'quiz') = 'pronostic'
      and questions.resolution_status = 'not_required'
    )
  );

alter table public.questions
drop constraint if exists questions_question_type_check;

alter table public.questions
add constraint questions_question_type_check
check (question_type in ('quiz', 'pronostic'));

alter table public.questions
drop constraint if exists questions_resolution_status_check;

alter table public.questions
add constraint questions_resolution_status_check
check (resolution_status in ('not_required', 'pending', 'resolved', 'cancelled'));

create index if not exists questions_question_type_idx
  on public.questions(question_type);

create index if not exists questions_pronostic_resolution_idx
  on public.questions(resolution_status)
  where question_type = 'pronostic';

comment on column public.questions.question_type is
  'Type metier de la question. quiz conserve le QCM actuel; pronostic active une experience mobile dediee.';

comment on column public.questions.prediction_type is
  'Sous-type facultatif de pronostic: match_winner, exact_score, over_under, scorer, custom, etc.';

comment on column public.questions.prediction_payload is
  'Configuration JSON facultative du pronostic: equipes, match, date, options, contexte.';

comment on column public.questions.result_payload is
  'Resultat JSON renseigne apres resolution du pronostic.';

comment on column public.questions.resolution_status is
  'Etat de resolution du pronostic. Les QCM classiques restent not_required.';

notify pgrst, 'reload schema';
