-- ============================================================
-- MAXI MOTORS — Database Schema
-- Run this SQL in your Supabase SQL Editor
-- ============================================================

-- 1. AGENTS (vinculado a auth.users)
CREATE TABLE agents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name TEXT NOT NULL,
  email TEXT UNIQUE NOT NULL,
  phone TEXT,
  avatar_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE agents ENABLE ROW LEVEL SECURITY;

-- 2. CLIENTS
CREATE TABLE clients (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  agent_id UUID REFERENCES agents(id) ON DELETE SET NULL,
  full_name TEXT NOT NULL,
  email TEXT,
  phone TEXT,
  id_type TEXT CHECK (id_type IN ('cedula', 'pasaporte')),
  id_number TEXT,
  address TEXT,
  city TEXT DEFAULT 'Ciudad de Panamá',
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE clients ENABLE ROW LEVEL SECURITY;

-- 3. VEHICLES
CREATE TYPE vehicle_status AS ENUM ('disponible', 'vendido', 'en_proceso', 'reservado');

CREATE TABLE vehicles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  agent_id UUID REFERENCES agents(id) ON DELETE SET NULL,
  client_id UUID REFERENCES clients(id) ON DELETE SET NULL,
  brand TEXT NOT NULL,
  model TEXT NOT NULL,
  year INTEGER NOT NULL,
  vin TEXT UNIQUE,
  license_plate TEXT,
  mileage INTEGER,
  color TEXT,
  fuel_type TEXT CHECK (fuel_type IN ('gasolina', 'diesel', 'hibrido', 'electrico')),
  transmission TEXT CHECK (transmission IN ('manual', 'automatica')),
  price DECIMAL(10,2),
  status vehicle_status DEFAULT 'disponible',
  image_url TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE vehicles ENABLE ROW LEVEL SECURITY;

-- 4. INSPECTION CATEGORIES (ej: Motor, Frenos, Suspensión, etc.)
CREATE TABLE inspection_categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  display_order INTEGER NOT NULL DEFAULT 0,
  icon TEXT
);

-- 5. INSPECTION ITEMS (los 140 puntos)
CREATE TABLE inspection_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  category_id UUID REFERENCES inspection_categories(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  display_order INTEGER NOT NULL DEFAULT 0
);

-- 6. INSPECTIONS
CREATE TYPE inspection_result AS ENUM ('aprobado', 'rechazado', 'observacion');

CREATE TABLE inspections (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  vehicle_id UUID REFERENCES vehicles(id) ON DELETE CASCADE,
  agent_id UUID REFERENCES agents(id) ON DELETE SET NULL,
  status TEXT CHECK (status IN ('en_progreso', 'completada')) DEFAULT 'en_progreso',
  summary TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  completed_at TIMESTAMPTZ
);

ALTER TABLE inspections ENABLE ROW LEVEL SECURITY;

-- 7. INSPECTION RESULTS (cada punto chequeado)
CREATE TABLE inspection_results (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  inspection_id UUID REFERENCES inspections(id) ON DELETE CASCADE,
  item_id UUID REFERENCES inspection_items(id) ON DELETE CASCADE,
  result inspection_result,
  notes TEXT,
  image_url TEXT,
  checked_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(inspection_id, item_id)
);

ALTER TABLE inspection_results ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- RLS POLICIES (solo el agente dueño de los datos)
-- ============================================================

CREATE POLICY "Agentes pueden ver sus propios datos"
  ON agents FOR ALL
  USING (auth.uid() = user_id);

CREATE POLICY "Agentes pueden gestionar sus clientes"
  ON clients FOR ALL
  USING (agent_id IN (SELECT id FROM agents WHERE user_id = auth.uid()));

CREATE POLICY "Agentes pueden gestionar sus vehículos"
  ON vehicles FOR ALL
  USING (agent_id IN (SELECT id FROM agents WHERE user_id = auth.uid()));

CREATE POLICY "Agentes pueden gestionar inspecciones"
  ON inspections FOR ALL
  USING (agent_id IN (SELECT id FROM agents WHERE user_id = auth.uid()));

CREATE POLICY "Agentes ven resultados de sus inspecciones"
  ON inspection_results FOR ALL
  USING (inspection_id IN (
    SELECT id FROM inspections WHERE agent_id IN (
      SELECT id FROM agents WHERE user_id = auth.uid()
    )
  ));

