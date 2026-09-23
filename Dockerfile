# Lightweight Java 21 runtime (Alpine base is smaller than Ubuntu-based JRE images).
FROM eclipse-temurin:21-jre-alpine

# Dedicated non-root user to run the application.
RUN addgroup -S app && adduser -S -G app -H -D app

WORKDIR /app

# The Maven-built Spring Boot JAR.
COPY target/gitops-self-healing-api-1.0.0.jar /app/gitops-self-healing-api-1.0.0.jar

# Spring Boot listens on 8080 by default (server.port in application.properties).
EXPOSE 8080

USER app

ENTRYPOINT ["java", "-jar", "/app/gitops-self-healing-api-1.0.0.jar"]