using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.OpenApi;
using Microsoft.OpenApi;

namespace phamngocanh.Services;

public sealed class ApiDocumentation : IOpenApiDocumentTransformer
{
    public Task TransformAsync(OpenApiDocument document,
        OpenApiDocumentTransformerContext context, CancellationToken cancellationToken)
    {
        document.Info.Title = "phamngocanh - KidGuard API";
        document.Info.Version = "v1";
        document.Info.Description = null;
        // Keep requests on the same public host, including a changed Conveyor URL.
        document.Servers = [new OpenApiServer { Url = "/" }];
        document.Components ??= new OpenApiComponents();
        document.Components.SecuritySchemes ??= new Dictionary<string, IOpenApiSecurityScheme>();
        document.Components.SecuritySchemes["Bearer"] = new OpenApiSecurityScheme
        {
            Type = SecuritySchemeType.Http,
            Scheme = "bearer",
            BearerFormat = "JWT",
            Description = "Dán accessToken nhận được sau khi xác minh OTP."
        };

        foreach (var description in context.DescriptionGroups.SelectMany(group => group.Items))
        {
            var metadata = description.ActionDescriptor.EndpointMetadata;
            var authorization = metadata.OfType<IAuthorizeData>().ToArray();
            if (authorization.Length == 0 || metadata.OfType<IAllowAnonymous>().Any()) continue;
            var path = "/" + description.RelativePath?.Split('?')[0];
            if (!document.Paths.TryGetValue(path, out var item) || item.Operations == null) continue;
            var operation = item.Operations.FirstOrDefault(pair =>
                string.Equals(pair.Key.ToString(), description.HttpMethod,
                    StringComparison.OrdinalIgnoreCase)).Value;
            if (operation == null) continue;
            operation.Security ??= [];
            operation.Security.Add(new OpenApiSecurityRequirement
            {
                [new OpenApiSecuritySchemeReference("Bearer", document)] = []
            });
            var roles = string.Join(", ", authorization.Select(value => value.Roles)
                .Where(value => !string.IsNullOrWhiteSpace(value)));
            operation.Description = (operation.Description + "\n\n" +
                (roles.Length > 0 ? $"Quyền yêu cầu: {roles}." : "Yêu cầu đăng nhập bằng JWT.")).Trim();
        }
        return Task.CompletedTask;
    }
}
