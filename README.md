# Photobook

Aplicación Rails para publicar fotografías. Los visitantes ven las diez publicaciones más recientes y sus detalles. Los usuarios pueden registrarse, iniciar/cerrar sesión, recuperar contraseñas, editar su perfil y gestionar sus propias publicaciones.

## Stack y requisitos

- Ruby **3.3.13** (`.ruby-version`), Bundler **2.5.22**.
- Rails **8.1.4**, Devise **5.0.4**, SQLite **2.10.2** (gema), Puma **8.0.2**.
- Active Storage, image_processing 2.2 y ruby-vips 2.3 (con libvips instalado) para imágenes; Propshaft y CSS sin compilador Sass ni Node.
- RSpec Rails 8, FactoryBot y Capybara con RackTest.
- Compilador C y headers para las gemas nativas. En macOS: Command Line Tools y `brew install vips`.

## Instalación local

Con Ruby ya instalado mediante rbenv:

```sh
ruby -v
bundle _2.5.22_ install
bin/rails db:prepare
bin/rails server
```

Abrir <http://localhost:3000>. `bin/setup` instala dependencias faltantes y ejecuta `db:prepare`; no borra bases, logs ni archivos. Una instalación nueva carga el esquema generado. Las migraciones completas desde cero también están verificadas.

En este equipo, Xcode no pudo enlazar contra el SDK 27. Se resolvió la instalación usando un SDK existente, sin modificar `xcode-select` ni rbenv:

```sh
SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk bundle _2.5.22_ install
```

Aplicar ese comando solo si ese SDK está instalado y se reproduce el mismo error. La configuración local de Bundler usada para validar instala en `vendor/bundle`, ignorado por Git.

## Configuración

Desarrollo y pruebas generan sus secretos locales automáticamente; no requieren `.env`. Rails no carga archivos `.env` por sí solo. Exportar variables en el proceso o configurarlas en el entorno del contenedor.

| Variable | Uso |
| --- | --- |
| `RAILS_ENV` | `development` por defecto; `production` en Docker |
| `SECRET_KEY_BASE` | Secreto aleatorio obligatorio en producción (`bin/rails secret`); nunca versionarlo |
| `APP_HOST` | Dominio sin esquema ni puerto; obligatorio en producción, restringe hosts y genera enlaces de correo |
| `MAILER_FROM` | Remitente; configurar una dirección real en producción |
| `SMTP_ADDRESS` | Servidor SMTP, obligatorio en producción |
| `SMTP_PORT` | Puerto SMTP, 587 por defecto |
| `SMTP_USERNAME`, `SMTP_PASSWORD` | Credenciales SMTP cuando el servidor las requiere |
| `DATABASE_PATH` | SQLite de producción; `storage/production.sqlite3` por defecto |
| `PORT`, `RAILS_MAX_THREADS` | Puma, 3000 y 5 por defecto |
| `LEGACY_PHOTO_ROOT`, `MODE` | Importación de originales Paperclip; ver abajo |

En desarrollo, los correos se escriben en `tmp/mails`; en pruebas quedan en memoria. Producción requiere SMTP y HTTPS delante de Puma. Conservar `SECRET_KEY_BASE` entre reinicios y respaldar juntos SQLite y `storage/`. La cola inline ejecuta análisis/purgas sin infraestructura adicional; en pruebas se utiliza el adaptador test.

## Fotografías y autorización

Se aceptan JPEG, PNG y WebP de hasta **10 MiB** y **40 megapíxeles**. Se inspeccionan los bytes y se comprueba que libvips pueda leer la imagen; no se confía en la extensión ni en el MIME del navegador. SVG no se acepta. Los formularios suben archivos mediante el servidor; no utilizan cargas directas ni identificadores de blobs enviados por el cliente.

Active Storage conserva el original en `storage/`. Las variantes `large` (600 × 600), `medium` (300 × 300) y `thumb` (100 × 100) usan límites de tamaño: mantienen la proporción y no amplían imágenes pequeñas. Se generan al solicitarlas. Borrar una publicación purga su fotografía; cancelar una cuenta elimina sus publicaciones y adjuntos.

Las publicaciones y sus imágenes son públicas. Crear exige autenticación. Editar, actualizar y borrar publicaciones ajenas devuelve **403**; visitantes que intentan esas acciones son enviados al login. `user_id` se obtiene de la sesión y no se permite en parámetros. Eliminar la única fotografía sin reemplazarla no es válido: para conservar la publicación hay que adjuntar otra imagen.

## Pruebas y calidad

```sh
RAILS_ENV=test bin/rails db:prepare
bundle exec rspec
RAILS_ENV=test bin/rails runner script/verify_migrations.rb
bin/rails zeitwerk:check
bundle exec rubocop
bundle exec brakeman --no-pager
bundle exec bundler-audit check --update
```

