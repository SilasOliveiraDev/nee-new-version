-- =====================================================================
-- Esquema do banco de dados (schema public) - projeto Nee
-- Gerado a partir do banco Supabase: zhubjmdpvkvbkbfcxeyh
-- Inclui: tabelas, colunas, defaults, PKs, FKs e CHECK constraints.
-- Nao inclui: dados, policies RLS, triggers/funcoes (listadas no final).
-- =====================================================================

CREATE TABLE public.banners (
  id bigint NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  imagem text,
  visible boolean
);
ALTER TABLE public.banners ADD CONSTRAINT banners_pkey PRIMARY KEY (id);

CREATE TABLE public.categoria_tiendas (
  id bigint NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  nome_categoria text,
  "is_disponivel?" text
);
ALTER TABLE public.categoria_tiendas ADD CONSTRAINT categoria_productos_pkey PRIMARY KEY (id);

CREATE TABLE public.categories (
  id bigint NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  nome text,
  imagem text,
  disponivel boolean
);
ALTER TABLE public.categories ADD CONSTRAINT categories_pkey PRIMARY KEY (id);

CREATE TABLE public.chats (
  id bigint NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  chat_name text,
  chat_description text,
  chat_img text,
  chat_members text[],
  last_message text,
  last_message_time timestamp with time zone
);
ALTER TABLE public.chats ADD CONSTRAINT chats_pkey PRIMARY KEY (id);

CREATE TABLE public.citys (
  id bigint NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  "nomeCidade" text,
  "isDisponible" boolean
);
ALTER TABLE public.citys ADD CONSTRAINT "Citys_pkey" PRIMARY KEY (id);

CREATE TABLE public.comercios (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  nome_comercio text,
  categoria_comercio text,
  barrio text,
  ciudad text,
  direccion text,
  "imagePerfil" text,
  telefono text,
  link text,
  horario_inicio timestamp with time zone,
  hoario_fim timestamp with time zone,
  "isDisponivel" boolean,
  "haceEntrega" boolean,
  "soloRetirada" boolean,
  "tiendaFIsica" boolean,
  id_user text
);
ALTER TABLE public.comercios ADD CONSTRAINT comercios_pkey PRIMARY KEY (id);

CREATE TABLE public.config (
  id bigint NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  "isManutencao" boolean,
  "standBy" boolean,
  "valorMinimo" double precision,
  "costoValidacion" double precision,
  "creditosStart" double precision,
  "apiMapbox" text
);
ALTER TABLE public.config ADD CONSTRAINT config_pkey PRIMARY KEY (id);

CREATE TABLE public.contracts (
  id bigint NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  service_id text,
  client_id text,
  autonomo_id text,
  status text,
  categoria character varying,
  "enProcesso" boolean DEFAULT false,
  "servicioRealizado" boolean DEFAULT false,
  "isFinalizado" boolean DEFAULT false
);
ALTER TABLE public.contracts ADD CONSTRAINT contracts_pkey PRIMARY KEY (id);

CREATE TABLE public.email_templates (
  id bigint DEFAULT nextval('email_templates_id_seq'::regclass) NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  template_id text NOT NULL,
  title text NOT NULL,
  description text,
  is_active boolean DEFAULT true,
  created_by text,
  last_used_at timestamp with time zone
);
ALTER TABLE public.email_templates ADD CONSTRAINT email_templates_pkey PRIMARY KEY (id);
ALTER TABLE public.email_templates ADD CONSTRAINT email_templates_template_id_key UNIQUE (template_id);

CREATE TABLE public.faq (
  id bigint NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  pergunta text,
  resposta text,
  "isVisible" boolean DEFAULT false,
  categoria text
);
ALTER TABLE public.faq ADD CONSTRAINT faq_pkey PRIMARY KEY (id);

CREATE TABLE public.logs (
  id bigint NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  user_id bigint,
  user_type text,
  action text NOT NULL,
  description text,
  metadata jsonb,
  device text,
  ip_address text,
  status text DEFAULT 'success'::text,
  origin text,
  trace_id text,
  handled_by text,
  is_critical boolean DEFAULT false
);
ALTER TABLE public.logs ADD CONSTRAINT logs_pkey PRIMARY KEY (id);
ALTER TABLE public.logs ADD CONSTRAINT logs_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL;

CREATE TABLE public.massive_notifications_whatsapp (
  id bigint NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  numero text,
  "isEnviado" boolean,
  nome text
);
ALTER TABLE public.massive_notifications_whatsapp ADD CONSTRAINT massive_notifications_whatsapp_pkey PRIMARY KEY (id);

