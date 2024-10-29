# Builder stage
FROM swift:5.9-jammy as builder

# Set up work directory
WORKDIR /build

# Create a Docker-specific Package.swift without tests
RUN echo '\
// swift-tools-version: 5.9\n\
import PackageDescription\n\
\n\
let package = Package(\n\
    name: "Swollama",\n\
    platforms: [.macOS(.v13)],\n\
    products: [\n\
        .library(name: "Swollama", targets: ["Swollama"]),\n\
        .executable(name: "SwollamaCLI", targets: ["SwollamaCLI"])\n\
    ],\n\
    targets: [\n\
        .target(name: "Swollama"),\n\
        .executableTarget(\n\
            name: "SwollamaCLI",\n\
            dependencies: ["Swollama"])\n\
    ]\n\
)' > Package.swift

# Copy source files
COPY Sources ./Sources/

# Build the CLI executable in release configuration
RUN swift build --configuration release --product SwollamaCLI

# Runtime stage
FROM swift:5.9-jammy-slim

# Install required runtime libraries
RUN apt-get update && apt-get install -y \
    libcurl4 \
    libxml2 \
    && rm -rf /var/lib/apt/lists/*

# Create a non-root user for security
RUN useradd -m swollama

# Set up work directory
WORKDIR /app

# Copy the built executable
COPY --from=builder /build/.build/release/SwollamaCLI /app/SwollamaCLI

# Set ownership
RUN chown -R swollama:swollama /app

# Switch to non-root user
USER swollama

# Set the entrypoint
ENTRYPOINT ["/app/SwollamaCLI"]