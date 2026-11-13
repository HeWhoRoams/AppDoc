using Microsoft.Extensions.Logging;

namespace Smells;

public class MismatchedHandler(ILogger<OtherHandler> logger)
{
    public void Run() => logger.LogInformation("x");
}

public class FieldMismatch
{
    private readonly ILogger<SomethingElse> _logger;

    public FieldMismatch(ILogger<SomethingElse> logger)
    {
        _logger = logger;
    }
}

// public class CommentedOut(ILogger<Nope> logger) { }

public class Matching(ILogger<Matching> logger)
{
}

public class GenericOk<T>(ILogger<T> logger)
{
}

public class ObjectOk(ILogger<object> logger)
{
}

public class Helper
{
    public static void Log(ILogger<Unrelated> logger) { }
}