-- ============================================================
-- AUTO-INSERT AGENT on signup
-- ============================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.agents (user_id, full_name, email)
  VALUES (NEW.id, COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.email), NEW.email);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================================
-- SEED: Inspection Categories & Items (140 puntos)
-- ============================================================

-- Categories
INSERT INTO inspection_categories (name, display_order, icon) VALUES
  ('Motor y Sistema de Combustión', 1, 'engine'),
  ('Transmisión', 2, 'gears'),
  ('Sistema de Frenos', 3, 'brakes'),
  ('Suspensión y Dirección', 4, 'suspension'),
  ('Sistema Eléctrico', 5, 'electrical'),
  ('Carrocería y Pintura', 6, 'body'),
  ('Interior y Tapicería', 7, 'interior'),
  ('Neumáticos y Ruedas', 8, 'tires'),
  ('Sistema de Refrigeración', 9, 'cooling'),
  ('Escape y Emisiones', 10, 'exhaust'),
  ('Sistema de Aire Acondicionado', 11, 'ac'),
  ('Luces y Señalización', 12, 'lights'),
  ('Limpiaparabrisas y Visibilidad', 13, 'visibility'),
  ('Seguridad y Airbags', 14, 'safety'),
  ('Documentación', 15, 'docs');

-- Items (140 puntos) — 9-10 por categoría
-- CAT 1: Motor
INSERT INTO inspection_items (category_id, name, description, display_order)
SELECT id, 'Compresión del motor', 'Verificar compresión en todos los cilindros', 1 FROM inspection_categories WHERE name = 'Motor y Sistema de Combustión' UNION ALL
SELECT id, 'Nivel y estado del aceite', 'Revisar nivel, color y viscosidad', 2 FROM inspection_categories WHERE name = 'Motor y Sistema de Combustión' UNION ALL
SELECT id, 'Filtro de aceite', 'Verificar estado y fecha de cambio', 3 FROM inspection_categories WHERE name = 'Motor y Sistema de Combustión' UNION ALL
SELECT id, 'Correa de distribución', 'Revisar desgaste y tensión', 4 FROM inspection_categories WHERE name = 'Motor y Sistema de Combustión' UNION ALL
SELECT id, 'Bujías', 'Verificar estado y calibración', 5 FROM inspection_categories WHERE name = 'Motor y Sistema de Combustión' UNION ALL
SELECT id, 'Inyectores', 'Prueba de pulverización y fugas', 6 FROM inspection_categories WHERE name = 'Motor y Sistema de Combustión' UNION ALL
SELECT id, 'Mangueras y conexiones', 'Revisar fugas y grietas', 7 FROM inspection_categories WHERE name = 'Motor y Sistema de Combustión' UNION ALL
SELECT id, 'Sistema de admisión', 'Filtro de aire y cuerpo de aceleración', 8 FROM inspection_categories WHERE name = 'Motor y Sistema de Combustión' UNION ALL
SELECT id, 'Ruidos anormales', 'Prueba de funcionamiento en ralentí y aceleración', 9 FROM inspection_categories WHERE name = 'Motor y Sistema de Combustión' UNION ALL
SELECT id, 'Tapa de válvulas', 'Verificar sellos y fugas de aceite', 10 FROM inspection_categories WHERE name = 'Motor y Sistema de Combustión';

-- CAT 2: Transmisión
INSERT INTO inspection_items (category_id, name, description, display_order)
SELECT id, 'Nivel de fluido de transmisión', 'Verificar nivel y color', 1 FROM inspection_categories WHERE name = 'Transmisión' UNION ALL
SELECT id, 'Cambios automáticos', 'Prueba de cambios suaves', 2 FROM inspection_categories WHERE name = 'Transmisión' UNION ALL
SELECT id, 'Embrague', 'Punto de fricción y deslizamiento', 3 FROM inspection_categories WHERE name = 'Transmisión' UNION ALL
SELECT id, 'Diferencial', 'Verificar fugas y ruidos', 4 FROM inspection_categories WHERE name = 'Transmisión' UNION ALL
SELECT id, 'Ejes de transmisión', 'Inspeccionar juntas homocinéticas', 5 FROM inspection_categories WHERE name = 'Transmisión' UNION ALL
SELECT id, 'Soporte de transmisión', 'Verificar roturas o desgaste', 6 FROM inspection_categories WHERE name = 'Transmisión' UNION ALL
SELECT id, 'Fugas de fluido', 'Inspeccionar bajo el vehículo', 7 FROM inspection_categories WHERE name = 'Transmisión' UNION ALL
SELECT id, 'Cambios manuales', 'Precisión y suavidad', 8 FROM inspection_categories WHERE name = 'Transmisión' UNION ALL
SELECT id, 'Modo deportivo/nieve', 'Verificar funcionamiento', 9 FROM inspection_categories WHERE name = 'Transmisión';

