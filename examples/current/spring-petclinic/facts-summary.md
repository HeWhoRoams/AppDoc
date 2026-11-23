# Facts summary

- Target: `spring-petclinic`
- Commit: `500158f732419217507c7656904b8e6aa1bcc0d6`
- Git history: shallow
- Schema: `appdoc-facts/7`

> Facts show what the extractors found. An empty list is not proof that something is absent: the extractors only recognise the patterns of the Stacks below, so read the source before writing "none". Facts from test code are marked `test` in `facts.json` and left out of the lists.

## System Connections

> Derived deterministically from the `connection`, `external_call` and `dependency` Facts in `facts.json` - a pure function of the Facts, byte-identical across runs. A group with no rows is not proof of absence; the extractors only recognise the patterns of the detected Stacks.

### Integration map

app -> { database }

| System | Kind | Count | Drivers / targets |
|---|---|---:|---|
| Database | connection | 2 | `spring.datasource.url` |

### Provenance

- **Database** - 2 x `spring.datasource.url`
  - `src/main/resources/application-mysql.properties:3`
  - `src/main/resources/application-postgres.properties:3`

### Dependencies

| Manager | Count | Examples |
|---|---:|---|
| gradle | 22 | `com.github.ben-manes.caffeine:caffeine`, `com.h2database:h2`, `com.mysql:mysql-connector-j`, `jakarta.xml.bind:jakarta.xml.bind-api`, `javax.cache:cache-api`, ... +17 more |
| maven | 30 | `com.github.ben-manes.caffeine:caffeine`, `com.h2database:h2`, `com.mysql:mysql-connector-j`, `com.puppycrawl.tools:checkstyle`, `io.spring.nohttp:nohttp-checkstyle`, ... +25 more |


## Stacks

| Stack | Supported | Files read | Marker files |
|---|---|---|---|
| java-spring | yes | 53 | `build.gradle`, `pom.xml` |

## Counts

| Kind | Count |
|---|---|
| config_key | 122 |
| connection | 2 |
| data_access | 10 |
| dependency | 52 |
| entry_point | 17 |
| external_call | 11 |
| file | 131 |
| message | 11 |
| schema_object | 50 |
| smell | 3 |

| Stack | Facts |
|---|---|
| generic | 357 |
| java-spring | 52 |

## Scan coverage

Files found: 132 = scanned 131 + pruned 1 + ignored by `.appdocignore` 0.

| Folder not scanned | Rule | Files |
|---|---|---|
| `.mvn/` | always | 1 |

Add `!name` to `.appdocignore` to scan a pruned folder.

## Config files

| Application config file | Keys |
|---|---|
| `src/main/resources/application.properties` | 12 |
| `src/main/resources/application-mysql.properties` | 5 |
| `src/main/resources/application-postgres.properties` | 5 |

- build: 1 file, 9 keys (not application settings)
- ci: 4 files, 30 keys (not application settings)
- orchestration: 4 files, 60 keys (not application settings)

## Top folders by file count

| Folder | Files | Entry points | Data access | External calls |
|---|---|---|---|---|
| `src` | 107 | 17 | 10 | 11 |
| `(root)` | 14 | 0 | 0 | 0 |
| `.github` | 4 | 0 | 0 | 0 |
| `.devcontainer` | 2 | 0 | 0 | 0 |
| `gradle` | 2 | 0 | 0 | 0 |
| `k8s` | 2 | 0 | 0 | 0 |

## Largest source files

| File | Lines |
|---|---|
| `src/main/resources/static/resources/css/petclinic.css` | 9532 |
| `src/main/resources/static/resources/fonts/varela_round-webfont.svg` | 7875 |
| `src/main/resources/static/resources/fonts/montserrat-webfont.svg` | 1283 |
| `src/test/jmeter/petclinic_test_plan.jmx` | 540 |
| `pom.xml` | 440 |
| `src/test/java/org/springframework/samples/petclinic/owner/OwnerControllerTests.java` | 318 |
| `src/test/java/org/springframework/samples/petclinic/service/ClinicServiceTests.java` | 315 |
| `mvnw` | 295 |
| `src/test/java/org/springframework/samples/petclinic/owner/PetControllerTests.java` | 274 |
| `gradlew` | 248 |
| `src/main/scss/petclinic.scss` | 214 |
| `src/main/java/org/springframework/samples/petclinic/owner/PetController.java` | 207 |
| `LICENSE.txt` | 202 |
| `mvnw.cmd` | 189 |
| `src/main/java/org/springframework/samples/petclinic/owner/Owner.java` | 188 |
| `src/main/java/org/springframework/samples/petclinic/owner/OwnerController.java` | 188 |
| `README.md` | 181 |
| `src/test/java/org/springframework/samples/petclinic/PostgresIntegrationTests.java` | 150 |
| `src/test/java/org/springframework/samples/petclinic/owner/PetValidatorTests.java` | 139 |
| `src/test/java/org/springframework/samples/petclinic/system/I18nPropertiesSyncTest.java` | 138 |
| `src/test/java/org/springframework/samples/petclinic/PetClinicConcurrencyTests.java` | 134 |
| `src/test/java/org/springframework/samples/petclinic/owner/VisitControllerTests.java` | 121 |
| `src/main/java/org/springframework/samples/petclinic/owner/VisitController.java` | 114 |
| `src/test/java/org/springframework/samples/petclinic/vet/VetControllerTests.java` | 111 |
| `src/test/java/org/springframework/samples/petclinic/system/CrashControllerIntegrationTests.java` | 101 |

