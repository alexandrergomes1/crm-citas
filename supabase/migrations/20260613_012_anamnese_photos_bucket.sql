-- KA Beauty OS — Bucket privado para fotos da ficha profissional de anamnese
-- Encoding: UTF-8
-- Caminho dos objetos: {org_id}/{anamnese_id}/{arquivo}. RLS por pertencimento a org.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'anamnese-photos', 'anamnese-photos', false, 10485760,
  array['image/jpeg','image/png','image/webp','image/heic','image/heif']
)
on conflict (id) do nothing;

drop policy if exists "anamnese_photos_select" on storage.objects;
drop policy if exists "anamnese_photos_insert" on storage.objects;
drop policy if exists "anamnese_photos_delete" on storage.objects;

create policy "anamnese_photos_select" on storage.objects for select to authenticated
using (
  bucket_id = 'anamnese-photos'
  and public.auth_user_role(((storage.foldername(name))[1])::uuid) is not null
);

create policy "anamnese_photos_insert" on storage.objects for insert to authenticated
with check (
  bucket_id = 'anamnese-photos'
  and public.auth_user_role(((storage.foldername(name))[1])::uuid) is not null
);

create policy "anamnese_photos_delete" on storage.objects for delete to authenticated
using (
  bucket_id = 'anamnese-photos'
  and public.auth_user_role(((storage.foldername(name))[1])::uuid) is not null
);
