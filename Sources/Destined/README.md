# HoshiHoshi

HoshiHoshi is a web service built with Swift, Vapor, and VaporElementary.

## Running the Application

To run HoshiHoshi locally:

```bash
swift run HoshiHoshi
```

The application will start on `http://localhost:4444` by default.

### Port Configuration

HoshiHoshi uses different ports for different environments:

- **Local Development**: `http://localhost:4444` (default)

- **Production/Docker**: `http://localhost:8080` (automatic when `ENV=PRODUCTION`)

You can override the default port using the `PORT` environment variable:

```bash
PORT=3000 swift run HoshiHoshi
```

### Environment Variables

- `ENV`: Set to `PRODUCTION` for production configuration (port 8080, hostname 0.0.0.0)

- `PORT`: Override the default port for any environment

## Building

To build the application:

```bash
swift build --product HoshiHoshi
```

## Testing

To run tests for HoshiHoshi:

```bash
swift test --filter HoshiHoshiTests
```

## Docker

To build and run with Docker:

```bash
docker build -f Sources/HoshiHoshi/Dockerfile -t hoshihoshi .
docker run -p 8080:8080 hoshihoshi
```

## TODO

- Astro Lines
- Intro quiz to get to know the user
- Blue & Green Colors
