# gitops-self-healing-api

A simple Task/Todo REST API built with **Java 17**, **Spring Boot**, and **Maven**. It was created as the starter application for a college DevOps assignment. Data is stored only in memory — no database and no authentication.

## What the application does

- Lets you store Todo items in an in-memory list.
- Returns all todos as JSON.
- Provides a health endpoint that reports the application status.
- Runs on port **8080**.

## How to run it

Requirements: Java 17+ and Maven.

```bash
# Build the project
mvn clean package

# Run the application
mvn spring-boot:run
```

Or run the packaged jar:

```bash
java -jar target/gitops-self-healing-api-1.0.0.jar
```

The application starts at `http://localhost:8080`.

## API endpoints

| Method | Path     | Description                          | Request body example                                      |
|--------|----------|--------------------------------------|-----------------------------------------------------------|
| GET    | `/todos` | Return all todos                     | —                                                         |
| POST   | `/todos` | Add a new todo                       | `{"title": "Buy milk", "completed": false}`               |
| GET    | `/health`| Return application health status     | —                                                         |

### Example responses

`GET /health`

```json
{"status": "UP"}
```

`POST /todos`

```json
{"id": 1, "title": "Buy milk", "completed": false}
```

## How to test it

Run the unit tests with Maven:

```bash
mvn test
```

Test the endpoints manually with `curl`:

```bash
# Check health
curl http://localhost:8080/health

# Add a todo
curl -X POST http://localhost:8080/todos \
  -H "Content-Type: application/json" \
  -d '{"title": "Buy milk", "completed": false}'

# Get all todos
curl http://localhost:8080/todos
```