CREATE TABLE public.messages (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  message_text text,
  sender_id bigint,
  recepient_id bigint,
  img_path text
);
ALTER TABLE public.messages ADD CONSTRAINT messages_pkey PRIMARY KEY (id);
ALTER TABLE public.messages ADD CONSTRAINT messages_recepient_id_fkey FOREIGN KEY (recepient_id) REFERENCES chats(id) ON UPDATE CASCADE ON DELETE CASCADE;
ALTER TABLE public.messages ADD CONSTRAINT messages_sender_id_fkey FOREIGN KEY (sender_id) REFERENCES users(id) ON UPDATE CASCADE ON DELETE CASCADE;

CREATE TABLE public.notifications (
  id bigint NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  title text NOT NULL,
  message text NOT NULL,
  type text DEFAULT 'sistema'::text,
  related_id text,
  is_read boolean DEFAULT false,
  is_active boolean DEFAULT true,
  icon_url text,
  metadata jsonb,
  user_id text
);
ALTER TABLE public.notifications ADD CONSTRAINT notifications_pkey PRIMARY KEY (id);

CREATE TABLE public.productos (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  nombre_producto text,
  descripcion text,
  precio double precision,
  "imagemProd" text,
  "categoriaProducto" text,
  estoque real,
  "idComercio" bigint,
  "isDisponivel" boolean
);
ALTER TABLE public.productos ADD CONSTRAINT productos_pkey PRIMARY KEY (id);

CREATE TABLE public.proposals (
  id bigint NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  professional_id text,
  service_request_id text,
  proposal_message text,
  price_estimate double precision,
  time_estimate text,
  status text,
  "idCliente" text,
  "IsDestaque" boolean
);
ALTER TABLE public.proposals ADD CONSTRAINT proposals_pkey PRIMARY KEY (id);

CREATE TABLE public.reviews (
  id bigint NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  service_id text,
  cliente_id text,
  rating double precision,
  comment character varying,
  profissional_id text,
  curtiu boolean DEFAULT false,
  is_visible boolean DEFAULT true
);
ALTER TABLE public.reviews ADD CONSTRAINT reviews_pkey PRIMARY KEY (id);

CREATE TABLE public.service_requests (
  id bigint NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  client_id text,
  service_id text,
  profissional_id text,
  title text,
  description text,
  status text,
  location_id text,
  "qtdPropostas" double precision,
  categoria text,
  "idPropostas" text[],
  disponivel boolean,
  codesecurity text,
  "imageCapa" text,
  created_at_local timestamp with time zone DEFAULT now(),
  coordenadas text,
  point point,
  address text,
  city text,
  state text,
  country text
);
ALTER TABLE public.service_requests ADD CONSTRAINT service_requests_pkey PRIMARY KEY (id);

CREATE TABLE public.services (
  id bigint NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  user_id uuid DEFAULT gen_random_uuid(),
  title text,
  description character varying,
  category_id text,
  price double precision,
  location character varying,
  imagem text,
  publicado boolean,
  telefone text,
  "isSuspenso" boolean DEFAULT false,
  "isBloqueado" boolean DEFAULT false,
  "isDestacado" boolean DEFAULT false,
  "NotaAvaliacao" double precision,
  qtd_propostas real DEFAULT '0'::real
);
ALTER TABLE public.services ADD CONSTRAINT services_pkey PRIMARY KEY (id);
ALTER TABLE public.services ADD CONSTRAINT services_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

CREATE TABLE public.subcategorias (
  id bigint NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  "nomeSubCategoria" character varying,
  icon text,
  categoria bigint
);
ALTER TABLE public.subcategorias ADD CONSTRAINT subcategorias_pkey PRIMARY KEY (id);
ALTER TABLE public.subcategorias ADD CONSTRAINT subcategorias_categoria_fkey FOREIGN KEY (categoria) REFERENCES categories(id) ON DELETE CASCADE;

CREATE TABLE public.tips (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  title text NOT NULL,
  description text,
  image_url text,
  is_active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now()
);
ALTER TABLE public.tips ADD CONSTRAINT tips_pkey PRIMARY KEY (id);

CREATE TABLE public.transactions (
  id bigint NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  payer_id text,
  receiver_id text,
  amount double precision,
  status text,
  "service_Id" text
);
ALTER TABLE public.transactions ADD CONSTRAINT transactions_pkey PRIMARY KEY (id);