-- CAT 3: Frenos
INSERT INTO inspection_items (category_id, name, description, display_order)
SELECT id, 'Pastillas de freno delanteras', 'Medir grosor restante', 1 FROM inspection_categories WHERE name = 'Sistema de Frenos' UNION ALL
SELECT id, 'Pastillas de freno traseras', 'Medir grosor restante', 2 FROM inspection_categories WHERE name = 'Sistema de Frenos' UNION ALL
SELECT id, 'Discos de freno', 'Verificar desgaste y alabeo', 3 FROM inspection_categories WHERE name = 'Sistema de Frenos' UNION ALL
SELECT id, 'Líquido de frenos', 'Nivel y punto de ebullición', 4 FROM inspection_categories WHERE name = 'Sistema de Frenos' UNION ALL
SELECT id, 'Mangueras de freno', 'Revisar grietas y fugas', 5 FROM inspection_categories WHERE name = 'Sistema de Frenos' UNION ALL
SELECT id, 'Freno de mano', 'Altura y retención', 6 FROM inspection_categories WHERE name = 'Sistema de Frenos' UNION ALL
SELECT id, 'ABS', 'Prueba de funcionamiento', 7 FROM inspection_categories WHERE name = 'Sistema de Frenos' UNION ALL
SELECT id, 'Servofreno', 'Verificar asistencia', 8 FROM inspection_categories WHERE name = 'Sistema de Frenos' UNION ALL
SELECT id, 'Test de frenado', 'Prueba en carretera', 9 FROM inspection_categories WHERE name = 'Sistema de Frenos' UNION ALL
SELECT id, 'Testigo de frenos', 'Verificar en tablero', 10 FROM inspection_categories WHERE name = 'Sistema de Frenos';

-- CAT 4: Suspensión y Dirección
INSERT INTO inspection_items (category_id, name, description, display_order)
SELECT id, 'Amortiguadores delanteros', 'Prueba de rebote y fugas', 1 FROM inspection_categories WHERE name = 'Suspensión y Dirección' UNION ALL
SELECT id, 'Amortiguadores traseros', 'Prueba de rebote y fugas', 2 FROM inspection_categories WHERE name = 'Suspensión y Dirección' UNION ALL
SELECT id, 'Resortes', 'Verificar roturas', 3 FROM inspection_categories WHERE name = 'Suspensión y Dirección' UNION ALL
SELECT id, 'Barras estabilizadoras', 'Verificar bujes y conexiones', 4 FROM inspection_categories WHERE name = 'Suspensión y Dirección' UNION ALL
SELECT id, 'Terminales de dirección', 'Verificar holgura', 5 FROM inspection_categories WHERE name = 'Suspensión y Dirección' UNION ALL
SELECT id, 'Cremallera de dirección', 'Fugas y juego', 6 FROM inspection_categories WHERE name = 'Suspensión y Dirección' UNION ALL
SELECT id, 'Alineación', 'Prueba de dirección', 7 FROM inspection_categories WHERE name = 'Suspensión y Dirección' UNION ALL
SELECT id, 'Rótulas', 'Verificar desgaste', 8 FROM inspection_categories WHERE name = 'Suspensión y Dirección' UNION ALL
SELECT id, 'Soporte de puntales', 'Verificar estado', 9 FROM inspection_categories WHERE name = 'Suspensión y Dirección';

