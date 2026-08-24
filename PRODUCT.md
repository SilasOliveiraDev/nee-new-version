# Product

<!-- impeccable:product-schema 1 -->

## Platform

adaptive

## Stack

Flutter (Material 3 + adaptação iOS/Android no mesmo código). Já existe: geolocator, flutter_map, supabase_flutter, google_fonts.

## Users

Pessoa em Bolívia que precisa de um ofício agora ou hoje: plomería, electricidad, limpieza, belleza e demais categorias do marketplace. Situação típica: em casa ou no bairro, no celular, escolhe um serviço, vê quem está perto e disponível, pede cotação ou reserva. Este recorte é só o **aplicativo do usuário (cliente)**, não o do profissional.

## Product Purpose

Ñee! conecta quem precisa de um serviço local a profissionais independentes próximos. Sucesso: achar alguém confiável perto, entender o estado do pedido, e voltar a pedir sem reaprender o app.

## Positioning

Matching local por proximidade e disponibilidade real: o mapa mostra profissionais **próximos e liberados** (visíveis para aquele usuário: perto + aptos a atender). Um diretório nacional ou um feed genérico de cards não replica isso.

## Operating Context

- Idioma da interface: espanhol (Bolívia).
- Moeda e preços em bolivianos (Bs.).
- Cidade de referência no protótipo: Santa Cruz e outras cidades bolivianas do onboarding.
- Conta: correo y contraseña (Supabase Auth); OTP de teste no onboarding.
- Sem `env.json` o app segue local (SharedPreferences + dados de demonstração).

## Capabilities and Constraints

- Casca atual do cliente: Inicio, Solicitudes, Mensajes, Perfil.
- Pedido: categorias, `Buscar servicio` / matching, estado da solicitud.
- Mapa já existe no fluxo de lugar do serviço (`flutter_map`); ainda não é aba de profissionais.
- **Decisão desta rodada:** o mapa de profissionais próximos e liberados é uma **aba própria** (Explorar / Mapa), sem substituir a home.
- **Escopo desta rodada:** redesenhar home (com caminho ao mapa) e Solicitudes; Mensajes e Perfil só recebem o mesmo visual, sem reescrever o fluxo.
- Profissionais, ratings e distâncias de lista atual podem ser demonstração (mock); não inventar avaliações, preços ou clientes reais como prova comercial.
- Componentes reutilizáveis: cards de profissional, pills de estado, navegação, transições compartilhadas. Performance: evitar widgets pesados duplicados; mapa só na aba de mapa (lazy).
- Motion: transições e animações que prendem atenção, com respeito a Reduce Motion / Remove animations.

## Brand Commitments

- Nome: **Ñee!**
- Voz da UI: espanhol direto, segunda pessoa informal onde já existe (`¿Qué servicio buscas hoy?`, `Cerca de ti`).
- Cores atuais do app são vinculantes: colete amarelo `vest` `#FFD000`, fuligem `soot` `#16140F`, papel `paper` `#EEEAE2`, giz `chalk` `#FBFBF8`. A imagem azul de marketplace enviada é **exemplo de layout**, não paleta.
- Logos em `assets/brand/nee-logo.png` e `assets/brand/nee-logo-lockup.png`.
- Super-minimalista: espaço, hierarquia e um acento; não copiar o visual “SaaS azul” do exemplo.
- Pertencimento: o usuário deve sentir o bairro e o ofício local, não um template global de gig economy.

## Evidence on Hand

- README e `pubspec.yaml`: marketplace móvel de serviços locais na Bolívia.
- `lib/theme.dart`: tokens atuais.
- `lib/screens/client_shell.dart`: home, solicitudes, mensajes, perfil.
- `lib/mock_data.dart`: categorias e profissionais de demonstração.
- Screenshot de referência do usuário: layout de home / solicitudes / categorias (anti-referência de paleta).
- Não há depoimentos, métricas ou clientes nomeados para citar como prova.

## Product Principles

1. Perto e liberado primeiro: o mapa e a lista só mostram quem o usuário pode de fato chamar.
2. O estado da solicitud é legível em um olhar (esperando, ofertas, asignado, hecho).
3. Uma ação primária por tela; o resto recua.
4. O mesmo componente serve home, mapa e solicitudes; o peso fica no sistema, não em telas únicas.
5. Pertencer ao bairro: cidade, distâncias e ofícios concretos, sem hype de plataforma.

## Accessibility & Inclusion

iOS Reduce Motion e Android Remove animations: crossfade em vez de parallax. Alvos 44pt / 48dp. Dynamic Type / escala de fonte do sistema nas superfícies adaptadas. Dark Mode é obrigação de plataforma (iOS e Android); o acento amarelo permanece reconhecível nos dois.
