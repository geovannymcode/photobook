# Migración de Photobook

Fecha de validación: **27 de octubre de 2026**. Rama: `chore/modernize-dependencies`.

## Decisiones y compatibilidad

Se conserva Ruby 3.3.13 y Bundler 2.5.22. [Rails 8.1.4 requiere Ruby >= 3.2](https://rubygems.org/gems/rails/versions/8.1.4), por lo que no fue necesario reinstalar Ruby. Ruby 3.3 está en mantenimiento de seguridad; planificar su siguiente actualización antes de su fin de soporte según el [calendario oficial](https://www.ruby-lang.org/en/downloads/branches/). Rails 8.1 continúa dentro del período de seguridad de la [política oficial](https://guides.rubyonrails.org/maintenance_policy.html). La guía de [actualización de Rails](https://guides.rubyonrails.org/upgrading_ruby_on_rails.html) se usó para identificar APIs retiradas.

La aplicación es pequeña: dos modelos, un CRUD y Devise. Se portó el código y la configuración a `load_defaults 8.1`, preservando el esquema legacy y sus IDs. No se intentó ejecutar Rails 4.2 sobre Ruby 3.3 ni se afirma haber validado versiones intermedias. El riesgo del salto se cubre con pruebas funcionales, migraciones sobre una base de 2016 simulada y un script de rollback. Antes de operar con datos reales, repetir el procedimiento sobre una copia representativa.

## Versiones y dependencias

| Componente | Antes (lockfile original) | Después |
| --- | --- | --- |
| Rails | 4.2.5 | 8.1.4 |
| Ruby | Proyecto de 2016; versión original no fijada | 3.3.13, conservando `.ruby-version` local |
| Bundler | Lockfile 1.12.1 | 2.5.22 |
| Devise | 4.1.1 | 5.0.4 |
| SQLite3 (gema) | 1.3.11 | 2.10.2 |
| RSpec Rails | 3.4.2 | 8.0.4 |
| Capybara | 2.7.1 | 3.40.0 |
| Factory Girl Rails | 4.7.0 | FactoryBot Rails 6.5.1 |
| Paperclip | 4.3.6 | Active Storage 8.1.4, image_processing 1.14.0 |
| Servidor | WEBrick implícito legacy | Puma 8.0.2 |
| Assets | Sprockets/Sass/Foundation/CoffeeScript/Uglifier/jQuery/Turbolinks | Propshaft 1.3.2 y CSS estándar |

Las versiones exactas y transitivas están fijadas en `Gemfile.lock`. Se resolvió todo el árbol con `bundle _2.5.22_ update`, evitando retener `json`/`minitest` de 2016. Se eliminaron Paperclip, Factory Girl, Faker, Cucumber, Database Cleaner, Sass Rails, Coffee Rails, Uglifier, jQuery Rails, Turbolinks, Foundation Rails, Spring, Byebug, Web Console antigua, sdoc y Letter Opener. No se añadió SPA, Node, Redis ni un servicio de colas.

La UI usa formularios HTML y `button_to` para DELETE/logout; no necesita Turbo ni JavaScript. CSS mantiene formularios, navegación y fotografías con diseño adaptable. Los JSON de publicaciones siguen funcionando. La cola inline permite purgar/procesar adjuntos sin un worker externo.

## Seguridad implementada

- `authenticate_user!` cubre todas las acciones de escritura, incluido `destroy`, y los formularios de creación/edición.
- La comprobación de propietario precede a editar/actualizar/eliminar; otros usuarios reciben 403. El CRUD público se limita a index/show.
- Crear construye desde `current_user.posts`; strong parameters excluyen `user_id` tanto al crear como al actualizar.
- CSRF, escaping ERB, CSP, validación de hosts de producción, SSL obligatorio y cookies HttpOnly/SameSite/Secure.
- Devise 5 y contraseñas nuevas de ocho caracteres; hashes bcrypt legacy y campos de tracking conservados. Respuestas de recuperación paranoicas; cookies antiguas invalidadas mediante una nueva clave de sesión. Las claves de desarrollo/test que estaban en `secrets.yml` se retiraron.
- Se mantiene validación de correo; `confirmable` no estaba activo ni tenía columnas. No se habilita retroactivamente ni se bloquea a usuarios existentes. `trackable` sigue soportado y se conserva.
- JPEG/PNG/WebP, 10 MiB, inspección del contenido sin usar la extensión como evidencia, lectura de cabecera con libvips y límite de 40 MP. Los signed blob IDs enviados a los formularios se rechazan.
- Tokens, contraseñas y parámetros de perfil/archivos filtrados en logs; producción usa nivel info.
- El importador resuelve rutas reales y rechaza path traversal y escapes mediante symlinks. Nunca elimina originales.

No se ofrece un endpoint para eliminar la única fotografía dejando una publicación inválida; se reemplaza la imagen o se elimina la publicación. Las imágenes son públicas por diseño, también mediante enlaces firmados Active Storage. Una auditoría sin hallazgos no prueba ausencia de todos los riesgos; siguen siendo necesarios TLS, backups, mantenimiento del host y configuración de correo antes de desplegar.

## Base de datos y conservación

Las migraciones históricas ahora declaran `ActiveRecord::Migration[4.2]`; la migración Paperclip crea explícitamente las mismas cuatro columnas sin depender de la gema retirada. No se cambiaron sus versiones ni se eliminaron columnas de usuarios o publicaciones.

`20261027000001_add_post_integrity.rb` detecta primero publicaciones con `user_id` nulo o inexistente. Si encuentra alguna, aborta antes de imponer restricciones. Añade índice de propietario, índice de orden reciente, NOT NULL y FK hacia users. No elimina ni reasigna datos automáticamente. Para localizar huérfanos en una copia:

```sql
SELECT posts.id, posts.user_id
FROM posts LEFT JOIN users ON users.id = posts.user_id
WHERE users.id IS NULL;
```

Resolver la propiedad con información del negocio; no asignar a un usuario arbitrario. Después repetir `db:migrate`. El borrado de cuenta usa `dependent: :destroy` para no dejar huérfanos y purgar adjuntos.

La migración oficial generada por `active_storage:install` añade blobs, attachments y variant records con índices y claves foráneas. `db/schema.rb` fue regenerado ejecutando migraciones, sin edición manual.

## Plan para originales Paperclip

1. Detener escrituras y tomar backup consistente de SQLite (incluyendo cambios pendientes de WAL) y `public/system`. Probar con copias; nunca copiar una base activa de forma inconsistente.
2. Conservar el código anterior y la versión del esquema, además del backup.
3. Instalar dependencias y ejecutar `bin/rails db:migrate` sobre la copia. Resolver huérfanos si los hay.
4. Localizar originales bajo `posts/photos/:id_partition/original/:filename`. Si había una configuración Paperclip externa, exportar los originales a esta estructura antes de importar.
5. Ejecutar `MODE=dry_run`, `MODE=import` y `MODE=verify` como indica el README. La operación se bloquea por registro durante la asignación, omite adjuntos existentes y puede repetirse tras corregir fallos.
6. Verificar conteos, checksums, lectura del almacenamiento, las tres variantes, perfil/login y CRUD en la copia. El verificador falla si el adjunto existente difiere del original; no lo sobrescribe. Un reemplazo moderno legítimo requiere revisión manual antes de interpretar esa diferencia.
7. Solo después realizar la misma operación en el entorno real con backup y ventana sin escrituras.

No había base de datos de usuario ni originales `public/system` en este checkout. No se afirma haber migrado fotografías reales. El flujo completo se probó con un original de la fixture JPEG, verificando idempotencia, integridad de bytes, variantes, ausencia de originales y rutas maliciosas. Si faltan archivos reales, recuperarlos del almacenamiento/backup original. Hasta entonces los posts conservan texto y metadatos legacy, sin mostrar la imagen ausente.

Los registros que no satisfagan las validaciones actuales (por ejemplo título inválido, formato antiguo no admitido o tamaño excesivo) se reportan como fallos. Conservar el original; revisar o convertir a un archivo derivado aprobado y repetir. No eliminar `photo_file_name`, `photo_content_type`, `photo_file_size`, `photo_updated_at` ni los originales hasta una verificación de negocio completa.

## Rollback

Antes de aceptar escrituras nuevas, rollback recomendado: detener la versión nueva, restaurar la copia consistente de SQLite y los originales, y volver al código/runtime anterior. No ejecutar Rails 4.2 con Ruby 3.3. Conservar también `storage/` para poder recuperar adjuntos nuevos si existieron.

Las dos migraciones nuevas son reversibles. Para ensayar **solo sobre una copia descartable**, después de guardar sus adjuntos:

```sh
bin/rails db:migrate:down VERSION=20261027193644
bin/rails db:migrate:down VERSION=20261027000001
```

La primera elimina las tablas Active Storage: no usarla como rollback operativo sobre datos reales. Quitar tablas no convierte archivos de Active Storage a Paperclip. Después de nuevas escrituras/reemplazos hace falta exportar y conciliar esas imágenes y cambios de datos antes de volver al código anterior; restaurar un backup antiguo perdería esas escrituras. No se ofrece una reversión automática que finja preservarlas.

## Validaciones reales

Resultados locales del 27/10/2026:

| Comando/control | Resultado |
| --- | --- |
| `SDKROOT=...MacOSX26.5.sdk bundle _2.5.22_ update` | Instalación completa; Ruby 3.3.13, Bundler 2.5.22 |
| `bin/rails active_storage:install` | Migración oficial generada |
| `bin/rails db:prepare` y `RAILS_ENV=test bin/rails db:prepare` | Correctos con SQLite |
| `bundle exec rspec` | 48 ejemplos, 0 fallos (seed 16902) |
| `RAILS_ENV=test bin/rails runner script/verify_migrations.rb` | Migraciones desde cero, datos legacy preservados, huérfano rechazado, FK/NOT NULL, rollback y reaplicación correctos |
| `bin/rails zeitwerk:check` | All is good |
| `bundle exec rubocop --cache false` | 56 archivos, sin infracciones |
| `bundle exec brakeman --no-pager --format json --output tmp/brakeman.json` | Brakeman 8.1.0, cero advertencias |
| `bundle exec bundler-audit check --update` | Ninguna vulnerabilidad; ruby-advisory-db commit `3df20d31748fbafd1f6c75ade50e5d1d266257ee`, actualizado 26/10/2026 |
| Precompilación de assets en producción con variables de build | Correcta |
| `bin/rails server -b 127.0.0.1 -p 3001` + petición HTTP | Puma 8.0.2, HTTP 200; servidor temporal detenido |
| `docker build -t photobook:modernized .` | Imagen ARM64 construida con Ruby oficial, dependencias y assets correctos |
| `bin/verify-container` | Correcto: HTTP 200 en producción, UID 1000, SQLite, carga JPEG, tres variantes y purga física; contenedor de prueba eliminado |
| Workflow GitHub Actions | YAML leído localmente; ejecución remota pendiente de publicación autorizada |

Docker Desktop perdió temporalmente su socket durante la primera comprobación; tras reiniciarlo, la construcción final y `bin/verify-container` terminaron con código 0. No se montaron datos reales ni se publicaron puertos en esa prueba.

La primera instalación falló por incompatibilidad del linker Xcode con el SDK 27; usar el SDK 26.5 instalado resolvió el problema sin reconfiguración global. Los primeros fallos de pruebas revelaron una detección MIME que confiaba en la extensión y el cierre prematuro del IO del importador antes de commit; ambos se corrigieron y los casos de regresión pasaron. También se actualizaron el texto Devise y la expectativa de controller para sustituir APIs retiradas.

## Pruebas y CI

Se conservaron las pruebas legacy de modelos, controladores y autenticación. Se modernizaron argumentos de requests, factories con asociaciones reales y helpers Devise. `be_success` se reemplazó por `be_successful`; el antiguo `render_template` se sustituyó por estado HTTP y se cubre el formulario real con Capybara. No se agregó la gema de compatibilidad de controller testing solo para esa expectativa.

Los escenarios Cucumber de home/signup se trasladaron a `spec/features/signup_spec.rb` con los mismos objetivos; la nueva política de password requiere ocho caracteres. Se eliminó el runner Cucumber legacy y Database Cleaner, reemplazado por transacciones RSpec en RackTest.

Nuevos request specs cubren autorización, mass assignment, JSON, XSS, CSRF, registro, recuperación por token real de correo y sesiones. Las pruebas de imágenes procesan variantes reales y comprueban purga física del archivo, MIME falso, SVG y tamaño. El script de migraciones corre sobre una base temporal separada.

`.github/workflows/ci.yml` ejecuta preparación DB, verificación de migraciones, Zeitwerk, RSpec (incluyendo Capybara), RuboCop, Brakeman y bundler-audit. Usa `actions/checkout@v6`, `ruby/setup-ruby@v1`, Ruby desde `.ruby-version` y permiso único `contents: read`. Dependabot revisa bundler y github-actions semanalmente. No se ejecutó el workflow remoto ni se verificó el panel Dependabot: no hubo push ni PR.

## Archivos y revisión

Cambios principales: Gemfile/lockfile, `app/models`, `app/controllers/posts_controller.rb`, vistas Rails/Devise y CSS, configuración Rails/Devise/storage/producción, scripts bin, migraciones y esquema generado, importador y rake task, specs, `script/verify_migrations.rb`, CI/Dependabot, Dockerfile, `.dockerignore`, RuboCop, README y este documento. Los archivos de integración legacy retirados se ven en `git diff --name-status`; archivos nuevos aparecen en `git ls-files --others --exclude-standard`.

Todo queda sin commits en `chore/modernize-dependencies`. `.ruby-version` ya existía sin seguimiento antes del trabajo y su contenido se conservó. No se hizo push, PR, despliegue ni cambios en ramas principales.

```sh
git status --short --branch
git diff --check
git diff --stat
git diff
git ls-files --others --exclude-standard
```

Después de revisar, el propietario puede preparar un commit y publicar la rama. Para abrir un PR tras autorizar/publicar, `gh pr create --head chore/modernize-dependencies --title "Modernize Photobook to Rails 8.1" --body-file MIGRATION.md` permite seleccionar la rama base predeterminada. Este comando no se ejecutó.


## Corrección de CI: actualización de image_processing 2.2.0

El fallo reportado corresponde al [PR #3 de Dependabot](https://github.com/geovannymcode/photobook/pull/3), ejecución [40590493312](https://github.com/geovannymcode/photobook/actions/runs/40590493312), revisión `81d6115bb1abc9b3bee38e3fda93e978a24936e6`. Falló `bin/rails runner script/verify_migrations.rb` al cargar `Post`, con `LoadError: cannot load such file -- vips`. El CI original de modernización y el push a master habían terminado correctamente; este fallo se produjo al actualizar image_processing de 1.14.0 a 2.2.0.

Desde 2.0, image_processing convirtió ruby-vips y mini_magick en dependencias opcionales, como indica su [changelog oficial](https://github.com/janko/image_processing/blob/v2.2.0/CHANGELOG.md#200-2026-05-20). Instalar libvips mediante apt no instala la gema Ruby `ruby-vips`. Photobook usa esta gema directamente al validar las fotografías y debe declararla por sí mismo.

Se actualiza image_processing a 2.2.0 y se declara `gem "ruby-vips", "~> 2.3", require: "vips"` como dependencia de runtime. El lockfile conserva ruby-vips 2.3.0 y elimina mini_magick, que no se utiliza. No se modifica la validación de fotografías ni se desactiva eager loading. El workflow incorpora una comprobación de ambos componentes antes de preparar la base:

```sh
bundle exec ruby -rvips -rimage_processing/vips -e 'puts "libvips #{Vips.version_string}"'
```

Validaciones locales ejecutadas con la corrección el 27/10/2026:

- `bundle _2.5.22_ update image_processing ruby-vips`: instalación correcta; actualización limitada a estas dependencias.
- Comprobación de carga: image_processing 2.2.0, ruby-vips 2.3.0 y libvips 8.18.7.
- `CI=true RAILS_ENV=test bin/rails db:prepare`: correcto.
- `CI=true RAILS_ENV=test bin/rails runner script/verify_migrations.rb`: correcto, incluidas conservación, huérfanos, restricciones y rollback.
- `CI=true RAILS_ENV=test bin/rails zeitwerk:check`: correcto.
- `CI=true bundle exec rspec`: 48 ejemplos, 0 fallos, seed 42323; incluye variantes, descarga de imágenes y purga.
- `bundle exec rubocop --cache false`: 56 archivos, sin infracciones.
- Brakeman 8.1.0: cero advertencias; bundler-audit: ninguna vulnerabilidad encontrada.
- `git diff --check`: correcto.

La corrección queda localmente en `chore/modernize-dependencies`, sin commit ni push. El PR #3 y su check remoto no se modificaron: hay que publicar/aplicar la corrección y volver a ejecutar CI antes de afirmar que esa actualización está aprobada en GitHub. No se ha reconstruido la imagen Docker para esta corrección; sus resultados anteriores corresponden a image_processing 1.14.0.