-- CAT 5: Eléctrico
INSERT INTO inspection_items (category_id, name, description, display_order)
SELECT id, 'Batería', 'Prueba de carga y bornes', 1 FROM inspection_categories WHERE name = 'Sistema Eléctrico' UNION ALL
SELECT id, 'Alternador', 'Prueba de carga', 2 FROM inspection_categories WHERE name = 'Sistema Eléctrico' UNION ALL
SELECT id, 'Motor de arranque', 'Prueba de funcionamiento', 3 FROM inspection_categories WHERE name = 'Sistema Eléctrico' UNION ALL
SELECT id, 'Fusibles', 'Verificar estado general', 4 FROM inspection_categories WHERE name = 'Sistema Eléctrico' UNION ALL
SELECT id, 'Sistema de carga', 'Verificar voltaje en reposo y marcha', 5 FROM inspection_categories WHERE name = 'Sistema Eléctrico' UNION ALL
SELECT id, 'Ventanas eléctricas', 'Prueba en todas las ventanas', 6 FROM inspection_categories WHERE name = 'Sistema Eléctrico' UNION ALL
SELECT id, 'Espejos eléctricos', 'Verificar ajuste', 7 FROM inspection_categories WHERE name = 'Sistema Eléctrico' UNION ALL
SELECT id, 'Cierre centralizado', 'Prueba de apertura/cierre', 8 FROM inspection_categories WHERE name = 'Sistema Eléctrico' UNION ALL
SELECT id, 'Tablero de instrumentos', 'Verificar testigos', 9 FROM inspection_categories WHERE name = 'Sistema Eléctrico' UNION ALL
SELECT id, 'Sensor de retroceso', 'Prueba de funcionamiento', 10 FROM inspection_categories WHERE name = 'Sistema Eléctrico';

-- CAT 6: Carrocería y Pintura
INSERT INTO inspection_items (category_id, name, description, display_order)
SELECT id, 'Capó', 'Alineación y cierre', 1 FROM inspection_categories WHERE name = 'Carrocería y Pintura' UNION ALL
SELECT id, 'Puertas (4)', 'Apertura, cierre y alineación', 2 FROM inspection_categories WHERE name = 'Carrocería y Pintura' UNION ALL
SELECT id, 'Baúl / Maletero', 'Apertura y cierre', 3 FROM inspection_categories WHERE name = 'Carrocería y Pintura' UNION ALL
SELECT id, 'Pintura general', 'Inspeccionar rayones, abolladuras, óxido', 4 FROM inspection_categories WHERE name = 'Carrocería y Pintura' UNION ALL
SELECT id, 'Parabrisas', 'Verificar estrellas y rayaduras', 5 FROM inspection_categories WHERE name = 'Carrocería y Pintura' UNION ALL
SELECT id, 'Guardafangos', 'Verificar estado', 6 FROM inspection_categories WHERE name = 'Carrocería y Pintura' UNION ALL
SELECT id, 'Parachoques', 'Verificar fisuras', 7 FROM inspection_categories WHERE name = 'Carrocería y Pintura' UNION ALL
SELECT id, 'Parte baja', 'Inspeccionar óxido y daños', 8 FROM inspection_categories WHERE name = 'Carrocería y Pintura' UNION ALL
SELECT id, 'Medición de pintura', 'Uso de medidor de espesor', 9 FROM inspection_categories WHERE name = 'Carrocería y Pintura';

-- CAT 7: Interior
INSERT INTO inspection_items (category_id, name, description, display_order)
SELECT id, 'Asientos delanteros', 'Verificar ajustes y estado', 1 FROM inspection_categories WHERE name = 'Interior y Tapicería' UNION ALL
SELECT id, 'Asientos traseros', 'Verificar estado', 2 FROM inspection_categories WHERE name = 'Interior y Tapicería' UNION ALL
SELECT id, 'Tapicería de puertas', 'Verificar desgaste', 3 FROM inspection_categories WHERE name = 'Interior y Tapicería' UNION ALL
SELECT id, 'Alfombras', 'Estado y limpieza', 4 FROM inspection_categories WHERE name = 'Interior y Tapicería' UNION ALL
SELECT id, 'Techo interior', 'Verificar estado', 5 FROM inspection_categories WHERE name = 'Interior y Tapicería' UNION ALL
SELECT id, 'Volante', 'Desgaste y funcionamiento', 6 FROM inspection_categories WHERE name = 'Interior y Tapicería' UNION ALL
SELECT id, 'Palanca de cambios', 'Estado y funcionamiento', 7 FROM inspection_categories WHERE name = 'Interior y Tapicería' UNION ALL
SELECT id, 'Cinturones de seguridad', 'Retracción y cierre', 8 FROM inspection_categories WHERE name = 'Interior y Tapicería' UNION ALL
SELECT id, 'Sistema de sonido', 'Radio, parlantes y conexiones', 9 FROM inspection_categories WHERE name = 'Interior y Tapicería' UNION ALL
SELECT id, 'Olor interior', 'Detectar humedad o tabaco', 10 FROM inspection_categories WHERE name = 'Interior y Tapicería';

