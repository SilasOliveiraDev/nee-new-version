-- Foto de perfil e portafolio públicos: leitura para visitantes (anon) e contas.
-- O bucket avatars continua privado para escrita; insert/update/delete seguem só do dono.

DROP POLICY IF EXISTS nee_services_public_read ON public.services;
CREATE POLICY nee_services_public_read ON public.services
  FOR SELECT TO anon, authenticated
  USING (coalesce(publicado, false) = true);

DROP POLICY IF EXISTS nee_avatar_professional_read ON storage.objects;
CREATE POLICY nee_avatar_professional_read ON storage.objects
  FOR SELECT TO anon, authenticated
  USING (
    bucket_id = 'avatars'
    AND (
      name LIKE '%/portfolio/%'
      OR split_part(name, '/', 2) IN (
        'profile.jpg',
        'profile.jpeg',
        'profile.png',
        'profile.webp'
      )
    )
  );
