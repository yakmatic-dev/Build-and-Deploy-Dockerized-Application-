# ============================
# Build stage
# ============================
FROM maven:3.9-eclipse-temurin-17 AS build
WORKDIR /app

# Copy pom.xml and download dependencies (cached layer)
COPY pom.xml .
RUN mvn dependency:go-offline -B

# Copy source code
COPY src ./src

# Build the application
RUN mvn clean package -DskipTests


# ============================
# Runtime stage
# ============================
FROM eclipse-temurin:17-jre-alpine
WORKDIR /app

# Create a non-root user and group
RUN addgroup -S spring && adduser -S spring -G spring
USER spring:spring

# Copy the built jar from the build stage with correct ownership
COPY --from=build --chown=spring:spring /app/target/*.jar app.jar

# Expose the Spring Boot default port
EXPOSE 8080

# Run the application
ENTRYPOINT ["java", "-jar", "/app/app.jar"]