-- CAT 8: Neumáticos
INSERT INTO inspection_items (category_id, name, description, display_order)
SELECT id, 'Presión de neumáticos', 'Verificar en frío', 1 FROM inspection_categories WHERE name = 'Neumáticos y Ruedas' UNION ALL
SELECT id, 'Profundidad de dibujo', 'Mínimo 1.6mm legal', 2 FROM inspection_categories WHERE name = 'Neumáticos y Ruedas' UNION ALL
SELECT id, 'Desgaste irregular', 'Inspeccionar banda de rodadura', 3 FROM inspection_categories WHERE name = 'Neumáticos y Ruedas' UNION ALL
SELECT id, 'Llantas de aleación', 'Verificar daños', 4 FROM inspection_categories WHERE name = 'Neumáticos y Ruedas' UNION ALL
SELECT id, 'Neumático de repuesto', 'Presión y estado', 5 FROM inspection_categories WHERE name = 'Neumáticos y Ruedas' UNION ALL
SELECT id, 'Tuercas de rueda', 'Verificar torque', 6 FROM inspection_categories WHERE name = 'Neumáticos y Ruedas' UNION ALL
SELECT id, 'Fecha de fabricación', 'Código DOT', 7 FROM inspection_categories WHERE name = 'Neumáticos y Ruedas' UNION ALL
SELECT id, 'Válvulas', 'Verificar fugas', 8 FROM inspection_categories WHERE name = 'Neumáticos y Ruedas' UNION ALL
SELECT id, 'Alineación delantera', 'Desgaste uniforme', 9 FROM inspection_categories WHERE name = 'Neumáticos y Ruedas';

-- CAT 9: Refrigeración
INSERT INTO inspection_items (category_id, name, description, display_order)
SELECT id, 'Nivel de refrigerante', 'Verificar nivel y concentración', 1 FROM inspection_categories WHERE name = 'Sistema de Refrigeración' UNION ALL
SELECT id, 'Radiador', 'Verificar fugas y estado', 2 FROM inspection_categories WHERE name = 'Sistema de Refrigeración' UNION ALL
SELECT id, 'Termostato', 'Prueba de apertura', 3 FROM inspection_categories WHERE name = 'Sistema de Refrigeración' UNION ALL
SELECT id, 'Ventilador eléctrico', 'Prueba de funcionamiento', 4 FROM inspection_categories WHERE name = 'Sistema de Refrigeración' UNION ALL
SELECT id, 'Mangueras del radiador', 'Revisar grietas', 5 FROM inspection_categories WHERE name = 'Sistema de Refrigeración' UNION ALL
SELECT id, 'Tapa del radiador', 'Verificar sello', 6 FROM inspection_categories WHERE name = 'Sistema de Refrigeración' UNION ALL
SELECT id, 'Bomba de agua', 'Verificar fugas', 7 FROM inspection_categories WHERE name = 'Sistema de Refrigeración' UNION ALL
SELECT id, 'Temperatura en marcha', 'Prueba en carretera', 8 FROM inspection_categories WHERE name = 'Sistema de Refrigeración' UNION ALL
SELECT id, 'Depósito de expansión', 'Verificar estado', 9 FROM inspection_categories WHERE name = 'Sistema de Refrigeración';

-- CAT 10: Escape
INSERT INTO inspection_items (category_id, name, description, display_order)
SELECT id, 'Múltiple de escape', 'Verificar grietas', 1 FROM inspection_categories WHERE name = 'Escape y Emisiones' UNION ALL
SELECT id, 'Catalizador', 'Verificar obstrucción', 2 FROM inspection_categories WHERE name = 'Escape y Emisiones' UNION ALL
SELECT id, 'Silenciador', 'Estado y fugas', 3 FROM inspection_categories WHERE name = 'Escape y Emisiones' UNION ALL
SELECT id, 'Tubo de escape', 'Verificar óxido y perforaciones', 4 FROM inspection_categories WHERE name = 'Escape y Emisiones' UNION ALL
SELECT id, 'Sondas lambda', 'Verificar lecturas', 5 FROM inspection_categories WHERE name = 'Escape y Emisiones' UNION ALL
SELECT id, 'Sistema EGR', 'Verificar funcionamiento', 6 FROM inspection_categories WHERE name = 'Escape y Emisiones' UNION ALL
SELECT id, 'Filtro de partículas (DPF)', 'Verificar estado', 7 FROM inspection_categories WHERE name = 'Escape y Emisiones' UNION ALL
SELECT id, 'Soportes de escape', 'Verificar roturas', 8 FROM inspection_categories WHERE name = 'Escape y Emisiones' UNION ALL
SELECT id, 'Prueba de emisiones', 'Medición de gases', 9 FROM inspection_categories WHERE name = 'Escape y Emisiones';

