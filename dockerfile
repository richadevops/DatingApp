# ----------- Stage 1: Build Angular frontend -----------
FROM node:20 AS angular-build
WORKDIR /app

# Copy package.json and package-lock.json
COPY client/package*.json ./

# Install dependencies
RUN npm install

# Copy the rest of the Angular app
COPY client/ ./

# Build Angular app for production
RUN npm run build -- --output-path=dist

# ----------- Stage 2: Build ASP.NET backend -----------
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src

# Copy solution and project files
COPY ["DatingApp.sln", "./"]
COPY ["API/API.csproj", "API/"]

# Restore dependencies
RUN dotnet restore "API/API.csproj"

# Copy the rest of the source code
COPY . .

# Copy Angular build into wwwroot
RUN rm -rf API/wwwroot && mkdir -p API/wwwroot
COPY --from=angular-build /app/dist ./API/wwwroot

# Build and publish backend
WORKDIR "/src/API"
RUN dotnet build -c Release -o /app/build
RUN dotnet publish -c Release -o /app/publish

# ----------- Stage 3: Runtime -----------
FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS runtime
WORKDIR /app

# Azure App Service expects port 80
ENV ASPNETCORE_URLS=http://+:80
EXPOSE 80

# Copy published backend
COPY --from=build /app/publish ./

# Start the app
ENTRYPOINT ["dotnet", "API.dll"]
