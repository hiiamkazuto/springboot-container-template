# syntax=docker/dockerfile:1

FROM eclipse-temurin:25-jdk-noble AS dependencies

WORKDIR /workspace

COPY --chmod=0755 mvnw mvnw
COPY .mvn/ .mvn/

RUN --mount=type=bind,source=pom.xml,target=pom.xml \
    --mount=type=cache,target=/root/.m2 \
    ./mvnw dependency:go-offline -DskipTests

FROM dependencies AS builder

WORKDIR /workspace

COPY ./src src/

RUN --mount=type=bind,source=pom.xml,target=pom.xml \
    --mount=type=cache,target=/root/.m2 \
    ./mvnw package -DskipTests && \
    mv target/*.jar target/app.jar

FROM builder AS extract

WORKDIR /workspace

RUN java -Djarmode=tools -jar target/app.jar extract --layers --launcher --destination target/extracted

FROM gcr.io/distroless/java25-debian13:nonroot AS final

COPY --from=extract --chown=nonroot:nonroot /workspace/target/extracted/dependencies/ ./
COPY --from=extract --chown=nonroot:nonroot /workspace/target/extracted/spring-boot-loader/ ./
COPY --from=extract --chown=nonroot:nonroot /workspace/target/extracted/snapshot-dependencies/ ./
COPY --from=extract --chown=nonroot:nonroot /workspace/target/extracted/application/ ./

EXPOSE 8080

ENTRYPOINT ["java", "org.springframework.boot.loader.launch.JarLauncher"]