-- CAT 11: A/C
INSERT INTO inspection_items (category_id, name, description, display_order)
SELECT id, 'Carga de refrigerante', 'Verificar nivel', 1 FROM inspection_categories WHERE name = 'Sistema de Aire Acondicionado' UNION ALL
SELECT id, 'Compresor de A/C', 'Prueba de embrague y funcionamiento', 2 FROM inspection_categories WHERE name = 'Sistema de Aire Acondicionado' UNION ALL
SELECT id, 'Temperatura del aire', 'Medir en salida de ventila', 3 FROM inspection_categories WHERE name = 'Sistema de Aire Acondicionado' UNION ALL
SELECT id, 'Filtro de cabina', 'Verificar estado', 4 FROM inspection_categories WHERE name = 'Sistema de Aire Acondicionado' UNION ALL
SELECT id, 'Condensador', 'Verificar limpieza y fugas', 5 FROM inspection_categories WHERE name = 'Sistema de Aire Acondicionado' UNION ALL
SELECT id, 'Ventilador interior', 'Prueba de velocidades', 6 FROM inspection_categories WHERE name = 'Sistema de Aire Acondicionado' UNION ALL
SELECT id, 'Calefacción', 'Prueba de funcionamiento', 7 FROM inspection_categories WHERE name = 'Sistema de Aire Acondicionado' UNION ALL
SELECT id, 'Controles de clima', 'Verificar panel', 8 FROM inspection_categories WHERE name = 'Sistema de Aire Acondicionado' UNION ALL
SELECT id, 'Fugas en evaporador', 'Inspeccionar', 9 FROM inspection_categories WHERE name = 'Sistema de Aire Acondicionado';

-- CAT 12: Luces
INSERT INTO inspection_items (category_id, name, description, display_order)
SELECT id, 'Faros delanteros', 'Funcionamiento y alineación', 1 FROM inspection_categories WHERE name = 'Luces y Señalización' UNION ALL
SELECT id, 'Luces traseras', 'Funcionamiento', 2 FROM inspection_categories WHERE name = 'Luces y Señalización' UNION ALL
SELECT id, 'Direccionales', 'Verificar 4 direcciones', 3 FROM inspection_categories WHERE name = 'Luces y Señalización' UNION ALL
SELECT id, 'Luces de freno', 'Verificar intensidad', 4 FROM inspection_categories WHERE name = 'Luces y Señalización' UNION ALL
SELECT id, 'Luces antiniebla', 'Funcionamiento', 5 FROM inspection_categories WHERE name = 'Luces y Señalización' UNION ALL
SELECT id, 'Luz de marcha atrás', 'Verificar', 6 FROM inspection_categories WHERE name = 'Luces y Señalización' UNION ALL
SELECT id, 'Luz de placa', 'Verificar', 7 FROM inspection_categories WHERE name = 'Luces y Señalización' UNION ALL
SELECT id, 'Luces de cortesía', 'Interior', 8 FROM inspection_categories WHERE name = 'Luces y Señalización' UNION ALL
SELECT id, 'Ajuste de altura de faros', 'Verificar', 9 FROM inspection_categories WHERE name = 'Luces y Señalización';

