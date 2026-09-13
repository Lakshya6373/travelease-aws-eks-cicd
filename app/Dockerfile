# ── Stage 1: Build ────────────────────────────────────────────────────────────
FROM maven:3.9-eclipse-temurin-17 AS build
WORKDIR /app

# Fetch dependencies first (better layer caching — only re-runs when pom.xml changes)
COPY pom.xml .
RUN mvn dependency:go-offline -q

# Build the application
COPY src ./src
RUN mvn package -DskipTests -q

# ── Stage 2: Runtime ──────────────────────────────────────────────────────────
FROM eclipse-temurin:17-jre-alpine

# Create a non-root user and group
RUN addgroup -S spring && adduser -S spring -G spring

WORKDIR /app

# Copy the fat JAR from the build stage
COPY --from=build /app/target/*.jar app.jar

# Drop privileges
USER spring

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "/app/app.jar"]