El script de migraciones usa exclusivamente una base SQLite temporal y prueba instalación desde migraciones, conservación de datos de 2016, detección de huérfanos, restricciones, rollback y reaplicación. Los antiguos escenarios Cucumber tienen equivalentes en `spec/features/signup_spec.rb`; ya no se necesita un segundo framework BDD ni Database Cleaner.

GitHub Actions comprueba primero la carga de `vips` y `image_processing/vips`, y ejecuta estos controles en PR y pushes a `main`/`master`. `ruby-vips` se declara explícitamente porque image_processing 2.x ya no instala automáticamente su backend. Dependabot revisa RubyGems y acciones semanalmente. Los resultados locales están documentados en [MIGRATION.md](MIGRATION.md); no certifican el estado remoto de Dependabot.

## Datos y fotografías legacy

Antes de actualizar una instalación existente: detener escrituras, respaldar de forma consistente SQLite y los originales Paperclip, y probar la actualización en una copia. **No ejecutar `db:reset` ni `db:drop`.**

```sh
bin/rails db:migrate
LEGACY_PHOTO_ROOT=/ruta/backup/posts/photos MODE=dry_run bin/rails legacy_photos:migrate
LEGACY_PHOTO_ROOT=/ruta/backup/posts/photos MODE=import bin/rails legacy_photos:migrate
LEGACY_PHOTO_ROOT=/ruta/backup/posts/photos MODE=verify bin/rails legacy_photos:migrate
```

La raíz contiene las particiones de ID (`000/000/001/original/foto.jpg`). Por defecto se busca `public/system/posts/photos`. Primero localizar los originales: no sustituirlos por thumbnails. El importador es idempotente, rechaza rutas fuera de la raíz, no sobrescribe adjuntos existentes y no borra archivos ni columnas legacy. `verify` compara checksums del original y de los bytes almacenados, y procesa las tres variantes. Cualquier fallo produce salida no exitosa con ID de publicación y clase de error; revisar de forma privada los datos de ese registro.

Si faltan originales o hay títulos/perfiles inválidos, resolverlos antes de completar la importación. Una publicación aún no migrada muestra su texto sin imagen. Los procedimientos de huérfanos, backup y rollback están en [MIGRATION.md](MIGRATION.md).

## Docker

```sh
docker build -t photobook:modernized .
bin/verify-container
docker volume create photobook-storage
docker run --rm -p 3000:3000 --env-file /ruta/privada/photobook.env \
  -v photobook-storage:/rails/storage photobook:modernized
```

`bin/verify-container` verifica HTTP de producción, UID 1000, SQLite, carga, variantes y purga en un contenedor descartable, sin puertos publicados ni volúmenes. Usa una clave dummy exclusivamente en esa prueba.

El archivo de entorno privado debe definir `SECRET_KEY_BASE`, `APP_HOST`, `SMTP_ADDRESS`, `MAILER_FROM` y las credenciales SMTP necesarias. No incluirlo en Git. El contenedor aplica `db:prepare` al iniciar Puma, ejecuta como UID/GID 1000 y guarda SQLite y adjuntos en el volumen. Usa HTTPS en el proxy; HTTP directo redirige a HTTPS. Para bind mounts, dar escritura al UID 1000. No montar ni migrar la base real hasta probar una copia.

Para desarrollo reproducible con SQLite y sin SMTP, usar la misma imagen con `RAILS_ENV=development` (las dependencias de test no están incluidas):

```sh
docker run --rm -p 3000:3000 -e RAILS_ENV=development \
  -v photobook-storage:/rails/storage -e DATABASE_URL=sqlite3:/rails/storage/development.sqlite3 \
  photobook:modernized
```

## Seguridad y operación

CSRF está activo fuera de las pruebas ordinarias y tiene una prueba específica con protección habilitada. Las vistas escapan contenido, las cookies son HttpOnly/SameSite y Secure en producción, y hay CSP sin scripts externos. Los parámetros de credenciales, tokens y perfil se filtran de logs. No publicar secretos; las antiguas claves de desarrollo/pruebas versionadas se retiraron y las sesiones usan una nueva cookie.

Las cuentas existentes conservan sus hashes bcrypt y datos. Los nuevos passwords requieren al menos ocho caracteres; los hashes de contraseñas antiguas de seis caracteres siguen autenticando. Se mantiene validación de formato/unicidad del email: el proyecto original no usaba `confirmable` ni tenía columnas de confirmación, por lo que no se fuerza una confirmación retroactiva.

## Autor

[Geovanny Mendoza](https://geovannycode.com/) · [GitHub](https://github.com/geovannymcode) · [X](https://x.com/geovannycode) · [LinkedIn](https://www.linkedin.com/in/geovannycode/) · [Bluesky](https://bsky.app/profile/geovannycode.bsky.social)
