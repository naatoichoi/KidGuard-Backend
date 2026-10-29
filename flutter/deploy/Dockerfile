FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src
COPY phamngocanh.csproj .
RUN dotnet restore phamngocanh.csproj
COPY . .
RUN dotnet publish phamngocanh.csproj -c Release --no-restore -o /publish /p:UseAppHost=false

FROM mcr.microsoft.com/dotnet/aspnet:10.0
WORKDIR /app
COPY --from=build /publish .
ENV ASPNETCORE_HTTP_PORTS=8080
EXPOSE 8080
USER $APP_UID
ENTRYPOINT ["dotnet", "phamngocanh.dll"]