## Entry points

- `/owners/new` — `src/main/java/org/springframework/samples/petclinic/owner/OwnerController.java:72`
- `/owners/new` — `src/main/java/org/springframework/samples/petclinic/owner/OwnerController.java:77`
- `/owners/find` — `src/main/java/org/springframework/samples/petclinic/owner/OwnerController.java:89`
- `/owners` — `src/main/java/org/springframework/samples/petclinic/owner/OwnerController.java:94`
- `/owners/{ownerId}/edit` — `src/main/java/org/springframework/samples/petclinic/owner/OwnerController.java:148`
- `/owners/{ownerId}/edit` — `src/main/java/org/springframework/samples/petclinic/owner/OwnerController.java:153`
- `/owners/{ownerId}` — `src/main/java/org/springframework/samples/petclinic/owner/OwnerController.java:178`
- `/owners/{ownerId}/pets/new` — `src/main/java/org/springframework/samples/petclinic/owner/PetController.java:100`
- `/owners/{ownerId}/pets/new` — `src/main/java/org/springframework/samples/petclinic/owner/PetController.java:107`
- `/owners/{ownerId}/pets/{petId}/edit` — `src/main/java/org/springframework/samples/petclinic/owner/PetController.java:139`
- `/owners/{ownerId}/pets/{petId}/edit` — `src/main/java/org/springframework/samples/petclinic/owner/PetController.java:144`
- `/owners/{ownerId}/pets/{petId}/visits/new` — `src/main/java/org/springframework/samples/petclinic/owner/VisitController.java:90`
- `/owners/{ownerId}/pets/{petId}/visits/new` — `src/main/java/org/springframework/samples/petclinic/owner/VisitController.java:97`
- `/oups` — `src/main/java/org/springframework/samples/petclinic/system/CrashController.java:31`
- `/` — `src/main/java/org/springframework/samples/petclinic/system/WelcomeController.java:25`
- `/vets.html` — `src/main/java/org/springframework/samples/petclinic/vet/VetController.java:45`
- `/vets` — `src/main/java/org/springframework/samples/petclinic/vet/VetController.java:72`

## Data access

- `owners` — `src/main/java/org/springframework/samples/petclinic/owner/Owner.java:48`
- `OwnerRepository` — `src/main/java/org/springframework/samples/petclinic/owner/OwnerRepository.java:36`
- `pets` — `src/main/java/org/springframework/samples/petclinic/owner/Pet.java:44`
- `types` — `src/main/java/org/springframework/samples/petclinic/owner/PetType.java:26`
- `PetTypeRepository` — `src/main/java/org/springframework/samples/petclinic/owner/PetTypeRepository.java:30`
- `PetType` — `src/main/java/org/springframework/samples/petclinic/owner/PetTypeRepository.java:36`
- `visits` — `src/main/java/org/springframework/samples/petclinic/owner/Visit.java:35`
- `specialties` — `src/main/java/org/springframework/samples/petclinic/vet/Specialty.java:28`
- `vets` — `src/main/java/org/springframework/samples/petclinic/vet/Vet.java:43`
- `VetRepository` — `src/main/java/org/springframework/samples/petclinic/vet/VetRepository.java:38`

## Connections (locations only)

- `spring.datasource.url` — `src/main/resources/application-mysql.properties:3`
- `spring.datasource.url` — `src/main/resources/application-postgres.properties:3`

## Config keys flagged as secret locations

- `stringData.password` — `k8s/db.yml:14`
- `spec.template.spec.containers.env.valueFrom.secretKeyRef.key` — `k8s/db.yml:51`
- `spec.template.spec.containers.env.valueFrom.secretKeyRef.key` — `k8s/db.yml:56`
- `spec.template.spec.containers.env.valueFrom.secretKeyRef.key` — `k8s/db.yml:61`
- `spring.datasource.password` — `src/main/resources/application-mysql.properties:5`
- `spring.datasource.password` — `src/main/resources/application-postgres.properties:5`
- (1 more in test code, not listed)

## External calls

None extracted (11 in test code, not listed).