CREATE TABLE public.transactions_add_credit (
  id bigint NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  alias text,
  "detalleGlosa" text,
  monto double precision,
  moneda text,
  "fechaVencimiento" text,
  "unicoUso" boolean,
  "idUser" text,
  status text,
  "idQrCode" text
);
ALTER TABLE public.transactions_add_credit ADD CONSTRAINT transactions_add_credit_pkey PRIMARY KEY (id);

CREATE TABLE public.users (
  id bigint NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  name character varying,
  email text,
  phone text,
  user_type text,
  verified boolean DEFAULT false,
  "UUID" uuid DEFAULT gen_random_uuid(),
  "Categoria" text,
  "categoriaId" bigint,
  "Subcategoria" text,
  "subcategoriaID" bigint,
  "imagemPerfil" character varying,
  "descricaoSobre" character varying,
  "Zona" character varying,
  "fechaNacimiento" text,
  sexo text,
  "isDestacado" boolean DEFAULT false,
  "isSuspenso" boolean DEFAULT false,
  "isBloqueado" boolean DEFAULT false,
  "isDeletado" boolean DEFAULT false,
  "rateAvaliacao" double precision,
  creditos double precision,
  cidade text,
  zona_atendimento text,
  step text,
  "diasSuspenso" bigint DEFAULT '0'::bigint,
  "comprovantedocFrente" text,
  "comprovantedocVerso" text,
  "comprovanteAntecedente" text,
  "comprovanteFacturaLuz" text,
  "statusDocumentos" text,
  "motivoDocumento" text,
  "userTest" boolean DEFAULT true,
  "idFCM" text,
  latlng text,
  adress text,
  city text,
  country text,
  complemento text,
  numeroresidencia text,
  "IdMautic" text
);
ALTER TABLE public.users ADD CONSTRAINT users_pkey PRIMARY KEY (id);
ALTER TABLE public.users ADD CONSTRAINT "users_UUID_fkey" FOREIGN KEY ("UUID") REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE public.users ADD CONSTRAINT "users_categoriaId_fkey" FOREIGN KEY ("categoriaId") REFERENCES categories(id) ON DELETE CASCADE;
ALTER TABLE public.users ADD CONSTRAINT "users_subcategoriaID_fkey" FOREIGN KEY ("subcategoriaID") REFERENCES subcategorias(id);

CREATE TABLE public.usuario (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  nome text NOT NULL,
  email text NOT NULL,
  criado_em timestamp with time zone DEFAULT timezone('utc'::text, now())
);
ALTER TABLE public.usuario ADD CONSTRAINT usuario_pkey PRIMARY KEY (id);
ALTER TABLE public.usuario ADD CONSTRAINT usuario_email_key UNIQUE (email);

CREATE TABLE public.version (
  id bigint NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  version text,
  "isDisponivel" boolean
);
ALTER TABLE public.version ADD CONSTRAINT version_pkey PRIMARY KEY (id);

CREATE TABLE public.whatsapp_campaigns (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  instance_id uuid NOT NULL,
  user_type text,
  message text NOT NULL,
  total_contacts integer DEFAULT 0 NOT NULL,
  sent_count integer DEFAULT 0 NOT NULL,
  failed_count integer DEFAULT 0 NOT NULL,
  delivered_count integer DEFAULT 0 NOT NULL,
  status text DEFAULT 'processing'::text NOT NULL,
  delay_ms integer DEFAULT 1000 NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  started_at timestamp with time zone,
  completed_at timestamp with time zone,
  error_message text,
  metadata jsonb DEFAULT '{}'::jsonb,
  list_id uuid,
  scheduled_at timestamp with time zone,
  is_scheduled boolean DEFAULT false
);
ALTER TABLE public.whatsapp_campaigns ADD CONSTRAINT whatsapp_campaigns_pkey PRIMARY KEY (id);
ALTER TABLE public.whatsapp_campaigns ADD CONSTRAINT whatsapp_campaigns_instance_id_fkey FOREIGN KEY (instance_id) REFERENCES whatsapp_instances(id) ON DELETE CASCADE;
ALTER TABLE public.whatsapp_campaigns ADD CONSTRAINT whatsapp_campaigns_list_id_fkey FOREIGN KEY (list_id) REFERENCES whatsapp_lists(id) ON DELETE SET NULL;
ALTER TABLE public.whatsapp_campaigns ADD CONSTRAINT whatsapp_campaigns_delay_ms_check CHECK (((delay_ms >= 500) AND (delay_ms <= 30000)));
ALTER TABLE public.whatsapp_campaigns ADD CONSTRAINT whatsapp_campaigns_status_check CHECK ((status = ANY (ARRAY['processing'::text, 'completed'::text, 'failed'::text, 'cancelled'::text, 'scheduled'::text])));
ALTER TABLE public.whatsapp_campaigns ADD CONSTRAINT whatsapp_campaigns_user_type_check CHECK ((user_type = ANY (ARRAY['Cliente'::text, 'Servico'::text, 'Todos'::text])));

