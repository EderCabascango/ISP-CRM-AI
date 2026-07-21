# 🌐 ISP CRM AI — Módulo: App Cliente Wi-Fi

<div align="center">

![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.9-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![Android](https://img.shields.io/badge/Android-API%2029+-3DDC84?style=for-the-badge&logo=android&logoColor=white)
![Architecture](https://img.shields.io/badge/Architecture-Clean%20%2B%20BLoC-purple?style=for-the-badge)
![Status](https://img.shields.io/badge/Estado-En%20Desarrollo%20Activo-orange?style=for-the-badge)

**Aplicación móvil para clientes de proveedores de internet (ISP).**  
Permite gestionar la red Wi-Fi del hogar, visualizar dispositivos conectados y preparar la base para la integración con el CRM central impulsado por IA.

</div>

---

## 🗺️ Visión General del Proyecto ISP CRM AI

> ⚠️ **Este repositorio contiene únicamente el módulo de App Cliente (Flutter/Android).**  
> Es uno de los componentes de un sistema CRM completo para ISPs.

```
ISP CRM AI — Ecosistema Completo
│
├── 📱 isp-app (Este repositorio)
│   └── App Android/iOS para clientes del ISP
│       ├── Escaneo de red local (Wi-Fi)
│       ├── Gestión de dispositivos conectados
│       └── Configuración de ONT/Router
│
├── 🧠 isp-crm-backend (próximamente)
│   └── API REST + Motor de IA
│       ├── Agentes de IA para gestión de usuarios
│       ├── Predicción de fallos de red
│       └── Automatización de soporte técnico
│
├── 🖥️ isp-crm-dashboard (próximamente)
│   └── Panel de administración web para el ISP
│       ├── CRM de clientes y contratos
│       ├── Monitoreo de red en tiempo real
│       └── Reportes y métricas con IA
│
└── 🤖 isp-ai-agents (próximamente)
    └── Agentes autónomos de IA
        ├── Agente de atención al cliente (chatbot)
        ├── Agente de diagnóstico de red
        └── Agente de renovación/cobranza automática
```

---

## 📱 Módulo Actual: App Cliente Wi-Fi

### ¿Qué hace esta app?

La aplicación permite a los clientes del ISP:

- **Iniciar sesión** con sus credenciales del servicio
- **Escanear su red local** y ver todos los dispositivos conectados al Wi-Fi del hogar en tiempo real (< 2 segundos)
- **Gestionar la configuración Wi-Fi** de su ONT (2.4GHz y 5GHz)
- **Identificar dispositivos no autorizados** conectados a su red

---

## ✨ Funcionalidades Implementadas

### 🔐 Autenticación
- Pantalla de login con validación de formulario
- Gestión de sesión segura con `flutter_secure_storage`
- Indicador visual de versión de compilación (para QA/testing)

### 📡 Escáner de Red Local (Motor Principal)
El corazón de la app. Detecta **todos los dispositivos activos** en la subred Wi-Fi usando una estrategia multicapa:

| Fase | Técnica | Propósito |
|------|---------|-----------|
| 1 | **UDP Broadcast** a puertos 137 (NetBIOS) y 5353 (mDNS) | Despertar servicios de descubrimiento en Windows y Android |
| 2 | **TCP Socket Paralelo** a 254 IPs simultáneamente | Detección directa de dispositivos activos |
| 3 | **Análisis de respuesta TCP** (Open / Explicit RST) | Identificar hosts reales sin falsos positivos |

**Puertos TCP analizados**: `135, 139, 445, 5357, 80, 443, 5353, 8080`

**Timeout por socket**: 250ms — tiempo suficiente para laptops con firewall activo.

**Dispositivos detectables**:
- ✅ Routers / Gateways
- ✅ PCs y Laptops Windows (incluso con Firewall activo)
- ✅ Smartphones Android / iOS
- ✅ Smart TVs y Chromecasts
- ✅ Impresoras y dispositivos IoT
- ✅ El propio teléfono Android

### 🛜 Configuración Wi-Fi
- Pantalla de configuración de red 2.4GHz y 5GHz
- Preparada para integración con API REST del ONT

### 🖥️ Lista de Dispositivos Conectados
- Vista de tarjetas con información de cada dispositivo
- Filtros por tipo de interfaz
- Identificación automática del tipo de equipo

---

## 🏗️ Arquitectura

La app sigue **Clean Architecture** con organización **Feature-First**:

```
lib/
│
├── app/                          # Configuración global de la app
│   ├── config/
│   │   ├── routes/               # go_router — Rutas y navegación
│   │   └── version_config.dart   # Control de versión de compilación
│   └── di/
│       └── injection.dart        # Inyección de dependencias (get_it)
│
├── core/                         # Utilidades y código compartido
│   ├── error/
│   │   ├── exceptions.dart       # Excepciones de dominio
│   │   └── failures.dart         # Failures (fpdart Either)
│   └── network/
│       └── network_info.dart     # Verificación de conectividad
│
└── features/                     # Módulos por funcionalidad
    ├── auth/                     # Autenticación
    │   ├── data/                 # DataSources + Repository Impl
    │   ├── domain/               # Entities + UseCases + Repository (interfaz)
    │   └── presentation/         # BLoC + Screens + Widgets
    │
    ├── devices/                  # Gestión de dispositivos conectados
    │   ├── data/
    │   │   ├── datasources/
    │   │   │   └── device_local_scanner_datasource.dart  ← Motor de escaneo
    │   │   └── repositories/
    │   ├── domain/
    │   └── presentation/
    │
    ├── wifi/                     # Configuración Wi-Fi (ONT)
    │   ├── data/
    │   ├── domain/
    │   └── presentation/
    │
    └── home/                     # Pantalla principal / Dashboard
        └── presentation/
```

### Patrón de Estado

```
UI Widget → BLoC / Cubit → UseCase → Repository → DataSource
                                                       ↑
                                              (Local Scanner / Mock / REST API)
```

---

## 🔧 Stack Tecnológico

| Categoría | Paquete | Versión | Uso |
|-----------|---------|---------|-----|
| **Estado** | `flutter_bloc` | ^8.1.6 | BLoC / Cubit pattern |
| **Navegación** | `go_router` | ^14.2.1 | Routing declarativo |
| **HTTP Client** | `dio` | ^5.5.0 | Peticiones a la API REST |
| **DI** | `get_it` + `injectable` | ^7.7 / ^2.4 | Inyección de dependencias |
| **FP** | `fpdart` | ^1.1.0 | Either / Option (manejo de errores) |
| **Modelos** | `equatable` | ^2.0.5 | Comparación de entidades |
| **Almacenamiento** | `flutter_secure_storage` | ^9.2.2 | Tokens / sesión segura |
| **Red** | `network_info_plus` | ^6.0.0 | IP local del Wi-Fi |
| **Permisos** | `permission_handler` | ^11.3.1 | Permisos de ubicación (Android) |

---

## 🚀 Cómo Ejecutar el Proyecto

### Requisitos Previos

- [Flutter SDK](https://flutter.dev/docs/get-started/install) `>= 3.x`
- Dart SDK `>= 3.9`
- Android Studio o VS Code con extensión Flutter
- Dispositivo Android físico (recomendado) o emulador con API 29+

### Instalación

```bash
# 1. Clonar el repositorio
git clone https://github.com/EderCabascango/ISP-CRM-AI.git
cd ISP-CRM-AI

# 2. Instalar dependencias
flutter pub get

# 3. Ejecutar en modo debug (con dispositivo conectado)
flutter run

# 4. Compilar APK de debug
flutter build apk --debug
# → El APK se genera en: build/app/outputs/flutter-apk/app-debug.apk
```

### Permisos Requeridos en Android

La app solicita los siguientes permisos en tiempo de ejecución:

| Permiso | Motivo |
|---------|--------|
| `ACCESS_FINE_LOCATION` | Requerido por Android para leer el SSID y la IP del Wi-Fi |
| `ACCESS_COARSE_LOCATION` | Complementario para acceso a info de red |
| `ACCESS_NETWORK_STATE` | Verificar estado de conectividad |
| `ACCESS_WIFI_STATE` | Leer información del punto de acceso Wi-Fi |
| `CHANGE_WIFI_MULTICAST_STATE` | Permitir paquetes multicast (mDNS) |

> **Nota**: En Android 10+, el permiso de ubicación es obligatorio para obtener la dirección IP del Wi-Fi. Es un requisito del sistema operativo, no de la app.

---

## 🔮 Roadmap — Próximas Funcionalidades

### Módulo App Cliente (Este repo)
- [ ] Integración con API REST del backend para leer datos reales del ONT
- [ ] Notificaciones push cuando se conecta un dispositivo desconocido
- [ ] Historial de dispositivos conectados
- [ ] Velocímetro de red (test de velocidad Wi-Fi)
- [ ] Soporte para múltiples idiomas (i18n)
- [ ] Modo oscuro / claro

### Ecosistema CRM (Futuros repositorios)
- [ ] **Backend API** — FastAPI/Node.js con integración a base de datos de clientes
- [ ] **Agente de IA para Soporte** — Chatbot entrenado en troubleshooting de red
- [ ] **Agente de Diagnóstico** — Detecta fallos antes de que el cliente los reporte
- [ ] **Agente de Cobranza** — Automatiza recordatorios de pago y renovaciones
- [ ] **Dashboard Web** — Panel de control para el equipo de soporte del ISP
- [ ] **Sistema de Tickets** — Gestión de incidencias con clasificación automática por IA

---

## 📂 Estructura del Proyecto (Árbol Completo)

```
ISP-APP/
├── android/
│   └── app/src/main/
│       └── AndroidManifest.xml      # Permisos de red y ubicación
├── lib/
│   ├── main.dart                    # Punto de entrada, MaterialApp
│   ├── app/
│   │   ├── config/
│   │   │   ├── routes/app_router.dart
│   │   │   └── version_config.dart
│   │   └── di/injection.dart
│   ├── core/
│   │   ├── error/exceptions.dart
│   │   ├── error/failures.dart
│   │   └── network/network_info.dart
│   └── features/
│       ├── auth/
│       │   ├── data/datasources/auth_mock_datasource.dart
│       │   ├── data/repositories/auth_repository_impl.dart
│       │   ├── domain/entities/user_session.dart
│       │   ├── domain/repositories/auth_repository.dart
│       │   ├── presentation/bloc/auth_bloc.dart
│       │   └── presentation/screens/login_screen.dart
│       ├── devices/
│       │   ├── data/datasources/device_local_scanner_datasource.dart  ⭐
│       │   ├── data/repositories/device_repository_impl.dart
│       │   ├── domain/entities/connected_device.dart
│       │   ├── presentation/bloc/devices_bloc.dart
│       │   └── presentation/screens/devices_screen.dart
│       ├── wifi/
│       │   ├── data/datasources/wifi_mock_datasource.dart
│       │   ├── domain/entities/wifi_network.dart
│       │   ├── presentation/cubit/wifi_cubit.dart
│       │   └── presentation/screens/wifi_settings_screen.dart
│       └── home/
│           └── presentation/screens/home_screen.dart
├── pubspec.yaml
└── README.md
```

---

## 🤝 Contribuir

Este proyecto está en desarrollo activo. Si quieres contribuir:

1. Haz un **fork** del repositorio
2. Crea una rama: `git checkout -b feature/nombre-funcionalidad`
3. Commit tus cambios: `git commit -m 'feat: descripción del cambio'`
4. Push a tu rama: `git push origin feature/nombre-funcionalidad`
5. Abre un **Pull Request**

### Convención de commits
Usamos [Conventional Commits](https://www.conventionalcommits.org/):
- `feat:` Nueva funcionalidad
- `fix:` Corrección de bug
- `refactor:` Refactorización de código
- `docs:` Cambios en documentación
- `test:` Añadir o modificar tests

---

## 📄 Licencia

Este proyecto es propiedad privada y está bajo desarrollo. Contactar al equipo de desarrollo antes de usar o distribuir.

---

<div align="center">

**ISP CRM AI** — Construyendo el futuro de la gestión de proveedores de internet con Inteligencia Artificial.

*Desarrollado con ❤️ usando Flutter + Dart*

</div>