-- CAT 13: Visibilidad
INSERT INTO inspection_items (category_id, name, description, display_order)
SELECT id, 'Limpiaparabrisas delantero', 'Funcionamiento y estado de escobillas', 1 FROM inspection_categories WHERE name = 'Limpiaparabrisas y Visibilidad' UNION ALL
SELECT id, 'Limpiaparabrisas trasero', 'Funcionamiento', 2 FROM inspection_categories WHERE name = 'Limpiaparabrisas y Visibilidad' UNION ALL
SELECT id, 'Líquido lavaparabrisas', 'Nivel', 3 FROM inspection_categories WHERE name = 'Limpiaparabrisas y Visibilidad' UNION ALL
SELECT id, 'Espejo retrovisor interior', 'Ajuste y estado', 4 FROM inspection_categories WHERE name = 'Limpiaparabrisas y Visibilidad' UNION ALL
SELECT id, 'Espejos laterales', 'Ajuste y estado', 5 FROM inspection_categories WHERE name = 'Limpiaparabrisas y Visibilidad' UNION ALL
SELECT id, 'Desempañador trasero', 'Prueba de funcionamiento', 6 FROM inspection_categories WHERE name = 'Limpiaparabrisas y Visibilidad' UNION ALL
SELECT id, 'Desempañador delantero', 'Prueba de funcionamiento', 7 FROM inspection_categories WHERE name = 'Limpiaparabrisas y Visibilidad' UNION ALL
SELECT id, 'Visibilidad general', 'Campo visual del conductor', 8 FROM inspection_categories WHERE name = 'Limpiaparabrisas y Visibilidad';

-- CAT 14: Seguridad
INSERT INTO inspection_items (category_id, name, description, display_order)
SELECT id, 'Airbags frontales', 'Verificar testigo en tablero', 1 FROM inspection_categories WHERE name = 'Seguridad y Airbags' UNION ALL
SELECT id, 'Airbags laterales', 'Verificar testigo', 2 FROM inspection_categories WHERE name = 'Seguridad y Airbags' UNION ALL
SELECT id, 'Pretensores de cinturón', 'Verificar funcionamiento', 3 FROM inspection_categories WHERE name = 'Seguridad y Airbags' UNION ALL
SELECT id, 'Sensor de estacionamiento', 'Prueba', 4 FROM inspection_categories WHERE name = 'Seguridad y Airbags' UNION ALL
SELECT id, 'Cámara de retroceso', 'Verificar imagen y guías', 5 FROM inspection_categories WHERE name = 'Seguridad y Airbags' UNION ALL
SELECT id, 'Control de estabilidad (ESC)', 'Verificar testigo', 6 FROM inspection_categories WHERE name = 'Seguridad y Airbags' UNION ALL
SELECT id, 'Control de tracción (TCS)', 'Verificar testigo', 7 FROM inspection_categories WHERE name = 'Seguridad y Airbags' UNION ALL
SELECT id, 'Alarma antirrobo', 'Prueba de funcionamiento', 8 FROM inspection_categories WHERE name = 'Seguridad y Airbags' UNION ALL
SELECT id, 'Inmovilizador', 'Verificar funcionamiento', 9 FROM inspection_categories WHERE name = 'Seguridad y Airbags' UNION ALL
SELECT id, 'Kit de carretera', 'Verificar presencia', 10 FROM inspection_categories WHERE name = 'Seguridad y Airbags';

-- CAT 15: Documentación
INSERT INTO inspection_items (category_id, name, description, display_order)
SELECT id, 'Matrícula / Placa', 'Verificar estado y vigencia', 1 FROM inspection_categories WHERE name = 'Documentación' UNION ALL
SELECT id, 'Certificado de circulación', 'Vigente', 2 FROM inspection_categories WHERE name = 'Documentación' UNION ALL
SELECT id, 'Revisión técnica (RTV)', 'Vigente', 3 FROM inspection_categories WHERE name = 'Documentación' UNION ALL
SELECT id, 'Seguro vehicular', 'Vigente', 4 FROM inspection_categories WHERE name = 'Documentación' UNION ALL
SELECT id, 'Historial CARFAX', 'Verificar reporte', 5 FROM inspection_categories WHERE name = 'Documentación' UNION ALL
SELECT id, 'Multas pendientes', 'Verificar en línea', 6 FROM inspection_categories WHERE name = 'Documentación' UNION ALL
SELECT id, 'Manual del propietario', 'Presente', 7 FROM inspection_categories WHERE name = 'Documentación' UNION ALL
SELECT id, 'Llave de repuesto', 'Verificar', 8 FROM inspection_categories WHERE name = 'Documentación' UNION ALL
SELECT id, 'Kit de herramientas', 'Verificar presencia', 9 FROM inspection_categories WHERE name = 'Documentación' UNION ALL
SELECT id, 'Tarjeta de garantía', 'Vigente', 10 FROM inspection_categories WHERE name = 'Documentación';
