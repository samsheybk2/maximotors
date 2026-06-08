export interface Agent {
  id: string;
  user_id: string;
  full_name: string;
  email: string;
  phone: string | null;
  avatar_url: string | null;
  created_at: string;
}

export interface Client {
  id: string;
  agent_id: string | null;
  full_name: string;
  email: string | null;
  phone: string | null;
  id_type: 'cedula' | 'pasaporte' | null;
  id_number: string | null;
  address: string | null;
  city: string;
  notes: string | null;
  created_at: string;
}

export interface Vehicle {
  id: string;
  agent_id: string | null;
  client_id: string | null;
  brand: string;
  model: string;
  year: number;
  vin: string | null;
  license_plate: string | null;
  mileage: number | null;
  color: string | null;
  fuel_type: 'gasolina' | 'diesel' | 'hibrido' | 'electrico' | null;
  transmission: 'manual' | 'automatica' | null;
  price: number | null;
  status: 'disponible' | 'vendido' | 'en_proceso' | 'reservado';
  image_url: string | null;
  notes: string | null;
  created_at: string;
}

export interface InspectionCategory {
  id: string;
  name: string;
  display_order: number;
  icon: string | null;
}

export interface InspectionItem {
  id: string;
  category_id: string;
  name: string;
  description: string | null;
  display_order: number;
}

export interface Inspection {
  id: string;
  vehicle_id: string;
  agent_id: string | null;
  status: 'en_progreso' | 'completada';
  summary: string | null;
  created_at: string;
  completed_at: string | null;
}

export interface InspectionResult {
  id: string;
  inspection_id: string;
  item_id: string;
  result: 'aprobado' | 'rechazado' | 'observacion' | null;
  notes: string | null;
  image_url: string | null;
  checked_at: string;
}
