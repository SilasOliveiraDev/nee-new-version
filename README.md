# Ñee!

Marketplace móvil de servicios locales en Bolivia: conecta a quien necesita un oficio con profesionales independientes cercanos.

## Qué incluye este prototipo

- Onboarding: datos, SMS (código de prueba `1234`), geolocalización, dirección, foto de perfil.
- Profesional: oficios + fotos/videos de trabajos.
- Cliente: categorías, pedido, matching y estado.
- Schema real do Supabase em `supabase/schema-nee.sql`.
- Onboarding local (progresso em `users.step` quando ligarmos o backend).

## Cómo correrlo

```bash
export PATH="$HOME/flutter/bin:$PATH"
cp env.json.example env.json
# Cole a anon key em env.json (Project Settings → API)
flutter pub get
flutter run -d chrome --no-web-resources-cdn --dart-define-from-file=env.json
```

OTP de teste no celular, no onboarding: `123456`. A entrada na conta é **correo y contraseña** (Supabase Auth).
Sem `env.json` o app segue local (SharedPreferences).

## Supabase

Schema oficial em `supabase/schema-nee.sql` (projeto `zhubjmdpvkvbkbfcxeyh`).

Antes do primeiro insert, rode no SQL Editor: `supabase/rls_client_policies.sql`.

Em Authentication → Providers, ligue **Email**. Em Authentication → Providers → Email, desative **Confirm email** enquanto testa (senão o login espera o link do e-mail).

O app sincroniza:
- `public.users` a cada passo de onboarding
- `public.service_requests` ao publicar uma solicitud

