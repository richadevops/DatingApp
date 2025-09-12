# =======================
# 1. Base image for runtime
# =======================
FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS base
WORKDIR /app
ENV ASPNETCORE_URLS=http://+:80
EXPOSE 80

# =======================
# 2. Build stage (with Node + Angular + .NET SDK)
# =======================
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build

# Install Node.js (needed for Angular)
RUN curl -sL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs

WORKDIR /src

# Copy csproj files first (for layer caching)
COPY ["./MongoBookStoreApp.Contracts/MongoBookStoreApp.Contracts.csproj", "src/MongoBookStoreApp.Contracts/"]
COPY ["./MongoBookStoreApp.Core/MongoBookStoreApp.Core.csproj", "src/MongoBookStoreApp.Core/"]
COPY ["./MongoBookStoreApp.Web/MongoBookStoreApp.Web.csproj", "src/MongoBookStoreApp.Web/"]

# Restore NuGet packages
RUN dotnet restore "src/MongoBookStoreApp.Web/MongoBookStoreApp.Web.csproj"

# Copy all code
COPY . .

# =======================
# 3. Build Angular
# =======================
WORKDIR /src/MongoBookStoreApp.Web/ClientApp

# Install Angular dependencies
RUN npm ci

# Build Angular app (production)
RUN npm run build -- --configuration production

# =======================
# 4. Build & publish .NET Web project
# =======================
WORKDIR /src/MongoBookStoreApp.Web
RUN dotnet build -c Release -o /app/build
RUN dotnet publish -c Release -o /app/publish

# =======================
# 5. Final runtime image
# =======================
FROM base AS final
WORKDIR /app

# Copy published output
COPY --from=build /app/publish .

# Copy Angular dist into wwwroot
COPY --from=build /src/MongoBookStoreApp.Web/ClientApp/dist ./wwwroot

ENTRYPOINT ["dotnet", "MongoBookStoreApp.Web.dll"]
