# Schema Nee (Supabase)

Arquivo oficial: [`schema-nee.sql`](schema-nee.sql), gerado do projeto `zhubjmdpvkvbkbfcxeyh`.

## Onboarding → `public.users`

| Etapa no app | Colunas |
| --- | --- |
| Localização atual + endereço | `latlng`, `adress`, `numeroresidencia`, `complemento`, `city`, `country`, `Zona`, `cidade` |
| Telefone + OTP | `phone`, `verified` |
| Nome, nascimento, e-mail | `name`, `fechaNacimiento`, `email`, `sexo` |
| Foto | `imagemPerfil` (upload depois) |
| Papel | `user_type`: `Cliente` ou `Servico` (constraint do WhatsApp) |
| Progresso | `step` |
| Ofício / especialidades | `Categoria`, `categoriaId`, `Subcategoria`, `subcategoriaID` |
| Área de atendimento | `zona_atendimento` |
| Bio | `descricaoSobre` |
| Documentos (níveis BASIC/VERIFIED/PRO) | `comprovantedocFrente`, `comprovantedocVerso`, `comprovanteAntecedente`, `comprovanteFacturaLuz`, `statusDocumentos` |

## Já existem no banco e entram nas homes

- `categories` + `subcategorias` — catálogo do prestador
- `service_requests` — pedidos (address, city, coordenadas, point)
- `proposals` / `contracts` / `reviews` / `transactions`
- `citys` + `zonas` — localização cadastrada
- `config.apiMapbox` — mapa no confirmar endereço
- `chats` / `messages` — coordenação cliente–profissional

## O schema ainda não cobre (fica local até migrar)

- Dois papéis no mesmo usuário (`user_roles`)
- Portfólio com N fotos/vídeos, capa e ordem (`provider_portfolio`)
- Raio em km tipado (`service_radius_km`)
- Endereço atual vs cadastrado como linhas separadas

O app já grava um payload `users` compatível para o insert futuro; o resto segue em `shared_preferences` até ligar o cliente Supabase.

## Ligar o Flutter

1. Copie `env.json.example` → `env.json` e cole a **anon public** key.
2. Rode `supabase/rls_client_policies.sql` no SQL Editor.
3. Authentication → Email ligado; **Confirm email** desligado para testes.
4. `flutter run --dart-define-from-file=env.json`

O cliente nunca usa a `service_role` key.