CREATE TABLE public.whatsapp_instances (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL,
  instance_name text NOT NULL,
  instance_id text,
  status text DEFAULT 'disconnected'::text NOT NULL,
  qr_code text,
  phone_number text,
  is_active boolean DEFAULT true NOT NULL,
  metadata jsonb DEFAULT '{}'::jsonb
);
ALTER TABLE public.whatsapp_instances ADD CONSTRAINT whatsapp_instances_pkey PRIMARY KEY (id);
ALTER TABLE public.whatsapp_instances ADD CONSTRAINT whatsapp_instances_instance_id_key UNIQUE (instance_id);
ALTER TABLE public.whatsapp_instances ADD CONSTRAINT whatsapp_instances_instance_name_key UNIQUE (instance_name);

CREATE TABLE public.whatsapp_list_contacts (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  list_id uuid NOT NULL,
  user_id text NOT NULL,
  phone_number text NOT NULL,
  name text,
  user_type text,
  added_at timestamp with time zone DEFAULT now() NOT NULL
);
ALTER TABLE public.whatsapp_list_contacts ADD CONSTRAINT whatsapp_list_contacts_pkey PRIMARY KEY (id);
ALTER TABLE public.whatsapp_list_contacts ADD CONSTRAINT whatsapp_list_contacts_list_id_fkey FOREIGN KEY (list_id) REFERENCES whatsapp_lists(id) ON DELETE CASCADE;
ALTER TABLE public.whatsapp_list_contacts ADD CONSTRAINT whatsapp_list_contacts_list_id_user_id_key UNIQUE (list_id, user_id);

CREATE TABLE public.whatsapp_lists (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  name text NOT NULL,
  description text,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL,
  is_active boolean DEFAULT true NOT NULL,
  total_contacts integer DEFAULT 0 NOT NULL
);
ALTER TABLE public.whatsapp_lists ADD CONSTRAINT whatsapp_lists_pkey PRIMARY KEY (id);

CREATE TABLE public.whatsapp_messages (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL,
  instance_id uuid NOT NULL,
  phone_number text NOT NULL,
  message text NOT NULL,
  message_id text,
  status text DEFAULT 'pending'::text NOT NULL,
  status_timestamp timestamp with time zone,
  error_message text,
  metadata jsonb DEFAULT '{}'::jsonb,
  campaign_id uuid
);
ALTER TABLE public.whatsapp_messages ADD CONSTRAINT whatsapp_messages_pkey PRIMARY KEY (id);
ALTER TABLE public.whatsapp_messages ADD CONSTRAINT whatsapp_messages_instance_id_fkey FOREIGN KEY (instance_id) REFERENCES whatsapp_instances(id) ON DELETE CASCADE;
ALTER TABLE public.whatsapp_messages ADD CONSTRAINT whatsapp_messages_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES whatsapp_campaigns(id) ON DELETE SET NULL;

CREATE TABLE public.zonas (
  id bigint NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  id_city text,
  nombre_zona text,
  disponible boolean DEFAULT true
);
ALTER TABLE public.zonas ADD CONSTRAINT zonas_pkey PRIMARY KEY (id);

-- =====================================================================
-- Triggers existentes (funcoes ja definidas no banco)
-- =====================================================================
-- proposals              AFTER INSERT  -> notify_new_proposal()
-- proposals              AFTER UPDATE  -> trigger_proposal_status_changed()
-- service_requests       AFTER INSERT  -> notify_new_service_request()
-- services               AFTER INSERT  -> trigger_new_service_published()
-- tips                   BEFORE UPDATE -> set_current_timestamp_updated_at()
-- usuario                AFTER INSERT  -> notify_new_usuario()
-- whatsapp_instances     BEFORE UPDATE -> update_updated_at_column()
-- whatsapp_messages      BEFORE UPDATE -> update_updated_at_column()
-- whatsapp_list_contacts AFTER INSERT/DELETE -> update_list_contact_count()

-- Observacao: RLS esta habilitado na maioria das tabelas (exceto public.usuario).
-- As policies nao estao incluidas neste arquivo.