## Auth checks

None extracted. This is not proof of absence.

## Schema objects

| Type | Dialect | Count |
|---|---|---|
| fk | h2 | 5 |
| fk | mysql | 5 |
| fk | postgres | 5 |
| index | h2 | 6 |
| index | postgres | 8 |
| table | h2 | 7 |
| table | mysql | 7 |
| table | postgres | 7 |

| Table | Dialect | Columns | Defined at |
|---|---|---|---|
| `owners` | h2 | 6 | `src/main/resources/db/h2/schema.sql:36` |
| `owners` | mysql | 6 | `src/main/resources/db/mysql/schema.sql:28` |
| `owners` | postgres | 6 | `src/main/resources/db/postgres/schema.sql:26` |
| `pets` | h2 | 5 | `src/main/resources/db/h2/schema.sql:46` |
| `pets` | mysql | 5 | `src/main/resources/db/mysql/schema.sql:38` |
| `pets` | postgres | 5 | `src/main/resources/db/postgres/schema.sql:36` |
| `specialties` | h2 | 2 | `src/main/resources/db/h2/schema.sql:17` |
| `specialties` | mysql | 2 | `src/main/resources/db/mysql/schema.sql:8` |
| `specialties` | postgres | 2 | `src/main/resources/db/postgres/schema.sql:8` |
| `types` | h2 | 2 | `src/main/resources/db/h2/schema.sql:30` |
| `types` | mysql | 2 | `src/main/resources/db/mysql/schema.sql:22` |
| `types` | postgres | 2 | `src/main/resources/db/postgres/schema.sql:20` |
| `vet_specialties` | h2 | 2 | `src/main/resources/db/h2/schema.sql:23` |
| `vet_specialties` | mysql | 2 | `src/main/resources/db/mysql/schema.sql:14` |
| `vet_specialties` | postgres | 2 | `src/main/resources/db/postgres/schema.sql:14` |
| `vets` | h2 | 3 | `src/main/resources/db/h2/schema.sql:10` |
| `vets` | mysql | 3 | `src/main/resources/db/mysql/schema.sql:1` |
| `vets` | postgres | 3 | `src/main/resources/db/postgres/schema.sql:1` |
| `visits` | h2 | 4 | `src/main/resources/db/h2/schema.sql:58` |
| `visits` | mysql | 4 | `src/main/resources/db/mysql/schema.sql:50` |
| `visits` | postgres | 4 | `src/main/resources/db/postgres/schema.sql:47` |

| Index | Table | Unique | Expression | Defined at |
|---|---|---|---|---|
| `idx_owners_last_name` | `owners` | no | `last_name` | `src/main/resources/db/postgres/schema.sql:34` |
| `owners_last_name` | `owners` | no | `last_name` | `src/main/resources/db/h2/schema.sql:44` |
| `idx_pets_name` | `pets` | no | `name` | `src/main/resources/db/postgres/schema.sql:43` |
| `idx_pets_owner_id` | `pets` | no | `owner_id` | `src/main/resources/db/postgres/schema.sql:44` |
| `pets_name` | `pets` | no | `name` | `src/main/resources/db/h2/schema.sql:56` |
| `unique_owner_pet_name` | `pets` | yes | `owner_id, LOWER(name)` | `src/main/resources/db/postgres/schema.sql:45` |
| `idx_specialties_name` | `specialties` | no | `name` | `src/main/resources/db/postgres/schema.sql:12` |
| `specialties_name` | `specialties` | no | `name` | `src/main/resources/db/h2/schema.sql:21` |
| `idx_types_name` | `types` | no | `name` | `src/main/resources/db/postgres/schema.sql:24` |
| `types_name` | `types` | no | `name` | `src/main/resources/db/h2/schema.sql:34` |
| `idx_vets_last_name` | `vets` | no | `last_name` | `src/main/resources/db/postgres/schema.sql:6` |
| `vets_last_name` | `vets` | no | `last_name` | `src/main/resources/db/h2/schema.sql:15` |
| `idx_visits_pet_id` | `visits` | no | `pet_id` | `src/main/resources/db/postgres/schema.sql:53` |
| `visits_pet_id` | `visits` | no | `pet_id` | `src/main/resources/db/h2/schema.sql:65` |

## Ownership files

None extracted. This is not proof of absence.

## UI pages

None extracted. This is not proof of absence.

## Finding candidates

| Pattern | Count | First locations | id |
|---|---|---|---|
| `actuator-exposed` | 1 | `src/main/resources/application.properties:21` | `1562fac5` |
| `flash-without-redirect` | 2 | `src/main/java/org/springframework/samples/petclinic/owner/OwnerController.java:80`, `src/main/java/org/springframework/samples/petclinic/owner/OwnerController.java:157` | `4b908b79`, `3d09653b` |
