using System.Text.Json;
using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.CSharp;
using Microsoft.CodeAnalysis.CSharp.Syntax;

if (args.Length < 1)
{
    Console.Error.WriteLine("Usage: AppDoc.CSharpAstParser <rootPath>");
    Environment.Exit(1);
}

var rootPath = Path.GetFullPath(args[0]);
if (!Directory.Exists(rootPath))
{
    Console.Error.WriteLine($"Root path does not exist: {rootPath}");
    Environment.Exit(1);
}

var records = new List<object>();
var csFiles = Directory
    .EnumerateFiles(rootPath, "*.cs", SearchOption.AllDirectories)
    .Where(path => !path.Contains($"{Path.DirectorySeparatorChar}bin{Path.DirectorySeparatorChar}", StringComparison.OrdinalIgnoreCase)
        && !path.Contains($"{Path.DirectorySeparatorChar}obj{Path.DirectorySeparatorChar}", StringComparison.OrdinalIgnoreCase))
    .Where(path => !path.Contains($"{Path.DirectorySeparatorChar}.appdoc{Path.DirectorySeparatorChar}tools{Path.DirectorySeparatorChar}", StringComparison.OrdinalIgnoreCase))
    .ToList();

foreach (var filePath in csFiles)
{
    var content = File.ReadAllText(filePath);
    if (string.IsNullOrWhiteSpace(content))
    {
        continue;
    }

    var syntaxTree = CSharpSyntaxTree.ParseText(content);
    var root = syntaxTree.GetRoot();

    var relativePath = Path.GetRelativePath(rootPath, filePath).Replace('\\', '/');

    foreach (var classDecl in root.DescendantNodes().OfType<ClassDeclarationSyntax>())
    {
        var properties = classDecl.Members
            .OfType<PropertyDeclarationSyntax>()
            .Select(property => $"{property.Identifier.ValueText}: {property.Type}")
            .ToArray();

        records.Add(new
        {
            file = relativePath,
            kind = "model",
            name = classDecl.Identifier.ValueText,
            lineNumber = classDecl.GetLocation().GetLineSpan().StartLinePosition.Line + 1,
            metadata = new
            {
                modelType = "class",
                properties,
                language = "C#"
            },
            provider = "roslyn",
            confidence = 0.95
        });
    }

    foreach (var interfaceDecl in root.DescendantNodes().OfType<InterfaceDeclarationSyntax>())
    {
        var properties = interfaceDecl.Members
            .OfType<PropertyDeclarationSyntax>()
            .Select(property => $"{property.Identifier.ValueText}: {property.Type}")
            .ToArray();

        records.Add(new
        {
            file = relativePath,
            kind = "model",
            name = interfaceDecl.Identifier.ValueText,
            lineNumber = interfaceDecl.GetLocation().GetLineSpan().StartLinePosition.Line + 1,
            metadata = new
            {
                modelType = "interface",
                properties,
                language = "C#"
            },
            provider = "roslyn",
            confidence = 0.93
        });
    }

    foreach (var methodDecl in root.DescendantNodes().OfType<MethodDeclarationSyntax>())
    {
        var attrs = methodDecl.AttributeLists
            .SelectMany(list => list.Attributes)
            .ToList();

        var httpAttr = attrs.FirstOrDefault(attribute =>
        {
            var name = attribute.Name.ToString();
            return name is "HttpGet" or "HttpPost" or "HttpPut" or "HttpDelete" or "HttpPatch"
                or "HttpGetAttribute" or "HttpPostAttribute" or "HttpPutAttribute" or "HttpDeleteAttribute" or "HttpPatchAttribute";
        });
        if (httpAttr is null)
        {
            continue;
        }

        var method = httpAttr.Name.ToString().Replace("Http", "", StringComparison.OrdinalIgnoreCase).ToUpperInvariant();
        var path = string.Empty;

        if (httpAttr.ArgumentList?.Arguments.Count > 0)
        {
            var firstArg = httpAttr.ArgumentList.Arguments[0].Expression;
            if (firstArg is LiteralExpressionSyntax literal)
            {
                path = literal.Token.ValueText;
            }
            else
            {
                path = firstArg.ToString().Trim('"');
            }
        }

        var controller = "Other";
        var containingClass = methodDecl.Parent as ClassDeclarationSyntax;
        if (containingClass is not null)
        {
            var className = containingClass.Identifier.ValueText;
            controller = className.EndsWith("Controller", StringComparison.Ordinal)
                ? className[..^"Controller".Length]
                : className;
        }

        var returnType = methodDecl.ReturnType.ToString();
        var parameters = methodDecl.ParameterList.Parameters
            .Select(parameter => $"{parameter.Identifier.ValueText}: {parameter.Type ?? SyntaxFactory.ParseTypeName("object")}")
            .ToArray();

        var hasAuthorize = attrs.Any(attribute => attribute.Name.ToString().Contains("Authorize", StringComparison.OrdinalIgnoreCase));

        records.Add(new
        {
            file = relativePath,
            kind = "endpoint",
            name = methodDecl.Identifier.ValueText,
            lineNumber = methodDecl.GetLocation().GetLineSpan().StartLinePosition.Line + 1,
            metadata = new
            {
                language = "C#",
                method,
                path,
                controller,
                returnType,
                parameters,
                auth = hasAuthorize ? "Required (Authorization)" : "None",
                description = "Roslyn extracted endpoint"
            },
            provider = "roslyn",
            confidence = 0.96
        });
    }
}

var payload = new
{
    generatedAt = DateTimeOffset.Now,
    provider = "roslyn",
    providerReady = true,
    records,
    note = "Extracted using Microsoft.CodeAnalysis (Roslyn)."
};

var options = new JsonSerializerOptions
{
    WriteIndented = true
};

Console.WriteLine(JsonSerializer.Serialize(payload, options));
