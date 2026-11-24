# Check: PASS

**Scope.** Run by AppDoc 2.7.0 (bundle 25b4b70e8137). This Check verifies **resolution and structure**: every Citation points to a real file and line inside the Target (see the Citation register), and every Evidence Register row's anchor text appears in the lines it cites. It does **not** judge whether a claim's wording follows from those lines; that is the source-to-claim audit, recorded in `evidence.jsonl`. A PASS is not an accuracy certification.

## Audit exclusions

The audit record declares sections the audit did not cover:

- 12: diagrams not audited
- 16.6: generated configuration reference block
- 16.7: generated scheduled jobs block
- 2.1: generated scan coverage block
- 3.2: diagram not audited
- 4: generated entry point list block only; the sampled feature rows were audited

## Gaps declared: Unknown by absence
Advisory only; this is not a problem.

- deployment runbook is Unknown by absence (no appdoc-context.md); add one to fill section 16.5 Rollback, Backup and Restore

## Citation register

| Doc line | Cited path | Line/range | Resolved |
|---|---|---|---|
| 12 | `src/main/java/org/springframework/samples/petclinic/owner/OwnerController.java` | 94 | yes |
| 13 | `src/main/java/org/springframework/samples/petclinic/owner/OwnerController.java` | 77 | yes |
| 14 | `src/main/java/org/springframework/samples/petclinic/owner/OwnerController.java` | 153 | yes |
| 15 | `src/main/java/org/springframework/samples/petclinic/owner/PetController.java` | 107 | yes |
| 16 | `src/main/java/org/springframework/samples/petclinic/owner/PetController.java` | 144 | yes |
| 17 | `src/main/java/org/springframework/samples/petclinic/owner/VisitController.java` | 97 | yes |
| 18 | `src/main/java/org/springframework/samples/petclinic/vet/VetController.java` | 45 | yes |
| 19 | `src/main/java/org/springframework/samples/petclinic/system/CrashController.java` | 31 | yes |
| 20 | `src/main/resources/application.properties` | 2 | yes |
| 21 | `src/main/java/org/springframework/samples/petclinic/owner/OwnerController.java` | 68 | yes |
| 27 | `README.md` |  | yes |
| 27 | `docker-compose.yml` |  | yes |
| 27 | `pom.xml` | 1-10 | yes |
| 27 | `src/main/java/org/springframework/samples/petclinic/` |  | yes |
| 27 | `src/main/resources/messages/messages.properties` |  | yes |
| 27 | `src/main/resources/static/` |  | yes |
| 27 | `src/main/resources/templates/` |  | yes |
| 27 | `src/main/scss/petclinic.scss` |  | yes |
| 27 | `src/test/jmeter/petclinic_test_plan.jmx` |  | yes |
| 29 | `.mvn/` |  | yes |
| 29 | `.mvn/wrapper/maven-wrapper.properties` | 1-3 | yes |
| 29 | `mvnw.cmd` |  | yes |
| 29 | `src/main/java/org/springframework/samples/petclinic/PetClinicApplication.java` | 28-34 | yes |
| 40 | `src/` |  | yes |
| 41 | `.github/` |  | yes |
| 42 | `.devcontainer/` |  | yes |
| 43 | `gradle/` |  | yes |
| 44 | `k8s/` |  | yes |
| 48 | `.mvn/` |  | yes |
| 53 | `README.md` | 1-16 | yes |
| 53 | `README.md` | 5-12 | yes |
| 53 | `pom.xml` | 41-66 | yes |
| 53 | `src/main/java/org/springframework/samples/petclinic/owner/OwnerController.java` | 48-49 | yes |
| 57 | `src/main/java/org/springframework/samples/petclinic/PetClinicApplication.java` | 28-34 | yes |
| 57 | `src/main/java/org/springframework/samples/petclinic/system/CacheConfiguration.java` | 35-38 | yes |
| 57 | `src/main/resources/application-mysql.properties` | 2-3 | yes |
| 57 | `src/main/resources/application-postgres.properties` | 2-3 | yes |
| 57 | `src/main/resources/application.properties` | 2-4 | yes |
| 57 | `src/main/resources/db/h2/schema.sql` | 1-10 | yes |
| 57 | `src/test/java/org/springframework/samples/petclinic/PetClinicIntegrationTests.java` | 55 | yes |
| 63 | `src/main/java/org/springframework/samples/petclinic/owner/` |  | yes |
| 63 | `src/main/java/org/springframework/samples/petclinic/owner/OwnerController.java` | 48-49 | yes |
| 63 | `src/main/java/org/springframework/samples/petclinic/owner/OwnerRepository.java` | 36 | yes |
| 63 | `src/main/java/org/springframework/samples/petclinic/owner/PetController.java` | 47-49 | yes |
| 63 | `src/main/java/org/springframework/samples/petclinic/owner/PetTypeRepository.java` | 30 | yes |
| 63 | `src/main/java/org/springframework/samples/petclinic/owner/VisitController.java` | 42-43 | yes |
| 64 | `src/main/java/org/springframework/samples/petclinic/vet/` |  | yes |
| 64 | `src/main/java/org/springframework/samples/petclinic/vet/VetController.java` | 36-37 | yes |
| 64 | `src/main/java/org/springframework/samples/petclinic/vet/VetRepository.java` | 38-56 | yes |
| 64 | `src/main/java/org/springframework/samples/petclinic/vet/Vets.java` | 30-31 | yes |
| 65 | `src/main/java/org/springframework/samples/petclinic/model/` |  | yes |
| 65 | `src/main/java/org/springframework/samples/petclinic/model/BaseEntity.java` | 32-37 | yes |
| 65 | `src/main/java/org/springframework/samples/petclinic/model/Person.java` | 28-39 | yes |
| 66 | `src/main/java/org/springframework/samples/petclinic/system/` |  | yes |
| 66 | `src/main/java/org/springframework/samples/petclinic/system/CrashController.java` | 28-29 | yes |
| 66 | `src/main/java/org/springframework/samples/petclinic/system/WebConfiguration.java` | 44-49 | yes |
| 66 | `src/main/java/org/springframework/samples/petclinic/system/WelcomeController.java` | 22-23 | yes |
| 67 | `src/main/resources/templates/` |  | yes |
| 67 | `src/main/resources/templates/fragments/layout.html` | 1-20 | yes |
| 68 | `src/main/resources/application.properties` | 2-4 | yes |
| 68 | `src/main/resources/db/` |  | yes |
| 69 | `build.gradle` |  | yes |
| 69 | `build.gradle` | 1-10 | yes |
| 69 | `docker-compose.yml` |  | yes |
| 69 | `docker-compose.yml` | 1-3 | yes |
| 69 | `k8s/db.yml` |  | yes |
| 69 | `k8s/petclinic.yml` |  | yes |
| 69 | `k8s/petclinic.yml` | 15-33 | yes |
| 69 | `pom.xml` |  | yes |
| 69 | `pom.xml` | 1-10 | yes |
| 90 | `src/main/java/org/springframework/samples/petclinic/owner/OwnerRepository.java` | 36-45 | yes |
| 90 | `src/main/java/org/springframework/samples/petclinic/vet/VetRepository.java` | 44-56 | yes |
| 94 | `build.gradle` | 33-40 | yes |
| 94 | `pom.xml` | 41-66 | yes |
| 94 | `src/main/java/org/springframework/samples/petclinic/owner/OwnerController.java` | 48-188 | yes |
| 111 | `src/main/java/org/springframework/samples/petclinic/owner/OwnerController.java` | 72-130 | yes |
| 115 | `src/main/java/org/springframework/samples/petclinic/system/WelcomeController.java` | 25-28 | yes |
| 115 | `src/main/resources/templates/welcome.html` | 1-12 | yes |
| 116 | `src/main/java/org/springframework/samples/petclinic/owner/OwnerController.java` | 89-130 | yes |
| 116 | `src/main/java/org/springframework/samples/petclinic/owner/OwnerRepository.java` | 45 | yes |
| 117 | `src/main/java/org/springframework/samples/petclinic/model/Person.java` | 31-39 | yes |
| 117 | `src/main/java/org/springframework/samples/petclinic/owner/Owner.java` | 52-65 | yes |
| 117 | `src/main/java/org/springframework/samples/petclinic/owner/OwnerController.java` | 59-62 | yes |
| 117 | `src/main/java/org/springframework/samples/petclinic/owner/OwnerController.java` | 72-87 | yes |
| 118 | `src/main/java/org/springframework/samples/petclinic/owner/OwnerController.java` | 148-171 | yes |
| 118 | `src/main/java/org/springframework/samples/petclinic/owner/OwnerController.java` | 161-165 | yes |
| 118 | `src/main/java/org/springframework/samples/petclinic/owner/OwnerController.java` | 59-62 | yes |
| 118 | `src/main/java/org/springframework/samples/petclinic/owner/OwnerController.java` | 64-70 | yes |
| 119 | `src/main/java/org/springframework/samples/petclinic/owner/OwnerController.java` | 178-186 | yes |
| 119 | `src/main/resources/templates/owners/ownerDetails.html` | 9-14 | yes |
| 120 | `src/main/java/org/springframework/samples/petclinic/owner/Owner.java` | 150 | yes |
| 120 | `src/main/java/org/springframework/samples/petclinic/owner/PetController.java` | 100-135 | yes |
| 120 | `src/main/java/org/springframework/samples/petclinic/owner/PetController.java` | 111-118 | yes |
| 120 | `src/main/java/org/springframework/samples/petclinic/owner/PetValidator.java` | 38-59 | yes |
| 121 | `src/main/java/org/springframework/samples/petclinic/owner/PetController.java` | 139-177 | yes |
| 121 | `src/main/java/org/springframework/samples/petclinic/owner/PetController.java` | 148-156 | yes |
| 121 | `src/main/java/org/springframework/samples/petclinic/owner/PetValidator.java` | 51-53 | yes |
| 122 | `src/main/java/org/springframework/samples/petclinic/owner/Visit.java` | 43-45 | yes |
| 122 | `src/main/java/org/springframework/samples/petclinic/owner/VisitController.java` | 100-102 | yes |
| 122 | `src/main/java/org/springframework/samples/petclinic/owner/VisitController.java` | 90-111 | yes |
| 123 | `src/main/java/org/springframework/samples/petclinic/vet/VetController.java` | 45-54 | yes |
| 123 | `src/main/java/org/springframework/samples/petclinic/vet/VetRepository.java` | 54-56 | yes |
| 124 | `pom.xml` | 71-74 | yes |
| 124 | `src/main/java/org/springframework/samples/petclinic/vet/VetController.java` | 72-79 | yes |
| 124 | `src/main/java/org/springframework/samples/petclinic/vet/Vets.java` | 30-41 | yes |
| 124 | `src/test/java/org/springframework/samples/petclinic/vet/VetControllerTests.java` | 105-108 | yes |
| 125 | `src/main/java/org/springframework/samples/petclinic/system/CrashController.java` | 31-35 | yes |
| 125 | `src/main/resources/templates/error.html` | 5-18 | yes |
| 126 | `src/main/java/org/springframework/samples/petclinic/system/WebConfiguration.java` | 44-58 | yes |
| 126 | `src/main/resources/application.properties` | 16 | yes |
| 127 | `pom.xml` | 43-46 | yes |
| 127 | `pom.xml` | 5-9 | yes |
| 127 | `src/main/resources/application.properties` | 21 | yes |
| 133 | `src/` |  | yes |
| 134 | `pom.xml` |  | yes |
| 135 | `.github/` |  | yes |
| 136 | `.devcontainer/` |  | yes |
| 137 | `gradle/` |  | yes |
| 138 | `k8s/` |  | yes |
| 144 | `pom.xml` | 41-66 | yes |
| 144 | `src/main/java/org/springframework/samples/petclinic/owner/Owner.java` | 48-50 | yes |
| 144 | `src/main/java/org/springframework/samples/petclinic/vet/Vet.java` | 43-45 | yes |
| 148 | `src/main/java/org/springframework/samples/petclinic/owner/OwnerController.java` | 59-62 | yes |
| 148 | `src/main/java/org/springframework/samples/petclinic/owner/OwnerController.java` | 59-62 | yes |
| 148 | `src/main/java/org/springframework/samples/petclinic/owner/PetController.java` | 89-98 | yes |
| 148 | `src/main/java/org/springframework/samples/petclinic/owner/VisitController.java` | 51-54 | yes |
| 148 | `src/main/java/org/springframework/samples/petclinic/system/WebConfiguration.java` | 55-58 | yes |
| 152 | `pom.xml` | 41-66 | yes |
| 156 | `src/main/java/org/springframework/samples/petclinic/system/WelcomeController.java` | 25 | yes |
| 157 | `src/main/java/org/springframework/samples/petclinic/owner/OwnerController.java` | 72-130 | yes |
| 158 | `src/main/java/org/springframework/samples/petclinic/owner/PetController.java` | 100-177 | yes |
| 159 | `src/main/java/org/springframework/samples/petclinic/owner/VisitController.java` | 90-111 | yes |
| 160 | `src/main/java/org/springframework/samples/petclinic/vet/VetController.java` | 45-79 | yes |
| 161 | `src/main/java/org/springframework/samples/petclinic/system/CrashController.java` | 31 | yes |
| 162 | `src/main/java/org/springframework/samples/petclinic/owner/OwnerController.java` | 72-130 | yes |
| 163 | `src/main/java/org/springframework/samples/petclinic/vet/VetController.java` | 45-79 | yes |
| 169 | `src/main/resources/templates/` |  | yes |
| 169 | `src/main/resources/templates/fragments/layout.html` | 1-20 | yes |
| 173 | `src/main/resources/templates/fragments/layout.html` | 22 | yes |
| 173 | `src/main/resources/templates/welcome.html` | 7-12 | yes |
| 174 | `src/main/resources/templates/owners/findOwners.html` | 9-29 | yes |
| 175 | `src/main/resources/templates/owners/ownersList.html` | 20-54 | yes |
| 176 | `src/main/resources/templates/owners/ownerDetails.html` | 9-73 | yes |
| 177 | `src/main/resources/templates/owners/createOrUpdateOwnerForm.html` | 8-20 | yes |
| 178 | `src/main/resources/templates/pets/createOrUpdatePetForm.html` | 11-31 | yes |
| 179 | `src/main/resources/templates/pets/createOrUpdateVisitForm.html` | 30-54 | yes |
| 180 | `src/main/resources/templates/vets/vetList.html` | 17-50 | yes |
| 181 | `src/main/resources/application.properties` | 1-29 | yes |
| 181 | `src/main/resources/templates/error.html` | 11-18 | yes |
| 181 | `src/main/resources/templates/error.html` | 18 | yes |
| 181 | `src/test/java/org/springframework/samples/petclinic/system/CrashControllerIntegrationTests.java` | 51 | yes |
| 187 | `src/main/resources/templates/owners/findOwners.html` | 9 | yes |
| 188 | `src/main/java/org/springframework/samples/petclinic/owner/OwnerController.java` | 141-146 | yes |
| 188 | `src/main/java/org/springframework/samples/petclinic/owner/OwnerController.java` | 94-107 | yes |
| 189 | `src/main/java/org/springframework/samples/petclinic/owner/OwnerController.java` | 108-114 | yes |
| 189 | `src/main/java/org/springframework/samples/petclinic/owner/OwnerController.java` | 116-120 | yes |
| 189 | `src/main/java/org/springframework/samples/petclinic/owner/OwnerController.java` | 122-126 | yes |
| 189 | `src/main/java/org/springframework/samples/petclinic/owner/OwnerController.java` | 129 | yes |
| 191 | `src/main/java/org/springframework/samples/petclinic/owner/OwnerRepository.java` | 45 | yes |
| 191 | `src/main/resources/templates/error.html` | 11-14 | yes |
| 195 | `src/main/java/org/springframework/samples/petclinic/owner/OwnerController.java` | 72-75 | yes |
| 196 | `src/main/java/org/springframework/samples/petclinic/owner/OwnerController.java` | 78-82 | yes |
| 197 | `src/main/java/org/springframework/samples/petclinic/owner/OwnerController.java` | 84-86 | yes |
| 199 | `src/main/java/org/springframework/samples/petclinic/owner/OwnerController.java` | 80-84 | yes |
| 203 | `src/main/java/org/springframework/samples/petclinic/owner/OwnerController.java` | 64-70 | yes |
| 204 | `src/main/java/org/springframework/samples/petclinic/owner/OwnerController.java` | 153-159 | yes |
| 205 | `src/main/java/org/springframework/samples/petclinic/owner/OwnerController.java` | 161-165 | yes |
| 205 | `src/main/java/org/springframework/samples/petclinic/owner/OwnerController.java` | 59-62 | yes |
| 205 | `src/main/java/org/springframework/samples/petclinic/owner/OwnerController.java` | 64-70 | yes |
| 206 | `src/main/java/org/springframework/samples/petclinic/owner/OwnerController.java` | 167-170 | yes |
| 208 | `src/main/java/org/springframework/samples/petclinic/owner/OwnerController.java` | 68-69 | yes |
| 208 | `src/main/resources/application.properties` | 1-29 | yes |
| 208 | `src/main/resources/templates/error.html` | 18 | yes |
| 208 | `src/test/java/org/springframework/samples/petclinic/system/CrashControllerIntegrationTests.java` | 51 | yes |
| 212 | `src/main/java/org/springframework/samples/petclinic/owner/PetController.java` | 100-105 | yes |
| 213 | `src/main/java/org/springframework/samples/petclinic/owner/PetController.java` | 111-118 | yes |
| 214 | `src/main/java/org/springframework/samples/petclinic/owner/PetController.java` | 124-127 | yes |
| 215 | `src/main/java/org/springframework/samples/petclinic/owner/PetController.java` | 128-134 | yes |
| 215 | `src/main/java/org/springframework/samples/petclinic/owner/PetController.java` | 202-205 | yes |
| 216 | `src/main/java/org/springframework/samples/petclinic/owner/PetController.java` | 135-136 | yes |
| 218 | `src/main/java/org/springframework/samples/petclinic/owner/PetController.java` | 204 | yes |
| 218 | `src/main/resources/db/mysql/schema.sql` | 47 | yes |
| 222 | `src/main/java/org/springframework/samples/petclinic/owner/PetController.java` | 139-142 | yes |
| 222 | `src/main/java/org/springframework/samples/petclinic/owner/PetController.java` | 75-87 | yes |
| 223 | `src/main/java/org/springframework/samples/petclinic/owner/PetController.java` | 148-156 | yes |
| 223 | `src/main/java/org/springframework/samples/petclinic/owner/PetController.java` | 158-161 | yes |
| 224 | `src/main/java/org/springframework/samples/petclinic/owner/PetController.java` | 186-200 | yes |
| 225 | `src/main/java/org/springframework/samples/petclinic/owner/PetController.java` | 177-178 | yes |
| 227 | `src/main/java/org/springframework/samples/petclinic/owner/PetController.java` | 167-176 | yes |
| 227 | `src/main/java/org/springframework/samples/petclinic/owner/PetController.java` | 70 | yes |
| 231 | `src/main/java/org/springframework/samples/petclinic/owner/Visit.java` | 50-52 | yes |
| 231 | `src/main/java/org/springframework/samples/petclinic/owner/VisitController.java` | 63-81 | yes |
| 232 | `src/main/java/org/springframework/samples/petclinic/owner/VisitController.java` | 100-106 | yes |
| 233 | `src/main/java/org/springframework/samples/petclinic/owner/VisitController.java` | 108-111 | yes |
| 235 | `src/main/java/org/springframework/samples/petclinic/owner/VisitController.java` | 67-72 | yes |
| 235 | `src/main/resources/application.properties` | 1-29 | yes |
| 235 | `src/main/resources/templates/error.html` | 18 | yes |
| 239 | `src/main/java/org/springframework/samples/petclinic/vet/VetController.java` | 45-69 | yes |
| 240 | `pom.xml` | 71-74 | yes |
| 240 | `src/main/java/org/springframework/samples/petclinic/vet/VetController.java` | 72-79 | yes |
| 240 | `src/main/java/org/springframework/samples/petclinic/vet/Vets.java` | 30-41 | yes |
| 240 | `src/test/java/org/springframework/samples/petclinic/vet/VetControllerTests.java` | 105-108 | yes |
| 241 | `src/main/java/org/springframework/samples/petclinic/vet/VetRepository.java` | 44-56 | yes |
| 243 | `src/main/java/org/springframework/samples/petclinic/system/CacheConfiguration.java` | 35-51 | yes |
| 243 | `src/main/java/org/springframework/samples/petclinic/vet/VetController.java` | 49-52 | yes |
| 247 | `src/main/resources/templates/fragments/layout.html` | 56-57 | yes |
| 248 | `src/main/java/org/springframework/samples/petclinic/system/CrashController.java` | 31-35 | yes |
| 248 | `src/main/resources/templates/error.html` | 5-18 | yes |
| 250 | `src/test/java/org/springframework/samples/petclinic/system/CrashControllerIntegrationTests.java` | 51 | yes |
| 250 | `src/test/java/org/springframework/samples/petclinic/system/CrashControllerIntegrationTests.java` | 62-93 | yes |
| 254 | `src/main/resources/application.properties` |  | yes |
| 254 | `src/main/resources/application.properties` | 2-4 | yes |
| 254 | `src/main/resources/db/h2/data.sql` |  | yes |
| 254 | `src/main/resources/db/h2/schema.sql` |  | yes |
| 255 | `src/main/resources/application-mysql.properties` | 2-7 | yes |
| 255 | `src/main/resources/application-postgres.properties` | 2-7 | yes |
| 256 | `src/main/resources/application.properties` | 10 | yes |
| 258 | `docker-compose.yml` | 1-20 | yes |
| 266 | `README.md` | 64 | yes |
| 266 | `src/main/resources/application.properties` | 2-4 | yes |
| 267 | `src/main/resources/application-mysql.properties` | 3 | yes |
| 268 | `src/main/resources/application-postgres.properties` | 3 | yes |
| 269 | `src/main/java/org/springframework/samples/petclinic/system/CacheConfiguration.java` | 35-38 | yes |
| 269 | `src/main/java/org/springframework/samples/petclinic/vet/VetRepository.java` | 44-56 | yes |
| 271 | `pom.xml` | 76-80 | yes |
| 271 | `src/main/resources/application.properties` | 1-29 | yes |
| 275 | `src/main/java/org/springframework/samples/petclinic/owner/OwnerRepository.java` | 45 | yes |
| 275 | `src/main/java/org/springframework/samples/petclinic/owner/PetTypeRepository.java` | 36-37 | yes |
| 275 | `src/main/java/org/springframework/samples/petclinic/vet/VetRepository.java` | 46 | yes |
| 275 | `src/main/java/org/springframework/samples/petclinic/vet/VetRepository.java` | 56 | yes |
| 275 | `src/main/resources/db/h2/schema.sql` | 1-65 | yes |
| 281 | `src/test/java/org/springframework/samples/petclinic/PetClinicIntegrationTests.java` | 55-62 | yes |
| 287 | `src/main/java/org/springframework/samples/petclinic/owner/Owner.java` | 48-65 | yes |
| 287 | `src/main/resources/db/h2/schema.sql` | 36-43 | yes |
| 288 | `src/main/java/org/springframework/samples/petclinic/owner/Pet.java` | 44-54 | yes |
| 288 | `src/main/resources/db/h2/schema.sql` | 46-52 | yes |
| 289 | `src/main/java/org/springframework/samples/petclinic/owner/PetType.java` | 26 | yes |
| 289 | `src/main/resources/db/h2/schema.sql` | 30-33 | yes |
| 290 | `src/main/java/org/springframework/samples/petclinic/owner/Visit.java` | 35-45 | yes |
| 290 | `src/main/resources/db/h2/schema.sql` | 58-63 | yes |
| 291 | `src/main/java/org/springframework/samples/petclinic/vet/Vet.java` | 43-45 | yes |
| 291 | `src/main/resources/db/h2/schema.sql` | 10-14 | yes |
| 292 | `src/main/java/org/springframework/samples/petclinic/vet/Specialty.java` | 28 | yes |
| 292 | `src/main/resources/db/h2/schema.sql` | 17-28 | yes |
| 298 | `src/main/resources/db/h2/schema.sql` | 37 | yes |
| 299 | `src/main/java/org/springframework/samples/petclinic/model/Person.java` | 31-34 | yes |
| 299 | `src/main/resources/db/h2/schema.sql` | 38 | yes |
| 300 | `src/main/resources/db/h2/schema.sql` | 39 | yes |
| 301 | `src/main/java/org/springframework/samples/petclinic/owner/Owner.java` | 52-55 | yes |
| 301 | `src/main/resources/db/h2/schema.sql` | 40 | yes |
| 302 | `src/main/java/org/springframework/samples/petclinic/owner/Owner.java` | 57-60 | yes |
| 302 | `src/main/resources/db/h2/schema.sql` | 41 | yes |
| 303 | `src/main/java/org/springframework/samples/petclinic/owner/Owner.java` | 62-65 | yes |
| 303 | `src/main/resources/db/h2/schema.sql` | 42 | yes |
| 309 | `src/main/resources/db/h2/schema.sql` | 47 | yes |
| 310 | `src/main/resources/db/h2/schema.sql` | 48 | yes |
| 310 | `src/main/resources/db/h2/schema.sql` | 55 | yes |
| 311 | `src/main/resources/db/h2/schema.sql` | 49 | yes |
| 312 | `src/main/resources/db/h2/schema.sql` | 50 | yes |
| 312 | `src/main/resources/db/h2/schema.sql` | 54 | yes |
| 313 | `src/main/resources/db/h2/schema.sql` | 51 | yes |
| 313 | `src/main/resources/db/h2/schema.sql` | 53 | yes |
| 319 | `src/main/resources/db/h2/schema.sql` | 59 | yes |
| 320 | `src/main/resources/db/h2/schema.sql` | 60 | yes |
| 320 | `src/main/resources/db/h2/schema.sql` | 64 | yes |
| 321 | `src/main/resources/db/h2/schema.sql` | 61 | yes |
| 322 | `src/main/java/org/springframework/samples/petclinic/owner/Visit.java` | 43-45 | yes |
| 322 | `src/main/resources/db/h2/schema.sql` | 62 | yes |
| 328 | `src/main/resources/application.properties` | 1-29 | yes |
| 328 | `src/main/resources/application.properties` | 24 | yes |
| 329 | `src/main/resources/application-mysql.properties` | 2-7 | yes |
| 329 | `src/main/resources/application.properties` | 21 | yes |
| 330 | `k8s/petclinic.yml` | 47-54 | yes |
| 330 | `src/main/resources/application-postgres.properties` | 2-7 | yes |
| 331 | `src/main/java/org/springframework/samples/petclinic/system/CacheConfiguration.java` | 49-51 | yes |
| 331 | `src/main/java/org/springframework/samples/petclinic/system/CacheConfiguration.java` | 50 | yes |
| 332 | `src/test/java/org/springframework/samples/petclinic/PetClinicIntegrationTests.java` | 55 | yes |
| 338 | `src/main/java/org/springframework/samples/petclinic/owner/OwnerController.java` | 182-183 | yes |
| 338 | `src/main/java/org/springframework/samples/petclinic/owner/OwnerController.java` | 68-69 | yes |
| 338 | `src/main/resources/application.properties` | 1-29 | yes |
| 338 | `src/main/resources/templates/error.html` | 18 | yes |
| 338 | `src/test/java/org/springframework/samples/petclinic/system/CrashControllerIntegrationTests.java` | 51 | yes |
| 339 | `src/main/java/org/springframework/samples/petclinic/owner/PetController.java` | 70 | yes |
| 339 | `src/main/java/org/springframework/samples/petclinic/owner/PetController.java` | 84 | yes |
| 339 | `src/main/resources/application.properties` | 1-29 | yes |
| 339 | `src/test/java/org/springframework/samples/petclinic/system/CrashControllerIntegrationTests.java` | 51 | yes |
| 340 | `src/main/java/org/springframework/samples/petclinic/owner/VisitController.java` | 72 | yes |
| 340 | `src/main/resources/application.properties` | 1-29 | yes |
| 340 | `src/test/java/org/springframework/samples/petclinic/system/CrashControllerIntegrationTests.java` | 51 | yes |
| 341 | `src/main/java/org/springframework/samples/petclinic/owner/PetController.java` | 111-113 | yes |
| 341 | `src/main/resources/db/h2/schema.sql` | 55 | yes |
| 341 | `src/main/resources/messages/messages.properties` | 4 | yes |
| 341 | `src/main/resources/messages/messages.properties` | 4 | yes |
| 342 | `src/main/java/org/springframework/samples/petclinic/owner/PetController.java` | 115-118 | yes |
| 342 | `src/main/resources/messages/messages.properties` | 8 | yes |
| 343 | `src/main/java/org/springframework/samples/petclinic/owner/VisitController.java` | 100-102 | yes |
| 343 | `src/main/resources/messages/messages.properties` | 9 | yes |
| 344 | `src/main/java/org/springframework/samples/petclinic/owner/Owner.java` | 62-64 | yes |
| 345 | `src/main/java/org/springframework/samples/petclinic/owner/OwnerController.java` | 80-81 | yes |
| 346 | `src/main/java/org/springframework/samples/petclinic/owner/PetTypeFormatter.java` | 59 | yes |
| 347 | `src/main/java/org/springframework/samples/petclinic/system/CrashController.java` | 33-34 | yes |
| 347 | `src/main/resources/application.properties` | 1-29 | yes |
| 347 | `src/test/java/org/springframework/samples/petclinic/system/CrashControllerIntegrationTests.java` | 51 | yes |
| 348 | `src/main/java/org/springframework/samples/petclinic/owner/PetController.java` | 202-205 | yes |
| 348 | `src/main/resources/db/mysql/schema.sql` | 47 | yes |
| 356 | `pom.xml` | 41-66 | yes |
| 356 | `pom.xml` | 43-46 | yes |
| 356 | `src/main/resources/application.properties` | 19-21 | yes |
| 357 | `README.md` | 1 | yes |
| 357 | `README.md` | 5-12 | yes |
| 357 | `pom.xml` | 41-66 | yes |
| 357 | `src/main/java/org/springframework/samples/petclinic/model/Person.java` | 31-39 | yes |
| 357 | `src/main/java/org/springframework/samples/petclinic/owner/Owner.java` | 52-65 | yes |
| 357 | `src/main/java/org/springframework/samples/petclinic/owner/OwnerController.java` | 72-130 | yes |
| 358 | `docker-compose.yml` | 4-5 | yes |
| 358 | `docker-compose.yml` | 7-8 | yes |
| 358 | `k8s/db.yml` | 5-14 | yes |
| 358 | `src/main/resources/application-mysql.properties` | 4-5 | yes |
| 358 | `src/main/resources/application-postgres.properties` | 4-5 | yes |
| 359 | `src/main/java/org/springframework/samples/petclinic/owner/PetController.java` | 202-205 | yes |
| 359 | `src/main/resources/db/mysql/schema.sql` | 47 | yes |
| 359 | `src/main/resources/db/postgres/schema.sql` | 45 | yes |
| 360 | `src/main/java/org/springframework/samples/petclinic/owner/OwnerController.java` | 157-158 | yes |
| 360 | `src/main/java/org/springframework/samples/petclinic/owner/OwnerController.java` | 80-81 | yes |
| 360 | `src/main/resources/templates/fragments/inputField.html` | 19 | yes |
| 360 | `src/main/resources/templates/owners/createOrUpdateOwnerForm.html` | 10-14 | yes |
| 361 | `src/main/java/org/springframework/samples/petclinic/system/CrashController.java` | 31-35 | yes |
| 361 | `src/main/resources/templates/fragments/layout.html` | 56-57 | yes |
| 367 | `build.gradle` | 33-40 | yes |
| 367 | `pom.xml` | 41-66 | yes |
| 368 | `k8s/petclinic.yml` | 7-10 | yes |
| 368 | `src/main/resources/application.properties` | 1-29 | yes |
| 369 | `pom.xml` | 41-66 | yes |
| 369 | `src/main/resources/templates/owners/createOrUpdateOwnerForm.html` | 8-20 | yes |
| 370 | `pom.xml` | 41-66 | yes |
| 371 | `src/main/java/org/springframework/samples/petclinic/system/WebConfiguration.java` | 32-37 | yes |
| 371 | `src/main/resources/application.properties` | 1-29 | yes |
| 372 | `pom.xml` | 41-66 | yes |
| 373 | `src/main/java/org/springframework/samples/petclinic/owner/OwnerController.java` | 48-188 | yes |
| 373 | `src/main/resources/application.properties` | 24 | yes |
| 374 | `docker-compose.yml` | 1-20 | yes |
| 374 | `docker-compose.yml` | 12-13 | yes |
| 374 | `k8s/db.yml` | 15-70 | yes |
| 375 | `k8s/db.yml` | 5-14 | yes |
| 375 | `src/main/resources/application-postgres.properties` | 3-5 | yes |
| 376 | `src/main/java/org/springframework/samples/petclinic/owner/Owner.java` | 52-65 | yes |
| 376 | `src/main/java/org/springframework/samples/petclinic/owner/PetValidator.java` | 38-59 | yes |
| 376 | `src/main/java/org/springframework/samples/petclinic/owner/VisitController.java` | 100-102 | yes |
| 377 | `src/main/java/org/springframework/samples/petclinic/owner/OwnerController.java` | 59-62 | yes |
| 377 | `src/main/java/org/springframework/samples/petclinic/owner/PetController.java` | 89-98 | yes |
| 377 | `src/main/java/org/springframework/samples/petclinic/owner/VisitController.java` | 51-54 | yes |
| 383 | `LICENSE.txt` | 1-5 | yes |
| 384 | `pom.xml` | 5-14 | yes |
| 385 | `README.md` | 58-60 | yes |
| 386 | `src/main/resources/db/mysql/petclinic_db_setup_mysql.txt` | 1-10 | yes |
| 387 | `README.md` | 1-16 | yes |
| 388 | `.github/workflows/gradle-build.yml` | 6-11 | yes |
| 388 | `.github/workflows/maven-build.yml` | 6-11 | yes |
| 388 | `pom.xml` |  | yes |
| 388 | `pom.xml` | 23 | yes |
| 389 | `src/test/java/org/springframework/samples/petclinic/owner/OwnerControllerTests.java` | 60-63 | yes |
| 390 | `src/test/java/org/springframework/samples/petclinic/service/ClinicServiceTests.java` | 72-76 | yes |
| 391 | `src/test/java/org/springframework/samples/petclinic/MySqlIntegrationTests.java` | 41-46 | yes |
| 391 | `src/test/java/org/springframework/samples/petclinic/PetClinicIntegrationTests.java` | 34-35 | yes |
| 391 | `src/test/java/org/springframework/samples/petclinic/PostgresIntegrationTests.java` | 51-55 | yes |
| 392 | `src/test/java/org/springframework/samples/petclinic/PetClinicConcurrencyTests.java` | 28-41 | yes |
| 393 | `src/test/java/org/springframework/samples/petclinic/system/I18nPropertiesSyncTest.java` | 25-44 | yes |
| 398 | `.github/workflows/gradle-build.yml` | 30-31 | yes |
| 398 | `.github/workflows/maven-build.yml` | 28-29 | yes |
| 399 | `src/main/resources/db/h2/schema.sql` | 1-65 | yes |
| 399 | `src/main/resources/db/mysql/schema.sql` | 1-50 | yes |
| 399 | `src/main/resources/db/postgres/schema.sql` | 1-47 | yes |
| 417 | `src/main/java/org/springframework/samples/petclinic/owner/PetController.java` | 107-136 | yes |
| 427 | `src/main/resources/db/h2/schema.sql` | 28-64 | yes |
| 439 | `README.md` | 25-34 | yes |
| 439 | `docker-compose.yml` | 1-20 | yes |
| 439 | `k8s/petclinic.yml` | 15-64 | yes |
| 445 | `src/main/java/org/springframework/samples/petclinic/owner/Owner.java` | 48-50 | yes |
| 446 | `src/main/java/org/springframework/samples/petclinic/owner/Pet.java` | 44-46 | yes |
| 447 | `src/main/java/org/springframework/samples/petclinic/owner/PetTypeRepository.java` | 36-37 | yes |
| 448 | `src/main/java/org/springframework/samples/petclinic/owner/Visit.java` | 35-37 | yes |
| 449 | `src/main/java/org/springframework/samples/petclinic/vet/Vet.java` | 43-50 | yes |
| 450 | `src/main/java/org/springframework/samples/petclinic/vet/Vets.java` | 30-41 | yes |
| 451 | `src/main/java/org/springframework/samples/petclinic/model/BaseEntity.java` | 32-49 | yes |
| 452 | `src/main/resources/templates/owners/ownerDetails.html` | 9-14 | yes |
| 453 | `src/main/resources/application-mysql.properties` | 1-3 | yes |
| 454 | `src/main/resources/db/h2/schema.sql` | 55 | yes |
| 455 | `src/main/java/org/springframework/samples/petclinic/system/CacheConfiguration.java` | 37 | yes |
| 456 | `src/main/resources/application.properties` | 21 | yes |
| 463 | `src/main/resources/application.properties` | 21 | yes |
| 464 | `k8s/petclinic.yml` | 33 | yes |
| 465 | `README.md` | 14-56 | yes |
| 466 | `README.md` | 65 | yes |
| 466 | `README.md` | 99 | yes |
| 466 | `build.gradle` | 49 | yes |
| 466 | `pom.xml` | 117 | yes |
| 466 | `pom.xml` | 76-80 | yes |
| 466 | `src/main/resources/application.properties` | 1-29 | yes |
| 489 | `docs/appdoc/evidence.jsonl` | 1 | yes |
| 489 | `pom.xml` | 1-10 | yes |
| 495 | `.github/workflows/maven-build.yml` | 22-25 | yes |
| 495 | `.mvn/wrapper/maven-wrapper.properties` | 3 | yes |
| 495 | `README.md` | 17 | yes |
| 495 | `build.gradle` | 17-21 | yes |
| 495 | `pom.xml` | 19 | yes |
| 495 | `pom.xml` | 5-9 | yes |
| 499 | `docker-compose.yml` | 1-20 | yes |
| 499 | `src/main/resources/application-mysql.properties` | 6-7 | yes |
| 499 | `src/main/resources/application.properties` | 2-4 | yes |
| 499 | `src/main/resources/db/h2/data.sql` |  | yes |
| 499 | `src/main/resources/db/h2/schema.sql` |  | yes |
| 499 | `src/main/resources/db/mysql/petclinic_db_setup_mysql.txt` | 1-20 | yes |
| 499 | `src/main/resources/db/postgres/schema.sql` | 1-6 | yes |
| 503 | `src/main/java/org/springframework/samples/petclinic/system/WebConfiguration.java` | 32-49 | yes |
| 503 | `src/main/resources/application.properties` | 1-29 | yes |
| 509 | `README.md` | 85-95 | yes |
| 510 | `src/main/java/org/springframework/samples/petclinic/system/CacheConfiguration.java` | 35-51 | yes |
| 511 | `.github/workflows/deploy-and-test-cluster.yml` | 29-31 | yes |
| 512 | `src/main/java/org/springframework/samples/petclinic/owner/OwnerController.java` | 68-69 | yes |
| 512 | `src/main/resources/templates/error.html` | 18 | yes |
| 518 | `.github/workflows/gradle-build.yml` | 30-31 | yes |
| 518 | `.github/workflows/maven-build.yml` | 28-29 | yes |
| 519 | `.github/workflows/gradle-build.yml` | 31 | yes |
| 519 | `.github/workflows/maven-build.yml` | 29 | yes |
| 520 | `.github/workflows/deploy-and-test-cluster.yml` | 20-26 | yes |
| 520 | `k8s/` |  | yes |
| 521 | `README.md` | 14-56 | yes |
| 522 | `README.md` | 14-56 | yes |
| 523 | `docker-compose.yml` | 1-20 | yes |
| 524 | `docker-compose.yml` | 1-20 | yes |
| 525 | `k8s/db.yml` | 5-14 | yes |
| 532 | `src/main/resources/application-mysql.properties` | 5 | yes |
| 533 | `src/main/resources/application-mysql.properties` | 2 | yes |
| 534 | `src/main/resources/application-mysql.properties` | 3 | yes |
| 535 | `src/main/resources/application-mysql.properties` | 4 | yes |
| 536 | `src/main/resources/application-mysql.properties` | 7 | yes |
| 537 | `src/main/resources/application.properties` | 3 | yes |
| 538 | `src/main/resources/application.properties` | 4 | yes |
| 539 | `src/main/resources/application.properties` | 7 | yes |
| 540 | `src/main/resources/application.properties` | 10 | yes |
| 541 | `src/main/resources/application.properties` | 11 | yes |
| 542 | `src/main/resources/application.properties` | 12 | yes |
| 543 | `src/main/resources/application.properties` | 13 | yes |
| 544 | `src/main/resources/application.properties` | 16 | yes |
| 545 | `src/main/resources/application.properties` | 21 | yes |
| 546 | `src/main/resources/application.properties` | 24 | yes |
| 547 | `src/main/resources/application.properties` | 29 | yes |
| 556 | `src/main/resources/application.properties` | 21 | yes |
| 557 | `src/main/resources/application-mysql.properties` | 7 | yes |
| 558 | `src/main/resources/application.properties` | 10 | yes |
| 566 | `src/main/java/org/springframework/samples/petclinic/PetClinicApplication.java` | 28-34 | yes |
| 572 | `README.md` | 17 | yes |
| 572 | `pom.xml` | 19 | yes |
| 573 | `.github/workflows/maven-build.yml` | 28-29 | yes |
| 574 | `.github/workflows/maven-build.yml` | 29 | yes |
| 575 | `README.md` | 28 | yes |
| 576 | `.github/workflows/gradle-build.yml` | 31 | yes |
| 578 | `README.md` | 33 | yes |
| 578 | `README.md` | 36 | yes |
| 578 | `build.gradle` | 61-62 | yes |
| 578 | `build.gradle` | 70-73 | yes |
| 578 | `pom.xml` | 205-247 | yes |
| 578 | `src/test/java/org/springframework/samples/petclinic/MySqlIntegrationTests.java` | 43 | yes |

## Verification

**Source-to-claim audit:** performed (auditor: independent). 61 rows (26 superseded): 61 Supported, 0 Corrected, 0 Downgraded.

| Section | IDs with a register row |
|---|---|
| 4 | 13 of 13 |
| 6 | 9 of 9 |
| 8.1 | 4 of 4 |
| 8.3 | 1 of 1 |
| 10.1 | 6 of 6 |
| 14 | 6 of 6 |
| 15 | 9 of 9 |
| 7 (workflows) | 9 of 9 |
